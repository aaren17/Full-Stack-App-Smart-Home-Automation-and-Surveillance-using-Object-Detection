import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:weather/weather.dart';

const String blynkAuthToken = "4V5l333thPAtcm6Cl4SAov58TSsqT-vK";
const String blynkBaseUrl = "https://blynk.cloud/external/api";
const String openWeatherApiKey = "0400bdc9b1a844cf904434e46de3c11e";

class TemperatureControlPage extends StatefulWidget {
  @override
  _TemperatureControlPageState createState() => _TemperatureControlPageState();
}

class _TemperatureControlPageState extends State<TemperatureControlPage> {
  double temperature = 25.0;
  double humidity = 50.0;
  double minTemp = 100.0;  // Start high to find minimum
  double maxTemp = 0.0;    // Start low to find maximum
  double minHumidity = 100.0;
  double maxHumidity = 0.0;
  Timer? timer;
  Weather? currentWeather;
  late WeatherFactory wf;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    wf = WeatherFactory(openWeatherApiKey, language: Language.ENGLISH);
    Future.wait([
      fetchTemperatureAndHumidity(),
      getCurrentWeather(),
    ]).then((_) {
      setState(() {
        isLoading = false;
      });
    });
    timer = Timer.periodic(Duration(seconds: 30), (timer) async {
      await fetchTemperatureAndHumidity();
    });
  }

  Future<void> getCurrentWeather() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        Weather weather = await wf.currentWeatherByLocation(
          position.latitude,
          position.longitude,
        );
        if (mounted) {
          setState(() {
            currentWeather = weather;
          });
        }
      }
    } catch (e) {
      print("Error getting weather: $e");
    }
  }

  Future<void> fetchTemperatureAndHumidity() async {
    final tempUrl = Uri.parse('$blynkBaseUrl/get?token=$blynkAuthToken&v0');
    final humUrl = Uri.parse('$blynkBaseUrl/get?token=$blynkAuthToken&v1');

    try {
      final responses = await Future.wait([
        http.get(tempUrl),
        http.get(humUrl),
      ]);

      if (mounted && responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        setState(() {
          temperature = double.tryParse(responses[0].body.replaceAll(RegExp(r'[\[\]]'), '')) ?? temperature;
          humidity = double.tryParse(responses[1].body.replaceAll(RegExp(r'[\[\]]'), '')) ?? humidity;

          // Update min/max values
          minTemp = temperature < minTemp ? temperature : minTemp;
          maxTemp = temperature > maxTemp ? temperature : maxTemp;
          minHumidity = humidity < minHumidity ? humidity : minHumidity;
          maxHumidity = humidity > maxHumidity ? humidity : maxHumidity;
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget _buildWeatherCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'External Environment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          if (isLoading)
            Center(child: CircularProgressIndicator())
          else if (currentWeather != null)
            Row(
              children: [
                Icon(
                  _getWeatherIcon(currentWeather!.weatherConditionCode!),
                  size: 45,
                  color: Colors.orange,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentWeather!.areaName ?? 'Unknown Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${currentWeather!.temperature?.celsius?.toStringAsFixed(1)}°C | ${currentWeather!.weatherDescription}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Text('Weather data unavailable'),
        ],
      ),
    );
  }

  IconData _getWeatherIcon(int condition) {
    if (condition < 300) return Icons.thunderstorm;
    if (condition < 400) return Icons.grain;
    if (condition < 600) return Icons.beach_access;
    if (condition < 700) return Icons.ac_unit;
    if (condition < 800) return Icons.cloud;
    if (condition == 800) return Icons.wb_sunny;
    return Icons.cloud;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Home Environment Monitor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        elevation: 0,
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
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() => isLoading = true);
              await Future.wait([
                fetchTemperatureAndHumidity(),
                getCurrentWeather(),
              ]);
              setState(() => isLoading = false);
            },
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeatherCard(),
                  Container(
                    margin: EdgeInsets.only(left: 4, bottom: 12),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Home Environment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  _buildCompactMetricCard(
                    title: 'Room Temperature',
                    value: temperature,
                    minValue: minTemp,
                    maxValue: maxTemp,
                    unit: '°C',
                    icon: Icons.thermostat_outlined,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 16),
                  _buildCompactMetricCard(
                    title: 'Room Humidity',
                    value: humidity,
                    minValue: minHumidity,
                    maxValue: maxHumidity,
                    unit: '%',
                    icon: Icons.water_drop_outlined,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMetricCard({
    required String title,
    required double value,
    required double minValue,
    required double maxValue,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${value.toStringAsFixed(1)}$unit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 220, // Increased gauge size
            child: SfRadialGauge(
              animationDuration: 1000,
              enableLoadingAnimation: true,
              axes: [
                RadialAxis(
                  minimum: 0,
                  maximum: title.contains('Temperature') ? 50 : 100,
                  showLabels: false, // Removed gauge numbers
                  showTicks: false,   // Removed ticks
                  startAngle: 180,
                  endAngle: 0,
                  radiusFactor: 0.9,  // Increased size
                  axisLineStyle: AxisLineStyle(
                    thickness: 0.2,
                    color: color.withOpacity(0.1),
                    thicknessUnit: GaugeSizeUnit.factor,
                  ),
                  pointers: [
                    RangePointer(
                      value: value,
                      width: 0.2,
                      sizeUnit: GaugeSizeUnit.factor,
                      color: color,
                      enableAnimation: true,
                    ),
                    MarkerPointer(
                      value: value,
                      markerType: MarkerType.circle,
                      color: Colors.white,
                      markerHeight: 25,  // Bigger marker
                      markerWidth: 25,
                      borderWidth: 3,
                      borderColor: color,
                    ),
                  ],
                  annotations: [
                    GaugeAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${value.toStringAsFixed(1)}$unit',
                            style: TextStyle(
                              fontSize: 32,  // Bigger font
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          Text(
                            'Current',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      positionFactor: 0.5,
                      angle: 90,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusItem('Today\'s Low', '${minValue.toStringAsFixed(1)}$unit', color),
                _buildStatusItem('Current', '${value.toStringAsFixed(1)}$unit', color),
                _buildStatusItem('Today\'s High', '${maxValue.toStringAsFixed(1)}$unit', color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}