/// Data model representing a verified NGO / Food Relief organization from ngos.json
class NgoRecord {
  final String id;
  final String nameEn;
  final String nameHi;
  final String state;
  final String stateHi;
  final String district;
  final String districtHi;
  final String? tehsil;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> acceptedProduce;
  final String demandLevel;
  final bool pickupAvailable;
  final String? operatingHours;
  final String? impactNote;
  final String? impactNoteHi;
  final String contact;
  final String sourceUrl;
  final String lastVerifiedDate;
  final String dataQuality;

  const NgoRecord({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.state,
    required this.stateHi,
    required this.district,
    required this.districtHi,
    this.tehsil,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.acceptedProduce,
    required this.demandLevel,
    required this.pickupAvailable,
    this.operatingHours,
    this.impactNote,
    this.impactNoteHi,
    required this.contact,
    required this.sourceUrl,
    required this.lastVerifiedDate,
    required this.dataQuality,
  });

  factory NgoRecord.fromJson(Map<String, dynamic> json) {
    final produceRaw = json['accepted_produce'] as List<dynamic>? ?? [];
    final produce = produceRaw.map((e) => e.toString().toLowerCase().trim()).toList();

    return NgoRecord(
      id: json['id']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      nameHi: json['name_hi']?.toString() ?? (json['name_en']?.toString() ?? ''),
      state: json['state']?.toString() ?? '',
      stateHi: json['state_hi']?.toString() ?? (json['state']?.toString() ?? ''),
      district: json['district']?.toString() ?? '',
      districtHi: json['district_hi']?.toString() ?? (json['district']?.toString() ?? ''),
      tehsil: json['tehsil']?.toString(),
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      acceptedProduce: produce,
      demandLevel: json['demand_level']?.toString() ?? 'Moderate',
      pickupAvailable: json['pickup_available'] == true,
      operatingHours: json['operating_hours']?.toString(),
      impactNote: json['impact_note']?.toString(),
      impactNoteHi: json['impact_note_hi']?.toString() ?? json['impact_note']?.toString(),
      contact: json['contact']?.toString() ?? '',
      sourceUrl: json['source_url']?.toString() ?? 'https://ngodarpan.gov.in',
      lastVerifiedDate: json['last_verified_date']?.toString() ?? '',
      dataQuality: json['data_quality']?.toString() ?? 'verified',
    );
  }

  String localizedName(bool isHindi) => isHindi ? nameHi : nameEn;
  String localizedDistrict(bool isHindi) => isHindi ? districtHi : district;
  String localizedState(bool isHindi) => isHindi ? stateHi : state;
  String? localizedImpactNote(bool isHindi) => isHindi ? (impactNoteHi ?? impactNote) : impactNote;

  bool get hasValidContact {
    final clean = contact.trim();
    if (clean.isEmpty) return false;
    final lower = clean.toLowerCase();
    if (lower == 'null' ||
        lower == 'none' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == 'undefined') {
      return false;
    }
    final digits = clean.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return false;
    // Reject placeholder or repeated digits like 0000000000 or 9999999999
    if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return false;

    // Standard Indian mobile number formats:
    // +91 followed by 10 digits starting with 6, 7, 8, or 9
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      return local.startsWith(RegExp(r'[6-9]'));
    }
    // 10 digits starting with 6, 7, 8, or 9
    if (digits.length == 10) {
      return digits.startsWith(RegExp(r'[6-9]'));
    }
    return false;
  }

  String contactDisplay(bool isHindi) {
    if (!hasValidContact) {
      return isHindi ? 'मोबाइल नंबर उपलब्ध नहीं है' : 'No mobile number available';
    }
    return contact.trim();
  }

  String localizedDemandLevel(bool isHindi) {
    if (!isHindi) return demandLevel;
    switch (demandLevel.toLowerCase()) {
      case 'high':
        return 'उच्च मांग';
      case 'critical':
        return 'अति आवश्यक';
      case 'moderate':
        return 'मध्यम मांग';
      case 'low':
        return 'सीमित मांग';
      default:
        return demandLevel;
    }
  }

  bool acceptsCrop(String cropSlug) {
    final clean = cropSlug.toLowerCase().trim();
    if (acceptedProduce.contains(clean)) return true;
    // Common aliases in produce
    if (clean == 'tomato' && acceptedProduce.contains('vegetables')) return true;
    if (clean == 'potato' && acceptedProduce.contains('vegetables')) return true;
    if (clean == 'onion' && acceptedProduce.contains('vegetables')) return true;
    if (clean == 'wheat' && (acceptedProduce.contains('grains') || acceptedProduce.contains('cereals'))) return true;
    if (clean == 'rice' && (acceptedProduce.contains('grains') || acceptedProduce.contains('cereals'))) return true;
    return false;
  }
}
