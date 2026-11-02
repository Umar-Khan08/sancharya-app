import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

enum LocationStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  timeout,
  networkError,
  unknownError,
}

class LocationCoordinates {
  final double latitude;
  final double longitude;
  final String? district;
  final String? state;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
    this.district,
    this.state,
  });
}

class LocationResult {
  final LocationStatus status;
  final double? latitude;
  final double? longitude;
  final String? locality;
  final String? district;
  final String? state;
  final String? country;
  final String? formattedAddress;
  final String? errorMessageEn;
  final String? errorMessageHi;

  const LocationResult({
    required this.status,
    this.latitude,
    this.longitude,
    this.locality,
    this.district,
    this.state,
    this.country,
    this.formattedAddress,
    this.errorMessageEn,
    this.errorMessageHi,
  });

  bool get isSuccess => status == LocationStatus.success;

  String displayError(bool isHindi) =>
      (isHindi ? errorMessageHi : errorMessageEn) ??
      (isHindi ? 'स्थान प्राप्त करने में त्रुटि हुई।' : 'Unable to acquire location.');
}

/// Service managing device GPS location and OpenStreetMap Nominatim geocoding
class LocationService {
  static const String _nominatimUserAgent =
      'SancharyaAgriculturalApp/1.0 (contact: info@sancharya.agri)';
  static const Duration _timeout = Duration(seconds: 10);

  // Dynamic in-memory cache for resolved coordinates
  static final Map<String, LocationCoordinates> _runtimeCache = {};

  static bool isValidCoordinates(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lon < -180.0 || lon > 180.0) return false;
    if (lat == 0.0 && lon == 0.0) return false;
    return true;
  }

  /// Requests device location, checks runtime permissions, and reverse-geocodes to District, State
  Future<LocationResult> getCurrentLocation() async {
    try {
      // 1. Check if device location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return const LocationResult(
          status: LocationStatus.serviceDisabled,
          errorMessageEn:
              'Device GPS/Location services are turned off. Please enable Location in device settings or select your district manually.',
          errorMessageHi:
              'डिवाइस की जीपीएस/स्थान सेवा बंद है। कृपया सेटिंग में स्थान चालू करें या मैन्युअल रूप से जिला चुनें।',
        );
      }

      // 2. Check runtime location permissions without repeatedly re-prompting if already granted
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            status: LocationStatus.permissionDenied,
            errorMessageEn:
                'Location permission was denied. You can continue by entering your district manually.',
            errorMessageHi:
                'स्थान अनुमति अस्वीकार कर दी गई। आप मैन्युअल रूप से अपना जिला दर्ज कर सकते हैं।',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          status: LocationStatus.permissionPermanentlyDenied,
          errorMessageEn:
              'Location permissions are permanently denied. Please enable them in app settings or enter your district manually.',
          errorMessageHi:
              'स्थान अनुमति स्थायी रूप से बंद है। कृपया ऐप सेटिंग्स में इसे चालू करें या मैन्युअल रूप से जिला लिखें।',
        );
      }

      // 3. Acquire current coordinates (works for actual GPS or emulator mock location)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      );

      final lat = position.latitude;
      final lon = position.longitude;

      if (!isValidCoordinates(lat, lon)) {
        return const LocationResult(
          status: LocationStatus.unknownError,
          errorMessageEn: 'GPS returned invalid coordinates. Please enter location manually.',
          errorMessageHi: 'जीपीएस ने अमान्य निर्देशांक दिए। कृपया मैन्युअल रूप से स्थान दर्ज करें।',
        );
      }

      // 4. Reverse geocode coordinates via OpenStreetMap Nominatim
      final geocoded = await reverseGeocode(latitude: lat, longitude: lon);

      return LocationResult(
        status: LocationStatus.success,
        latitude: lat,
        longitude: lon,
        locality: geocoded['locality'],
        district: geocoded['district'],
        state: geocoded['state'],
        country: geocoded['country'],
        formattedAddress: geocoded['formatted'],
      );
    } on TimeoutException {
      return const LocationResult(
        status: LocationStatus.timeout,
        errorMessageEn: 'Location request timed out. Please enter your district manually.',
        errorMessageHi: 'स्थान अनुरोध का समय समाप्त हो गया। कृपया मैन्युअल रूप से जिला दर्ज करें।',
      );
    } catch (e) {
      debugPrint('SANCHARYA LocationService error: $e');
      return LocationResult(
        status: LocationStatus.unknownError,
        errorMessageEn: 'Could not detect location ($e). Please enter your district manually.',
        errorMessageHi: 'स्थान का पता नहीं लगाया जा सका। कृपया मैन्युअल रूप से अपना जिला लिखें।',
      );
    }
  }

  /// Reverse geocodes coordinates to Locality, District, State using OpenStreetMap Nominatim
  Future<Map<String, String?>> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!isValidCoordinates(latitude, longitude)) {
      return {
        'locality': null,
        'district': null,
        'state': null,
        'country': null,
        'formatted': 'Invalid Coordinates',
      };
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=12&addressdetails=1',
      );

      final sw = Stopwatch()..start();
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _nominatimUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));
      debugPrint('[TIMING] Nominatim reverseGeocode took ${sw.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final locality = address['suburb']?.toString() ??
              address['neighbourhood']?.toString() ??
              address['village']?.toString() ??
              address['hamlet']?.toString() ??
              address['town']?.toString() ??
              address['city']?.toString();

          final district = address['state_district']?.toString() ??
              address['county']?.toString() ??
              address['district']?.toString() ??
              address['city']?.toString();

          final state = address['state']?.toString();
          final country = address['country']?.toString();

          String formatted;
          if (district != null && state != null) {
            formatted = '$district, $state';
          } else if (locality != null && state != null) {
            formatted = '$locality, $state';
          } else if (district != null) {
            formatted = district;
          } else if (state != null) {
            formatted = state;
          } else {
            formatted = data['display_name']?.toString().split(',').take(2).join(',').trim() ??
                '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
          }

          return {
            'locality': locality,
            'district': district,
            'state': state,
            'country': country,
            'formatted': formatted,
          };
        }
      }
    } catch (e) {
      debugPrint('SANCHARYA Reverse Geocoding notice: $e');
    }

    // Offline proximity check for known hubs if network reverse geocoding is unavailable
    for (final entry in _knownAgriHubs.entries) {
      final d = Geolocator.distanceBetween(latitude, longitude, entry.value.latitude, entry.value.longitude) / 1000.0;
      if (d <= 35.0) {
        final dist = entry.value.district ?? entry.key;
        final st = entry.value.state ?? 'India';
        return {
          'locality': null,
          'district': dist,
          'state': st,
          'country': 'India',
          'formatted': '$dist, $st',
        };
      }
    }

    return {
      'locality': null,
      'district': null,
      'state': null,
      'country': null,
      'formatted': '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
    };
  }

  /// Resolves coordinates for a manually entered district/state string
  static const Map<String, LocationCoordinates> _knownAgriHubs = {
    'kanpur nagar': LocationCoordinates(latitude: 26.4499, longitude: 80.3319, district: 'Kanpur Nagar', state: 'Uttar Pradesh'),
    'kanpur dehat': LocationCoordinates(latitude: 26.4673, longitude: 79.9515, district: 'Kanpur Dehat', state: 'Uttar Pradesh'),
    'kanpur': LocationCoordinates(latitude: 26.4499, longitude: 80.3319, district: 'Kanpur Nagar', state: 'Uttar Pradesh'),
    'agra': LocationCoordinates(latitude: 27.1767, longitude: 78.0081, district: 'Agra', state: 'Uttar Pradesh'),
    'lucknow': LocationCoordinates(latitude: 26.8467, longitude: 80.9462, district: 'Lucknow', state: 'Uttar Pradesh'),
    'varanasi': LocationCoordinates(latitude: 25.3176, longitude: 82.9739, district: 'Varanasi', state: 'Uttar Pradesh'),
    'prayagraj': LocationCoordinates(latitude: 25.4358, longitude: 81.8463, district: 'Prayagraj', state: 'Uttar Pradesh'),
    'allahabad': LocationCoordinates(latitude: 25.4358, longitude: 81.8463, district: 'Prayagraj', state: 'Uttar Pradesh'),
    'aligarh': LocationCoordinates(latitude: 27.8974, longitude: 78.0880, district: 'Aligarh', state: 'Uttar Pradesh'),
    'bareilly': LocationCoordinates(latitude: 28.3670, longitude: 79.4304, district: 'Bareilly', state: 'Uttar Pradesh'),
    'gorakhpur': LocationCoordinates(latitude: 26.7606, longitude: 83.3732, district: 'Gorakhpur', state: 'Uttar Pradesh'),
    'jhansi': LocationCoordinates(latitude: 25.4484, longitude: 78.5685, district: 'Jhansi', state: 'Uttar Pradesh'),
    'mathura': LocationCoordinates(latitude: 27.4924, longitude: 77.6737, district: 'Mathura', state: 'Uttar Pradesh'),
    'moradabad': LocationCoordinates(latitude: 28.8389, longitude: 78.7768, district: 'Moradabad', state: 'Uttar Pradesh'),
    'meerut': LocationCoordinates(latitude: 28.9845, longitude: 77.7064, district: 'Meerut', state: 'Uttar Pradesh'),
    'ayodhya': LocationCoordinates(latitude: 26.7922, longitude: 82.1998, district: 'Ayodhya', state: 'Uttar Pradesh'),
    'faizabad': LocationCoordinates(latitude: 26.7731, longitude: 82.1460, district: 'Ayodhya', state: 'Uttar Pradesh'),
    'nashik': LocationCoordinates(latitude: 19.9975, longitude: 73.7898, district: 'Nashik', state: 'Maharashtra'),
    'lasalgaon': LocationCoordinates(latitude: 20.1478, longitude: 74.2255, district: 'Nashik', state: 'Maharashtra'),
    'pune': LocationCoordinates(latitude: 18.5204, longitude: 73.8567, district: 'Pune', state: 'Maharashtra'),
    'indore': LocationCoordinates(latitude: 22.7196, longitude: 75.8577, district: 'Indore', state: 'Madhya Pradesh'),
    'nagpur': LocationCoordinates(latitude: 21.1458, longitude: 79.0882, district: 'Nagpur', state: 'Maharashtra'),
    'delhi': LocationCoordinates(latitude: 28.6139, longitude: 77.2090, district: 'Delhi', state: 'Delhi'),
    'mumbai': LocationCoordinates(latitude: 19.0760, longitude: 72.8777, district: 'Mumbai', state: 'Maharashtra'),
    'bhopal': LocationCoordinates(latitude: 23.2599, longitude: 77.4126, district: 'Bhopal', state: 'Madhya Pradesh'),
    'ahmednagar': LocationCoordinates(latitude: 19.0952, longitude: 74.7496, district: 'Ahilyanagar', state: 'Maharashtra'),
    'jalgaon': LocationCoordinates(latitude: 21.0077, longitude: 75.5626, district: 'Jalgaon', state: 'Maharashtra'),
    'solapur': LocationCoordinates(latitude: 17.6599, longitude: 75.9064, district: 'Solapur', state: 'Maharashtra'),
    'kolhapur': LocationCoordinates(latitude: 16.7050, longitude: 74.2433, district: 'Kolhapur', state: 'Maharashtra'),
  };

  /// Synchronous offline coordinate lookup for verified agricultural trading hubs
  static LocationCoordinates? lookupKnownCoordinates(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return null;
    final sortedKeys = _knownAgriHubs.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      final pattern = RegExp('\\b${RegExp.escape(key)}\\b', caseSensitive: false);
      if (pattern.hasMatch(clean)) {
        return _knownAgriHubs[key];
      }
    }
    return null;
  }

  Future<LocationCoordinates?> resolveCoordinatesForLocation(String locationQuery) async {
    final clean = locationQuery.trim();
    if (clean.isEmpty) return null;
    final lower = clean.toLowerCase();

    if (_runtimeCache.containsKey(lower)) {
      return _runtimeCache[lower];
    }

    // 1. Instant offline lookup for major agricultural hubs
    final known = lookupKnownCoordinates(clean);
    if (known != null) {
      _runtimeCache[lower] = known;
      return known;
    }

    // 2. Network forward geocode via Nominatim
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(clean)}&format=json&limit=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _nominatimUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));
      debugPrint('[TIMING] Nominatim resolveCoordinates took ${sw.elapsedMilliseconds}ms for $clean');

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (isValidCoordinates(lat, lon)) {
            final coords = LocationCoordinates(
              latitude: lat!,
              longitude: lon!,
              district: clean.split(',').first.trim(),
            );
            _runtimeCache[lower] = coords;
            return coords;
          }
        }
      }
    } catch (e) {
      debugPrint('SANCHARYA Forward Geocoding notice for $locationQuery: $e');
    }

    return null;
  }
}
