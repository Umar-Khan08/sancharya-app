import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/services/agriculture/local_mandi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalMandiService Tests', () {
    late LocalMandiService mandiService;

    setUp(() {
      mandiService = LocalMandiService();
    });

    test('Loads exactly 827 mandi records from assets/data/mandis.json', () async {
      final mandis = await mandiService.getAllMandis();
      expect(mandis.length, 827);

      final first = mandis.first;
      expect(first.id, isNotEmpty);
      expect(first.nameEn, isNotEmpty);
      expect(first.district, isNotEmpty);
      expect(first.state, isNotEmpty);
      expect(first.currentPricePerQuintal, isNotEmpty);
      expect(first.sourceUrl, contains('agmarknet.gov.in'));
      expect(first.lastVerifiedDate, isNotEmpty);
    });

    test('Exact district and crop match for Ludhiana (Tomato)', () async {
      final match = await mandiService.findPriceForCropAndLocation(
        cropQuery: 'Tomato',
        locationQuery: 'Ludhiana, Punjab',
      );

      expect(match, isNotNull);
      expect(match!.mandi.district.toLowerCase(), 'ludhiana');
      expect(match.matchedCropKey, 'tomato');
      expect(match.pricePerQuintal, greaterThan(0));
      expect(match.pricePerKg, match.pricePerQuintal / 100.0);
      expect(match.sourceUrl, contains('agmarknet.gov.in'));
      expect(match.dataQuality, isNotEmpty);
    });

    test('Hindi crop and location normalization (Tamatar / टमाटर in Ludhiana)', () async {
      final matchHindi = await mandiService.findPriceForCropAndLocation(
        cropQuery: 'टमाटर',
        locationQuery: 'लुधियाना',
      );

      expect(matchHindi, isNotNull);
      expect(matchHindi!.matchedCropKey, 'tomato');
      expect(matchHindi.pricePerQuintal, greaterThan(0));

      final matchAlias = await mandiService.findPriceForCropAndLocation(
        cropQuery: 'tamatar',
        locationQuery: 'Ludhiana',
      );
      expect(matchAlias, isNotNull);
      expect(matchAlias!.matchedCropKey, 'tomato');
    });

    test('Strict matching: unmapped district does NOT substitute prices from another district', () async {
      final match = await mandiService.findPriceForCropAndLocation(
        cropQuery: 'Tomato',
        locationQuery: 'NonExistentDistrict999, Nowhere',
      );

      // Must return null — NEVER substitute prices from another district
      expect(match, isNull);
    });

    test('District matches but crop is not traded in that district returns null', () async {
      final match = await mandiService.findPriceForCropAndLocation(
        cropQuery: 'UnheardOfAlienCrop',
        locationQuery: 'Ludhiana, Punjab',
      );

      expect(match, isNull);
    });

    test('Unit conversion: pricePerKg is exactly pricePerQuintal / 100.0', () async {
      final match = await mandiService.findPriceForCropAndLocation(
        cropQuery: 'Wheat',
        locationQuery: 'Ludhiana, Punjab',
      );

      expect(match, isNotNull);
      expect(match!.pricePerKg, closeTo(match.pricePerQuintal / 100.0, 0.001));
    });

    test('In-memory caching: subsequent lookups execute instantly without re-reading file', () async {
      final watch = Stopwatch()..start();
      await mandiService.getAllMandis();
      final firstDurationMs = watch.elapsedMilliseconds;

      watch.reset();
      final cached = await mandiService.getAllMandis();
      final cachedDurationMs = watch.elapsedMilliseconds;

      expect(cached.length, 827);
      expect(cachedDurationMs, lessThanOrEqualTo(5));
      debugPrint('[PERFORMANCE] Initial load: ${firstDurationMs}ms, Cached lookup: ${cachedDurationMs}ms');
    });
  });
}
