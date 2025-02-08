import cv2
from ultralytics import YOLO
import threading
import time
import os
import subprocess  # For FFmpeg streaming
import concurrent.futures

# ─────────────────────────────────────────────────────────────────────────────
# Firebase Setup
# ─────────────────────────────────────────────────────────────────────────────
import firebase_admin
from firebase_admin import credentials, storage, messaging

# Initialize Firebase Admin SDK with your JSON credentials.
cred = credentials.Certificate("recordingstorage-58932-firebase-adminsdk-fbsvc-4df68cf7ba.json")
firebase_admin.initialize_app(cred, {
    'storageBucket': 'recordingstorage-58932.firebasestorage.app'
})
bucket = storage.bucket()

def upload_to_firebase(local_path, remote_path):
    """
    Uploads a local file to Firebase Storage and then deletes the local file.
    """
    try:
        blob = bucket.blob(remote_path)
        blob.upload_from_filename(local_path)
        print(f"✅ Uploaded '{local_path}' to Firebase as '{remote_path}'")
        if os.path.exists(local_path):
            os.remove(local_path)
            print(f"🗑️  Removed local file '{local_path}' after upload.")
    except Exception as e:
        print(f"❌ Firebase upload error: {e}")

# Executor for asynchronous uploads
upload_executor = concurrent.futures.ThreadPoolExecutor(max_workers=4)

# ─────────────────────────────────────────────────────────────────────────────
# Camera Configuration & Local Directories
# ─────────────────────────────────────────────────────────────────────────────
camera_configs = [
    {
        "ip_url": "http://10.115.27.194:8080/video",
        "rtsp_url": "rtsp://localhost:8554/cam1",
        "name": "Camera 1"
    },
    {
        "ip_url": "http://10.115.21.13:8080/video",
        "rtsp_url": "rtsp://localhost:8554/cam2",
        "name": "Camera 2"
    }
]

# Temporary local folders (files will be deleted after upload)
os.makedirs("videos1", exist_ok=True)
os.makedirs("pictures1", exist_ok=True)
os.makedirs("videos2", exist_ok=True)
os.makedirs("pictures2", exist_ok=True)

# ─────────────────────────────────────────────────────────────────────────────
# Global Variables & Model Setup
# ─────────────────────────────────────────────────────────────────────────────
model = YOLO('yolo11s.pt').to('cuda')  # Ensure your YOLO model uses the GPU

# Confidence thresholds
DETECTION_CONFIDENCE = 0.7
NOTIFICATION_CONFIDENCE = 0.7

# Shared frame buffers and locks
raw_frames = [None] * len(camera_configs)
raw_frame_locks = [threading.Lock() for _ in camera_configs]

annotated_frames = [None] * len(camera_configs)
annotated_frame_locks = [threading.Lock() for _ in camera_configs]

# Recording state per camera
recording = [False] * len(camera_configs)
video_writers = [None] * len(camera_configs)
video_filenames = [None] * len(camera_configs)
last_detection_time = [0] * len(camera_configs)
snapshot_taken = [False] * len(camera_configs)
notification_sent = [False] * len(camera_configs)  # One notification per recording session

# Record for 5 seconds after the last detection
record_duration_after_motion = 5

# Global flag to signal threads to stop
stop_threads = False

# Desired capture resolution (720p)
CAPTURE_WIDTH = 1280
CAPTURE_HEIGHT = 720

# ─────────────────────────────────────────────────────────────────────────────
# FFmpeg Streaming Pipe
# ─────────────────────────────────────────────────────────────────────────────
def start_ffmpeg_stream_pipe(rtsp_url):
    cmd = [
        "ffmpeg",
        "-f", "rawvideo",
        "-pix_fmt", "bgr24",
        "-s", f"{CAPTURE_WIDTH}x{CAPTURE_HEIGHT}",
        "-i", "pipe:0",
        "-vf", "scale=1280:720,fps=15,format=yuv420p",
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-tune", "zerolatency",
        "-f", "rtsp",
        rtsp_url
    ]
    return subprocess.Popen(cmd, stdin=subprocess.PIPE,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# ─────────────────────────────────────────────────────────────────────────────
# Capture Thread: Reads frames from camera stream
# ─────────────────────────────────────────────────────────────────────────────
def capture_thread(camera_index, config):
    global raw_frames, stop_threads
    cap = cv2.VideoCapture(config["ip_url"])
    if not cap.isOpened():
        print(f"❌ Error: Unable to open camera stream {config['ip_url']}. Exiting capture thread...")
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAPTURE_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAPTURE_HEIGHT)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    ret, frame = cap.read()
    if not ret or frame is None:
        print(f"❌ Error: No frames from {config['ip_url']} on first read. Exiting capture thread...")
        cap.release()
        return

    with raw_frame_locks[camera_index]:
        raw_frames[camera_index] = frame

    while not stop_threads:
        ret, frame = cap.read()
        if not ret or frame is None:
            print(f"⚠️ {config['name']} failed to capture a frame.")
            time.sleep(0.1)
            continue
        with raw_frame_locks[camera_index]:
            raw_frames[camera_index] = frame
    cap.release()
    print(f"🔴 Capture thread ended for {config['name']}.")

# ─────────────────────────────────────────────────────────────────────────────
# Send Notification Function
# ─────────────────────────────────────────────────────────────────────────────
def send_notification(title, body, token=None, topic=None):
    """
    Sends a push notification via Firebase Cloud Messaging.
    Here, we're using a topic ("personDetectionAlerts") so that all devices
    subscribed to that topic receive the alert.
    """
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body
        ),
        token=token,   # Use a device token if available
        topic=topic    # Alternatively, use a topic
    )
    try:
        response = messaging.send(message)
        print(f"✅ Notification sent: {response}")
    except Exception as e:
        print(f"❌ Notification error: {e}")

# ─────────────────────────────────────────────────────────────────────────────
# Detection & Recording Thread
# ─────────────────────────────────────────────────────────────────────────────
def detection_thread(camera_index, config):
    global stop_threads, model
    while not stop_threads:
        with raw_frame_locks[camera_index]:
            frame = None if raw_frames[camera_index] is None else raw_frames[camera_index].copy()
        if frame is None:
            time.sleep(0.05)
            continue

        # Run YOLO detection for "person" (class 0)
        with threading.Lock():
            results = model(frame, classes=[0])
        
        # Check for detection above thresholds
        detection_found = any(conf >= DETECTION_CONFIDENCE for conf in results[0].boxes.conf)
        high_confidence = any(conf >= NOTIFICATION_CONFIDENCE for conf in results[0].boxes.conf)
        
        # If high-confidence detection occurs and no notification has been sent yet in this session,
        # send a notification and mark it as sent.
        if high_confidence and not notification_sent[camera_index]:
            send_notification(
                f"Activity Detected - {config['name']}",
                f"Activity detected on {config['name']}.",
                topic="personDetectionAlerts"
            )
            notification_sent[camera_index] = True

        # Draw detections on the frame if found
        annotated = results[0].plot() if detection_found else frame

        # Update annotated frame for streaming
        with annotated_frame_locks[camera_index]:
            annotated_frames[camera_index] = annotated

        current_time = time.time()
        if detection_found:
            last_detection_time[camera_index] = current_time
            print(f"✅ Person detected in {config['name']} with confidence >= {DETECTION_CONFIDENCE}!")
            
            # Start recording if not already active
            if not recording[camera_index]:
                video_dir = "videos1" if camera_index == 0 else "videos2"
                video_filename = f"camera_{camera_index+1}_{int(current_time)}.mp4"
                video_path = os.path.join(video_dir, video_filename)
                video_writers[camera_index] = cv2.VideoWriter(
                    video_path,
                    cv2.VideoWriter_fourcc(*'mp4v'),
                    15,  # FPS matching RTSP stream
                    (CAPTURE_WIDTH, CAPTURE_HEIGHT)
                )
                video_filenames[camera_index] = video_path
                recording[camera_index] = True
                snapshot_taken[camera_index] = False
                # Do not reset notification_sent here so that only one notification
                # is sent during the recording session.
                print(f"🎥 Started recording for {config['name']}: {video_path}")

            # Take one snapshot per event (if not already taken)
            if not snapshot_taken[camera_index]:
                pic_dir = "pictures1" if camera_index == 0 else "pictures2"
                snapshot_filename = f"camera_{camera_index+1}_{int(current_time)}.jpg"
                snapshot_path = os.path.join(pic_dir, snapshot_filename)
                cv2.imwrite(snapshot_path, annotated)
                print(f"📸 Saved snapshot for {config['name']} to {snapshot_path}")
                remote_snapshot_path = f"{pic_dir}/{snapshot_filename}"
                upload_executor.submit(upload_to_firebase, snapshot_path, remote_snapshot_path)
                snapshot_taken[camera_index] = True

            # Write the annotated frame to the recording
            if video_writers[camera_index] is not None:
                video_writers[camera_index].write(annotated)
                print(f"✍️ Writing frame to {video_filenames[camera_index]}")
        else:
            # If no detection, maintain recording for a grace period
            if recording[camera_index]:
                time_since = current_time - last_detection_time[camera_index]
                if time_since <= record_duration_after_motion:
                    print(f"⏳ No person detected in {config['name']}, still recording... ({record_duration_after_motion - time_since:.2f} sec left)")
                    if video_writers[camera_index] is not None:
                        video_writers[camera_index].write(annotated)
                else:
                    print(f"🛑 Stopping recording for {config['name']} after {record_duration_after_motion}s of no detection.")
                    recording[camera_index] = False
                    if video_writers[camera_index] is not None:
                        video_writers[camera_index].release()
                        local_vid_path = video_filenames[camera_index]
                        if local_vid_path:
                            remote_vid_path = local_vid_path  # Modify remote path if needed
                            upload_executor.submit(upload_to_firebase, local_vid_path, remote_vid_path)
                        video_writers[camera_index] = None
                        video_filenames[camera_index] = None
                    # Reset notification flag for the next recording session.
                    notification_sent[camera_index] = False

        time.sleep(0.05)
    # Ensure we release the writer if still recording when stopping.
    if recording[camera_index] and video_writers[camera_index] is not None:
        video_writers[camera_index].release()
    print(f"🔴 Detection thread ended for {config['name']}.")

# ─────────────────────────────────────────────────────────────────────────────
# Streaming Thread: Pipes annotated frames to FFmpeg for RTSP streaming
# ─────────────────────────────────────────────────────────────────────────────
def streaming_thread(camera_index, config):
    ffmpeg_proc = start_ffmpeg_stream_pipe(config["rtsp_url"])
    while not stop_threads:
        with annotated_frame_locks[camera_index]:
            frame_to_stream = annotated_frames[camera_index]
        if frame_to_stream is None:
            with raw_frame_locks[camera_index]:
                frame_to_stream = raw_frames[camera_index]
        if frame_to_stream is None:
            time.sleep(0.05)
            continue
        try:
            ffmpeg_proc.stdin.write(frame_to_stream.tobytes())
        except Exception as e:
            print(f"Error writing to FFmpeg for {config['name']}: {e}")
            break
        time.sleep(0.01)
    try:
        ffmpeg_proc.stdin.close()
        ffmpeg_proc.wait()
    except Exception:
        pass
    print(f"🔴 Streaming thread ended for {config['name']}.")

# ─────────────────────────────────────────────────────────────────────────────
# Main: Start Threads and Run the System
# ─────────────────────────────────────────────────────────────────────────────
threads = []
for i, config in enumerate(camera_configs):
    t_cap = threading.Thread(target=capture_thread, args=(i, config))
    t_det = threading.Thread(target=detection_thread, args=(i, config))
    t_stream = threading.Thread(target=streaming_thread, args=(i, config))
    t_cap.start()
    t_det.start()
    t_stream.start()
    threads.extend([t_cap, t_det, t_stream])

print("System running... (Press Ctrl+C to stop)")
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("🔴 KeyboardInterrupt received. Stopping all threads...")
    stop_threads = True

for t in threads:
    t.join()

print("All threads terminated. Exiting.")

