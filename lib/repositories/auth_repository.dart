import '../data/interfaces/i_auth_service.dart';
import '../models/farmer_user.dart';

/// Single source of truth for Farmer Authentication and session state.
class AuthRepository {
  final IAuthService _service;

  AuthRepository(this._service);

  bool get isProductionSmsConfigured => _service.isProductionSmsConfigured;

  Future<FarmerUser?> getCurrentUser() => _service.getCurrentUser();

  Future<OtpSession> requestOtp(String phoneNumber) =>
      _service.requestOtp(phoneNumber);

  Future<FarmerUser> verifyOtp({
    required String verificationId,
    required String otp,
    required String name,
    required String district,
  }) =>
      _service.verifyOtp(
        verificationId: verificationId,
        otp: otp,
        name: name,
        district: district,
      );

  Future<FarmerUser> loginAsGuest() => _service.loginAsGuest();

  Future<void> logout() => _service.logout();
}
