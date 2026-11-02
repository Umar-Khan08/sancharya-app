import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/weather_model.dart';

abstract class IWeatherService {
  Future<WeatherData?> getWeather({
    required double latitude,
    required double longitude,
    String? locationName,
  });
}

/// Weather Service consuming official Open-Meteo free API
/// https://api.open-meteo.com/v1/forecast
class OpenMeteoWeatherService implements IWeatherService {
  static const Duration _timeout = Duration(seconds: 4);

  // In-memory weather cache to prevent repeated requests
  static final Map<String, WeatherData> _weatherCache = {};

  @override
  Future<WeatherData?> getWeather({
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180 || (latitude == 0.0 && longitude == 0.0)) {
      return null;
    }

    final cacheKey = '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';
    if (_weatherCache.containsKey(cacheKey)) {
      debugPrint('[TIMING] Open-Meteo weather served from cache for $cacheKey (0ms)');
      return _weatherCache[cacheKey];
    }

    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max'
        '&timezone=auto',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'SancharyaAgriculturalApp/1.0',
        },
      ).timeout(_timeout);
      debugPrint('[TIMING] Open-Meteo weather request took ${sw.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        final daily = data['daily'] as Map<String, dynamic>?;

        if (current != null) {
          final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
          final appTemp = (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
          final humidity = (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0.0;
          final precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
          final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
          final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;

          // Parse daily forecasts
          final dailyList = <DailyForecast>[];
          if (daily != null) {
            final times = daily['time'] as List<dynamic>? ?? [];
            final codes = daily['weather_code'] as List<dynamic>? ?? [];
            final maxTemps = daily['temperature_2m_max'] as List<dynamic>? ?? [];
            final minTemps = daily['temperature_2m_min'] as List<dynamic>? ?? [];
            final precipSums = daily['precipitation_sum'] as List<dynamic>? ?? [];
            final precipProbs = daily['precipitation_probability_max'] as List<dynamic>? ?? [];

            for (var i = 0; i < times.length && i < 4; i++) {
              dailyList.add(
                DailyForecast.fromJson(
                  dateStr: times[i].toString(),
                  maxTemp: (maxTemps.length > i ? (maxTemps[i] as num).toDouble() : temp),
                  minTemp: (minTemps.length > i ? (minTemps[i] as num).toDouble() : temp),
                  weatherCode: (codes.length > i ? (codes[i] as num).toInt() : weatherCode),
                  precipitationSum: (precipSums.length > i ? (precipSums[i] as num).toDouble() : 0.0),
                  precipitationProbability: (precipProbs.length > i ? (precipProbs[i] as num).toInt() : 0),
                ),
              );
            }
          }

          final weatherObj = WeatherData(
            temperature: temp,
            apparentTemperature: appTemp,
            relativeHumidity: humidity,
            precipitation: precip,
            windSpeed: wind,
            weatherCode: weatherCode,
            timestamp: DateTime.now(),
            isLive: true,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            dailyForecasts: dailyList,
          );
          _weatherCache[cacheKey] = weatherObj;
          return weatherObj;
        }
      } else {
        debugPrint('SANCHARYA Open-Meteo returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('SANCHARYA Open-Meteo fetch error: $e');
    }

    return null;
  }
}
