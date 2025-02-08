# Smart Home Automation and Security System

## Description of the Smart Home Automation and Security System
The **Smart Home Automation and Security System** is an AI and IoT-based project that allows users to control home appliances, monitor environmental conditions, and enhance security through real-time surveillance and event-based recording. 

The system integrates multiple technologies such as **YOLOv11s for object detection**, **Blynk API for device control**, and **Firebase for cloud storage and real-time alerts**. Users can access and control devices remotely through a **Flutter-based mobile application**.

---

## Key Features

### **1. Home Automation**
- **Appliance Control:** Remotely controls **LED lights and a DC motor** (acting as a fan or air conditioning system).
- **Environmental Monitoring:** Uses a **DHT11 sensor** to track temperature and humidity.
- **Remote Management:** Utilizes the **Blynk API** for controlling IoT devices.
- **Weather Display:** Fetches real-time weather data using the **OpenWeather API**.

### **2. Surveillance & Security System**
- **Object Detection:** Implements **YOLOv11s** to detect people in surveillance footage.
- **Event-Based Recording:** Captures video and images **only when a person is detected**, reducing unnecessary storage usage.
- **Live Streaming:** Uses **MediaMTX & WebRTC** to provide a real-time video feed accessible via an HTTP link.
- **Cloud Storage & Alerts:** Automatically uploads **recorded images and videos to Firebase** and **sends notifications via Firebase Cloud Messaging (FCM)**.

---

## Implementation Details

- **ESP8266 (NodeMCU):** Acts as the core microcontroller for home automation.
- **Flutter Mobile App:** Provides a user-friendly interface for device control and monitoring.
- **Python & YOLOv11s:** Handles object detection and event-based recording.
- **MediaMTX & WebRTC:** Enables real-time video streaming with minimal latency.
- **Firebase:** Stores captured images and videos and handles real-time notifications.
- **Blynk API:** Allows IoT devices to be controlled remotely.

---

