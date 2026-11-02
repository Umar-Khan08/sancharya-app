import '../../models/farmer_user.dart';

/// Metadata for an active OTP verification challenge
class OtpSession {
  final String verificationId;
  final String phoneNumber;
  final DateTime expiresAt;
  final String? testCodeForDisplay; // Populated in development/test environment for testers
  final bool isSmsDelivered;
  final bool isProviderConfigured;
  final String providerName;
  final String? statusMessageEn;
  final String? statusMessageHi;
  final int cooldownSeconds;

  const OtpSession({
    required this.verificationId,
    required this.phoneNumber,
    required this.expiresAt,
    this.testCodeForDisplay,
    this.isSmsDelivered = false,
    this.isProviderConfigured = false,
    this.providerName = 'unconfigured',
    this.statusMessageEn,
    this.statusMessageHi,
    this.cooldownSeconds = 60,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Interface for Farmer Phone Number & OTP Authentication.
abstract class IAuthService {
  Future<FarmerUser?> getCurrentUser();

  /// Initiates OTP delivery challenge to the validated phone number
  Future<OtpSession> requestOtp(String phoneNumber);

  /// Validates the submitted OTP against the active challenge
  Future<FarmerUser> verifyOtp({
    required String verificationId,
    required String otp,
    required String name,
    required String district,
  });

  /// Separate guest demo access without phone number authentication
  Future<FarmerUser> loginAsGuest();

  Future<void> logout();

  bool get isProductionSmsConfigured;
}
