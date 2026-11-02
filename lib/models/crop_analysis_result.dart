import 'agri_resource.dart';
import 'crop_analysis_input.dart';
import 'weather_model.dart';

enum SpoilageRiskLevel {
  low,
  medium,
  high,
}

enum PriceTrend {
  rising,
  stable,
  falling,
}

enum SellingAction {
  sellNow,
  storeColdStorage,
  transportSoon,
  holdNormal,
}

/// Spoilage Risk Model
class SpoilageRiskAssessment {
  final SpoilageRiskLevel riskLevel;
  final int riskScore; // 0 (safest) to 100 (highest risk)
  final int safeShelfLifeDaysRemaining;
  final String explanationEn;
  final String explanationHi;
  final List<String> criticalRiskFactorsEn;
  final List<String> criticalRiskFactorsHi;
  final List<String> preservationTipsEn;
  final List<String> preservationTipsHi;

  const SpoilageRiskAssessment({
    required this.riskLevel,
    required this.riskScore,
    required this.safeShelfLifeDaysRemaining,
    required this.explanationEn,
    required this.explanationHi,
    required this.criticalRiskFactorsEn,
    required this.criticalRiskFactorsHi,
    required this.preservationTipsEn,
    required this.preservationTipsHi,
  });

  String getExplanation(bool isHindi) => isHindi ? explanationHi : explanationEn;

  List<String> getRiskFactors(bool isHindi) =>
      isHindi ? criticalRiskFactorsHi : criticalRiskFactorsEn;

  List<String> getPreservationTips(bool isHindi) =>
      isHindi ? preservationTipsHi : preservationTipsEn;
}

/// Mandi Market Price Prediction Benchmark
class MarketPriceBenchmark {
  final double currentAvgPricePerQuintal;
  final double predictedFuturePricePerQuintal;
  final double minExpectedPrice;
  final double maxExpectedPrice;
  final PriceTrend trend;
  final double expectedPriceChangePercent;
  final String mandiName;
  final bool isPredictionModelConnected;
  final bool isLiveMandiData;
  final bool isDatasetRecord;
  final bool isDatabaseRecord;
  final String priceUnit;

  // Specific provenance fields
  final String? market;
  final String? district;
  final String? state;
  final String? arrivalDate;
  final String? fallbackLevel; // 'district', 'nearby_mandi', 'state', 'nationwide', or 'demonstration'
  final String? requestedDistrict;
  final String? noticeMessageEn;
  final String? noticeMessageHi;
  final double? distanceKm;
  final String? forecastModelName;
  final double? holdoutMape;
  final int? forecastHorizonDays;
  final String? forecastPeriod;
  final bool isGenuineHoldout;
  final int? historicalObservationCount;
  final String? sourceUrl;
  final String? lastVerifiedDate;
  final String? dataQuality;
  final bool isStale;
  final bool isHistorical;
  final String? sourceName;
  final String? statusReason;

  const MarketPriceBenchmark({
    required this.currentAvgPricePerQuintal,
    required this.predictedFuturePricePerQuintal,
    required this.minExpectedPrice,
    required this.maxExpectedPrice,
    required this.trend,
    required this.expectedPriceChangePercent,
    required this.mandiName,
    this.isPredictionModelConnected = false,
    this.isLiveMandiData = false,
    this.isDatasetRecord = false,
    this.isDatabaseRecord = false,
    this.priceUnit = '₹/quintal',
    this.market,
    this.district,
    this.state,
    this.arrivalDate,
    this.fallbackLevel,
    this.requestedDistrict,
    this.noticeMessageEn,
    this.noticeMessageHi,
    this.distanceKm,
    this.forecastModelName,
    this.holdoutMape,
    this.forecastHorizonDays,
    this.forecastPeriod,
    this.isGenuineHoldout = false,
    this.historicalObservationCount,
    this.sourceUrl,
    this.lastVerifiedDate,
    this.dataQuality,
    this.isStale = false,
    this.isHistorical = false,
    this.sourceName,
    this.statusReason,
  });

  bool get hasLiveRecord =>
      (isLiveMandiData || isDatasetRecord || isDatabaseRecord || isHistorical) &&
      currentAvgPricePerQuintal >= 100.0;
  bool get isNetworkError => fallbackLevel == 'error';
  bool get isDataNotAvailable => !hasLiveRecord && !isNetworkError;
  bool get isRejectedRecord => statusReason == 'rejected';
  bool get hasValidPrediction =>
      isPredictionModelConnected && hasVerifiedAccuracy && predictedFuturePricePerQuintal > 0;

  bool get isNearbyMandi => fallbackLevel == 'nearby_mandi';
  bool get isStateFallback => fallbackLevel == 'state';
  bool get isNationwideFallback => fallbackLevel == 'nationwide';
  bool get isDistrictLive =>
      (fallbackLevel == 'district' || fallbackLevel == null) &&
      isLiveMandiData &&
      !isDatabaseRecord &&
      !isDatasetRecord &&
      !isHistorical;
  bool get isDemonstration =>
      !isLiveMandiData && !isDatasetRecord && !isDatabaseRecord && !isHistorical;
  bool get hasVerifiedAccuracy =>
      isGenuineHoldout && holdoutMape != null && isPredictionModelConnected;
  bool get isStaleRecord => isStale || isHistorical;
  bool get isOfflineLocal => isDatasetRecord && !isLiveMandiData && !isDatabaseRecord;
  bool get isStoredDatabaseObservation => isDatabaseRecord && !isLiveMandiData;

  String? noticeMessage(bool isHindi) => isHindi ? noticeMessageHi : noticeMessageEn;

  /// 1 Quintal = 100 Kilograms
  double get pricePerKg => currentAvgPricePerQuintal / 100.0;
  double get predictedFuturePricePerKg => predictedFuturePricePerQuintal / 100.0;
}

/// Selling Action Recommendation
class SellingRecommendation {
  final SellingAction action;
  final String headlineEn;
  final String headlineHi;
  final String rationaleEn;
  final String rationaleHi;
  final double estimatedNetAdvantagePerQuintal;
  final List<String> nextStepsEn;
  final List<String> nextStepsHi;

  const SellingRecommendation({
    required this.action,
    required this.headlineEn,
    required this.headlineHi,
    required this.rationaleEn,
    required this.rationaleHi,
    required this.estimatedNetAdvantagePerQuintal,
    required this.nextStepsEn,
    required this.nextStepsHi,
  });

  String getHeadline(bool isHindi) => isHindi ? headlineHi : headlineEn;
  String getRationale(bool isHindi) => isHindi ? rationaleHi : rationaleEn;
  List<String> getNextSteps(bool isHindi) => isHindi ? nextStepsHi : nextStepsEn;
}

/// Combined Decision Support Output
/// Presenting price prediction, spoilage risk, discovered nearby resources, and smart advice together.
class CombinedCropAnalysisResult {
  final String analysisId;
  final DateTime timestamp;
  final CropAnalysisInput input;
  final SpoilageRiskAssessment spoilageRisk;
  final MarketPriceBenchmark marketBenchmark;
  final SellingRecommendation recommendation;
  final List<AgriResource> nearbyResources;
  final bool isSimulatedModel;
  final WeatherData? weatherData;

  const CombinedCropAnalysisResult({
    required this.analysisId,
    required this.timestamp,
    required this.input,
    required this.spoilageRisk,
    required this.marketBenchmark,
    required this.recommendation,
    required this.nearbyResources,
    this.isSimulatedModel = true,
    this.weatherData,
  });

  /// Calculated estimated gross crop value based on quantity and rate (null if price unavailable)
  double? get grossCropValue {
    if (!marketBenchmark.hasLiveRecord) return null;
    if (input.quantityUnit == QuantityUnit.kilogram) {
      return input.quantity * marketBenchmark.pricePerKg;
    } else {
      return input.quantity * marketBenchmark.currentAvgPricePerQuintal;
    }
  }

  /// Plain text summary synthesized for voice Text-to-Speech (English)
  String get speechSummaryEn {
    final cropName = input.crop.nameEn;
    final riskText = spoilageRisk.riskLevel == SpoilageRiskLevel.low
        ? 'Low Risk'
        : spoilageRisk.riskLevel == SpoilageRiskLevel.medium
            ? 'Moderate Risk'
            : 'High Spoilage Risk';
    final actionText = recommendation.headlineEn;

    String priceText;
    if (marketBenchmark.hasLiveRecord) {
      final predPart = marketBenchmark.hasValidPrediction
          ? ', with expected future rate of ₹${marketBenchmark.predictedFuturePricePerQuintal.toStringAsFixed(0)}'
          : '';
      final grossPart = grossCropValue != null
          ? ' Estimated gross value for ${input.quantity.toStringAsFixed(0)} ${input.quantityUnit == QuantityUnit.kilogram ? "kg" : "quintals"} is ₹${grossCropValue!.toStringAsFixed(0)} before costs.'
          : '';
      priceText = 'Current market price is ₹${marketBenchmark.currentAvgPricePerQuintal.toStringAsFixed(0)} per quintal$predPart.$grossPart';
    } else if (marketBenchmark.isNetworkError) {
      priceText = 'Unable to fetch price data. Please try again.';
    } else {
      priceText = 'Mandi price data is not available for this location.';
    }

    String weatherSummary = '';
    if (weatherData != null) {
      weatherSummary = ' Local weather: ${weatherData!.temperature.toStringAsFixed(0)} degrees Celsius, ${weatherData!.conditionDescriptionEn}, with humidity ${weatherData!.relativeHumidity.toStringAsFixed(0)} percent. ${weatherData!.weatherAdvisoryEn}';
    }

    return '$cropName analysis report: Spoilage is at $riskText, with ${spoilageRisk.safeShelfLifeDaysRemaining} safe days remaining. Recommended action: $actionText. $priceText$weatherSummary';
  }

  /// Plain text summary synthesized for voice Text-to-Speech (Hindi)
  String get speechSummaryHi {
    final cropName = input.crop.nameHi;
    final riskText = spoilageRisk.riskLevel == SpoilageRiskLevel.low
        ? 'कम जोखिम'
        : spoilageRisk.riskLevel == SpoilageRiskLevel.medium
            ? 'मध्यम जोखिम'
            : 'अत्यधिक खराब होने का खतरा';
    final actionText = recommendation.headlineHi;

    String priceText;
    if (marketBenchmark.hasLiveRecord) {
      final predPart = marketBenchmark.hasValidPrediction
          ? ', और भविष्य का अनुमानित भाव ₹${marketBenchmark.predictedFuturePricePerQuintal.toStringAsFixed(0)} है'
          : '';
      final grossPart = grossCropValue != null
          ? ' ${input.quantity.toStringAsFixed(0)} ${input.quantityUnit == QuantityUnit.kilogram ? "किलोग्राम" : "क्विंटल"} का अनुमानित सकल मूल्य लगभग ₹${grossCropValue!.toStringAsFixed(0)} है।'
          : '';
      priceText = 'वर्तमान मंडी भाव लगभग ₹${marketBenchmark.currentAvgPricePerQuintal.toStringAsFixed(0)} प्रति क्विंटल है$predPart।$grossPart';
    } else if (marketBenchmark.isNetworkError) {
      priceText = 'मंडी भाव प्राप्त करने में असमर्थ। कृपया पुनः प्रयास करें।';
    } else {
      priceText = 'इस स्थान के लिए मंडी भाव उपलब्ध नहीं है।';
    }

    String weatherSummary = '';
    if (weatherData != null) {
      weatherSummary = ' स्थानीय मौसम: ${weatherData!.temperature.toStringAsFixed(0)} डिग्री सेल्सियस, ${weatherData!.conditionDescriptionHi}, और आर्द्रता ${weatherData!.relativeHumidity.toStringAsFixed(0)} प्रतिशत है। ${weatherData!.weatherAdvisoryHi}';
    }

    return '$cropName विश्लेषण रिपोर्ट: खराब होने का जोखिम $riskText है, और ${spoilageRisk.safeShelfLifeDaysRemaining} दिन सुरक्षित भंडारण शेष है। सलाह: $actionText। $priceText$weatherSummary';
  }
}
