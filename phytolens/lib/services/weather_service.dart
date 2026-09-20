import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
class WeatherCondition {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double precipitation;
  
  WeatherCondition({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
  });
}

class SprayWindow {
  final bool isOptimal;
  final String message;
  final String nextBestTime; // e.g. "Tomorrow, 6 AM"
  final WeatherCondition current;

  SprayWindow({
    required this.isOptimal,
    required this.message,
    required this.nextBestTime,
    required this.current,
  });
}

class WeatherService {
  Future<Position?> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return null;
    } 

    return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  Future<SprayWindow?> getSprayWindow() async {
    try {
      final position = await _getLocation();
      // Default to a central rural location if location is denied for demo purposes
      final lat = position?.latitude ?? 28.7041; 
      final lon = position?.longitude ?? 77.1025;

      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation'
          '&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation'
          '&timezone=auto');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final current = data['current'];
        final condition = WeatherCondition(
          temperature: (current['temperature_2m'] as num).toDouble(),
          humidity: (current['relative_humidity_2m'] as num).toDouble(),
          windSpeed: (current['wind_speed_10m'] as num).toDouble(),
          precipitation: (current['precipitation'] as num).toDouble(),
        );

        // Optimal Spray Conditions:
        // Temp: 15-28 °C
        // Wind: < 15 km/h
        // Rain: 0 mm
        
        bool isTempOk = condition.temperature >= 10 && condition.temperature <= 32;
        bool isWindOk = condition.windSpeed < 15;
        bool isRainOk = condition.precipitation == 0;
        
        bool isOptimal = isTempOk && isWindOk && isRainOk;
        
        String message = "Optimal conditions for spraying.";
        if (!isOptimal) {
          if (!isRainOk) {
            message = "High chance of rain. Do not spray.";
          } else if (!isWindOk) {
            message = "Too windy (${condition.windSpeed} km/h). Risk of spray drift.";
          } else if (!isTempOk) {
            message = "Temperature not optimal (${condition.temperature}°C).";
          }
        }

        // Extremely simplified next best time logic based on hourly forecast (just look ahead 24h)
        String nextBestTime = "No optimal window soon";
        if (!isOptimal) {
          final hourly = data['hourly'];
          final times = hourly['time'] as List;
          final temps = hourly['temperature_2m'] as List;
          final winds = hourly['wind_speed_10m'] as List;
          final rains = hourly['precipitation'] as List;
          
          for (int i = 0; i < 24 && i < times.length; i++) {
             bool tOk = (temps[i] as num) >= 10 && (temps[i] as num) <= 32;
             bool wOk = (winds[i] as num) < 15;
             bool rOk = (rains[i] as num) == 0;
             if (tOk && wOk && rOk) {
               // Extract hour from ISO string e.g., "2023-10-12T15:00"
               final dt = DateTime.parse(times[i]);
               if (dt.isAfter(DateTime.now())) {
                 // Format simply
                 String hour = dt.hour.toString().padLeft(2, '0');
                 nextBestTime = "Try at $hour:00";
                 break;
               }
             }
          }
        }

        return SprayWindow(
          isOptimal: isOptimal,
          message: message,
          nextBestTime: nextBestTime,
          current: condition,
        );
      }
    } catch (e) {
      debugPrint("Error fetching weather: $e");
    }
    return null;
  }
}
