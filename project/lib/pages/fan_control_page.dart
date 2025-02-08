import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String blynkAuthToken = "4V5l333thPAtcm6Cl4SAov58TSsqT-vK";
const String blynkBaseUrl = "https://blynk.cloud/external/api";
const double defaultFanSpeed = 50.0; // Default speed when turning on
const double defaultTempThreshold = 25.0;
const Duration updateInterval = Duration(seconds: 5);

class FanControlPage extends StatefulWidget {
  @override
  _FanControlPageState createState() => _FanControlPageState();
}

class _FanControlPageState extends State<FanControlPage> {
  bool isFanOn = false;
  double fanSpeed = 0;
  double temperature = 0;
  bool autoMode = false;
  double tempThreshold = defaultTempThreshold;
  Timer? timer;
  bool isTemperatureLoaded = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeSystem();
  }

  Future<void> initializeSystem() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        fetchTemperature(),
        fetchFanState(),
      ]);

      startPeriodicUpdates();
    } catch (e) {
      print("Error initializing system: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void startPeriodicUpdates() {
    timer?.cancel();
    timer = Timer.periodic(updateInterval, (timer) async {
      await fetchFanState();
      await fetchTemperature();
      checkTemperatureThreshold();
    });
  }

  Future<void> fetchTemperature() async {
    final tempUrl = Uri.parse('$blynkBaseUrl/get?token=$blynkAuthToken&v0');
    try {
      final response = await http.get(tempUrl);
      if (response.statusCode == 200) {
        setState(() {
          temperature = double.tryParse(response.body.replaceAll(RegExp(r'[\[\]]'), '')) ?? 0;
          isTemperatureLoaded = temperature > 0;

          if (autoMode && tempThreshold == defaultTempThreshold && isTemperatureLoaded) {
            tempThreshold = temperature;
          }
        });
      }
    } catch (e) {
      print("Error fetching temperature: $e");
      rethrow;
    }
  }

  Future<void> fetchFanState() async {
    final fanOnUrl = Uri.parse('$blynkBaseUrl/get?token=$blynkAuthToken&v6');
    final fanSpeedUrl = Uri.parse('$blynkBaseUrl/get?token=$blynkAuthToken&v7');

    try {
      final responses = await Future.wait([
        http.get(fanOnUrl),
        http.get(fanSpeedUrl),
      ]);

      if (responses.every((response) => response.statusCode == 200)) {
        setState(() {
          isFanOn = responses[0].body.replaceAll(RegExp(r'[\[\]]'), '') == '1';
          double pwmValue = double.tryParse(responses[1].body.replaceAll(RegExp(r'[\[\]]'), '')) ?? 0;
          fanSpeed = (pwmValue / 255) * 100;
        });
      }
    } catch (e) {
      print("Error fetching fan state: $e");
      rethrow;
    }
  }

  void checkTemperatureThreshold() {
    if (!autoMode || !isTemperatureLoaded) return;

    if (temperature >= tempThreshold && !isFanOn) {
      toggleFan(true);
    } else if (temperature < tempThreshold && isFanOn) {
      toggleFan(false);
    }
  }

  Future<void> toggleFan(bool state) async {
    try {
      if (state && fanSpeed == 0) {
        // If turning on and speed is 0, set to default speed first
        await setFanSpeed(defaultFanSpeed);
      }

      await setFanState(state);

      // If turning off, reset speed to 0
      if (!state) {
        await setFanSpeed(0);
      }
    } catch (e) {
      print("Error toggling fan: $e");
      // Revert the UI state if there's an error
      setState(() => isFanOn = !state);
    }
  }

  Future<void> setFanState(bool state) async {
    final fanOnUrl = Uri.parse('$blynkBaseUrl/update?token=$blynkAuthToken&v6=${state ? 1 : 0}');

    try {
      final response = await http.get(fanOnUrl);
      if (response.statusCode == 200) {
        setState(() => isFanOn = state);
      } else {
        throw Exception('Failed to update fan state');
      }
    } catch (e) {
      print("Error updating fan state: $e");
      rethrow;
    }
  }

  Future<void> setFanSpeed(double speed) async {
    int pwmValue = ((speed / 100) * 255).toInt();
    final fanSpeedUrl = Uri.parse('$blynkBaseUrl/update?token=$blynkAuthToken&v7=$pwmValue');

    try {
      final response = await http.get(fanSpeedUrl);
      if (response.statusCode == 200) {
        setState(() => fanSpeed = speed);
      } else {
        throw Exception('Failed to update fan speed');
      }
    } catch (e) {
      print("Error updating fan speed: $e");
      rethrow;
    }
  }

  void toggleAutoMode(bool value) {
    setState(() {
      autoMode = value;
      if (value && isTemperatureLoaded) {
        tempThreshold = temperature;
        if (temperature >= tempThreshold && !isFanOn) {
          toggleFan(true);
        }
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget buildTemperatureControl() {
    return Container(
      margin: EdgeInsets.only(top: 10),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Auto Mode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Row(
                children: [
                  if (!isTemperatureLoaded)
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                      ),
                    ),
                  Switch(
                    value: autoMode,
                    onChanged: isTemperatureLoaded ? toggleAutoMode : null,
                    activeColor: Colors.blue[700],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: autoMode ? [
                  Colors.blue[700]!,
                  Colors.blue[500]!,
                ] : [
                  Colors.grey[400]!,
                  Colors.grey[300]!,
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: (autoMode ? Colors.blue[700]! : Colors.grey[400]!).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Current Temperature',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(autoMode ? 0.9 : 0.7),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.thermostat,
                      color: Colors.white.withOpacity(autoMode ? 1.0 : 0.7),
                      size: 36,
                    ),
                    SizedBox(width: 10),
                    isTemperatureLoaded
                        ? Text(
                      '${temperature.toStringAsFixed(1)}°C',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(autoMode ? 1.0 : 0.7),
                      ),
                    )
                        : SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(autoMode ? 1.0 : 0.7)
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Temperature Threshold',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: autoMode ? Colors.blue[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${tempThreshold.toInt()}°C',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: autoMode ? Colors.blue[700] : Colors.grey[300],
              inactiveTrackColor: Colors.grey[200],
              thumbColor: autoMode ? Colors.blue[700] : Colors.grey[300],
              overlayColor: Color.fromRGBO(
                  autoMode ? Colors.blue[700]!.red : Colors.grey[300]!.red,
                  autoMode ? Colors.blue[700]!.green : Colors.grey[300]!.green,
                  autoMode ? Colors.blue[700]!.blue : Colors.grey[300]!.blue,
                  0.2),
              trackHeight: 8,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              value: tempThreshold,
              min: 20,
              max: 35,
              divisions: 15,
              onChanged: autoMode ? (value) => setState(() => tempThreshold = value) : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Fan Control',
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
        padding: EdgeInsets.symmetric(horizontal: 20),
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
            child: Column(
              children: [
                // Fan Power Section
                Container(
                  margin: EdgeInsets.only(top: 10),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.1),
                        blurRadius: 20,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Fan Power',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => toggleFan(!isFanOn),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFanOn ? Colors.blue[700] : Colors.grey[300],
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(
                                    isFanOn ? Colors.blue[700]!.red : Colors.grey[300]!.red,
                                    isFanOn ? Colors.blue[700]!.green : Colors.grey[300]!.green,
                                    isFanOn ? Colors.blue[700]!.blue : Colors.grey[300]!.blue,0.3),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.power_settings_new,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        isFanOn ? 'ON' : 'OFF',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isFanOn ? Colors.blue[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                // Fan Speed Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.1),
                        blurRadius: 20,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fan Speed',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isFanOn ? Colors.blue[700] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${fanSpeed.toInt()}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: isFanOn ? Colors.blue[700] : Colors.grey[300],
                          inactiveTrackColor: Colors.grey[200],
                          thumbColor: isFanOn ? Colors.blue[700] : Colors.grey[300],
                          overlayColor: Color.fromRGBO(
                              isFanOn ? Colors.blue[700]!.red : Colors.grey[300]!.red,
                              isFanOn ? Colors.blue[700]!.green : Colors.grey[300]!.green,
                              isFanOn ? Colors.blue[700]!.blue : Colors.grey[300]!.blue,
                              0.2),
                          trackHeight: 8,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                        ),
                        child: Slider(
                          value: fanSpeed,
                          min: 0,
                          max: 100,
                          divisions: 10,
                          onChanged: isFanOn ? (value) => setFanSpeed(value) : null,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0%', style: TextStyle(color: Colors.grey[600])),
                          Text('100%', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                buildTemperatureControl(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}