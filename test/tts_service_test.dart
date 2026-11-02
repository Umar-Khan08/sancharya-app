import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/data/demo_data/demo_crops.dart';
import 'package:sancharya/models/crop_analysis_input.dart';
import 'package:sancharya/services/agriculture/demo_agriculture_service.dart';
import 'package:sancharya/services/voice/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final log = <MethodCall>[];
  bool mockHindiAvailable = true;

  setUp(() {
    log.clear();
    mockHindiAvailable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'awaitSpeakCompletion':
        case 'setQueueMode':
        case 'setSpeechRate':
        case 'setVolume':
        case 'setPitch':
        case 'stop':
        case 'pause':
          return 1;
        case 'getDefaultEngine':
          return 'com.google.android.tts';
        case 'getEngines':
          return ['com.google.android.tts'];
        case 'getLanguages':
          return mockHindiAvailable ? ['en-US', 'en-IN', 'hi-IN'] : ['en-US', 'en-IN'];
        case 'isLanguageAvailable':
          final lang = methodCall.arguments.toString();
          if (lang.startsWith('hi')) {
            return mockHindiAvailable ? 1 : -2;
          }
          return 1;
        case 'setLanguage':
          return 1;
        case 'speak':
          return 1;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('TtsService Unit Tests', () {
    test('Initialization configures rate, volume, queue mode, and completion', () async {
      final tts = TtsService();
      final initialized = await tts.ensureInitialized();

      expect(initialized, isTrue);
      expect(tts.isAvailable, isTrue);
      expect(tts.isPlaying, isFalse);

      final methods = log.map((c) => c.method).toList();
      expect(methods.contains('awaitSpeakCompletion'), isTrue);
      expect(methods.contains('setSpeechRate'), isTrue);
      expect(methods.contains('setVolume'), isTrue);
      expect(methods.contains('setPitch'), isTrue);
      tts.dispose();
    });

    test('Empty or whitespace text is rejected without speaking', () async {
      final tts = TtsService();
      await tts.ensureInitialized();
      log.clear();

      await tts.speak(text: '', isHindi: false);
      await tts.speak(text: '   \n  \t  ', isHindi: true);

      final speakCalls = log.where((c) => c.method == 'speak');
      expect(speakCalls.isEmpty, isTrue);
      expect(tts.isPlaying, isFalse);
      tts.dispose();
    });

    test('Speaking in Hindi applies hi-IN when available', () async {
      final tts = TtsService();
      await tts.ensureInitialized();
      log.clear();

      await tts.speak(text: 'टमाटर की गुणवत्ता अच्छी है', isHindi: true);

      final langCalls = log.where((c) => c.method == 'setLanguage');
      expect(langCalls.isNotEmpty, isTrue);
      expect(langCalls.last.arguments, 'hi-IN');
      expect(tts.activeLanguage, 'hi-IN');
      tts.dispose();
    });

    test('Speaking in Hindi gracefully falls back to en-IN when Hindi is unavailable', () async {
      mockHindiAvailable = false;
      final tts = TtsService();
      await tts.ensureInitialized();
      log.clear();

      await tts.speak(text: 'टमाटर रिपोर्ट', isHindi: true);

      final langCalls = log.where((c) => c.method == 'setLanguage');
      expect(langCalls.isNotEmpty, isTrue);
      expect(langCalls.last.arguments, 'en-IN');
      expect(tts.activeLanguage, 'en-IN');
      expect(tts.errorMessage, contains('हिंदी'));
      tts.dispose();
    });

    test('stop() resets isPlaying and invokes platform stop', () async {
      final tts = TtsService();
      await tts.ensureInitialized();
      log.clear();

      await tts.stop();
      expect(tts.isPlaying, isFalse);

      final stopCalls = log.where((c) => c.method == 'stop');
      expect(stopCalls.isNotEmpty, isTrue);
      tts.dispose();
    });

    test('CropAnalysisResult speechSummary synthesizes non-empty Hindi and English text', () async {
      final agService = DemoAgricultureService();
      final tomato = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomato,
        location: 'Nashik, Maharashtra',
        quantity: 500,
        quantityUnit: QuantityUnit.kilogram,
        harvestDate: DateTime.now().subtract(const Duration(days: 2)),
        condition: CropCondition.good,
      );

      final result = await agService.analyzeCrop(input);

      expect(result.speechSummaryEn.isNotEmpty, isTrue);
      expect(result.speechSummaryHi.isNotEmpty, isTrue);
      expect(result.speechSummaryEn, contains('Tomato analysis report'));
      expect(result.speechSummaryHi, contains('टमाटर विश्लेषण रिपोर्ट'));
    });
  });
}
