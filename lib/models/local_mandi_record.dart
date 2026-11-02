/// Data model representing a physical APMC mandi record from mandis.json
class LocalMandiRecord {
  final String id;
  final String nameEn;
  final String nameHi;
  final String type;
  final String state;
  final String stateHi;
  final String district;
  final String districtHi;
  final String? tehsil;
  final String? address;
  final double latitude;
  final double longitude;
  final List<String> cropsTraded;
  final Map<String, double> currentPricePerQuintal;
  final int dailyArrivalTons;
  final String? operatingHours;
  final double rating;
  final String sourceUrl;
  final String lastVerifiedDate;
  final String dataQuality;

  const LocalMandiRecord({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.type,
    required this.state,
    required this.stateHi,
    required this.district,
    required this.districtHi,
    this.tehsil,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.cropsTraded,
    required this.currentPricePerQuintal,
    required this.dailyArrivalTons,
    this.operatingHours,
    required this.rating,
    required this.sourceUrl,
    required this.lastVerifiedDate,
    required this.dataQuality,
  });

  factory LocalMandiRecord.fromJson(Map<String, dynamic> json) {
    final pricesRaw = json['current_price_per_quintal'] as Map<String, dynamic>? ?? {};
    final prices = <String, double>{};
    pricesRaw.forEach((k, v) {
      if (v is num) {
        prices[k.toString().toLowerCase().trim()] = v.toDouble();
      }
    });

    final cropsRaw = json['crops_traded'] as List<dynamic>? ?? [];
    final crops = cropsRaw.map((e) => e.toString().toLowerCase().trim()).toList();

    return LocalMandiRecord(
      id: json['id']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      nameHi: json['name_hi']?.toString() ?? (json['name_en']?.toString() ?? ''),
      type: json['type']?.toString() ?? 'apmc_mandi',
      state: json['state']?.toString() ?? '',
      stateHi: json['state_hi']?.toString() ?? (json['state']?.toString() ?? ''),
      district: json['district']?.toString() ?? '',
      districtHi: json['district_hi']?.toString() ?? (json['district']?.toString() ?? ''),
      tehsil: json['tehsil']?.toString(),
      address: json['address']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      cropsTraded: crops,
      currentPricePerQuintal: prices,
      dailyArrivalTons: (json['daily_arrival_tons'] as num?)?.toInt() ?? 0,
      operatingHours: json['operating_hours']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      sourceUrl: json['source_url']?.toString() ?? 'https://agmarknet.gov.in',
      lastVerifiedDate: json['last_verified_date']?.toString() ?? '',
      dataQuality: json['data_quality']?.toString() ?? 'verified',
    );
  }

  String localizedName(bool isHindi) => isHindi ? nameHi : nameEn;
  String localizedDistrict(bool isHindi) => isHindi ? districtHi : districtEn;
  String localizedState(bool isHindi) => isHindi ? stateHi : state;

  String get districtEn => district;

  /// Gets price per quintal for [cropKey] (lowercase normalized). Returns null if not traded.
  double? getPricePerQuintal(String cropKey) {
    return currentPricePerQuintal[cropKey.toLowerCase().trim()];
  }

  /// Converts ₹/quintal to ₹/kg (1 quintal = 100 kg)
  double? getPricePerKg(String cropKey) {
    final qPrice = getPricePerQuintal(cropKey);
    if (qPrice == null) return null;
    return qPrice / 100.0;
  }
}
