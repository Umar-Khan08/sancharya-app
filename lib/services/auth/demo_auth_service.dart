import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../data/interfaces/i_auth_service.dart';
import '../../models/farmer_user.dart';

class _ActiveChallenge {
  final String verificationId;
  final String phoneNumber;
  final String code;
  final DateTime expiresAt;

  _ActiveChallenge({
    required this.verificationId,
    required this.phoneNumber,
    required this.code,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Authentication service with dynamic OTP challenge & verification.
/// Ready to swap with Firebase Phone Auth when google-services.json is configured.
class DemoAuthService implements IAuthService {
  FarmerUser? _currentUser;
  final Map<String, _ActiveChallenge> _activeChallenges = {};

  @override
  bool get isProductionSmsConfigured => false;

  @override
  Future<FarmerUser?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.keyUserLoggedIn) ?? false;
      if (!isLoggedIn) return null;

      final name = prefs.getString(AppConstants.keyUserName) ?? 'Kisan Mitra';
      final phone = prefs.getString(AppConstants.keyUserPhone) ?? '';
      final isGuest = phone.startsWith('GUEST');

      _currentUser = FarmerUser(
        id: 'usr_local',
        name: name,
        phone: isGuest ? 'Guest Farmer' : phone,
        district: 'Nashik District',
        state: 'Maharashtra',
      );
      return _currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OtpSession> requestOtp(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length != 10) {
      throw const ValidationException('Please enter a valid 10-digit mobile number.');
    }

    // Simulate SMS dispatch latency
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate dynamic 6-digit verification code (e.g. 100000 - 999999)
    final random = Random();
    final dynamicCode = (100000 + random.nextInt(900000)).toString();

    final verificationId = 'ver_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}';
    final expiresAt = DateTime.now().add(const Duration(minutes: 2));

    final challenge = _ActiveChallenge(
      verificationId: verificationId,
      phoneNumber: cleanPhone,
      code: dynamicCode,
      expiresAt: expiresAt,
    );

    _activeChallenges[verificationId] = challenge;

    return OtpSession(
      verificationId: verificationId,
      phoneNumber: cleanPhone,
      expiresAt: expiresAt,
      testCodeForDisplay: dynamicCode, // Displayed transparently in development/sandbox mode
    );
  }

  @override
  Future<FarmerUser> verifyOtp({
    required String verificationId,
    required String otp,
    required String name,
    required String district,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final challenge = _activeChallenges[verificationId];
    if (challenge == null) {
      throw const ValidationException('Verification session not found. Please request a new OTP.');
    }

    if (challenge.isExpired) {
      _activeChallenges.remove(verificationId);
      throw const ValidationException('OTP has expired. Please tap Resend OTP to get a new code.');
    }

    if (otp.trim() != challenge.code) {
      throw const ValidationException('Incorrect OTP entered. Please check and try again.');
    }

    // OTP verification confirmed! Clear challenge and create authenticated session
    _activeChallenges.remove(verificationId);

    final user = FarmerUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Kisan Mitra' : name.trim(),
      phone: challenge.phoneNumber,
      district: district.trim().isEmpty ? 'Nashik District' : district.trim(),
      state: 'Maharashtra',
    );

    _currentUser = user;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyUserLoggedIn, true);
      await prefs.setString(AppConstants.keyUserName, user.name);
      await prefs.setString(AppConstants.keyUserPhone, user.phone);
    } catch (_) {}

    return user;
  }

  @override
  Future<FarmerUser> loginAsGuest() async {
    await Future.delayed(const Duration(milliseconds: 200));

    final user = FarmerUser(
      id: 'usr_guest_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Guest Farmer (डेमो किसान)',
      phone: 'GUEST-MODE',
      district: 'Nashik Agro Belt',
      state: 'Maharashtra',
    );

    _currentUser = user;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyUserLoggedIn, true);
      await prefs.setString(AppConstants.keyUserName, user.name);
      await prefs.setString(AppConstants.keyUserPhone, user.phone);
    } catch (_) {}

    return user;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _activeChallenges.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyUserLoggedIn);
      await prefs.remove(AppConstants.keyUserName);
      await prefs.remove(AppConstants.keyUserPhone);
    } catch (_) {}
  }
}
