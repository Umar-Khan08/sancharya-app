import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VoiceLanguage { hindi, english }

/// Robust Speech-to-Text service for farmers supporting Hindi (hi_IN) and English (en_IN/en_US).
/// Designed with graceful fallback when microphone permissions are denied or speech engine is unavailable (e.g. emulators).
class SpeechRecognitionService extends ChangeNotifier {
  static final SpeechRecognitionService _instance = SpeechRecognitionService._internal();
  factory SpeechRecognitionService() => _instance;
  SpeechRecognitionService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _isListening = false;
  String _recognizedText = '';
  String? _errorMessageEn;
  String? _errorMessageHi;
  VoiceLanguage _selectedLanguage = VoiceLanguage.hindi;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  String? get errorMessageEn => _errorMessageEn;
  String? get errorMessageHi => _errorMessageHi;
  VoiceLanguage get selectedLanguage => _selectedLanguage;

  String get currentLocaleId => _selectedLanguage == VoiceLanguage.hindi ? 'hi_IN' : 'en_IN';

  void setLanguage(VoiceLanguage lang) {
    if (_selectedLanguage == lang) return;
    _selectedLanguage = lang;
    notifyListeners();
  }

  /// Sets error messages for manual or test purposes
  @visibleForTesting
  void setErrorMessageForTest({String? en, String? hi}) {
    _errorMessageEn = en;
    _errorMessageHi = hi;
    notifyListeners();
  }

  /// Resolves the best matching available locale on the device
  Future<String> resolveTargetLocale() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) {
        return currentLocaleId;
      }

      if (_selectedLanguage == VoiceLanguage.hindi) {
        final hiMatches = locales.where((l) => l.localeId.toLowerCase().startsWith('hi')).toList();
        if (hiMatches.isNotEmpty) {
          final exact = hiMatches.firstWhere(
            (l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'hi_in',
            orElse: () => hiMatches.first,
          );
          return exact.localeId;
        }
        // If Hindi model is not installed on device, prefer Indian English or US English
        final enMatch = locales.where((l) => l.localeId.toLowerCase().startsWith('en')).firstOrNull;
        return enMatch?.localeId ?? locales.first.localeId;
      } else {
        final enMatches = locales.where((l) => l.localeId.toLowerCase().startsWith('en')).toList();
        if (enMatches.isNotEmpty) {
          final exactIn = enMatches.where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'en_in').firstOrNull;
          final exactUs = enMatches.where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'en_us').firstOrNull;
          return (exactIn ?? exactUs ?? enMatches.first).localeId;
        }
        return locales.first.localeId;
      }
    } catch (_) {
      return currentLocaleId;
    }
  }

  /// Initializes the device speech recognition engine
  Future<bool> initialize() async {
    if (_isInitialized && _isAvailable) return true;

    try {
      _isAvailable = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: false,
      );
      _isInitialized = true;
      if (!_isAvailable) {
        _errorMessageEn = 'Speech recognition service is not available on this device/emulator. Please enter text manually using the keyboard.';
        _errorMessageHi = 'इस डिवाइस या एमुलेटर पर वाक् पहचान (स्पीच) सेवा उपलब्ध नहीं है। कृपया कीबोर्ड से टाइप करें।';
      }
      notifyListeners();
      return _isAvailable;
    } catch (e) {
      _isInitialized = true;
      _isAvailable = false;
      _errorMessageEn = 'Speech service initialization error: $e. Please use manual entry.';
      _errorMessageHi = 'वाक् सेवा शुरू करने में समस्या हुई। कृपया कीबोर्ड से टाइप करें।';
      notifyListeners();
      return false;
    }
  }

  /// Starts listening for speech in the selected language
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    Duration listenFor = const Duration(seconds: 15),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    _errorMessageEn = null;
    _errorMessageHi = null;
    _recognizedText = '';

    final ready = await initialize();
    if (!ready || !_isAvailable) {
      notifyListeners();
      return false;
    }

    try {
      final targetLocale = await resolveTargetLocale();

      await _speech.listen(
        onResult: (result) {
          _recognizedText = result.recognizedWords;
          notifyListeners();
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: listenFor,
          pauseFor: pauseFor,
          localeId: targetLocale,
          cancelOnError: false,
          partialResults: true,
        ),
      );

      _isListening = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isListening = false;
      _errorMessageEn = 'Microphone or speech recognition failure: $e';
      _errorMessageHi = 'माइक्रोफ़ोन या वाक् पहचान में समस्या: $e';
      notifyListeners();
      return false;
    }
  }

  /// Stops current speech recognition explicitly
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (_) {}
    _isListening = false;
    notifyListeners();
  }

  /// Cancels recognition without emitting final result
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (_) {}
    _isListening = false;
    _recognizedText = '';
    notifyListeners();
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _isListening = true;
    } else if (status == 'notListening' || status == 'done') {
      _isListening = false;
      if (_recognizedText.trim().isEmpty && _errorMessageEn == null) {
        _errorMessageEn = 'Listening stopped. No speech detected. Tap the mic to try again or type manually.';
        _errorMessageHi = 'सुनना समाप्त हुआ। कोई शब्द नहीं मिला। पुनः बोलने के लिए माइक दबाएं या कीबोर्ड से लिखें।';
      }
    }
    notifyListeners();
  }

  void _onError(SpeechRecognitionError error) {
    _isListening = false;
    final msg = error.errorMsg.toLowerCase();

    if (msg.contains('error_permission') || msg.contains('permission')) {
      _errorMessageEn = 'Microphone permission was denied. Please allow microphone access in device settings.';
      _errorMessageHi = 'माइक्रोफ़ोन अनुमति अस्वीकृत की गई। कृपया सेटिंग्स में जाकर अनुमति दें।';
    } else if (msg.contains('error_speech_timeout') || msg.contains('timeout')) {
      _errorMessageEn = 'No speech detected (timeout). Please tap the microphone and speak again.';
      _errorMessageHi = 'कोई आवाज़ नहीं सुनाई दी (समय समाप्त)। कृपया माइक दबाकर पुनः बोलें।';
    } else if (msg.contains('error_no_match') || msg.contains('no_match')) {
      _errorMessageEn = 'Could not understand spoken words. Please speak clearly into the microphone.';
      _errorMessageHi = 'आवाज़ स्पष्ट नहीं सुनाई दी। कृपया साफ़ आवाज़ में पुनः बोलें।';
    } else if (msg.contains('error_audio') || msg.contains('audio')) {
      _errorMessageEn = 'Microphone audio recording error. Please check your mic connection.';
      _errorMessageHi = 'ऑडियो रिकॉर्डिंग में समस्या हुई। कृपया माइक्रोफ़ोन की जांच करें।';
    } else if (msg.contains('error_client') || msg.contains('client')) {
      _errorMessageEn = 'Speech recognition engine is unavailable on this device/emulator. Please enter text manually using the keyboard.';
      _errorMessageHi = 'इस डिवाइस/एमुलेटर पर वाक् पहचान सेवा उपलब्ध नहीं है। कृपया कीबोर्ड से लिखें।';
    } else if (msg.contains('error_network') || msg.contains('network')) {
      _errorMessageEn = 'Network connection required for voice recognition. Please check your internet or enter manually.';
      _errorMessageHi = 'वाक् पहचान के लिए इंटरनेट आवश्यक है। कृपया कनेक्शन जांचें या कीबोर्ड से लिखें।';
    } else if (msg.contains('error_busy') || msg.contains('busy')) {
      _errorMessageEn = 'Speech recognizer is busy. Please wait a moment and try again.';
      _errorMessageHi = 'वाक् सेवा व्यस्त है। कृपया कुछ क्षण बाद पुनः प्रयास करें।';
    } else {
      _errorMessageEn = 'Speech recognition issue (${error.errorMsg}). Please use manual entry.';
      _errorMessageHi = 'वाक् पहचान में समस्या (${error.errorMsg})। कृपया कीबोर्ड से दर्ज करें।';
    }
    notifyListeners();
  }
}
