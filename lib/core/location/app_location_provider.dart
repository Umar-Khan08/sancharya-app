import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/location/location_service.dart';

/// Single Source of Truth for user location throughout SANCHARYA
class AppLocationProvider extends ChangeNotifier {
  static const String _prefLocation = 'sancharya_active_location';
  static const String _prefDistrict = 'sancharya_active_district';
  static const String _prefState = 'sancharya_active_state';
  static const String _prefLat = 'sancharya_active_lat';
  static const String _prefLon = 'sancharya_active_lon';
  static const String _prefIsAuto = 'sancharya_active_is_auto';

  final LocationService _locationService;

  String _formattedLocation = 'Nashik, Maharashtra';
  String? _locality;
  String? _district = 'Nashik';
  String? _state = 'Maharashtra';
  String? _country = 'India';
  double? _latitude = 19.9975;
  double? _longitude = 73.7898;
  bool _hasUserLocation = false;
  bool _isAutoDetected = false;
  bool _isLoading = false;
  String? _errorMessageEn;
  String? _errorMessageHi;
  DateTime? _lastUpdated;
  int _requestEpoch = 0;

  AppLocationProvider({LocationService? locationService})
      : _locationService = locationService ?? LocationService() {
    _loadPersistedLocation();
  }

  // Getters
  String get formattedLocation => _formattedLocation;
  String? get locality => _locality;
  String? get district => _district;
  String? get state => _state;
  String? get country => _country;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  bool get hasUserLocation => _hasUserLocation;
  bool get isAutoDetected => _isAutoDetected;
  bool get isLoading => _isLoading;
  String? get errorMessageEn => _errorMessageEn;
  String? get errorMessageHi => _errorMessageHi;
  DateTime? get lastUpdated => _lastUpdated;
  int get requestEpoch => _requestEpoch;

  bool get hasValidCoordinates =>
      _latitude != null &&
      _longitude != null &&
      _latitude! >= -90.0 &&
      _latitude! <= 90.0 &&
      _longitude! >= -180.0 &&
      _longitude! <= 180.0 &&
      !(_latitude == 0.0 && _longitude == 0.0);

  String displayLocation(bool isHindi) {
    if (_district != null && _state != null) {
      return '$_district, $_state';
    } else if (_district != null) {
      return _district!;
    }
    return _formattedLocation;
  }

  Future<void> _loadPersistedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLoc = prefs.getString(_prefLocation);
      if (savedLoc != null && savedLoc.isNotEmpty) {
        _district = prefs.getString(_prefDistrict);
        _state = prefs.getString(_prefState);
        _latitude = prefs.getDouble(_prefLat);
        _longitude = prefs.getDouble(_prefLon);
        // If savedLoc was saved as raw coordinates e.g. "27.1767, 78.0081", format cleanly as district name
        if (RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(savedLoc.trim())) {
          _formattedLocation = (_district != null && _state != null)
              ? '$_district, $_state'
              : (_district ?? savedLoc);
        } else {
          _formattedLocation = savedLoc;
        }
        _isAutoDetected = prefs.getBool(_prefIsAuto) ?? false;
        _hasUserLocation = true;
        _lastUpdated = DateTime.now();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persistLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLocation, _formattedLocation);
      if (_district != null) await prefs.setString(_prefDistrict, _district!);
      if (_state != null) await prefs.setString(_prefState, _state!);
      if (_latitude != null) await prefs.setDouble(_prefLat, _latitude!);
      if (_longitude != null) await prefs.setDouble(_prefLon, _longitude!);
      await prefs.setBool(_prefIsAuto, _isAutoDetected);
    } catch (_) {}
  }

  /// Triggers device GPS detection with runtime permission handling
  Future<bool> autoDetectLocation({required bool isHindi}) async {
    _requestEpoch++;
    final currentEpoch = _requestEpoch;

    _isLoading = true;
    _errorMessageEn = null;
    _errorMessageHi = null;
    notifyListeners();

    try {
      final result = await _locationService.getCurrentLocation();

      // Guard against stale response if user changed location while query was running
      if (currentEpoch != _requestEpoch) return false;

      if (!result.isSuccess) {
        _isLoading = false;
        _errorMessageEn = result.errorMessageEn;
        _errorMessageHi = result.errorMessageHi;
        notifyListeners();
        return false;
      }

      final lat = result.latitude;
      final lon = result.longitude;

      if (lat == null || lon == null || !LocationService.isValidCoordinates(lat, lon)) {
        _isLoading = false;
        _errorMessageEn = 'GPS reported invalid coordinates.';
        _errorMessageHi = 'जीपीएस ने अमान्य निर्देशांक दिए।';
        notifyListeners();
        return false;
      }

      _latitude = lat;
      _longitude = lon;
      _locality = result.locality;
      _district = result.district;
      _state = result.state;
      _country = result.country;
      _formattedLocation = result.formattedAddress ??
          (_district != null && _state != null
              ? '$_district, $_state'
              : '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}');
      _isAutoDetected = true;
      _hasUserLocation = true;
      _isLoading = false;
      _lastUpdated = DateTime.now();

      await _persistLocation();
      notifyListeners();
      return true;
    } catch (e) {
      if (currentEpoch != _requestEpoch) return false;
      _isLoading = false;
      _errorMessageEn = 'Failed to detect location: $e';
      _errorMessageHi = 'स्थान का पता लगाने में विफल: $e';
      notifyListeners();
      return false;
    }
  }

  /// Manually selects or updates a location string and resolves coordinates
  Future<bool> setManualLocation(String query, {required bool isHindi}) async {
    final clean = query.trim();
    if (clean.isEmpty) return false;

    _requestEpoch++;
    final currentEpoch = _requestEpoch;

    _isLoading = true;
    _errorMessageEn = null;
    _errorMessageHi = null;
    notifyListeners();

    try {
      // 1. Resolve coordinates for manual query via forward geocoding
      final coords = await _locationService.resolveCoordinatesForLocation(clean);

      if (currentEpoch != _requestEpoch) return false;

      if (coords != null && LocationService.isValidCoordinates(coords.latitude, coords.longitude)) {
        _latitude = coords.latitude;
        _longitude = coords.longitude;
        final parts = clean.split(',');
        _district = coords.district ?? parts.first.trim();
        _state = coords.state ?? (parts.length > 1 ? parts[1].trim() : null);
        _formattedLocation = clean;
      } else {
        // Fallback: If network lookup fails, clear previous coordinates to prevent stale city coords!
        _latitude = null;
        _longitude = null;
        final parts = clean.split(',');
        _district = parts.first.trim();
        _state = parts.length > 1 ? parts[1].trim() : null;
        _formattedLocation = clean;
        _errorMessageEn = 'Could not resolve coordinates for "$clean". Please check the district name.';
        _errorMessageHi = '"$clean" के निर्देशांक प्राप्त नहीं हो सके। कृपया जिले का नाम जांचें।';
      }

      _isAutoDetected = false;
      _hasUserLocation = true;
      _isLoading = false;
      _lastUpdated = DateTime.now();

      await _persistLocation();
      notifyListeners();
      return true;
    } catch (e) {
      if (currentEpoch != _requestEpoch) return false;
      _isLoading = false;
      _errorMessageEn = 'Could not resolve location: $e';
      _errorMessageHi = 'स्थान का समाधान नहीं हो सका: $e';
      notifyListeners();
      return false;
    }
  }

  /// Directly set location when already resolved
  void setExplicitLocation({
    required String formatted,
    String? district,
    String? state,
    double? latitude,
    double? longitude,
    bool isAuto = false,
  }) {
    _requestEpoch++;
    _formattedLocation = formatted;
    _district = district;
    _state = state;
    _latitude = latitude;
    _longitude = longitude;
    _isAutoDetected = isAuto;
    _isLoading = false;
    _lastUpdated = DateTime.now();
    _persistLocation();
    notifyListeners();
  }
}
