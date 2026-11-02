import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../services/voice/speech_recognition_service.dart';

/// Reusable Farmer-Friendly Voice Input Microphone Button & Listening Sheet
/// Supports Hindi (hi_IN) and English (en_IN), live transcription, review before insert,
/// and protection against overwriting manual text without confirmation.
class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;
  final String fieldNameEn;
  final String fieldNameHi;
  final String? spokenHintEn;
  final String? spokenHintHi;
  final bool isNumericField;
  final bool isHindi;
  final VoidCallback? onTextApplied;

  const VoiceInputButton({
    super.key,
    required this.controller,
    required this.fieldNameEn,
    required this.fieldNameHi,
    this.spokenHintEn,
    this.spokenHintHi,
    this.isNumericField = false,
    this.isHindi = false,
    this.onTextApplied,
  });

  /// Converts spoken Hindi and English number words into numeric digits for input fields.
  static String convertSpokenNumberToDigits(String spoken) {
    var s = spoken.toLowerCase().trim();

    // Direct words to numbers
    const numberWords = {
      // Hindi
      'शून्य': '0', 'एक': '1', 'दो': '2', 'तीन': '3', 'चार': '4',
      'पांच': '5', 'पाँच': '5', 'छह': '6', 'सात': '7', 'आठ': '8',
      'नौ': '9', 'दस': '10', 'ग्यारह': '11', 'बारह': '12',
      'पंद्रह': '15', 'बीस': '20', 'पच्चीस': '25', 'तीस': '30',
      'पैंतीस': '35', 'चालीस': '40', 'पंतालीस': '45', 'पचास': '50',
      'प बचपन': '55', 'साठ': '60', 'सत्तर': '70', 'अस्सी': '80',
      'नब्बे': '90', 'सौ': '100', 'दो सौ': '200', 'पांच सौ': '500',
      'हजार': '1000', 'एक हजार': '1000', 'डेढ़': '1.5', 'ढाई': '2.5',
      // English
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'ten': '10', 'twenty': '20', 'twenty five': '25', 'thirty': '30',
      'forty': '40', 'fifty': '50', 'sixty': '60', 'seventy': '70',
      'eighty': '80', 'ninety': '90', 'hundred': '100', 'one hundred': '100',
      'one hundred and fifty': '150', 'thousand': '1000',
    };

    for (final entry in numberWords.entries) {
      if (s == entry.key) return entry.value;
    }

    // Try extracting any digits already present (e.g. "120 quintals", "दस क्विंटल")
    for (final entry in numberWords.entries) {
      if (s.contains(entry.key)) {
        s = s.replaceAll(entry.key, entry.value);
      }
    }

    final digits = s.replaceAll(RegExp(r'[^0-9.]'), '');
    return digits.isNotEmpty ? digits : spoken;
  }

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.mic_rounded, color: AppColors.primaryGreen, size: 22),
      tooltip: widget.isHindi ? 'बोलकर दर्ज करें (आवाज़)' : 'Speak input (Voice)',
      onPressed: _handleMicPressed,
    );
  }

  Future<void> _handleMicPressed() async {
    final existingText = widget.controller.text.trim();

    // Protection: If user already typed text manually, confirm replacement or append
    if (existingText.isNotEmpty) {
      final shouldProceed = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              widget.isHindi ? 'पहले से टेक्स्ट मौजूद है' : 'Replace or Append Text?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Text(
              widget.isHindi
                  ? 'आपने पहले "$existingText" लिखा है। आप बोलकर नया टेक्स्ट बदलना चाहते हैं या आगे जोड़ना चाहते हैं?'
                  : 'You already entered "$existingText". Would you like to replace it or append your spoken words?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: Text(widget.isHindi ? 'रद्द करें' : 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'append'),
                child: Text(widget.isHindi ? 'आगे जोड़ें' : 'Append'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                ),
                onPressed: () => Navigator.pop(ctx, 'replace'),
                child: Text(widget.isHindi ? 'बदलें (Replace)' : 'Replace'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (shouldProceed == null || shouldProceed == 'cancel') return;
      _openVoiceListeningSheet(replaceMode: shouldProceed == 'replace');
    } else {
      _openVoiceListeningSheet(replaceMode: true);
    }
  }

  void _openVoiceListeningSheet({required bool replaceMode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _VoiceListeningSheet(
          fieldNameEn: widget.fieldNameEn,
          fieldNameHi: widget.fieldNameHi,
          spokenHintEn: widget.spokenHintEn,
          spokenHintHi: widget.spokenHintHi,
          isNumericField: widget.isNumericField,
          isHindi: widget.isHindi,
          onApplyText: (spokenText) {
            if (spokenText.trim().isEmpty) return;

            var processed = spokenText.trim();
            if (widget.isNumericField) {
              processed = VoiceInputButton.convertSpokenNumberToDigits(processed);
            }

            if (replaceMode || widget.controller.text.trim().isEmpty) {
              widget.controller.text = processed;
            } else {
              widget.controller.text = '${widget.controller.text.trim()} $processed';
            }

            widget.onTextApplied?.call();
          },
        );
      },
    );
  }
}

class _VoiceListeningSheet extends StatefulWidget {
  final String fieldNameEn;
  final String fieldNameHi;
  final String? spokenHintEn;
  final String? spokenHintHi;
  final bool isNumericField;
  final bool isHindi;
  final ValueChanged<String> onApplyText;

  const _VoiceListeningSheet({
    required this.fieldNameEn,
    required this.fieldNameHi,
    this.spokenHintEn,
    this.spokenHintHi,
    required this.isNumericField,
    required this.isHindi,
    required this.onApplyText,
  });

  @override
  State<_VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<_VoiceListeningSheet> {
  final SpeechRecognitionService _service = SpeechRecognitionService();
  String _liveTranscription = '';
  bool _isListening = false;
  String? _serviceError;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _service.setLanguage(widget.isHindi ? VoiceLanguage.hindi : VoiceLanguage.english);
    _startRecording();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _service.stopListening();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {
      _isListening = _service.isListening;
      if (_service.recognizedText.isNotEmpty) {
        _liveTranscription = _service.recognizedText;
      }
      final err = widget.isHindi ? _service.errorMessageHi : _service.errorMessageEn;
      if (err != null) {
        _serviceError = err;
      }
    });
  }

  Future<void> _startRecording() async {
    setState(() {
      _liveTranscription = '';
      _serviceError = null;
      _isListening = true;
    });

    final success = await _service.startListening(
      onResult: (words, isFinal) {
        if (mounted) {
          setState(() {
            _liveTranscription = words;
            if (isFinal) _isListening = false;
          });
        }
      },
    );

    if (!success && mounted) {
      setState(() {
        _isListening = false;
        _serviceError = widget.isHindi
            ? (_service.errorMessageHi ?? 'माइक्रोफ़ोन या वाक् पहचान सेवा उपलब्ध नहीं है।')
            : (_service.errorMessageEn ?? 'Microphone or speech recognition service unavailable.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = widget.isHindi;
    final hint = isHindi
        ? (widget.spokenHintHi ?? 'साफ़ आवाज़ में बोलें...')
        : (widget.spokenHintEn ?? 'Speak clearly...');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header with language toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isHindi ? '${widget.fieldNameHi} बोलें' : 'Speak ${widget.fieldNameEn}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('हिन्दी', style: TextStyle(fontSize: 12)),
                    selected: _service.selectedLanguage == VoiceLanguage.hindi,
                    selectedColor: AppColors.primaryGreenLight,
                    onSelected: (_) {
                      setState(() => _service.setLanguage(VoiceLanguage.hindi));
                      _startRecording();
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('English', style: TextStyle(fontSize: 12)),
                    selected: _service.selectedLanguage == VoiceLanguage.english,
                    selectedColor: AppColors.primaryGreenLight,
                    onSelected: (_) {
                      setState(() => _service.setLanguage(VoiceLanguage.english));
                      _startRecording();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Listening Microphone Animation
          GestureDetector(
            onTap: _isListening ? () => _service.stopListening() : _startRecording,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? AppColors.riskHighBg : AppColors.surfaceMuted,
                border: Border.all(
                  color: _isListening ? AppColors.riskHigh : AppColors.primaryGreen,
                  width: _isListening ? 3 : 2,
                ),
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 40,
                color: _isListening ? AppColors.riskHigh : AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            _isListening
                ? (isHindi ? 'सुन रहा हूँ... बोलिए' : 'Listening... Speak now')
                : (_serviceError != null
                    ? (isHindi ? 'वाक् सेवा स्थिति' : 'Speech Status')
                    : (_liveTranscription.isNotEmpty
                        ? (isHindi ? 'आवाज़ दर्ज हुई' : 'Speech captured')
                        : (isHindi ? 'सुनना समाप्त हुआ' : 'Listening stopped'))),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _isListening
                  ? AppColors.riskHigh
                  : (_serviceError != null ? AppColors.riskHigh : AppColors.textSecondary),
            ),
          ),

          const SizedBox(height: 14),

          // Live Transcription Box
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 65),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _serviceError != null ? AppColors.riskHigh.withValues(alpha: 0.4) : AppColors.borderLight,
              ),
            ),
            child: _serviceError != null
                ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.riskHigh),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _serviceError!,
                              style: const TextStyle(color: AppColors.riskHigh, fontSize: 13, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isHindi ? '💡 आप कीबोर्ड से भी आसानी से लिख सकते हैं।' : '💡 You can easily enter text using the keyboard.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Text(
                    _liveTranscription.isNotEmpty ? _liveTranscription : hint,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _liveTranscription.isNotEmpty ? FontWeight.w700 : FontWeight.w400,
                      color: _liveTranscription.isNotEmpty ? AppColors.textDark : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),

          const SizedBox(height: 18),

          // Actions: Use Text, Try Again, Cancel
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              if (!_isListening) ...[
                IconButton(
                  tooltip: isHindi ? 'पुनः बोलें' : 'Try Again',
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.resourceBlue),
                  onPressed: _startRecording,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    isHindi ? 'टेक्स्ट दर्ज करें' : 'Apply Text',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _liveTranscription.trim().isNotEmpty
                      ? () {
                          widget.onApplyText(_liveTranscription);
                          Navigator.pop(context);
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
