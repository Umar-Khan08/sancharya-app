import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/local_mandi_record.dart';

class LocalMandiMatch {
  final LocalMandiRecord mandi;
  final String matchedCropKey;
  final double pricePerQuintal;
  final double pricePerKg;
  final String sourceUrl;
  final String lastVerifiedDate;
  final String dataQuality;

  const LocalMandiMatch({
    required this.mandi,
    required this.matchedCropKey,
    required this.pricePerQuintal,
    required this.pricePerKg,
    required this.sourceUrl,
    required this.lastVerifiedDate,
    required this.dataQuality,
  });
}

/// Service for loading and querying the local 827-mandi dataset (`assets/data/mandis.json`).
/// Fully offline-ready, non-blocking, with in-memory caching.
class LocalMandiService {
  static List<LocalMandiRecord>? _cachedMandis;
  static bool _isLoading = false;

  /// Crop alias dictionary mapping canonical names, IDs, Hindi terms, and synonyms
  /// to the exact crop keys present in mandis.json.
  static const Map<String, String> _cropKeyAliases = {
    // Tomato
    'tomato': 'tomato',
    'tamatar': 'tomato',
    'tamator': 'tomato',
    'tamato': 'tomato',
    'tmatr': 'tomato',
    'टमाटर': 'tomato',

    // Onion
    'onion': 'onion',
    'pyaz': 'onion',
    'pyaaz': 'onion',
    'pyaj': 'onion',
    'kanda': 'onion',
    'प्याज': 'onion',
    'कांदा': 'onion',

    // Potato
    'potato': 'potato',
    'aloo': 'potato',
    'alu': 'potato',
    'aalu': 'potato',
    'batata': 'potato',
    'आलू': 'potato',

    // Wheat
    'wheat': 'wheat',
    'gehu': 'wheat',
    'gehun': 'wheat',
    'gehoon': 'wheat',
    'kanak': 'wheat',
    'गेहूं': 'wheat',

    // Rice
    'rice': 'rice',
    'paddy': 'rice',
    'dhan': 'rice',
    'chawal': 'rice',
    'चावल': 'rice',
    'धान': 'rice',

    // Maize
    'maize': 'maize',
    'corn': 'maize',
    'makka': 'maize',
    'makki': 'maize',
    'मक्का': 'maize',

    // Mustard
    'mustard': 'mustard',
    'sarson': 'mustard',
    'rai': 'mustard',
    'सरसों': 'mustard',

    // Soybean
    'soybean': 'soybean',
    'soya bean': 'soybean',
    'soyabean': 'soybean',
    'soya': 'soybean',
    'सोयाबीन': 'soybean',

    // Banana
    'banana': 'banana',
    'kela': 'banana',
    'केला': 'banana',

    // Cotton
    'cotton': 'cotton',
    'kapas': 'cotton',
    'कपास': 'cotton',

    // Sugarcane
    'sugarcane': 'sugarcane',
    'ganna': 'sugarcane',
    'गन्ना': 'sugarcane',

    // Groundnut
    'groundnut': 'groundnut',
    'peanut': 'groundnut',
    'moongphali': 'groundnut',
    'मूंगफली': 'groundnut',

    // Chickpea
    'chickpea': 'chickpea',
    'chana': 'chickpea',
    'चना': 'chickpea',

    // Pulses / Lentil
    'lentil': 'lentil',
    'masoor': 'lentil',
    'मसूर': 'lentil',
    'pulses': 'pulses',
    'dal': 'pulses',
    'दाल': 'pulses',
    'pigeonpeas': 'pigeonpeas',
    'arhar': 'pigeonpeas',
    'tur': 'pigeonpeas',
    'तुअर': 'pigeonpeas',
    'अरहर': 'pigeonpeas',

    // Grapes
    'grapes': 'grapes',
    'angoor': 'grapes',
    'अंगूर': 'grapes',

    // Pomegranate
    'pomegranate': 'pomegranate',
    'anaar': 'pomegranate',
    'anar': 'pomegranate',
    'अनार': 'pomegranate',

    // Coffee
    'coffee': 'coffee',
    'कॉफ़ी': 'coffee',

    // Barley
    'barley': 'barley',
    'jau': 'barley',
    'जौ': 'barley',

    // Ragi
    'ragi': 'ragi',
    'रागी': 'ragi',
  };

  /// Asynchronously loads and parses `assets/data/mandis.json`.
  /// Uses in-memory caching: reads from disk only once per application session.
  Future<List<LocalMandiRecord>> getAllMandis() async {
    if (_cachedMandis != null && _cachedMandis!.isNotEmpty) {
      return _cachedMandis!;
    }

    if (_isLoading) {
      // Small busy-wait poll if already loading concurrently
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (_cachedMandis != null) return _cachedMandis!;
    }

    _isLoading = true;
    final watch = Stopwatch()..start();

    try {
      final jsonString = await rootBundle.loadString('assets/data/mandis.json');
      final dynamic raw = jsonDecode(jsonString);

      if (raw is List) {
        final list = <LocalMandiRecord>[];
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            list.add(LocalMandiRecord.fromJson(item));
          }
        }
        _cachedMandis = list;
        debugPrint('[TIMING] Loaded and parsed ${_cachedMandis!.length} local mandis in ${watch.elapsedMilliseconds}ms');
        return _cachedMandis!;
      } else {
        debugPrint('[ERROR] mandis.json did not contain a List');
        _cachedMandis = [];
        return [];
      }
    } catch (e, stack) {
      debugPrint('[ERROR] Failed to load assets/data/mandis.json: $e\n$stack');
      _cachedMandis = [];
      return [];
    } finally {
      _isLoading = false;
    }
  }

  /// Normalizes raw crop input (name, ID, or Hindi) to the dataset crop key.
  static String? normalizeCropKey(String rawCrop) {
    final cleaned = rawCrop.trim().toLowerCase();
    if (cleaned.isEmpty) return null;

    if (_cropKeyAliases.containsKey(cleaned)) {
      return _cropKeyAliases[cleaned];
    }

    // Direct match against known keys
    const knownKeys = [
      'banana', 'barley', 'chickpea', 'coconut', 'coffee', 'cotton',
      'grapes', 'groundnut', 'lentil', 'maize', 'mothbeans', 'mustard',
      'onion', 'pigeonpeas', 'pomegranate', 'potato', 'pulses', 'ragi',
      'rice', 'soybean', 'sugarcane', 'tomato', 'vegetables', 'wheat',
    ];

    for (final key in knownKeys) {
      if (cleaned == key || cleaned.contains(key) || key.contains(cleaned)) {
        return key;
      }
    }

    return null;
  }

  /// Normalizes location string into district and state components.
  static ({String district, String? state}) parseLocation(String location) {
    final parts = location.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return (district: '', state: null);

    final rawDistrict = parts[0]
        .replaceAll(RegExp(r'\b(district|dist\.?|city|taluka|tehsil)\b', caseSensitive: false), '')
        .trim();

    String? rawState;
    if (parts.length > 1) {
      rawState = parts[1]
          .replaceAll(RegExp(r'\b(state|pradesh)\b', caseSensitive: false), '')
          .trim();
    }

    return (district: rawDistrict, state: rawState);
  }

  /// Finds the best matching mandi price in the local dataset.
  /// Strict matching rule:
  /// - ONLY matches within the requested district (or state).
  /// - Does NOT substitute a different district or state.
  /// - Returns `null` if no matching mandi record is found.
  Future<LocalMandiMatch?> findPriceForCropAndLocation({
    required String cropQuery,
    required String locationQuery,
    double? latitude,
    double? longitude,
  }) async {
    final watch = Stopwatch()..start();
    final mandis = await getAllMandis();
    if (mandis.isEmpty) return null;

    final cropKey = normalizeCropKey(cropQuery);
    if (cropKey == null) {
      debugPrint('[LocalMandiService] Crop "$cropQuery" is not matched to dataset keys.');
      return null;
    }

    final parsedLoc = parseLocation(locationQuery);
    final reqDist = parsedLoc.district.toLowerCase();
    final reqState = parsedLoc.state?.toLowerCase();

    if (reqDist.isEmpty && locationQuery.trim().isEmpty) {
      return null;
    }

    // Filter mandis that match the exact district (English or Hindi)
    final districtMatches = mandis.where((m) {
      final mDistEn = m.district.toLowerCase();
      final mDistHi = m.districtHi.toLowerCase();

      final matchesDist = (reqDist.isNotEmpty && (mDistEn == reqDist ||
          mDistEn.contains(reqDist) ||
          reqDist.contains(mDistEn) ||
          mDistHi == reqDist ||
          mDistHi.contains(reqDist)));

      if (!matchesDist) return false;

      // If state was also specified, enforce state match too
      if (reqState != null && reqState.isNotEmpty) {
        final mStateEn = m.state.toLowerCase();
        final mStateHi = m.stateHi.toLowerCase();
        final matchesState = mStateEn.contains(reqState) ||
            reqState.contains(mStateEn) ||
            mStateHi.contains(reqState);
        if (!matchesState) return false;
      }

      return true;
    }).toList();

    if (districtMatches.isEmpty) {
      debugPrint('[TIMING] LocalMandiService found NO district match for "$locationQuery" in ${watch.elapsedMilliseconds}ms');
      return null;
    }

    // Among matching mandis in the district, find ones that trade this crop
    final mandisWithCrop = districtMatches.where((m) {
      final price = m.getPricePerQuintal(cropKey);
      return price != null && price > 0;
    }).toList();

    if (mandisWithCrop.isEmpty) {
      debugPrint('[TIMING] District "${parsedLoc.district}" matches ${districtMatches.length} mandis, but none trade "$cropKey"');
      return null;
    }

    // Choose the best mandi (closest if coordinates given, or highest rating)
    LocalMandiRecord bestMandi = mandisWithCrop.first;
    if (latitude != null && longitude != null && latitude != 0 && longitude != 0) {
      double minDistance = double.infinity;
      for (final m in mandisWithCrop) {
        if (m.latitude != 0 && m.longitude != 0) {
          final d = _haversineDistance(latitude, longitude, m.latitude, m.longitude);
          if (d < minDistance) {
            minDistance = d;
            bestMandi = m;
          }
        }
      }
    } else {
      // Pick highest rating
      mandisWithCrop.sort((a, b) => b.rating.compareTo(a.rating));
      bestMandi = mandisWithCrop.first;
    }

    final pricePerQuintal = bestMandi.getPricePerQuintal(cropKey)!;
    final pricePerKg = pricePerQuintal / 100.0;

    debugPrint('[TIMING] LocalMandiService resolved rate in ${watch.elapsedMilliseconds}ms: ₹$pricePerQuintal/Qtl (₹$pricePerKg/kg) at ${bestMandi.nameEn}');

    return LocalMandiMatch(
      mandi: bestMandi,
      matchedCropKey: cropKey,
      pricePerQuintal: pricePerQuintal,
      pricePerKg: pricePerKg,
      sourceUrl: bestMandi.sourceUrl,
      lastVerifiedDate: bestMandi.lastVerifiedDate,
      dataQuality: bestMandi.dataQuality,
    );
  }

  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        ((lat2 - lat1) * p) / 2 +
        ((lat1 * p) * (lat2 * p)) * (1 - ((lon2 - lon1) * p)) / 2;
    return 12742 * (a > 0 ? (a < 1 ? a : 1) : 0);
  }
}
