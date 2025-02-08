This project is a home automation and security system integrating AI and IoT technologies. It focuses on controlling appliances, monitoring environmental conditions, and implementing a smart surveillance system with event-based recording and real-time notifications.

1. Home Automation System
Controls LED lights and a DC motor (acting as a fan or air conditioning device).
Monitors environmental conditions using a DHT11 sensor for temperature and humidity data.
Utilizes the Blynk API to manage and control connected devices remotely.
Fetches weather information using the OpenWeather API for display purposes.
2. Surveillance & Security System
Implements YOLOv11s for object detection.
Event-based recording is a core feature, capturing video and images when a person is detected in the surveillance feed.
Streams footage using MediaMTX and WebRTC, allowing access via an HTTP link with minimal latency.
Processes video footage from an IP Webcam on a PC, running object detection before streaming it to MediaMTX via RTSP for WebRTC access.
Stores recorded videos and images in Firebase.
Sends real-time alerts via Firebase Cloud Messaging (FCM) when a person is detected.
3. System Components & Technologies
Hardware: ESP8266 (NodeMCU), DHT11 sensor, LED lights, DC motor, motor controller, battery holder (for ESP8266 power), and a diode for power protection.
Software: Flutter (for the mobile interface), Python (for object detection and event recording), Firebase (for storage and notifications), OpenWeather API (for weather information retrieval).
This project enhances security by implementing event-based recording, ensuring that storage and processing are only utilized when significant motion or object detection events occur. By reducing continuous recording, it optimizes resource usage while maintaining an efficient surveillance system. The integration of Firebase and FCM ensures that users receive immediate alerts when relevant events are detected.
