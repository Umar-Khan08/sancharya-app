import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/crop_analysis_input.dart';
import '../../models/crop_analysis_result.dart';
import '../../models/crop_model.dart';
import '../../models/agri_resource.dart';

/// Local offline persistence service for Farmer Search & Analysis History.
///
/// Features:
/// - Scoped to authenticated farmer user (phone number) or guest default.
/// - Stores only essential analysis metadata (no secrets, OTPs, or API keys).
/// - Deduplicates rapid repeated submissions from widget rebuilds.
/// - Orders entries newest first.
/// - Persists across application restarts via SharedPreferences.
class SearchHistoryService {
  static const String _baseKey = 'sancharya_farmer_search_history';
  static const int maxHistoryEntries = 10;

  static String _storageKey(String? userPhone) {
    if (userPhone != null && userPhone.trim().isNotEmpty) {
      final clean = userPhone.replaceAll(RegExp(r'\D'), '');
      if (clean.isNotEmpty) {
        return '${_baseKey}_$clean';
      }
    }
    return '${_baseKey}_default';
  }

  /// Saves a successfully completed crop analysis to local history.
  /// Rejects incomplete or invalid searches (empty crop or location).
  static Future<bool> saveAnalysis(
    CombinedCropAnalysisResult result, {
    String? userPhone,
  }) async {
    try {
      final input = result.input;
      // Requirement: Invalid or incomplete searches are not saved as completed analyses
      if (input.crop.nameEn.trim().isEmpty || input.location.trim().isEmpty) {
        return false;
      }
      if (input.quantity <= 0) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = _storageKey(userPhone);
      final rawList = prefs.getStringList(key) ?? [];

      final existingEntries = <Map<String, dynamic>>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          existingEntries.add(decoded);
        } catch (_) {
          // Skip corrupted entries safely
        }
      }

      final newEntry = _serializeResult(result, userPhone);

      // Anti-duplicate protection: avoid duplicate entries caused by widget rebuilds or repeated callbacks
      existingEntries.removeWhere((item) {
        if (item['analysisId'] == result.analysisId) return true;
        // Same crop, location, and quantity within 2 minutes
        final sameCrop = item['cropId'] == input.crop.id || item['cropNameEn'] == input.crop.nameEn;
        final sameLoc = (item['location']?.toString().toLowerCase().trim()) == input.location.toLowerCase().trim();
        final sameQty = (item['quantity'] as num?)?.toDouble() == input.quantity;
        if (sameCrop && sameLoc && sameQty) {
          final itemTime = DateTime.tryParse(item['timestamp']?.toString() ?? '');
          if (itemTime != null && result.timestamp.difference(itemTime).inMinutes.abs() < 2) {
            return true;
          }
        }
        return false;
      });

      // Insert newest at top
      existingEntries.insert(0, newEntry);

      // Enforce limit
      if (existingEntries.length > maxHistoryEntries) {
        existingEntries.removeRange(maxHistoryEntries, existingEntries.length);
      }

      final encodedList = existingEntries.map((e) => jsonEncode(e)).toList();
      await prefs.setStringList(key, encodedList);
      return true;
    } catch (e) {
      debugPrint('[SEARCH_HISTORY] Failed to save search history: $e');
      return false;
    }
  }

  /// Retrieves stored search history, ordered newest first.
  static Future<List<CombinedCropAnalysisResult>> getRecentAnalyses({
    String? userPhone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKey(userPhone);
      final rawList = prefs.getStringList(key) ?? [];

      final results = <CombinedCropAnalysisResult>[];
      for (final raw in rawList) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final parsed = _deserializeResult(map);
          if (parsed != null) {
            results.add(parsed);
          }
        } catch (_) {
          // Skip corrupted entries gracefully
        }
      }

      // Ensure sorted newest first
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return results;
    } catch (e) {
      debugPrint('[SEARCH_HISTORY] Error loading search history: $e');
      return [];
    }
  }

  /// Clears stored history for the current user or guest.
  static Future<void> clearHistory({String? userPhone}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKey(userPhone);
      await prefs.remove(key);
    } catch (_) {}
  }

  static Map<String, dynamic> _serializeResult(
    CombinedCropAnalysisResult res,
    String? userPhone,
  ) {
    final input = res.input;
    final risk = res.spoilageRisk;
    final bench = res.marketBenchmark;
    final rec = res.recommendation;

    return {
      'analysisId': res.analysisId,
      'timestamp': res.timestamp.toIso8601String(),
      'cropId': input.crop.id,
      'cropNameEn': input.crop.nameEn,
      'cropNameHi': input.crop.nameHi,
      'cropCategory': input.crop.category,
      'shelfLifeDays': input.crop.standardShelfLifeDays,
      'benchmarkPrice': input.crop.benchmarkPricePerQuintal,
      'location': input.location,
      'quantity': input.quantity,
      'quantityUnit': input.quantityUnit.name,
      'harvestDate': input.harvestDate.toIso8601String(),
      'condition': input.condition.name,
      'latitude': input.latitude,
      'longitude': input.longitude,
      // Spoilage risk
      'riskLevel': risk.riskLevel.name,
      'riskScore': risk.riskScore,
      'safeShelfLife': risk.safeShelfLifeDaysRemaining,
      'riskExplEn': risk.explanationEn,
      'riskExplHi': risk.explanationHi,
      // Recommendation
      'recAction': rec.action.name,
      'headlineEn': rec.headlineEn,
      'headlineHi': rec.headlineHi,
      'rationaleEn': rec.rationaleEn,
      'rationaleHi': rec.rationaleHi,
      'netAdvantage': rec.estimatedNetAdvantagePerQuintal,
      // Market benchmark
      'currentAvgPrice': bench.currentAvgPricePerQuintal,
      'predictedPrice': bench.predictedFuturePricePerQuintal,
      'minExpectedPrice': bench.minExpectedPrice,
      'maxExpectedPrice': bench.maxExpectedPrice,
      'mandiName': bench.mandiName,
      'district': bench.district,
      'state': bench.state,
      'priceTrend': bench.trend.name,
      'expectedChangePercent': bench.expectedPriceChangePercent,
      'priceUnit': bench.priceUnit,
      'isLiveMandiData': bench.isLiveMandiData,
      'isDatabaseRecord': bench.isDatabaseRecord,
      'isDatasetRecord': bench.isDatasetRecord,
      'isHistorical': bench.isHistorical,
      'sourceName': bench.sourceName,
      'sourceUrl': bench.sourceUrl,
      'arrivalDate': bench.arrivalDate,
      'userPhone': userPhone,
      'nearbyResources': res.nearbyResources.map((r) => {
        'id': r.id,
        'nameEn': r.nameEn,
        'nameHi': r.nameHi,
        'type': r.type.name,
        'districtEn': r.districtEn,
        'districtHi': r.districtHi,
        'distanceKm': r.distanceKm,
        'capacityMetricTons': r.capacityMetricTons,
        'availableMetricTons': r.availableMetricTons,
        'contactPhone': r.contactPhone,
        'estimatedRatePerMonthPerQuintal': r.estimatedRatePerMonthPerQuintal,
        'isGovernmentAccredited': r.isGovernmentAccredited,
        'isSimulatedData': r.isSimulatedData,
        'isOsmMapped': r.isOsmMapped,
        'hasLiveAgmarknetPrice': r.hasLiveAgmarknetPrice,
        'isCapacityVerified': r.isCapacityVerified,
        'isPhoneVerified': r.isPhoneVerified,
        'verificationNoticeEn': r.verificationNoticeEn,
        'verificationNoticeHi': r.verificationNoticeHi,
        'latitude': r.latitude,
        'longitude': r.longitude,
      }).toList(),
    };
  }

  static CombinedCropAnalysisResult? _deserializeResult(Map<String, dynamic> json) {
    try {
      final crop = Crop(
        id: json['cropId']?.toString() ?? 'crop_unknown',
        nameEn: json['cropNameEn']?.toString() ?? 'Crop',
        nameHi: json['cropNameHi']?.toString() ?? 'फसल',
        category: json['cropCategory']?.toString() ?? 'General',
        standardShelfLifeDays: (json['shelfLifeDays'] as num?)?.toInt() ?? 7,
        benchmarkPricePerQuintal: (json['benchmarkPrice'] as num?)?.toDouble() ?? 2000.0,
      );

      final quantityUnit = json['quantityUnit'] == 'kilogram'
          ? QuantityUnit.kilogram
          : QuantityUnit.quintal;

      final condition = CropCondition.values.firstWhere(
        (c) => c.name == json['condition'],
        orElse: () => CropCondition.good,
      );

      final harvestDate = DateTime.tryParse(json['harvestDate']?.toString() ?? '') ?? DateTime.now();

      final input = CropAnalysisInput(
        crop: crop,
        location: json['location']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 10.0,
        quantityUnit: quantityUnit,
        harvestDate: harvestDate,
        condition: condition,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

      final riskLevel = SpoilageRiskLevel.values.firstWhere(
        (r) => r.name == json['riskLevel'],
        orElse: () => SpoilageRiskLevel.low,
      );

      final risk = SpoilageRiskAssessment(
        riskLevel: riskLevel,
        riskScore: (json['riskScore'] as num?)?.toInt() ?? 20,
        safeShelfLifeDaysRemaining: (json['safeShelfLife'] as num?)?.toInt() ?? 5,
        explanationEn: json['riskExplEn']?.toString() ?? '',
        explanationHi: json['riskExplHi']?.toString() ?? '',
        criticalRiskFactorsEn: const [],
        criticalRiskFactorsHi: const [],
        preservationTipsEn: const [],
        preservationTipsHi: const [],
      );

      final action = SellingAction.values.firstWhere(
        (a) => a.name == json['recAction'],
        orElse: () => SellingAction.sellNow,
      );

      final rec = SellingRecommendation(
        action: action,
        headlineEn: json['headlineEn']?.toString() ?? '',
        headlineHi: json['headlineHi']?.toString() ?? '',
        rationaleEn: json['rationaleEn']?.toString() ?? '',
        rationaleHi: json['rationaleHi']?.toString() ?? '',
        estimatedNetAdvantagePerQuintal: (json['netAdvantage'] as num?)?.toDouble() ?? 0.0,
        nextStepsEn: const [],
        nextStepsHi: const [],
      );

      final trend = PriceTrend.values.firstWhere(
        (t) => t.name == json['priceTrend'],
        orElse: () => PriceTrend.stable,
      );

      final bench = MarketPriceBenchmark(
        currentAvgPricePerQuintal: (json['currentAvgPrice'] as num?)?.toDouble() ?? 0.0,
        predictedFuturePricePerQuintal: (json['predictedPrice'] as num?)?.toDouble() ?? 0.0,
        minExpectedPrice: (json['minExpectedPrice'] as num?)?.toDouble() ?? 0.0,
        maxExpectedPrice: (json['maxExpectedPrice'] as num?)?.toDouble() ?? 0.0,
        trend: trend,
        expectedPriceChangePercent: (json['expectedChangePercent'] as num?)?.toDouble() ?? 0.0,
        mandiName: json['mandiName']?.toString() ?? 'Nearby APMC',
        district: json['district']?.toString(),
        state: json['state']?.toString(),
        fallbackLevel: 'district',
        requestedDistrict: json['district']?.toString() ?? json['location']?.toString() ?? '',
        isLiveMandiData: json['isLiveMandiData'] == true,
        isDatabaseRecord: json['isDatabaseRecord'] == true,
        isDatasetRecord: json['isDatasetRecord'] == true,
        isHistorical: json['isHistorical'] == true,
        sourceName: json['sourceName']?.toString(),
        sourceUrl: json['sourceUrl']?.toString(),
        arrivalDate: json['arrivalDate']?.toString(),
        priceUnit: json['priceUnit']?.toString() ?? '₹/quintal',
      );

      final timestamp = DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now();

      final rawRes = json['nearbyResources'] as List<dynamic>? ?? [];
      final nearbyList = rawRes.map((r) {
        if (r is! Map<String, dynamic>) return null;
        final type = AgriResourceType.values.firstWhere(
          (t) => t.name == r['type'],
          orElse: () => AgriResourceType.coldStorage,
        );
        return AgriResource(
          id: r['id']?.toString() ?? '',
          nameEn: r['nameEn']?.toString() ?? '',
          nameHi: r['nameHi']?.toString() ?? (r['nameEn']?.toString() ?? ''),
          type: type,
          districtEn: r['districtEn']?.toString() ?? '',
          districtHi: r['districtHi']?.toString() ?? '',
          distanceKm: (r['distanceKm'] as num?)?.toDouble() ?? 0.0,
          capacityMetricTons: (r['capacityMetricTons'] as num?)?.toDouble() ?? 0.0,
          availableMetricTons: (r['availableMetricTons'] as num?)?.toDouble() ?? 0.0,
          contactPhone: r['contactPhone']?.toString() ?? '',
          estimatedRatePerMonthPerQuintal: (r['estimatedRatePerMonthPerQuintal'] as num?)?.toDouble() ?? 0.0,
          isGovernmentAccredited: r['isGovernmentAccredited'] == true,
          isSimulatedData: r['isSimulatedData'] == true,
          isOsmMapped: r['isOsmMapped'] == true,
          hasLiveAgmarknetPrice: r['hasLiveAgmarknetPrice'] == true,
          isCapacityVerified: r['isCapacityVerified'] == true,
          isPhoneVerified: r['isPhoneVerified'] == true,
          verificationNoticeEn: r['verificationNoticeEn']?.toString(),
          verificationNoticeHi: r['verificationNoticeHi']?.toString(),
          latitude: (r['latitude'] as num?)?.toDouble(),
          longitude: (r['longitude'] as num?)?.toDouble(),
        );
      }).whereType<AgriResource>().toList();

      return CombinedCropAnalysisResult(
        analysisId: json['analysisId']?.toString() ?? 'ANALYSIS-${timestamp.millisecondsSinceEpoch}',
        timestamp: timestamp,
        input: input,
        spoilageRisk: risk,
        marketBenchmark: bench,
        recommendation: rec,
        nearbyResources: nearbyList,
        isSimulatedModel: false,
      );
    } catch (e) {
      debugPrint('[SEARCH_HISTORY] Deserialization error: $e');
      return null;
    }
  }
}
