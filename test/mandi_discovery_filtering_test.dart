import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/models/agri_resource.dart';
import 'package:sancharya/services/resources/mandi_discovery_service.dart';

void main() {
  group('MandiDiscoveryService - Agricultural Market Exclusion & Filtering Tests', () {
    // 1. Valid agricultural mandi
    test('Identifies valid agricultural APMC mandis correctly', () {
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Lasalgaon APMC Market Yard'),
        isTrue,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Collectorganj Krishi Mandi'),
        isTrue,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'चकरपुर कृषि उत्पादन मंडी'),
        isTrue,
      );
    });

    // 2. Fruit-and-vegetable market
    test('Identifies fruit-and-vegetable wholesale mandis correctly', () {
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Azadpur Sabzi Mandi'),
        isTrue,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Pune Fruit and Vegetable Yard'),
        isTrue,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(
          name: 'Local Kisan Mandi',
          tags: {'produce': 'vegetables', 'market': 'farmers'},
        ),
        isTrue,
      );
    });

    // 3. Cloth or textile wholesale market
    test('Strictly excludes cloth and textile wholesale markets', () {
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Surat Textile Market'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Gandhi Nagar Cloth Market'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'कलेक्टरगंज कपड़ा बाजार'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Naveen Saree & Fabric Wholesaler'),
        isFalse,
      );
    });

    // 4. Garment market
    test('Strictly excludes garment and apparel wholesale markets', () {
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Kanpur Garment Wholesale Complex'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Ludhiana Readymade Garments Market'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'रेडिमेड गारमेंट मंडी'),
        isFalse,
      );
    });

    // 5. Unrelated wholesale business
    test('Strictly excludes unrelated wholesale businesses (electronics, jewelry, timber, furniture)', () {
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Sarafa Jewelry Market'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Lamington Electronics Market'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'City Timber and Furniture Yard'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Central Shopping Mall'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Leather and Footwear Bazaar'),
        isFalse,
      );
    });

    // 6. Unknown or missing category (ambiguous generic names)
    test('Safely rejects ambiguous generic markets without agricultural confirmation', () {
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Central Plaza Market'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: 'Main Bazaar 4'),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: ''),
        isFalse,
      );
      expect(
        MandiDiscoveryService.isAgriculturalMarket(name: '   '),
        isFalse,
      );
    });

    // 7. Duplicate market results
    test('deduplicateMandis removes duplicate physical markets within proximity radius', () {
      final list = [
        const AgriResource(
          id: 'osm_1',
          nameEn: 'Collectorganj Krishi Mandi',
          nameHi: 'कलेक्टरगंज कृषि मंडी',
          type: AgriResourceType.mandi,
          districtEn: 'Kanpur Nagar',
          districtHi: 'कानपुर नगर',
          distanceKm: 2.5,
          capacityMetricTons: 0,
          availableMetricTons: 0,
          contactPhone: '',
          estimatedRatePerMonthPerQuintal: 0,
          isGovernmentAccredited: true,
          isSimulatedData: false,
          latitude: 26.4580,
          longitude: 80.3540,
        ),
        // Duplicate: same location and name with slight difference
        const AgriResource(
          id: 'osm_2',
          nameEn: 'Collectorganj Mandi Yard',
          nameHi: 'कलेक्टरगंज मंडी यार्ड',
          type: AgriResourceType.mandi,
          districtEn: 'Kanpur Nagar',
          districtHi: 'कानपुर नगर',
          distanceKm: 2.55,
          capacityMetricTons: 0,
          availableMetricTons: 0,
          contactPhone: '',
          estimatedRatePerMonthPerQuintal: 0,
          isGovernmentAccredited: true,
          isSimulatedData: false,
          latitude: 26.4582,
          longitude: 80.3542,
        ),
        // Distinct market
        const AgriResource(
          id: 'osm_3',
          nameEn: 'Chakarpur Krishi Utpadan Mandi',
          nameHi: 'चकरपुर कृषि उत्पादन मंडी',
          type: AgriResourceType.mandi,
          districtEn: 'Kanpur Nagar',
          districtHi: 'कानपुर नगर',
          distanceKm: 8.0,
          capacityMetricTons: 0,
          availableMetricTons: 0,
          contactPhone: '',
          estimatedRatePerMonthPerQuintal: 0,
          isGovernmentAccredited: true,
          isSimulatedData: false,
          latitude: 26.4385,
          longitude: 80.2520,
        ),
      ];

      final deduped = MandiDiscoveryService.deduplicateMandis(list);
      expect(deduped.length, 2);
      expect(deduped.first.nameEn, 'Collectorganj Krishi Mandi');
      expect(deduped.last.nameEn, 'Chakarpur Krishi Utpadan Mandi');
    });

    // 8. Offline dataset filtering
    test('Offline dataset entries pass agricultural produce validation', () {
      final sampleOfflineMandiNames = [
        'Lasalgaon APMC',
        'Pimpalgaon Baswant APMC',
        'Agra APMC',
        'Pune APMC Market',
        'Chakarpur Mandi',
      ];

      for (final name in sampleOfflineMandiNames) {
        expect(
          MandiDiscoveryService.isAgriculturalMarket(name: name),
          isTrue,
          reason: '$name must pass agricultural validation',
        );
      }
    });
  });
}

