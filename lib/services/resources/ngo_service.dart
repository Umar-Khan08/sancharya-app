import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/ngo_record.dart';

class NgoSearchResult {
  final List<NgoWithDistance> ngos;
  final int totalCount;
  final String? filteredDistrict;
  final String? filteredCrop;

  const NgoSearchResult({
    required this.ngos,
    required this.totalCount,
    this.filteredDistrict,
    this.filteredCrop,
  });

  bool get isEmpty => ngos.isEmpty;
  bool get isNotEmpty => ngos.isNotEmpty;
}

class NgoWithDistance {
  final NgoRecord record;
  final double? distanceKm;

  const NgoWithDistance({
    required this.record,
    this.distanceKm,
  });
}

/// Service for loading, searching, and filtering NGOs from `assets/data/ngos.json`.
/// Adheres strictly to dataset facts: never invents addresses, phone numbers, or accepted produce.
class NgoService {
  static List<NgoRecord>? _cachedNgos;
  static bool _isLoading = false;

  /// Haversine distance formula in kilometers
  static double calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a > 0 ? (a < 1 ? a : 1) : 0));
  }

  /// Loads all 827 NGOs asynchronously with in-memory caching
  Future<List<NgoRecord>> getAllNgos() async {
    if (_cachedNgos != null && _cachedNgos!.isNotEmpty) {
      return _cachedNgos!;
    }

    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (_cachedNgos != null) return _cachedNgos!;
    }

    _isLoading = true;
    final watch = Stopwatch()..start();

    try {
      final jsonString = await rootBundle.loadString('assets/data/ngos.json');
      final dynamic raw = jsonDecode(jsonString);

      if (raw is List) {
        final list = <NgoRecord>[];
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            list.add(NgoRecord.fromJson(item));
          }
        }
        _cachedNgos = list;
        debugPrint('[TIMING] Loaded and parsed ${_cachedNgos!.length} NGOs in ${watch.elapsedMilliseconds}ms');
        return _cachedNgos!;
      } else {
        debugPrint('[ERROR] ngos.json did not contain a List');
        _cachedNgos = [];
        return [];
      }
    } catch (e, stack) {
      debugPrint('[ERROR] Failed to load assets/data/ngos.json: $e\n$stack');
      _cachedNgos = [];
      return [];
    } finally {
      _isLoading = false;
    }
  }

  /// Searches and filters NGOs strictly adhering to the dataset
  Future<NgoSearchResult> searchNgos({
    String? locationQuery,
    String? cropQuery,
    bool? pickupOnly,
    String? demandLevelFilter,
    double? userLatitude,
    double? userLongitude,
  }) async {
    final watch = Stopwatch()..start();
    final all = await getAllNgos();

    String? reqDistrict;
    if (locationQuery != null && locationQuery.trim().isNotEmpty) {
      final parts = locationQuery.split(',');
      reqDistrict = parts[0]
          .replaceAll(RegExp(r'\b(district|dist\.?|city|taluka|tehsil)\b', caseSensitive: false), '')
          .trim()
          .toLowerCase();
    }

    String? cleanCrop;
    if (cropQuery != null && cropQuery.trim().isNotEmpty && cropQuery.toLowerCase() != 'all') {
      cleanCrop = cropQuery.trim().toLowerCase();
    }

    final filtered = all.where((ngo) {
      // 1. Location / District filter
      if (reqDistrict != null && reqDistrict.isNotEmpty) {
        final distEn = ngo.district.toLowerCase();
        final distHi = ngo.districtHi.toLowerCase();
        final stateEn = ngo.state.toLowerCase();
        final stateHi = ngo.stateHi.toLowerCase();

        final matchesDist = distEn.contains(reqDistrict) ||
            reqDistrict.contains(distEn) ||
            distHi.contains(reqDistrict) ||
            stateEn.contains(reqDistrict) ||
            stateHi.contains(reqDistrict);

        if (!matchesDist) return false;
      }

      // 2. Crop / Accepted produce filter
      if (cleanCrop != null) {
        if (!ngo.acceptsCrop(cleanCrop)) return false;
      }

      // 3. Pickup availability filter
      if (pickupOnly == true && !ngo.pickupAvailable) {
        return false;
      }

      // 4. Demand level filter
      if (demandLevelFilter != null && demandLevelFilter.isNotEmpty && demandLevelFilter != 'all') {
        if (ngo.demandLevel.toLowerCase() != demandLevelFilter.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    // Attach distances and sort
    final withDistance = filtered.map((record) {
      double? dist;
      if (userLatitude != null &&
          userLongitude != null &&
          userLatitude != 0 &&
          userLongitude != 0 &&
          record.latitude != 0 &&
          record.longitude != 0) {
        dist = calculateDistanceKm(
          userLatitude,
          userLongitude,
          record.latitude,
          record.longitude,
        );
      }
      return NgoWithDistance(record: record, distanceKm: dist);
    }).toList();

    if (userLatitude != null && userLongitude != null && userLatitude != 0 && userLongitude != 0) {
      withDistance.sort((a, b) {
        if (a.distanceKm == null && b.distanceKm == null) return 0;
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });
    }

    debugPrint('[TIMING] NGO search completed in ${watch.elapsedMilliseconds}ms: ${withDistance.length} matching out of ${all.length}');

    return NgoSearchResult(
      ngos: withDistance,
      totalCount: withDistance.length,
      filteredDistrict: reqDistrict,
      filteredCrop: cleanCrop,
    );
  }
}
