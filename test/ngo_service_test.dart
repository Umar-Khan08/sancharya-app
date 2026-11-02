import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/services/resources/ngo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NgoService & ngos.json Tests', () {
    late NgoService ngoService;

    setUp(() {
      ngoService = NgoService();
    });

    test('Loads exactly 827 NGO records from assets/data/ngos.json', () async {
      final ngos = await ngoService.getAllNgos();
      expect(ngos.length, 827);

      final first = ngos.first;
      expect(first.id, isNotEmpty);
      expect(first.nameEn, isNotEmpty);
      expect(first.district, isNotEmpty);
      expect(first.state, isNotEmpty);
      expect(first.acceptedProduce, isNotEmpty);
      expect(first.sourceUrl, contains('ngodarpan.gov.in'));
      expect(first.dataQuality, 'verified');

      // Verify that genuine contacts are preserved and unverified ones are empty
      final withContact = ngos.firstWhere((n) => n.hasValidContact);
      expect(withContact.contact, isNotEmpty);
      expect(withContact.contactDisplay(false), withContact.contact);

      final withoutContact = ngos.firstWhere((n) => !n.hasValidContact);
      expect(withoutContact.contact, isEmpty);
      expect(withoutContact.contactDisplay(false), 'No mobile number available');
      expect(withoutContact.contactDisplay(true), 'मोबाइल नंबर उपलब्ध नहीं है');
    });

    test('Filters NGOs by location (Ludhiana) accurately', () async {
      final result = await ngoService.searchNgos(
        locationQuery: 'Ludhiana, Punjab',
      );

      expect(result.isNotEmpty, true);
      for (final item in result.ngos) {
        expect(item.record.district.toLowerCase(), contains('ludhiana'));
      }
    });

    test('Filters NGOs by crop acceptance (Tomato)', () async {
      final result = await ngoService.searchNgos(
        cropQuery: 'tomato',
      );

      expect(result.isNotEmpty, true);
      for (final item in result.ngos) {
        expect(item.record.acceptsCrop('tomato'), true);
      }
    });

    test('Strict produce check: does NOT claim NGO accepts a crop if not in acceptedProduce', () async {
      final ngos = await ngoService.getAllNgos();
      final sample = ngos.first;

      // Check crops the sample definitely does NOT accept
      const exoticCrop = 'DragonFruitExotic';
      expect(sample.acceptsCrop(exoticCrop), false);
    });

    test('Pickup availability filter works correctly', () async {
      final result = await ngoService.searchNgos(
        pickupOnly: true,
      );

      expect(result.isNotEmpty, true);
      for (final item in result.ngos) {
        expect(item.record.pickupAvailable, true);
      }
    });

    test('Empty state when searching in non-existent location', () async {
      final result = await ngoService.searchNgos(
        locationQuery: 'CompletelyFakeDistrict12345',
      );

      expect(result.isEmpty, true);
      expect(result.totalCount, 0);
    });

    test('Proximity sorting: sorts by distance when user coordinates are provided', () async {
      // Ludhiana coordinates
      final result = await ngoService.searchNgos(
        locationQuery: 'Ludhiana',
        userLatitude: 30.9010,
        userLongitude: 75.8573,
      );

      expect(result.isNotEmpty, true);
      for (int i = 0; i < result.ngos.length - 1; i++) {
        final currentDist = result.ngos[i].distanceKm;
        final nextDist = result.ngos[i + 1].distanceKm;
        if (currentDist != null && nextDist != null) {
          expect(currentDist, lessThanOrEqualTo(nextDist));
        }
      }
    });

    test('Bilingual getters provide both English and Hindi text correctly', () async {
      final ngos = await ngoService.getAllNgos();
      final first = ngos.first;

      expect(first.localizedName(false), first.nameEn);
      expect(first.localizedName(true), first.nameHi);
      expect(first.localizedDistrict(false), first.district);
      expect(first.localizedDistrict(true), first.districtHi);
      expect(first.localizedDemandLevel(false), first.demandLevel);
      expect(first.localizedDemandLevel(true), isNotEmpty);
    });
  });
}
