Smart Home Automation and Security System Using AI & IoT
Overview
This project is a smart home automation and security system that integrates AI and IoT technologies to control home appliances, monitor environmental conditions, and enhance surveillance through object detection. It features event-based recording, real-time notifications, and remote device control via a mobile interface.

Features
1. Home Automation System
Appliance Control: Remotely controls LED lights and a DC motor (acting as a fan or air conditioning device).
Environmental Monitoring: Uses a DHT11 sensor to measure temperature and humidity.
Blynk API Integration: Allows remote management of connected devices.
Weather Information Display: Fetches real-time weather data using the OpenWeather API.
2. Surveillance & Security System
Object Detection: Uses YOLOv11s to detect people in the surveillance feed.
Event-Based Recording: Captures video and images only when a person is detected, optimizing storage and processing resources.
Live Streaming: Streams video using MediaMTX and WebRTC, providing real-time access via an HTTP link.
Efficient Processing: Video footage from an IP Webcam is processed on a PC, running object detection before being streamed to MediaMTX via RTSP for WebRTC access.
Cloud Storage: Recorded videos and images are uploaded to Firebase.
Real-Time Alerts: Sends push notifications using Firebase Cloud Messaging (FCM) when a person is detected.
System Components & Technologies
Hardware
ESP8266 (NodeMCU)
DHT11 Sensor (for temperature and humidity monitoring)
LED Lights (for smart lighting control)
DC Motor (acting as a fan/air conditioning device)
Motor Controller (to manage motor operations)
Battery Holder (external power supply for ESP8266)
Diode (for power protection)
Software & APIs
Flutter (for mobile application interface)
Python (for object detection and event-based recording)
YOLOv11s (AI model for object detection)
Firebase (for cloud storage and notifications)
Firebase Cloud Messaging (FCM) (for real-time alerts)
Blynk API (for IoT device control)
MediaMTX & WebRTC (for low-latency video streaming)
OpenWeather API (for fetching weather data)
