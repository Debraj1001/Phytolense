import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// WMO weather code → human-readable description + icon data
class _WmoCode {
  final String description;
  final String emoji;
  final bool isRainy;
  const _WmoCode(this.description, this.emoji, {this.isRainy = false});
}

const Map<int, _WmoCode> _wmoCodes = {
  0:  _WmoCode('Clear Sky', '☀️'),
  1:  _WmoCode('Mainly Clear', '🌤️'),
  2:  _WmoCode('Partly Cloudy', '⛅'),
  3:  _WmoCode('Overcast', '☁️'),
  45: _WmoCode('Foggy', '🌫️'),
  48: _WmoCode('Rime Fog', '🌫️'),
  51: _WmoCode('Light Drizzle', '🌦️', isRainy: true),
  53: _WmoCode('Moderate Drizzle', '🌦️', isRainy: true),
  55: _WmoCode('Dense Drizzle', '🌧️', isRainy: true),
  56: _WmoCode('Freezing Drizzle', '🌧️', isRainy: true),
  57: _WmoCode('Heavy Freezing Drizzle', '🌧️', isRainy: true),
  61: _WmoCode('Slight Rain', '🌦️', isRainy: true),
  63: _WmoCode('Moderate Rain', '🌧️', isRainy: true),
  65: _WmoCode('Heavy Rain', '🌧️', isRainy: true),
  66: _WmoCode('Freezing Rain', '🌧️', isRainy: true),
  67: _WmoCode('Heavy Freezing Rain', '🌧️', isRainy: true),
  71: _WmoCode('Light Snowfall', '🌨️'),
  73: _WmoCode('Moderate Snowfall', '🌨️'),
  75: _WmoCode('Heavy Snowfall', '❄️'),
  77: _WmoCode('Snow Grains', '❄️'),
  80: _WmoCode('Light Showers', '🌦️', isRainy: true),
  81: _WmoCode('Moderate Showers', '🌧️', isRainy: true),
  82: _WmoCode('Violent Showers', '⛈️', isRainy: true),
  85: _WmoCode('Light Snow Showers', '🌨️'),
  86: _WmoCode('Heavy Snow Showers', '❄️'),
  95: _WmoCode('Thunderstorm', '⛈️', isRainy: true),
  96: _WmoCode('Thunderstorm + Hail', '⛈️', isRainy: true),
  99: _WmoCode('Severe Thunderstorm', '⛈️', isRainy: true),
};

class WeatherCondition {
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double windSpeed;
  final double precipitation;
  final int weatherCode;
  final String weatherDescription;
  final String weatherEmoji;
  final bool isCurrentlyRaining;
  final int precipitationProbability; // next-hour %

  WeatherCondition({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.weatherCode,
    required this.weatherDescription,
    required this.weatherEmoji,
    required this.isCurrentlyRaining,
    required this.precipitationProbability,
  });
}

class SprayWindow {
  final bool isOptimal;
  final String message;
  final String nextBestTime;
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
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<SprayWindow?> getSprayWindow() async {
    try {
      final position = await _getLocation();
      final lat = position?.latitude ?? 28.7041;
      final lon = position?.longitude ?? 77.1025;

      // Request current weather with weather_code + apparent_temperature
      // Request hourly with precipitation_probability for accurate forecasting
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
        'precipitation,weather_code,wind_speed_10m'
        '&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,'
        'precipitation,precipitation_probability,weather_code'
        '&forecast_days=2'
        '&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final current = data['current'];
      if (current == null) return null;

      final int wmoCode = (current['weather_code'] as num?)?.toInt() ?? 0;
      final wmo = _wmoCodes[wmoCode] ?? const _WmoCode('Unknown', '🌡️');

      final double precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
      final bool isRaining = wmo.isRainy || precip > 0.1;

      // Get next-hour precipitation probability from hourly data
      int nextHourPrecipProb = 0;
      try {
        final hourly = data['hourly'];
        if (hourly != null) {
          final times = hourly['time'] as List? ?? [];
          final probs = hourly['precipitation_probability'] as List? ?? [];
          final now = DateTime.now();
          for (int i = 0; i < times.length && i < probs.length; i++) {
            final dt = DateTime.tryParse(times[i] ?? '');
            if (dt != null && dt.isAfter(now)) {
              nextHourPrecipProb = (probs[i] as num?)?.toInt() ?? 0;
              break;
            }
          }
        }
      } catch (_) {}

      final condition = WeatherCondition(
        temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
        feelsLike: (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
        humidity: (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
        windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        precipitation: precip,
        weatherCode: wmoCode,
        weatherDescription: wmo.description,
        weatherEmoji: wmo.emoji,
        isCurrentlyRaining: isRaining,
        precipitationProbability: nextHourPrecipProb,
      );

      // ── Spray Condition Logic ──────────────────────────────────────
      bool isTempOk = condition.temperature >= 10 && condition.temperature <= 32;
      bool isWindOk = condition.windSpeed < 15;
      bool isRainOk = !isRaining && nextHourPrecipProb < 30;
      bool isHumidityOk = condition.humidity < 90;

      bool isOptimal = isTempOk && isWindOk && isRainOk && isHumidityOk;

      String message;
      if (isOptimal) {
        message = 'Optimal conditions for spraying. '
            '${wmo.emoji} ${wmo.description}, ${condition.temperature.toStringAsFixed(1)}°C';
      } else if (isRaining) {
        message = '${wmo.emoji} ${wmo.description} right now '
            '(${precip.toStringAsFixed(1)} mm). Avoid spraying.';
      } else if (nextHourPrecipProb >= 30) {
        message = '$nextHourPrecipProb% chance of rain in the next hour. '
            'Wait for a drier window.';
      } else if (!isWindOk) {
        message = 'Wind speed ${condition.windSpeed.toStringAsFixed(1)} km/h '
            '– risk of spray drift. Wait for calmer conditions.';
      } else if (!isTempOk) {
        if (condition.temperature < 10) {
          message = 'Too cold (${condition.temperature.toStringAsFixed(1)}°C). '
              'Spray efficacy drops below 10°C.';
        } else {
          message = 'Too hot (${condition.temperature.toStringAsFixed(1)}°C). '
              'Rapid evaporation reduces effectiveness.';
        }
      } else {
        message = 'Humidity at ${condition.humidity.toStringAsFixed(0)}%. '
            'Very high humidity may reduce spray adherence.';
      }

      // ── Find Next Optimal Window ───────────────────────────────────
      String nextBestTime = 'No optimal window in the next 48 hours';
      if (!isOptimal) {
        try {
          final hourly = data['hourly'];
          if (hourly != null) {
            final times = hourly['time'] as List? ?? [];
            final temps = hourly['temperature_2m'] as List? ?? [];
            final winds = hourly['wind_speed_10m'] as List? ?? [];
            final rains = hourly['precipitation'] as List? ?? [];
            final probs = hourly['precipitation_probability'] as List? ?? [];
            final codes = hourly['weather_code'] as List? ?? [];

            final now = DateTime.now();
            for (int i = 0; i < times.length; i++) {
              final dt = DateTime.tryParse(times[i] ?? '');
              if (dt == null || !dt.isAfter(now)) continue;

              final t = (temps.length > i ? temps[i] as num? : null)?.toDouble() ?? 0;
              final w = (winds.length > i ? winds[i] as num? : null)?.toDouble() ?? 0;
              final r = (rains.length > i ? rains[i] as num? : null)?.toDouble() ?? 0;
              final p = (probs.length > i ? probs[i] as num? : null)?.toInt() ?? 0;
              final c = (codes.length > i ? codes[i] as num? : null)?.toInt() ?? 0;
              final cWmo = _wmoCodes[c];

              bool tOk = t >= 10 && t <= 32;
              bool wOk = w < 15;
              bool rOk = r < 0.1 && p < 30 && (cWmo == null || !cWmo.isRainy);

              if (tOk && wOk && rOk) {
                final diff = dt.difference(now);
                if (diff.inHours < 1) {
                  nextBestTime = 'Within the next hour';
                } else if (diff.inHours < 24) {
                  final h = dt.hour.toString().padLeft(2, '0');
                  nextBestTime = 'Today at $h:00';
                } else {
                  final h = dt.hour.toString().padLeft(2, '0');
                  nextBestTime = 'Tomorrow at $h:00';
                }
                break;
              }
            }
          }
        } catch (_) {}
      }

      return SprayWindow(
        isOptimal: isOptimal,
        message: message,
        nextBestTime: nextBestTime,
        current: condition,
      );
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
    return null;
  }
}
