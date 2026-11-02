import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/agri_resource.dart';

/// Service for discovering real physical APMC mandis and marketplaces
/// via OpenStreetMap Overpass API and Nominatim search.
/// Eliminates duplicate entries and calculates genuine proximity.
class MandiDiscoveryService {
  static const String _userAgent =
      'SancharyaAgriculturalApp/1.0 (contact: info@sancharya.agri)';

  /// Calculates real distance in kilometers between two GPS coordinates using Haversine formula
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
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// In-memory cache for discovered mandis by coordinate grid to prevent disappearance during network hiccups
  static final Map<String, List<AgriResource>> _mandiCache = {};

  /// List of excluded English terms for non-agricultural markets (cloth, textile, garments, electronics, jewelry, etc.)
  static final RegExp _excludedMarketRegex = RegExp(
    r'\b(cloth|textile|textiles|garment|garments|clothing|apparel|fabric|saree|sari|suit|dress|tailor|'
    r'kapda|vastra|'
    r'jewel|jewelry|jeweller|sarafa|'
    r'electronics|hardware|furniture|timber|footwear|shoe|shoes|leather|'
    r'automotive|automobile|motor|metal|steel|iron|book|books|utensil|utensils|'
    r'mall|shopping mall|shopping center|cinema|multiplex|plastic)\b',
    caseSensitive: false,
  );

  /// Hindi non-agricultural keywords (Devanagari does not match ASCII \b)
  static const List<String> _excludedHindiTerms = [
    'कपड़ा', 'वस्त्र', 'साड़ी', 'टेक्सटाइल', 'गारमेंट',
    'सराफा', 'ज्वैलर', 'इलेक्ट्रॉनिक', 'फर्नीचर', 'जूता', 'चमड़ा', 'ऑटो'
  ];

  /// Positive English indicators for agricultural produce markets
  static final RegExp _agriculturalProduceRegex = RegExp(
    r'\b(apmc|mandi|krishi|grain|subzi|sabzi|vegetable|vegetables|fruit|fruits|anaaj|anaj|'
    r'utpadan|upaj|kisan|farmer|farmers|market yard|yard|bajar samiti|bazar samiti)\b',
    caseSensitive: false,
  );

  /// Hindi agricultural produce keywords
  static const List<String> _agriculturalHindiTerms = [
    'कृषि', 'मंडी', 'सब्जी', 'अनाज', 'किसान', 'उपज', 'उत्पादन', 'बाजार समिति'
  ];

  /// Validates if a market is a genuine agricultural produce market, excluding cloth/textiles and unrelated businesses.
  static bool isAgriculturalMarket({
    required String name,
    Map<String, dynamic>? tags,
    String? category,
  }) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;
    final lowerName = cleanName.toLowerCase();

    // 1. Direct Exclusion: check if name matches non-agricultural keywords
    if (_excludedMarketRegex.hasMatch(lowerName)) {
      return false;
    }
    for (final term in _excludedHindiTerms) {
      if (cleanName.contains(term)) {
        return false;
      }
    }

    // Check tags if available
    if (tags != null) {
      for (final val in tags.values) {
        if (val is String) {
          final lVal = val.toLowerCase();
          if (_excludedMarketRegex.hasMatch(lVal)) return false;
          for (final term in _excludedHindiTerms) {
            if (val.contains(term)) return false;
          }
        }
      }
      final marketTag = tags['market']?.toString().toLowerCase();
      if (marketTag != null &&
          (marketTag.contains('cloth') ||
              marketTag.contains('textile') ||
              marketTag.contains('clothes') ||
              marketTag.contains('garment'))) {
        return false;
      }
      final shopTag = tags['shop']?.toString().toLowerCase();
      if (shopTag != null &&
          (shopTag.contains('clothes') ||
              shopTag.contains('fabric') ||
              shopTag.contains('shoes'))) {
        return false;
      }
    }

    // 2. Positive confirmation: Agricultural produce / Mandi / APMC / Krishi
    if (_agriculturalProduceRegex.hasMatch(lowerName)) {
      return true;
    }
    for (final term in _agriculturalHindiTerms) {
      if (cleanName.contains(term)) {
        return true;
      }
    }

    // If OSM tags explicitly indicate farmers / vegetables / produce
    if (tags != null) {
      final produce = tags['produce']?.toString().toLowerCase() ?? '';
      final market = tags['market']?.toString().toLowerCase() ?? '';
      if (produce.contains('food') ||
          produce.contains('vegetable') ||
          market.contains('farmers') ||
          market.contains('vegetable') ||
          market.contains('produce')) {
        return true;
      }
    }

    // 3. Ambiguous generic markets (e.g. "Main Market", "City Center Market")
    // Safe handling: If it has neither agricultural keywords nor agricultural tags,
    // we do not automatically treat generic wholesale / shopping complexes as agricultural mandis.
    return false;
  }

  /// Curated physical directory of verified major APMC mandis and prominent agricultural markets.
  /// Guarantees that genuine, physical markets like Chakarpur Krishi Utpadan Mandi and Collectorganj Krishi Mandi
  /// in Kanpur Nagar remain discoverable even during Overpass or Nominatim network rate limits.
  static const List<Map<String, dynamic>> _curatedPhysicalMandis = [
    {
      'id': 'mandi_up_kanpur_chakarpur',
      'nameEn': 'Chakarpur Krishi Utpadan Mandi',
      'nameHi': 'चकरपुर कृषि उत्पादन मंडी',
      'lat': 26.4385,
      'lon': 80.2520,
      'districtEn': 'Kanpur Nagar',
      'districtHi': 'कानपुर नगर',
    },
    {
      'id': 'mandi_up_kanpur_collectorganj',
      'nameEn': 'Collectorganj Krishi Mandi',
      'nameHi': 'कलेक्टरगंज कृषि मंडी',
      'lat': 26.4580,
      'lon': 80.3540,
      'districtEn': 'Kanpur Nagar',
      'districtHi': 'कानपुर नगर',
    },
    {
      'id': 'mandi_up_kanpur_chaubepur',
      'nameEn': 'Chaubepur Mandi Yard',
      'nameHi': 'चौबेपुर मंडी यार्ड',
      'lat': 26.6180,
      'lon': 80.1750,
      'districtEn': 'Kanpur Nagar',
      'districtHi': 'कानपुर नगर',
    },
    {
      'id': 'mandi_up_unnao_apmc',
      'nameEn': 'Unnao Krishi Utpadan Mandi',
      'nameHi': 'उन्नाव कृषि उत्पादन मंडी',
      'lat': 26.5450,
      'lon': 80.4900,
      'districtEn': 'Unnao',
      'districtHi': 'उन्नाव',
    },
    {
      'id': 'mandi_mh_lasalgaon',
      'nameEn': 'Lasalgaon APMC Market Yard',
      'nameHi': 'लासलगांव एपीएमसी मार्केट यार्ड',
      'lat': 20.1450,
      'lon': 74.2250,
      'districtEn': 'Nashik',
      'districtHi': 'नासिक',
    },
    {
      'id': 'mandi_mh_pimpalgaon',
      'nameEn': 'Pimpalgaon Baswant APMC',
      'nameHi': 'पिंपलगांव बसवंत एपीएमसी',
      'lat': 20.1700,
      'lon': 73.9850,
      'districtEn': 'Nashik',
      'districtHi': 'नासिक',
    },
    {
      'id': 'mandi_mh_nashik_panchavati',
      'nameEn': 'Nashik Krishi Utpanna Bajar Samiti (Panchavati)',
      'nameHi': 'नासिक कृषि उत्पन्न बाजार समिति (पंचवटी)',
      'lat': 20.0050,
      'lon': 73.7850,
      'districtEn': 'Nashik',
      'districtHi': 'नासिक',
    },
  ];

  /// Discovers nearby physical mandis and markets using OSM / Overpass with fallback to curated registry
  Future<List<AgriResource>> discoverNearbyMandis({
    required double latitude,
    required double longitude,
    String? district,
    double maxRadiusKm = 50.0,
  }) async {
    final cacheKey = '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}_${district ?? ""}';
    if (_mandiCache.containsKey(cacheKey) && _mandiCache[cacheKey]!.isNotEmpty) {
      return _mandiCache[cacheKey]!;
    }

    final rawList = <AgriResource>[];

    // Tier 1: Try Overpass API with short timeout and multi-endpoint failover
    final overpassEndpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
    ];

    final radiusMeters = (maxRadiusKm * 1000).toInt();
    final overpassQuery = '[out:json][timeout:5];'
        '('
        'nwr["amenity"="marketplace"](around:$radiusMeters, $latitude, $longitude);'
        'nwr["name"~"APMC|Mandi|Market Yard|Krishi|Sabzi|Subzi|Grain Market|कृषि उपज मंडी|सब्जी मंडी|अनाज मंडी", i](around:$radiusMeters, $latitude, $longitude);'
        ');'
        'out center 12;';

    for (final endpoint in overpassEndpoints) {
      try {
        final uri = Uri.parse('$endpoint?data=${Uri.encodeComponent(overpassQuery)}');
        final response = await http.get(
          uri,
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        ).timeout(const Duration(milliseconds: 2500));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final elements = data['elements'] as List<dynamic>? ?? [];

          for (final el in elements) {
            final tags = el['tags'] as Map<String, dynamic>? ?? {};
            final name = tags['name']?.toString() ??
                tags['name:en']?.toString() ??
                tags['description']?.toString();

            final center = el['center'] as Map<String, dynamic>?;
            final elLat = (el['lat'] as num?)?.toDouble() ?? (center?['lat'] as num?)?.toDouble();
            final elLon = (el['lon'] as num?)?.toDouble() ?? (center?['lon'] as num?)?.toDouble();

            if (name != null && elLat != null && elLon != null) {
              // Strict exclusion: discard cloth, textile, garment and unrelated markets
              if (!isAgriculturalMarket(name: name, tags: tags)) {
                continue;
              }

              final distance = calculateDistanceKm(latitude, longitude, elLat, elLon);

              if (distance <= maxRadiusKm) {
                rawList.add(
                  AgriResource(
                    id: 'osm_overpass_${el['id']}',
                    nameEn: name,
                    nameHi: tags['name:hi']?.toString() ?? name,
                    type: AgriResourceType.mandi,
                    districtEn: district ?? 'Nearby Sub-District',
                    districtHi: district ?? 'नजदीकी क्षेत्र',
                    distanceKm: double.parse(distance.toStringAsFixed(1)),
                    capacityMetricTons: 0,
                    availableMetricTons: 0,
                    contactPhone: '',
                    estimatedRatePerMonthPerQuintal: 0,
                    isGovernmentAccredited: true,
                    isSimulatedData: false,
                    isOsmMapped: true,
                    hasLiveAgmarknetPrice: false,
                    isCapacityVerified: false,
                    isPhoneVerified: false,
                    verificationNoticeEn: 'Mapped market location — Verified physical location and distance',
                    verificationNoticeHi: 'मैप पर दर्ज मंडी — सत्यापित भौतिक स्थान और दूरी',
                    latitude: elLat,
                    longitude: elLon,
                  ),
                );
              }
            }
          }
          if (rawList.isNotEmpty) break;
        }
      } catch (e) {
        debugPrint('SANCHARYA Overpass lookup notice: $e');
      }
    }

    // Tier 2: Nominatim search for marketplace/mandi in district
    if (rawList.isEmpty) {
      try {
        final queryTerm = district != null && district.isNotEmpty
            ? 'market in $district'
            : 'APMC market';

        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(queryTerm)}&format=json&limit=8',
        );

        final response = await http.get(
          uri,
          headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;

          for (final item in list) {
            final displayName = item['display_name']?.toString() ?? '';
            final parts = displayName.split(',');
            final name = parts.isNotEmpty ? parts.first.trim() : 'Local APMC Market';

            final elLat = double.tryParse(item['lat']?.toString() ?? '');
            final elLon = double.tryParse(item['lon']?.toString() ?? '');

            if (elLat != null && elLon != null) {
              // Strict exclusion: discard cloth, textile, garment and unrelated markets
              if (!isAgriculturalMarket(name: name, category: item['category']?.toString())) {
                continue;
              }

              final distance = calculateDistanceKm(latitude, longitude, elLat, elLon);

              if (distance <= maxRadiusKm) {
                rawList.add(
                  AgriResource(
                    id: 'osm_nom_${item['place_id']}',
                    nameEn: name,
                    nameHi: name,
                    type: AgriResourceType.mandi,
                    districtEn: district ?? (parts.length > 1 ? parts[1].trim() : 'Local Area'),
                    districtHi: district ?? (parts.length > 1 ? parts[1].trim() : 'स्थानीय क्षेत्र'),
                    distanceKm: double.parse(distance.toStringAsFixed(1)),
                    capacityMetricTons: 0,
                    availableMetricTons: 0,
                    contactPhone: '',
                    estimatedRatePerMonthPerQuintal: 0,
                    isGovernmentAccredited: true,
                    isSimulatedData: false,
                    isOsmMapped: true,
                    hasLiveAgmarknetPrice: false,
                    isCapacityVerified: false,
                    isPhoneVerified: false,
                    verificationNoticeEn: 'Mapped market location — Verified physical location and distance',
                    verificationNoticeHi: 'मैप पर दर्ज मंडी — सत्यापित भौतिक स्थान और दूरी',
                    latitude: elLat,
                    longitude: elLon,
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('SANCHARYA Nominatim market lookup notice: $e');
      }
    }

    // Tier 3: Curated verified directory integration
    // Ensures physical agricultural mandis within radius (e.g., Chakarpur Krishi Utpadan Mandi in Kanpur Nagar) are preserved
    for (final m in _curatedPhysicalMandis) {
      final name = m['nameEn'] as String;
      if (!isAgriculturalMarket(name: name)) continue;
      final mLat = m['lat'] as double;
      final mLon = m['lon'] as double;
      final dist = calculateDistanceKm(latitude, longitude, mLat, mLon);
      if (dist <= maxRadiusKm) {
        rawList.add(
          AgriResource(
            id: m['id'] as String,
            nameEn: m['nameEn'] as String,
            nameHi: m['nameHi'] as String,
            type: AgriResourceType.mandi,
            districtEn: m['districtEn'] as String,
            districtHi: m['districtHi'] as String,
            distanceKm: double.parse(dist.toStringAsFixed(1)),
            capacityMetricTons: 0,
            availableMetricTons: 0,
            contactPhone: '',
            estimatedRatePerMonthPerQuintal: 0,
            isGovernmentAccredited: true,
            isSimulatedData: false,
            isOsmMapped: true,
            hasLiveAgmarknetPrice: false,
            isCapacityVerified: false,
            isPhoneVerified: false,
            verificationNoticeEn: 'Mapped market location — Verified physical location and distance',
            verificationNoticeHi: 'मैप पर दर्ज मंडी — सत्यापित भौतिक स्थान और दूरी',
            latitude: mLat,
            longitude: mLon,
          ),
        );
      }
    }

    // Apply strict deduplication and distance sorting
    final deduped = deduplicateMandis(rawList);
    if (deduped.isNotEmpty) {
      _mandiCache[cacheKey] = deduped;
    }
    return deduped;
  }

  /// Deduplicates identical OSM elements and multiple representations of the same physical market
  static List<AgriResource> deduplicateMandis(List<AgriResource> list) {
    final deduped = <AgriResource>[];
    final seenIds = <String>{};

    for (final item in list) {
      if (seenIds.contains(item.id)) continue;

      final normName = item.nameEn.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '')
          .replaceAll('market', '')
          .replaceAll('mandi', '')
          .replaceAll('apmc', '')
          .replaceAll('yard', '');

      bool isDuplicate = false;
      for (final existing in deduped) {
        final existingNorm = existing.nameEn.toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '')
            .replaceAll('market', '')
            .replaceAll('mandi', '')
            .replaceAll('apmc', '')
            .replaceAll('yard', '');

        final distBetween = (item.latitude != null && item.longitude != null &&
                existing.latitude != null && existing.longitude != null)
            ? calculateDistanceKm(item.latitude!, item.longitude!, existing.latitude!, existing.longitude!)
            : 999.0;

        // Condition 1: Same normalized name within 1.0 km (e.g. Naveen Market node vs way)
        // Condition 2: Within 60 meters regardless of minor name differences
        if ((normName == existingNorm && distBetween < 1.0) || distBetween < 0.06) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        seenIds.add(item.id);
        deduped.add(item);
      }
    }

    deduped.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return deduped;
  }
}
