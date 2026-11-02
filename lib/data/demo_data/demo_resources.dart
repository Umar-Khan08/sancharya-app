import '../../models/agri_resource.dart';

/// Transparent demonstration facilities for SANCHARYA.
/// Labeled honestly as unverified demonstration benchmarks to prevent misleading farmers.
class DemoResources {
  DemoResources._();

  static const List<AgriResource> sampleFacilities = [
    AgriResource(
      id: 'demo_res_01',
      nameEn: 'Regional Cold Storage (Demonstration Benchmark)',
      nameHi: 'क्षेत्रीय कोल्ड स्टोरेज (डेमो बेंचमार्क)',
      type: AgriResourceType.coldStorage,
      districtEn: 'Reference Agro Cluster',
      districtHi: 'संदर्भ कृषि क्षेत्र',
      distanceKm: 12.0,
      capacityMetricTons: 0,
      availableMetricTons: 0,
      contactPhone: '',
      estimatedRatePerMonthPerQuintal: 0,
      isGovernmentAccredited: false,
      isSimulatedData: true,
      isCapacityVerified: false,
      isPhoneVerified: false,
      verificationNoticeEn: 'Demonstration benchmark — real availability and charges must be confirmed locally',
      verificationNoticeHi: 'डेमो संदर्भ — वास्तविक उपलब्धता व दरों की पुष्टि सीधे सुविधा से करें',
    ),
  ];
}
