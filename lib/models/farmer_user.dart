/// Farmer profile model
class FarmerUser {
  final String id;
  final String name;
  final String phone;
  final String district;
  final String state;
  final String preferredLanguage;
  final bool isPhoneVerified;
  final DateTime? verifiedAt;

  const FarmerUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.district,
    required this.state,
    this.preferredLanguage = 'en',
    this.isPhoneVerified = false,
    this.verifiedAt,
  });
}
