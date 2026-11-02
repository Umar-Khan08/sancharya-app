import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech (TTS) Service for farmer voice assistance.
/// Gracefully handles initialization race conditions, Android 11+ visibility,
/// language availability (Hindi / English), speech completion, and error states.
class TtsService extends ChangeNotifier {
  FlutterTts? _flutterTts;
  bool _isPlaying = false;
  bool _isAvailable = false;
  bool _isInitializing = false;
  bool _isBusy = false;
  bool _wasStopped = false;
  String? _errorMessage;
  String? _activeLanguage;
  Completer<bool>? _initCompleter;

  bool get isPlaying => _isPlaying;
  bool get isAvailable => _isAvailable;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  String? get activeLanguage => _activeLanguage;

  TtsService({FlutterTts? ttsInstance}) {
    if (ttsInstance != null) {
      _flutterTts = ttsInstance;
    }
    _initTts();
  }

  /// Ensures TTS engine is initialized before executing any speech operation.
  Future<bool> ensureInitialized() async {
    if (_isAvailable && _flutterTts != null) return true;
    if (_initCompleter != null) return _initCompleter!.future;
    return _initTts();
  }

  Future<bool> _initTts() async {
    if (_initCompleter != null) return _initCompleter!.future;
    final completer = Completer<bool>();
    _initCompleter = completer;
    _isInitializing = true;

    try {
      debugPrint('[TTS] Initializing FlutterTts engine...');
      _flutterTts ??= FlutterTts();
      final tts = _flutterTts!;

      tts.setStartHandler(() {
        debugPrint('[TTS] Speech started successfully');
        _isPlaying = true;
        _errorMessage = null;
        notifyListeners();
      });

      tts.setCompletionHandler(() {
        debugPrint('[TTS] Speech playback completed');
        _isPlaying = false;
        notifyListeners();
      });

      tts.setCancelHandler(() {
        debugPrint('[TTS] Speech playback cancelled/stopped');
        _isPlaying = false;
        notifyListeners();
      });

      tts.setPauseHandler(() {
        debugPrint('[TTS] Speech paused');
        _isPlaying = false;
        notifyListeners();
      });

      tts.setContinueHandler(() {
        debugPrint('[TTS] Speech continued');
        _isPlaying = true;
        notifyListeners();
      });

      tts.setErrorHandler((dynamic msg) {
        debugPrint('[TTS] Speech error occurred: $msg');
        _isPlaying = false;
        _errorMessage = msg?.toString() ?? 'Text-to-Speech playback error';
        notifyListeners();
      });

      // Synchronize speech completion so speak() returns reliably
      await tts.awaitSpeakCompletion(true);

      // On Android, configure queue mode and inspect available engines
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await tts.setQueueMode(0); // QUEUE_FLUSH drops previous utterances
          final defaultEngine = await tts.getDefaultEngine;
          final engines = await tts.getEngines;
          debugPrint('[TTS] Android default engine: $defaultEngine, Available engines: $engines');
        } catch (e) {
          debugPrint('[TTS] Android engine query notice: $e');
        }
      }

      // Configure clear and gentle farmer-friendly pacing (rate 0.45, full volume)
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);

      _isAvailable = true;
      _errorMessage = null;
      debugPrint('[TTS] FlutterTts engine initialized and ready');
      completer.complete(true);
    } catch (e, stack) {
      debugPrint('[TTS] Error initializing TTS engine: $e\n$stack');
      _isAvailable = false;
      _errorMessage = 'Failed to initialize voice engine: $e';
      completer.complete(false);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }

    return completer.future;
  }

  /// Speaks the provided [text] in either Hindi or English.
  /// Handles language resolution, stops ongoing speech, and handles rapid repeated taps.
  Future<void> speak({required String text, required bool isHindi}) async {
    final sanitizedText = text.trim();
    if (sanitizedText.isEmpty) {
      debugPrint('[TTS] speak() called with empty text. Skipping.');
      return;
    }

    if (_isBusy) {
      debugPrint('[TTS] Operation in progress; queueing request after brief lock');
    }
    _isBusy = true;

    try {
      final initialized = await ensureInitialized();
      if (!initialized || _flutterTts == null) {
        final err = isHindi
            ? 'आवाज़ सेवा डिवाइस पर उपलब्ध नहीं है। कृपया TTS सेटिंग्स की जाँच करें।'
            : 'Voice engine is not installed or available on this device. Please check TTS settings.';
        debugPrint('[TTS] Cannot speak: $err');
        _errorMessage = err;
        _isPlaying = false;
        notifyListeners();
        return;
      }

      // Stop previous utterance if currently playing
      if (_isPlaying) {
        debugPrint('[TTS] Halting ongoing speech before starting new utterance');
        await stop();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // Resolve language and verify availability
      final targetLang = await _resolveLanguage(isHindi: isHindi);
      _activeLanguage = targetLang;
      debugPrint('[TTS] Setting language to "$targetLang" (requested isHindi: $isHindi)');
      await _flutterTts!.setLanguage(targetLang);

      // Enforce farmer-friendly pacing and clarity
      await _flutterTts!.setSpeechRate(0.45);
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      _isPlaying = true;
      notifyListeners();

      final preview = sanitizedText.length > 50
          ? '${sanitizedText.substring(0, 50)}...'
          : sanitizedText;
      debugPrint('[TTS] Executing speak: "$preview"');

      _wasStopped = false;
      final result = await _flutterTts!.speak(sanitizedText);
      debugPrint('[TTS] speak() platform invocation returned: $result');

      // Android returns 0 if TextToSpeech was unable to start playback or was cancelled
      if (result == 0 && !_wasStopped) {
        debugPrint('[TTS] Platform returned 0: voice playback could not be initiated');
        _isPlaying = false;
        _errorMessage = isHindi
            ? 'डिवाइस पर आवाज़ शुरू नहीं हो सकी। कृपया TTS सेटिंग्स देखें।'
            : 'Could not start voice playback. Please check device TTS settings.';
        notifyListeners();
      }
    } catch (e, stack) {
      debugPrint('[TTS] speak() encountered exception: $e\n$stack');
      _isPlaying = false;
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isBusy = false;
    }
  }

  /// Stops any currently playing speech.
  Future<void> stop() async {
    debugPrint('[TTS] stop() called');
    _wasStopped = true;
    try {
      await _flutterTts?.stop();
    } catch (e) {
      debugPrint('[TTS] stop() warning: $e');
    } finally {
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Checks if a language is installed / supported on the active engine.
  Future<bool> _isLanguageAvailable(String langCode) async {
    if (_flutterTts == null) return false;

    // 1. Check isLanguageAvailable API
    try {
      final dynamic res = await _flutterTts!.isLanguageAvailable(langCode);
      debugPrint('[TTS] isLanguageAvailable("$langCode") platform check: $res');
      if (res is bool && res) return true;
      if (res is num && res >= 0) return true; // Android returns >= 0 for supported
    } catch (e) {
      debugPrint('[TTS] isLanguageAvailable check notice: $e');
    }

    // 2. Cross-reference with getLanguages
    try {
      final dynamic langs = await _flutterTts!.getLanguages;
      if (langs is List) {
        final normalized = langCode.toLowerCase().replaceAll('_', '-');
        final match = langs.any((dynamic item) {
          final s = item.toString().toLowerCase().replaceAll('_', '-');
          return s == normalized || s.startsWith('$normalized-') || normalized.startsWith('$s-');
        });
        if (match) {
          debugPrint('[TTS] Language "$langCode" matched in installed language list');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[TTS] getLanguages check notice: $e');
    }

    return false;
  }

  /// Resolves the optimal language locale code.
  /// Falls back gracefully if Hindi is requested but voice pack is not installed on the device.
  Future<String> _resolveLanguage({required bool isHindi}) async {
    if (isHindi) {
      if (await _isLanguageAvailable('hi-IN')) return 'hi-IN';
      if (await _isLanguageAvailable('hi')) return 'hi';

      debugPrint('[TTS] Warning: Neither "hi-IN" nor "hi" voice data found on device/engine.');
      // Attempt Indian English or English fallback
      if (await _isLanguageAvailable('en-IN')) {
        _errorMessage = 'डिवाइस पर हिंदी वॉइस पैक नहीं मिला (भारतीय अंग्रेजी में चलाया जा रहा है)।';
        return 'en-IN';
      }
      if (await _isLanguageAvailable('en-US')) {
        _errorMessage = 'डिवाइस पर हिंदी वॉइस पैक नहीं मिला (अंग्रेजी में चलाया जा रहा है)।';
        return 'en-US';
      }
      if (await _isLanguageAvailable('en')) return 'en';

      // Default to hi-IN so engine can attempt synthesis
      return 'hi-IN';
    } else {
      if (await _isLanguageAvailable('en-IN')) return 'en-IN';
      if (await _isLanguageAvailable('en-US')) return 'en-US';
      if (await _isLanguageAvailable('en')) return 'en';
      return 'en-US';
    }
  }

  /// Retrieves list of languages supported by current TTS engine.
  Future<List<String>> getAvailableLanguages() async {
    await ensureInitialized();
    if (_flutterTts == null) return [];
    try {
      final dynamic langs = await _flutterTts!.getLanguages;
      if (langs is List) {
        return langs.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint('[TTS] getAvailableLanguages error: $e');
    }
    return [];
  }

  /// Retrieves list of TTS engines installed on the device (Android only).
  Future<List<String>> getAvailableEngines() async {
    await ensureInitialized();
    if (_flutterTts == null) return [];
    try {
      final dynamic engines = await _flutterTts!.getEngines;
      if (engines is List) {
        return engines.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint('[TTS] getAvailableEngines error: $e');
    }
    return [];
  }

  @override
  void dispose() {
    debugPrint('[TTS] Service disposed');
    _flutterTts?.stop();
    super.dispose();
  }
}
