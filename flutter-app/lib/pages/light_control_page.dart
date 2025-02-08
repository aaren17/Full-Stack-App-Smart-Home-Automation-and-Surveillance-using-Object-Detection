import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

const String blynkAuthToken = "4V5l333thPAtcm6Cl4SAov58TSsqT-vK";
const String blynkBaseUrl = "https://blynk.cloud/external/api";

class LightControlPage extends StatefulWidget {
  @override
  _LightControlPageState createState() => _LightControlPageState();
}

class _LightControlPageState extends State<LightControlPage> {
  final List<Light> lights = [
    Light(name: 'Light 1', pinToggle: 'v2', pinBrightness: 'v3'),
    Light(name: 'Light 2', pinToggle: 'v4', pinBrightness: 'v5'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeLights();
  }

  @override
  void dispose() {
    for (var light in lights) {
      light.brightnessDebounce?.cancel();
      light.scheduleTimer?.cancel();
    }
    super.dispose();
  }

  Future<void> _initializeLights() async {
    for (var light in lights) {
      await _getLightState(light);
      if (light.isScheduleEnabled && light.startTime != null && light.endTime != null) {
        _setupSchedule(light);
      }
    }
  }

  Future<void> _getLightState(Light light) async {
    final url = Uri.parse('$blynkBaseUrl/get?token=$blynkAuthToken&${light.pinToggle}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          final value = int.tryParse(response.body.replaceAll('[', '').replaceAll(']', ''));
          light.isOn = value == 1;
        });
      }
    } catch (e) {
      print('Error getting ${light.name} state: $e');
    }
  }

  Future<void> toggleLight(Light light, {bool manualToggle = true}) async {
    final newState = !light.isOn;
    final url = Uri.parse('$blynkBaseUrl/update?token=$blynkAuthToken&${light.pinToggle}=${newState ? 1 : 0}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          light.isOn = newState;
          if (manualToggle && !light.isOn) {
            light.scheduleTimer?.cancel();
            light.isScheduleEnabled = false;
          }
        });

        if (light.isOn) {
          await adjustBrightness(light, light.brightness);
        }
      }
    } catch (e) {
      print('Error toggling ${light.name}: $e');
    }
  }

  Future<void> adjustBrightness(Light light, double value) async {
    setState(() {
      light.brightness = value;
    });

    light.brightnessDebounce?.cancel();

    light.brightnessDebounce = Timer(Duration(milliseconds: 500), () async {
      final url = Uri.parse('$blynkBaseUrl/update?token=$blynkAuthToken&${light.pinBrightness}=${value.toInt()}');
      try {
        final response = await http.get(url);
        if (response.statusCode != 200) {
          print('Error adjusting ${light.name} brightness: ${response.body}');
        }
      } catch (e) {
        print('Error adjusting ${light.name} brightness: $e');
      }
    });
  }

  void _setupSchedule(Light light) {
    light.scheduleTimer?.cancel();

    if (!light.isScheduleEnabled || light.startTime == null || light.endTime == null) return;

    void checkAndUpdateSchedule() {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);
      final start = light.startTime!;
      final end = light.endTime!;

      // Convert all times to minutes for comparison
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;

      bool shouldBeOn;
      if (startMinutes <= endMinutes) {
        // Same day schedule
        shouldBeOn = currentMinutes >= startMinutes && currentMinutes < endMinutes;
      } else {
        // Overnight schedule
        shouldBeOn = currentMinutes >= startMinutes || currentMinutes < endMinutes;
      }

      if (light.isOn != shouldBeOn) {
        toggleLight(light, manualToggle: false);
      }
    }

    // Calculate time until next minute starts
    final now = DateTime.now();
    final nextMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    final initialDelay = nextMinute.difference(now);

    // Initial delay to sync with minute start
    Future.delayed(initialDelay, () {
      // Do initial check
      checkAndUpdateSchedule();

      // Then set up periodic timer that runs exactly on minute boundaries
      light.scheduleTimer = Timer.periodic(Duration(minutes: 1), (_) {
        if (light.isScheduleEnabled) {
          checkAndUpdateSchedule();
        } else {
          light.scheduleTimer?.cancel();
        }
      });
    });
  }

  void _handleScheduleToggle(Light light, bool value) {
    setState(() {
      light.isScheduleEnabled = value;
      if (value && light.startTime != null && light.endTime != null) {
        _setupSchedule(light);
      } else {
        light.scheduleTimer?.cancel();
      }
    });
  }

  void _showBottomTimePicker(Light light, bool isStartTime) {
    final now = DateTime.now();
    DateTime initialTime;
    if (isStartTime && light.startTime != null) {
      initialTime = DateTime(now.year, now.month, now.day, light.startTime!.hour, light.startTime!.minute);
    } else if (!isStartTime && light.endTime != null) {
      initialTime = DateTime(now.year, now.month, now.day, light.endTime!.hour, light.endTime!.minute);
    } else {
      initialTime = now;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[700]!, Colors.blue[600]!],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isStartTime ? 'Set Start Time' : 'Set End Time',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.check, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                      if (light.isScheduleEnabled && light.startTime != null && light.endTime != null) {
                        _setupSchedule(light);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: initialTime,
                use24hFormat: true,
                onDateTimeChanged: (DateTime time) {
                  setState(() {
                    final timeOfDay = TimeOfDay.fromDateTime(time);
                    if (isStartTime) {
                      light.startTime = timeOfDay;
                    } else {
                      light.endTime = timeOfDay;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Light Control',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.grey[100]!],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.only(
                top: 40,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Column(
                children: lights.map((light) {
                  return buildLightControlCard(light);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLightControlCard(Light light) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: light.isOn
                    ? [Colors.blue[700]!, Colors.blue[600]!]
                    : [Colors.grey[300]!, Colors.grey[200]!],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: light.isOn
                            ? [BoxShadow(
                          color: Colors.blue[300]!.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )]
                            : [],
                      ),
                      child: Icon(
                        Icons.lightbulb,
                        color: light.isOn ? Colors.white : Colors.grey[700],
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      light.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: light.isOn ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => toggleLight(light),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: light.isOn
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: light.isOn
                            ? Colors.white.withOpacity(0.3)
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: light.isOn
                              ? Colors.blue[900]!.withOpacity(0.2)
                              : Colors.grey[400]!.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      color: light.isOn ? Colors.white : Colors.grey[700],
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Brightness',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: light.isOn
                              ? [Colors.blue[700]!, Colors.blue[600]!]
                              : [Colors.grey[400]!, Colors.grey[300]!],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (light.isOn ? Colors.blue[300]! : Colors.grey[300]!)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${light.brightness.toInt()}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  height: 40,
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: light.isOn ? Colors.blue[600] : Colors.grey[400],
                      inactiveTrackColor: Colors.grey[200],
                      thumbColor: light.isOn ? Colors.blue[700] : Colors.grey[600],
                      overlayColor: (light.isOn ? Colors.blue[700] : Colors.grey[600])!
                          .withOpacity(0.2),
                      trackHeight: 6,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: 12,
                        pressedElevation: 8,
                      ),
                      overlayShape: RoundSliderOverlayShape(overlayRadius: 24),
                      trackShape: CustomTrackShape(),
                    ),
                    child: Slider(
                      value: light.brightness,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: light.isOn ? (value) => adjustBrightness(light, value) : null,
                    ),
                  ),
                ),

                SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    setState(() {
                      light.isScheduleExpanded = !light.isScheduleExpanded;
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Schedule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Row(
                          children: [
                            Switch(
                              value: light.isScheduleEnabled,
                              onChanged: (value) => _handleScheduleToggle(light, value),
                              activeColor: Colors.blue[700],
                            ),
                            Icon(
                              light.isScheduleExpanded ? Icons.expand_less : Icons.expand_more,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (light.isScheduleExpanded) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTimeRow(
                          'Start Time',
                          light.startTime?.format(context) ?? '--:--',
                          light.isScheduleEnabled,
                              () => _showBottomTimePicker(light, true),
                        ),
                        Divider(height: 16, thickness: 1, color: Colors.grey[200]),
                        _buildTimeRow(
                          'End Time',
                          light.endTime?.format(context) ?? '--:--',
                          light.isScheduleEnabled,
                              () => _showBottomTimePicker(light, false),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, String time, bool enabled, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: enabled ? Colors.grey[800] : Colors.grey[400],
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: Icon(Icons.access_time),
          label: Text(
            'Set',
            style: TextStyle(fontSize: 16),
          ),
          style: TextButton.styleFrom(
            foregroundColor: enabled ? Colors.blue[700] : Colors.grey[400],
          ),
        ),
      ],
    );
  }
}

// Custom track shape for better touch area
class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 0;
    final double trackLeft = offset.dx + 10;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width - 20;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}

class Light {
  final String name;
  final String pinToggle;
  final String pinBrightness;
  double brightness;
  bool isOn;
  bool isScheduleExpanded;
  bool isScheduleEnabled;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  Timer? brightnessDebounce;
  Timer? scheduleTimer;

  Light({
    required this.name,
    required this.pinToggle,
    required this.pinBrightness,
    this.brightness = 50.0,
    this.isOn = false,
    this.isScheduleExpanded = false,
    this.isScheduleEnabled = false,
    this.startTime,
    this.endTime,
    this.brightnessDebounce,
    this.scheduleTimer,
  });
}