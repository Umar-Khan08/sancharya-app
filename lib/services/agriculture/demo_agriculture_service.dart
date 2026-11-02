import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/demo_data/demo_crops.dart';
import '../../data/interfaces/i_agriculture_service.dart';
import '../../models/crop_model.dart';
import '../../models/crop_analysis_input.dart';
import '../../models/crop_analysis_result.dart';
import '../../models/agri_resource.dart';
import '../../models/weather_model.dart';
import '../location/location_service.dart';
import '../weather/weather_service.dart';
import '../resources/mandi_discovery_service.dart';
import '../resources/cold_storage_discovery_service.dart';


/// Simulated Agricultural Decision Service.
/// Implements calibrated algorithms modeling crop perishability,
/// harvest age, visual crop condition, and price volatility.
/// Fully decoupled from UI; ready to connect Python ML microservices and AGMARKNET APIs.
class DemoAgricultureService implements IAgricultureService {
  final List<CombinedCropAnalysisResult> _recentAnalyses = [];
  final IWeatherService _weatherService;
  final LocationService _locationService;
  final MandiDiscoveryService _mandiDiscoveryService;
  final ColdStorageDiscoveryService _coldStorageDiscoveryService;

  DemoAgricultureService({
    IWeatherService? weatherService,
    LocationService? locationService,
    MandiDiscoveryService? mandiDiscoveryService,
    ColdStorageDiscoveryService? coldStorageDiscoveryService,
  })  : _weatherService = weatherService ?? OpenMeteoWeatherService(),
        _locationService = locationService ?? LocationService(),
        _mandiDiscoveryService = mandiDiscoveryService ?? MandiDiscoveryService(),
        _coldStorageDiscoveryService = coldStorageDiscoveryService ?? ColdStorageDiscoveryService();

  @override
  bool get isDemonstrationProvider => true;

  @override
  Future<List<Crop>> getSupportedCrops() async {
    return DemoCrops.sampleCrops;
  }

  @override
  Future<CombinedCropAnalysisResult> analyzeCrop(CropAnalysisInput input) async {
    final totalWatch = Stopwatch()..start();
    final crop = input.crop;
    final daysElapsed = input.daysSinceHarvest;

    // 0. Resolve coordinates if not provided
    double? lat = input.latitude;
    double? lon = input.longitude;

    if (lat == null || lon == null) {
      final locWatch = Stopwatch()..start();
      try {
        final resolved = await _locationService.resolveCoordinatesForLocation(input.location);
        if (resolved != null) {
          lat = resolved.latitude;
          lon = resolved.longitude;
        }
      } catch (_) {}
      debugPrint('[TIMING] Location resolution took ${locWatch.elapsedMilliseconds}ms');
    }

    // 1. Kick off Weather, Nearby Mandis, and Cold Storage discovery concurrently!
    final weatherWatch = Stopwatch()..start();
    final mandiWatch = Stopwatch()..start();
    final coldWatch = Stopwatch()..start();

    final weatherFuture = (lat != null && lon != null)
        ? _weatherService.getWeather(
            latitude: lat,
            longitude: lon,
            locationName: input.location,
          ).timeout(const Duration(seconds: 4), onTimeout: () {
            debugPrint('[TIMING] Weather request timed out after 4s');
            return null;
          }).catchError((_) => null)
        : Future<WeatherData?>.value(null);

    final mandiDiscoveryFuture = (lat != null && lon != null)
        ? _mandiDiscoveryService.discoverNearbyMandis(
            latitude: lat,
            longitude: lon,
            district: input.location,
            maxRadiusKm: 50.0,
          ).timeout(const Duration(seconds: 4), onTimeout: () {
            debugPrint('[TIMING] Nearby mandi discovery timed out after 4s');
            return <AgriResource>[];
          }).catchError((_) => <AgriResource>[])
        : Future<List<AgriResource>>.value(<AgriResource>[]);

    final coldStorageFuture = (lat != null && lon != null)
        ? _coldStorageDiscoveryService.searchColdStorage(
            latitude: lat,
            longitude: lon,
            district: input.location,
            initialRadiusKm: 30.0,
            maxRadiusKm: 100.0,
          ).timeout(const Duration(seconds: 4), onTimeout: () {
            debugPrint('[TIMING] Cold storage search timed out after 4s');
            return const ColdStorageSearchResult(facilities: [], searchedRadiusKm: 30.0);
          }).catchError((_) => const ColdStorageSearchResult(facilities: [], searchedRadiusKm: 30.0))
        : Future<ColdStorageSearchResult>.value(const ColdStorageSearchResult(facilities: [], searchedRadiusKm: 30.0));

    final asyncResults = await Future.wait([
      weatherFuture.then((w) {
        debugPrint('[TIMING] Weather fetch took ${weatherWatch.elapsedMilliseconds}ms');
        return w;
      }),
      mandiDiscoveryFuture.then((m) {
        debugPrint('[TIMING] Nearby mandi discovery took ${mandiWatch.elapsedMilliseconds}ms');
        return m;
      }),
      coldStorageFuture.then((c) {
        debugPrint('[TIMING] Cold storage discovery took ${coldWatch.elapsedMilliseconds}ms');
        return c;
      }),
    ]);

    final weatherData = asyncResults[0] as WeatherData?;
    final mandis = asyncResults[1] as List<AgriResource>;
    final coldResult = asyncResults[2] as ColdStorageSearchResult;

    // 2. Condition Degradation Multiplier
    double conditionMultiplier;
    switch (input.condition) {
      case CropCondition.good:
        conditionMultiplier = 1.0;
        break;
      case CropCondition.average:
        conditionMultiplier = 1.6;
        break;
      case CropCondition.poor:
        conditionMultiplier = 2.8;
        break;
    }

    // 2. Shelf Life & Spoilage Calculation
    final baselineShelfLife = crop.standardShelfLifeDays.toDouble();
    final effectiveDaysElapsed = daysElapsed * conditionMultiplier;
    final safeRemainingDays = max(0, (baselineShelfLife - effectiveDaysElapsed).round());

    final riskScore = ((effectiveDaysElapsed / baselineShelfLife) * 100)
        .clamp(5.0, 98.0)
        .round();

    SpoilageRiskLevel riskLevel;
    String explanationEn;
    String explanationHi;

    if (riskScore >= 65 || safeRemainingDays <= 2 || input.condition == CropCondition.poor) {
      riskLevel = SpoilageRiskLevel.high;
      explanationEn = 'High spoilage risk due to harvest age and biological softening. Immediate sale recommended.';
      explanationHi = 'कटाई के समय और फसल की वर्तमान स्थिति के कारण खराब होने का अत्यधिक खतरा है। तुरंत बेचना अनुशंसित है।';
    } else if (riskScore >= 35 || safeRemainingDays <= 5 || input.condition == CropCondition.average) {
      riskLevel = SpoilageRiskLevel.medium;
      explanationEn = 'Moderate spoilage risk. Quality will hold for a few days under proper aeration.';
      explanationHi = 'मध्यम जोखिम है। उचित हवादार स्थान पर रखने पर फसल 3-5 दिन तक ठीक रहेगी।';
    } else {
      riskLevel = SpoilageRiskLevel.low;
      explanationEn = 'Low spoilage risk. Produce is fresh and healthy with substantial shelf life.';
      explanationHi = 'कम जोखिम है। फसल ताजी, स्वस्थ और मजबूत स्थिति में है।';
    }

    // Risk factors & preservation tips
    final riskFactorsEn = <String>[];
    final riskFactorsHi = <String>[];
    final preservationTipsEn = <String>[];
    final preservationTipsHi = <String>[];

    if (input.condition == CropCondition.poor) {
      riskFactorsEn.add('Produce exhibits visible softening, discoloration, or moisture sweating.');
      riskFactorsHi.add('फसल में मुरझान, दाग या नमी का अत्यधिक जमाव देखा गया है।');
      preservationTipsEn.add('Sort out decaying produce immediately to protect the healthy lot.');
      preservationTipsHi.add('दागी और खराब दाने तुरंत अलग करें ताकि बाकी माल सुरक्षित रहे।');
    } else if (input.condition == CropCondition.average) {
      riskFactorsEn.add('Signs of standard ambient moisture loss observed.');
      riskFactorsHi.add('सामान्य भंडारण में नमी घटने के संकेत मिले हैं।');
      preservationTipsEn.add('Store in well-ventilated crates away from direct heat.');
      preservationTipsHi.add('सीधी धूप और गर्मी से बचाकर हवादार क्रेट्स में रखें।');
    } else {
      riskFactorsEn.add('Produce is in premium farm-gate fresh condition.');
      riskFactorsHi.add('फसल उत्कृष्ट ताजा व स्वस्थ स्थिति में है।');
      preservationTipsEn.add('Maintain dry shade cover to preserve natural firmness.');
      preservationTipsHi.add('फसल की प्राकृतिक ताजगी बनाए रखने के लिए सूखी छाया में रखें।');
    }

    if (crop.category.contains('Perishable') && safeRemainingDays <= 3) {
      riskFactorsEn.add('High biological perishability: bacterial softening rapid in ambient temperatures.');
      riskFactorsHi.add('जल्दी खराब होने वाली प्रकृति: सामान्य तापमान में गुणवत्ता तेजी से गिर सकती है।');
      preservationTipsEn.add('Avoid delays in dispatching to the nearest mandi.');
      preservationTipsHi.add('नजदीकी मंडी में प्रेषण में अनावश्यक देरी न करें।');
    }

    if (weatherData != null) {
      if (weatherData.isHighHeat) {
        riskFactorsEn.add('Ambient heat warning (${weatherData.temperature.toStringAsFixed(0)}°C): Extreme temperatures accelerate cellular respiration and pulp softening.');
        riskFactorsHi.add('अत्यधिक तापमान (${weatherData.temperature.toStringAsFixed(0)}°C): उच्च गर्मी से फसल में श्वसन दर और दाने का ढीलापन तेजी से बढ़ता है।');
        preservationTipsEn.add('Keep harvest strictly in covered shade or aerated holding rooms during peak afternoon heat.');
        preservationTipsHi.add('दोपहर की तेज धूप में फसल को ढककर छायादार या हवादार कक्ष में रखें।');
      }
      if (weatherData.isHighHumidity) {
        riskFactorsEn.add('Elevated atmospheric humidity (${weatherData.relativeHumidity.toStringAsFixed(0)}%): Humid air creates condensation and promotes fungal mold growth.');
        riskFactorsHi.add('उच्च नमी (${weatherData.relativeHumidity.toStringAsFixed(0)}%): अधिक उमस से सतह पर नमी जमा होने और फंगस का जोखिम बढ़ता है।');
        preservationTipsEn.add('Stack crates with lateral spacing to maintain continuous air circulation.');
        preservationTipsHi.add('क्रेट्स को रखते समय पर्याप्त गैप रखें ताकि हवा का प्रवाह बना रहे।');
      }
      if (weatherData.isRainRisk) {
        riskFactorsEn.add('Precipitation risk: Moisture accumulation on harvested produce accelerates bacterial rot.');
        riskFactorsHi.add('बारिश की चेतावनी: पानी के संपर्क में आने से फसल में सड़न बहुत तेजी से फैलती है।');
        preservationTipsEn.add('Cover transport loads with waterproof tarpaulin and avoid unpaved wet holding areas.');
        preservationTipsHi.add('परिवहन और भंडारण के दौरान तिरपाल से अच्छी तरह ढकें और सीलन से बचाएं।');
      }
    }

    final spoilageAssessment = SpoilageRiskAssessment(
      riskLevel: riskLevel,
      riskScore: riskScore,
      safeShelfLifeDaysRemaining: safeRemainingDays,
      explanationEn: explanationEn,
      explanationHi: explanationHi,
      criticalRiskFactorsEn: riskFactorsEn,
      criticalRiskFactorsHi: riskFactorsHi,
      preservationTipsEn: preservationTipsEn,
      preservationTipsHi: preservationTipsHi,
    );

    // 3. Market Price Prediction Formulation
    final locLabel = input.location.isNotEmpty ? input.location.split(',').first.trim() : 'Selected Location';

    final marketBenchmark = MarketPriceBenchmark(
      currentAvgPricePerQuintal: 0,
      predictedFuturePricePerQuintal: 0,
      minExpectedPrice: 0,
      maxExpectedPrice: 0,
      trend: PriceTrend.stable,
      expectedPriceChangePercent: 0,
      mandiName: '$locLabel (Data Not Available)',
      fallbackLevel: 'none',
      requestedDistrict: input.location,
      noticeMessageEn: 'Data Not Available',
      noticeMessageHi: 'डेटा उपलब्ध नहीं है',
      isPredictionModelConnected: false,
      isLiveMandiData: false,
      priceUnit: '₹/quintal',
    );

    // 4. Intelligent Selling Recommendation Synthesis
    SellingRecommendation recommendation;
    if (riskLevel == SpoilageRiskLevel.high || (crop.category.contains('Perishable') && safeRemainingDays <= 2)) {
      recommendation = SellingRecommendation(
        action: SellingAction.sellNow,
        headlineEn: 'Sell Immediately in Nearest Mandi',
        headlineHi: 'नजदीकी मंडी में तुरंत बेचें',
        rationaleEn: 'Spoilage risk is critical ($riskScore%). Holding risks crop deterioration. Dispatch to nearest mandi promptly.',
        rationaleHi: 'फसल खराब होने का जोखिम गंभीर ($riskScore%) है। रुकने से उपज सड़ने का खतरा है, अतः तुरंत बेचें।',
        estimatedNetAdvantagePerQuintal: 0.0,
        nextStepsEn: [
          'Dispatch batch to nearest APMC market yard before tomorrow morning auction.',
          'Sort out damaged pieces immediately to protect the main lot value.',
          'Avoid holding stock in open farm sheds tonight.',
        ],
        nextStepsHi: [
          'कल सुबह की नीलामी से पहले माल नजदीकी मंडी यार्ड पहुंचाएं।',
          'दागी और खराब दाने तुरंत अलग करें ताकि मुख्य खेप का भाव अच्छा मिले।',
          'आज रात फसल को खुले खेत में बिल्कुल न रखें।',
        ],
      );
    } else {
      recommendation = SellingRecommendation(
        action: SellingAction.holdNormal,
        headlineEn: 'Hold in Ventilated Storage (Confirm Local Rates)',
        headlineHi: 'हवादार भंडार में सुरक्षित रखें (स्थानीय भाव की पुष्टि करें)',
        rationaleEn: 'Produce stability is good ($safeRemainingDays safe days remaining). Mandi price records are currently not available; confirm morning quotes directly with your local APMC yard before selling.',
        rationaleHi: 'फसल की स्थिति मजबूत है ($safeRemainingDays दिन सुरक्षित)। मंडी भाव उपलब्ध न होने से सीधे स्थानीय APMC यार्ड से आज के भाव की पुष्टि करें।',
        estimatedNetAdvantagePerQuintal: 0.0,
        nextStepsEn: [
          'Keep stored in a cool, dry, well-ventilated storage space.',
          'Confirm current morning modal prices directly with your local APMC yard.',
          'Inspect bottom bags every morning for temperature and humidity spikes.',
        ],
        nextStepsHi: [
          'फसल को ठंडे, सूखे और हवादार स्थान पर रखें।',
          'स्थानीय मंडी यार्ड से सीधे वर्तमान नीलामी दरों की पुष्टि करें।',
          'हर सुबह ढेर के तापमान और नमी की जांच करें।',
        ],
      );
    }


    // 5. Combine Discovered Real Nearby Mandis and Cold Storage Facilities
    final discoveredResources = <AgriResource>[
      ...mandis.take(3),
      ...coldResult.facilities.take(2),
    ];
    discoveredResources.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    debugPrint('[TIMING] DemoAgricultureService.analyzeCrop completed in ${totalWatch.elapsedMilliseconds}ms');

    final result = CombinedCropAnalysisResult(
      analysisId: 'ANALYSIS-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      input: input,
      spoilageRisk: spoilageAssessment,
      marketBenchmark: marketBenchmark,
      recommendation: recommendation,
      nearbyResources: discoveredResources,
      isSimulatedModel: true,
      weatherData: weatherData,
    );

    _recentAnalyses.insert(0, result);
    if (_recentAnalyses.length > 5) {
      _recentAnalyses.removeLast();
    }

    return result;
  }

  @override
  Future<List<CombinedCropAnalysisResult>> getRecentAnalyses() async {
    return List.unmodifiable(_recentAnalyses);
  }
}
