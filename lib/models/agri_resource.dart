enum AgriResourceType {
  coldStorage,
  warehouse,
  mandi,
}

/// Model for agricultural infrastructure resources
class AgriResource {
  final String id;
  final String nameEn;
  final String nameHi;
  final AgriResourceType type;
  final String districtEn;
  final String districtHi;
  final double distanceKm;
  final double capacityMetricTons;
  final double availableMetricTons;
  final String contactPhone;
  final double estimatedRatePerMonthPerQuintal;
  final bool isGovernmentAccredited;
  final bool isSimulatedData;
  final bool isOsmMapped;
  final bool hasLiveAgmarknetPrice;
  final bool isCapacityVerified;
  final bool isPhoneVerified;
  final String? verificationNoticeEn;
  final String? verificationNoticeHi;
  final double? latitude;
  final double? longitude;

  const AgriResource({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.type,
    required this.districtEn,
    required this.districtHi,
    required this.distanceKm,
    required this.capacityMetricTons,
    required this.availableMetricTons,
    required this.contactPhone,
    required this.estimatedRatePerMonthPerQuintal,
    this.isGovernmentAccredited = true,
    this.isSimulatedData = true,
    this.isOsmMapped = false,
    this.hasLiveAgmarknetPrice = false,
    this.isCapacityVerified = false,
    this.isPhoneVerified = false,
    this.verificationNoticeEn,
    this.verificationNoticeHi,
    this.latitude,
    this.longitude,
  });

  String localizedName(bool isHindi) => isHindi ? nameHi : nameEn;
  String localizedDistrict(bool isHindi) => isHindi ? districtHi : districtEn;
  String? localizedVerificationNotice(bool isHindi) =>
      isHindi ? verificationNoticeHi : verificationNoticeEn;

  String verificationNotice(bool isHindi) =>
      localizedVerificationNotice(isHindi) ??
      (isHindi ? 'मैप पर दर्ज स्थान' : 'Mapped location');

  bool get hasValidPhone =>
      isPhoneVerified && contactPhone.trim().isNotEmpty && !contactPhone.contains('0000');
}
