import 'package:flutter/material.dart';

/// Represents a single day in a short-term weather forecast
class DailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;
  final double precipitationSum;
  final int precipitationProbability;

  const DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
    required this.precipitationSum,
    required this.precipitationProbability,
  });

  factory DailyForecast.fromJson({
    required String dateStr,
    required double maxTemp,
    required double minTemp,
    required int weatherCode,
    required double precipitationSum,
    required int precipitationProbability,
  }) {
    return DailyForecast(
      date: DateTime.tryParse(dateStr) ?? DateTime.now(),
      maxTemp: maxTemp,
      minTemp: minTemp,
      weatherCode: weatherCode,
      precipitationSum: precipitationSum,
      precipitationProbability: precipitationProbability,
    );
  }

  String conditionDescription(bool isHindi) =>
      WeatherData.getConditionDescription(weatherCode, isHindi);

  IconData get conditionIcon => WeatherData.getConditionIcon(weatherCode);
}

/// Real-time and forecasted agro-climatic weather data model
class WeatherData {
  final double temperature;
  final double apparentTemperature;
  final double relativeHumidity;
  final double precipitation;
  final double windSpeed;
  final int weatherCode;
  final DateTime timestamp;
  final bool isLive;
  final String? locationName;
  final double latitude;
  final double longitude;
  final List<DailyForecast> dailyForecasts;

  const WeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.relativeHumidity,
    required this.precipitation,
    required this.windSpeed,
    required this.weatherCode,
    required this.timestamp,
    required this.isLive,
    this.locationName,
    required this.latitude,
    required this.longitude,
    this.dailyForecasts = const [],
  });

  /// WMO Weather Interpretation Codes translated to English and Hindi
  static String getConditionDescription(int code, bool isHindi) {
    if (isHindi) {
      switch (code) {
        case 0:
          return 'साफ़ आसमान';
        case 1:
          return 'मुख्यतः साफ़';
        case 2:
          return 'आंशिक रूप से बादल';
        case 3:
          return 'घने बादल';
        case 45:
        case 48:
          return 'कोहरा';
        case 51:
        case 53:
        case 55:
          return 'हल्की बूंदाबांदी';
        case 61:
          return 'हल्की बारिश';
        case 63:
          return 'मध्यम बारिश';
        case 65:
          return 'भारी बारिश';
        case 71:
        case 73:
        case 75:
          return 'बर्फबारी';
        case 80:
        case 81:
        case 82:
          return 'बारिश की बौछारें';
        case 95:
          return 'गरज के साथ बारिश';
        case 96:
        case 99:
          return 'तूफान और ओलावृष्टि';
        default:
          return 'सामान्य मौसम';
      }
    } else {
      switch (code) {
        case 0:
          return 'Clear Sky';
        case 1:
          return 'Mainly Clear';
        case 2:
          return 'Partly Cloudy';
        case 3:
          return 'Overcast';
        case 45:
        case 48:
          return 'Foggy';
        case 51:
        case 53:
        case 55:
          return 'Drizzle';
        case 61:
          return 'Slight Rain';
        case 63:
          return 'Moderate Rain';
        case 65:
          return 'Heavy Rain';
        case 71:
        case 73:
        case 75:
          return 'Snow Fall';
        case 80:
        case 81:
        case 82:
          return 'Rain Showers';
        case 95:
          return 'Thunderstorm';
        case 96:
        case 99:
          return 'Thunderstorm with Hail';
        default:
          return 'Fair Weather';
      }
    }
  }

  static IconData getConditionIcon(int code) {
    switch (code) {
      case 0:
        return Icons.wb_sunny_rounded;
      case 1:
      case 2:
        return Icons.wb_cloudy_rounded;
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.foggy;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.water_drop_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.cloud_queue_rounded;
    }
  }

  String conditionDescription(bool isHindi) => getConditionDescription(weatherCode, isHindi);
  String get conditionDescriptionEn => getConditionDescription(weatherCode, false);
  String get conditionDescriptionHi => getConditionDescription(weatherCode, true);
  IconData get conditionIcon => getConditionIcon(weatherCode);

  bool get isHighHeat => temperature >= 35.0;
  bool get isHighHumidity => relativeHumidity >= 75.0;
  bool get isRainRisk =>
      precipitation > 0.0 ||
      (dailyForecasts.isNotEmpty &&
          dailyForecasts.take(2).any((d) => d.precipitationProbability > 40 || d.precipitationSum > 1.0));

  /// Scientifically defensible post-harvest micro-climate advisory
  String get weatherAdvisoryEn {
    if (isRainRisk) {
      return 'Rainfall risk detected. Protect harvested produce from wet exposure to prevent rapid bacterial rot and mold.';
    } else if (isHighHeat && isHighHumidity) {
      return 'Hot and humid conditions accelerate fungal growth and pulp softening. Maintain ventilated shade and prioritize early dispatch.';
    } else if (isHighHeat) {
      return 'High ambient temperature (°C) increases moisture loss. Keep crop shielded from direct afternoon sunlight.';
    } else if (isHighHumidity) {
      return 'Elevated humidity (%) slows natural curing. Stack crates with adequate spacing for air circulation.';
    } else {
      return 'Favorable ambient micro-climate conditions for post-harvest handling.';
    }
  }

  String get weatherAdvisoryHi {
    if (isRainRisk) {
      return 'बारिश का जोखिम: भीगने से बचाने के लिए फसल को तुरंत तिरपाल से ढकें ताकि सड़न और फंगस न लगे।';
    } else if (isHighHeat && isHighHumidity) {
      return 'उच्च तापमान व उमस: फफूंद व नरमी का खतरा अधिक है। हवादार छाया में रखें और मंडी प्रेषण में देरी न करें।';
    } else if (isHighHeat) {
      return 'अधिक तापमान (°C): नमी तेजी से घट सकती है। फसल को सीधी तेज धूप से बचाकर रखें।';
    } else if (isHighHumidity) {
      return 'उच्च आर्द्रता (%): हवा का संचार बनाए रखने के लिए क्रेट्स को उचित दूरी पर रखें।';
    } else {
      return 'कटाई उपरांत रखरखाव के लिए मौसम की स्थिति सामान्य और अनुकूल है।';
    }
  }
}
