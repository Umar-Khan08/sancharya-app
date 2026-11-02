import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/models/agri_resource.dart';
import 'package:sancharya/models/crop_analysis_input.dart';
import 'package:sancharya/models/crop_analysis_result.dart';
import 'package:sancharya/models/weather_model.dart';
import 'package:sancharya/services/location/location_service.dart';
import 'package:sancharya/services/resources/mandi_discovery_service.dart';
import 'package:sancharya/services/weather/weather_service.dart';
import 'package:sancharya/data/demo_data/demo_crops.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService & Geocoding Tests', () {
    test('LocationCoordinates cache provides instant lookup for major Indian agri hubs', () async {
      final service = LocationService();
      final nashikCoords = await service.resolveCoordinatesForLocation('Nashik, Maharashtra');
      expect(nashikCoords, isNotNull);
      expect(nashikCoords!.latitude, closeTo(19.99, 0.05));
      expect(nashikCoords.longitude, closeTo(73.78, 0.05));

      final puneCoords = await service.resolveCoordinatesForLocation('Pune, Maharashtra');
      expect(puneCoords, isNotNull);
      expect(puneCoords!.latitude, closeTo(18.52, 0.05));

      final indoreCoords = await service.resolveCoordinatesForLocation('Indore, Madhya Pradesh');
      expect(indoreCoords, isNotNull);
      expect(indoreCoords!.latitude, closeTo(22.71, 0.05));
    });

    test('LocationResult returns bilingual error messages', () {
      const disabledResult = LocationResult(
        status: LocationStatus.serviceDisabled,
        errorMessageEn: 'GPS disabled.',
        errorMessageHi: 'जीपीएस बंद है।',
      );

      expect(disabledResult.displayError(false), 'GPS disabled.');
      expect(disabledResult.displayError(true), 'जीपीएस बंद है।');
      expect(disabledResult.isSuccess, false);
    });
  });

  group('Open-Meteo Weather Model & Advisories Tests', () {
    test('WMO weather interpretation codes translate to English and Hindi', () {
      expect(WeatherData.getConditionDescription(0, false), 'Clear Sky');
      expect(WeatherData.getConditionDescription(0, true), 'साफ़ आसमान');

      expect(WeatherData.getConditionDescription(2, false), 'Partly Cloudy');
      expect(WeatherData.getConditionDescription(2, true), 'आंशिक रूप से बादल');

      expect(WeatherData.getConditionDescription(63, false), 'Moderate Rain');
      expect(WeatherData.getConditionDescription(63, true), 'मध्यम बारिश');

      expect(WeatherData.getConditionDescription(95, false), 'Thunderstorm');
      expect(WeatherData.getConditionDescription(95, true), 'गरज के साथ बारिश');
    });

    test('High heat and high humidity generate scientifically grounded post-harvest advisories', () {
      final hotWeather = WeatherData(
        temperature: 38.5,
        apparentTemperature: 41.0,
        relativeHumidity: 82.0,
        precipitation: 0.0,
        windSpeed: 8.0,
        weatherCode: 1,
        timestamp: DateTime.now(),
        isLive: true,
        latitude: 20.0,
        longitude: 73.78,
      );

      expect(hotWeather.isHighHeat, true);
      expect(hotWeather.isHighHumidity, true);
      expect(hotWeather.weatherAdvisoryEn.contains('Hot and humid conditions accelerate fungal growth'), true);
      expect(hotWeather.weatherAdvisoryHi.contains('उच्च तापमान व उमस'), true);
    });

    test('Rainfall risk advisory flags moisture damage', () {
      final rainyWeather = WeatherData(
        temperature: 26.0,
        apparentTemperature: 26.0,
        relativeHumidity: 90.0,
        precipitation: 4.5,
        windSpeed: 12.0,
        weatherCode: 63,
        timestamp: DateTime.now(),
        isLive: true,
        latitude: 20.0,
        longitude: 73.78,
      );

      expect(rainyWeather.isRainRisk, true);
      expect(rainyWeather.weatherAdvisoryEn.contains('Rainfall risk detected'), true);
      expect(rainyWeather.weatherAdvisoryHi.contains('बारिश का जोखिम'), true);
    });

    test('OpenMeteoWeatherService rejects invalid coordinates without making bad requests', () async {
      final service = OpenMeteoWeatherService();
      final nullResult = await service.getWeather(latitude: 0.0, longitude: 0.0);
      expect(nullResult, isNull);

      final outOfBounds = await service.getWeather(latitude: 95.0, longitude: 200.0);
      expect(outOfBounds, isNull);
    });
  });

  group('MandiDiscoveryService & Distance Tests', () {
    test('Haversine distance calculation is mathematically accurate', () {
      // Distance between Nashik (19.9975, 73.7898) and Lasalgaon (20.1478, 74.2255)
      // Approximate straight-line distance is ~48 km
      final dist = MandiDiscoveryService.calculateDistanceKm(
        19.9975, 73.7898,
        20.1478, 74.2255,
      );

      expect(dist, greaterThan(40.0));
      expect(dist, lessThan(55.0));
    });

    test('Discovered physical mandis are clearly tagged as OSM Mapped and distinguish live Agmarknet prices', () {
      const mandi = AgriResource(
        id: 'osm_123',
        nameEn: 'Pimpalgaon APMC Yard',
        nameHi: 'पिंपलगांव मंडी',
        type: AgriResourceType.mandi,
        districtEn: 'Nashik',
        districtHi: 'नासिक',
        distanceKm: 18.5,
        capacityMetricTons: 0,
        availableMetricTons: 0,
        contactPhone: 'Inquire at APMC Gate',
        estimatedRatePerMonthPerQuintal: 0,
        isGovernmentAccredited: true,
        isSimulatedData: false,
        isOsmMapped: true,
        hasLiveAgmarknetPrice: false,
      );

      expect(mandi.isOsmMapped, true);
      expect(mandi.hasLiveAgmarknetPrice, false);
      expect(mandi.isSimulatedData, false);
      expect(mandi.distanceKm, 18.5);
    });

    test('MandiDiscoveryService preserves genuine agricultural mandis and excludes cloth markets for Kanpur Nagar', () async {
      final service = MandiDiscoveryService();
      final results = await service.discoverNearbyMandis(
        latitude: 26.4499,
        longitude: 80.3319,
        district: 'Kanpur Nagar',
        maxRadiusKm: 30.0,
      );

      // Verifies genuine agricultural mandis (Chakarpur / Collectorganj) are discovered
      expect(
        results.any((r) =>
            r.nameEn.toLowerCase().contains('chakarpur') ||
            r.nameEn.toLowerCase().contains('collectorganj')),
        true,
      );

      // Verifies non-agricultural cloth/textile markets (Naveen Market) are strictly excluded
      expect(
        results.any((r) => r.nameEn.toLowerCase().contains('naveen market')),
        false,
      );
    });
  });

  group('Voice Narration with Weather Integration Tests', () {
    test('Speech summary incorporates local weather observations when present', () {
      final crop = DemoCrops.sampleCrops.first;
      final input = CropAnalysisInput(
        crop: crop,
        location: 'Nashik, Maharashtra',
        quantity: 30,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
        latitude: 20.0,
        longitude: 73.78,
      );

      final weather = WeatherData(
        temperature: 31.0,
        apparentTemperature: 32.0,
        relativeHumidity: 45.0,
        precipitation: 0.0,
        windSpeed: 4.0,
        weatherCode: 0,
        timestamp: DateTime.now(),
        isLive: true,
        latitude: 20.0,
        longitude: 73.78,
      );

      const benchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2000,
        predictedFuturePricePerQuintal: 2100,
        minExpectedPrice: 1800,
        maxExpectedPrice: 2300,
        trend: PriceTrend.rising,
        expectedPriceChangePercent: 5.0,
        mandiName: 'Nashik APMC',
      );

      const spoilage = SpoilageRiskAssessment(
        riskLevel: SpoilageRiskLevel.low,
        riskScore: 20,
        safeShelfLifeDaysRemaining: 12,
        explanationEn: 'Produce is healthy',
        explanationHi: 'फसल सुरक्षित है',
        criticalRiskFactorsEn: [],
        criticalRiskFactorsHi: [],
        preservationTipsEn: [],
        preservationTipsHi: [],
      );

      const recommendation = SellingRecommendation(
        action: SellingAction.holdNormal,
        headlineEn: 'Hold produce in ventilated storage',
        headlineHi: 'हवादार भंडार में सुरक्षित रखें',
        rationaleEn: 'Market rates steady',
        rationaleHi: 'बाज़ार भाव स्थिर हैं',
        estimatedNetAdvantagePerQuintal: 2000,
        nextStepsEn: ['Inspect regularly'],
        nextStepsHi: ['नियमित जांच करें'],
      );

      final result = CombinedCropAnalysisResult(
        analysisId: 'TEST-1',
        timestamp: DateTime.now(),
        input: input,
        spoilageRisk: spoilage,
        marketBenchmark: benchmark,
        recommendation: recommendation,
        nearbyResources: [],
        weatherData: weather,
      );

      expect(result.speechSummaryEn.contains('31 degrees Celsius'), true);
      expect(result.speechSummaryEn.contains('Clear Sky'), true);
      expect(result.speechSummaryHi.contains('31 डिग्री सेल्सियस'), true);
      expect(result.speechSummaryHi.contains('साफ़ आसमान'), true);
    });
  });
}
