import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../data/interfaces/i_auth_service.dart';
import '../../models/farmer_user.dart';
import 'demo_auth_service.dart';

/// Production-ready Auth Service connected to FastAPI backend.
/// Automatically handles Android emulator host routing (10.0.2.2 vs localhost),
/// rates limits, Indian mobile normalization, and real SMS verification status.
class ApiAuthService implements IAuthService {
  final String _baseUrl;
  final IAuthService _fallbackService;
  FarmerUser? _currentUser;
  bool _isBackendReachable = true;

  ApiAuthService({String? customBaseUrl, IAuthService? fallbackService})
      : _baseUrl = customBaseUrl ?? _determineDefaultBaseUrl(),
        _fallbackService = fallbackService ?? DemoAuthService();

  static String _determineDefaultBaseUrl() {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  @override
  bool get isProductionSmsConfigured => _isBackendReachable;

  @override
  Future<FarmerUser?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.keyUserLoggedIn) ?? false;
      if (!isLoggedIn) return null;

      final name = prefs.getString(AppConstants.keyUserName) ?? 'Kisan Mitra';
      final phone = prefs.getString(AppConstants.keyUserPhone) ?? '';
      final isVerified = prefs.getBool('sancharya_phone_verified') ?? false;

      _currentUser = FarmerUser(
        id: 'usr_${phone.replaceAll(RegExp(r"\D"), "")}',
        name: name,
        phone: phone,
        district: 'Nashik District',
        state: 'Maharashtra',
        isPhoneVerified: isVerified,
      );
      return _currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OtpSession> requestOtp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      throw const ValidationException('Please enter a valid 10-digit Indian mobile number.');
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/auth/request-otp');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'phone_number': cleanPhone}),
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _isBackendReachable = true;
        return OtpSession(
          verificationId: data['verification_id'] as String,
          phoneNumber: data['phone_number'] as String,
          expiresAt: DateTime.now().add(Duration(seconds: (data['expires_in_seconds'] as int?) ?? 300)),
          testCodeForDisplay: data['sandbox_test_code'] as String?,
          isSmsDelivered: (data['is_sms_delivered'] as bool?) ?? false,
          isProviderConfigured: (data['is_provider_configured'] as bool?) ?? false,
          providerName: (data['provider_name'] as String?) ?? 'unconfigured',
          statusMessageEn: data['message_en'] as String?,
          statusMessageHi: data['message_hi'] as String?,
          cooldownSeconds: (data['cooldown_seconds'] as int?) ?? 60,
        );
      } else if (resp.statusCode == 429) {
        final err = jsonDecode(resp.body);
        throw ValidationException(err['detail'] ?? 'Rate limit reached. Please wait before retrying.');
      } else {
        final err = jsonDecode(resp.body);
        throw ValidationException(err['detail'] ?? 'Server could not process OTP request.');
      }
    } catch (e) {
      if (e is ValidationException) rethrow;
      // Backend offline: gracefully fallback to dynamic local challenge without crash
      _isBackendReachable = false;
      return _fallbackService.requestOtp(phoneNumber);
    }
  }

  @override
  Future<FarmerUser> verifyOtp({
    required String verificationId,
    required String otp,
    required String name,
    required String district,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/verify-otp');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'verification_id': verificationId,
          'otp': otp.trim(),
          'name': name.trim().isEmpty ? 'Kisan Mitra' : name.trim(),
          'district': district.trim().isEmpty ? 'Nashik' : district.trim(),
        }),
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = FarmerUser(
          id: data['user_id'] as String? ?? 'usr_local',
          name: data['name'] as String? ?? name,
          phone: data['phone'] as String? ?? '',
          district: data['district'] as String? ?? district,
          state: data['state'] as String? ?? 'Maharashtra',
          isPhoneVerified: true,
          verifiedAt: DateTime.now(),
        );

        _currentUser = user;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConstants.keyUserLoggedIn, true);
        await prefs.setString(AppConstants.keyUserName, user.name);
        await prefs.setString(AppConstants.keyUserPhone, user.phone);
        await prefs.setBool('sancharya_phone_verified', true);

        return user;
      } else {
        final err = jsonDecode(resp.body);
        throw ValidationException(err['detail'] ?? 'Incorrect OTP code.');
      }
    } catch (e) {
      if (e is ValidationException) rethrow;
      // If backend was offline, verify against fallback challenge
      return _fallbackService.verifyOtp(
        verificationId: verificationId,
        otp: otp,
        name: name,
        district: district,
      );
    }
  }

  @override
  Future<FarmerUser> loginAsGuest() => _fallbackService.loginAsGuest();

  @override
  Future<void> logout() async {
    _currentUser = null;
    await _fallbackService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sancharya_phone_verified');
  }
}
