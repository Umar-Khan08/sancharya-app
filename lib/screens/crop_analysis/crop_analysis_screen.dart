import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routing/app_routes.dart';
import '../../models/crop_analysis_input.dart';
import '../../models/crop_model.dart';
import '../../repositories/agriculture_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/voice_input_button.dart';
import '../../services/voice/speech_recognition_service.dart';
import '../../widgets/loading_indicator.dart';
import '../../core/location/app_location_provider.dart';
import '../../services/location/location_service.dart';
import '../../data/resolvers/crop_resolver.dart';
import '../../core/localization/app_language_provider.dart';

/// Single Unified Crop-Analysis Form
/// Farmers enter their crop harvest details once to receive price prediction,
/// spoilage risk, discovered nearby storage, and smart selling advice together.
class CropAnalysisScreen extends StatefulWidget {
  final bool isEmbedded;

  const CropAnalysisScreen({super.key, this.isEmbedded = false});

  @override
  State<CropAnalysisScreen> createState() => _CropAnalysisScreenState();
}

class _CropAnalysisScreenState extends State<CropAnalysisScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Crop> _availableCrops = [];
  Crop? _selectedCrop;
  bool _isManualCropEntry = false;
  final _cropTextController = TextEditingController();
  String? _cropValidationError;
  final _locationController = TextEditingController();
  final _quantityController = TextEditingController(text: '40');
  QuantityUnit _selectedUnit = QuantityUnit.quintal;
  DateTime _harvestDate = DateTime.now();
  CropCondition _selectedCondition = CropCondition.good;

  bool _isLoadingCrops = true;
  bool _isAnalyzing = false;
  bool _isDetectingLocation = false;
  double? _detectedLatitude;
  double? _detectedLongitude;
  String? _detectedDistrict;

  @override
  void initState() {
    super.initState();
    _locationController.addListener(_onLocationInputChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _locationController.removeListener(_onLocationInputChanged);
    _locationController.dispose();
    _quantityController.dispose();
    _cropTextController.dispose();
    super.dispose();
  }

  void _onLocationInputChanged() {
    final text = _locationController.text.trim();
    if (text.isEmpty) {
      if (_detectedLatitude != null || _detectedLongitude != null || _detectedDistrict != null) {
        setState(() {
          _detectedLatitude = null;
          _detectedLongitude = null;
          _detectedDistrict = null;
        });
      }
      return;
    }

    final known = LocationService.lookupKnownCoordinates(text);
    if (known != null) {
      if (_detectedLatitude != known.latitude || _detectedLongitude != known.longitude) {
        setState(() {
          _detectedLatitude = known.latitude;
          _detectedLongitude = known.longitude;
          _detectedDistrict = known.district ?? text.split(',').first.trim();
        });
      }
    } else {
      // If user typed a different city name that doesn't match the current detected district,
      // immediately clear stale coordinates from the previous city so they never overwrite!
      if (_detectedDistrict != null && !text.toLowerCase().contains(_detectedDistrict!.toLowerCase())) {
        setState(() {
          _detectedLatitude = null;
          _detectedLongitude = null;
          _detectedDistrict = null;
        });
      }
    }
  }

  Future<void> _loadInitialData() async {
    final repo = context.read<AgricultureRepository>();
    final authRepo = context.read<AuthRepository>();

    final crops = await repo.getSupportedCrops();
    final user = await authRepo.getCurrentUser();

    if (mounted) {
      setState(() {
        _availableCrops = crops;
        if (crops.isNotEmpty) {
          _selectedCrop = crops.first;
          _cropTextController.text = crops.first.nameEn;
        }
        final locProvider = context.read<AppLocationProvider>();
        if (locProvider.hasUserLocation && locProvider.hasValidCoordinates) {
          _locationController.text = locProvider.formattedLocation;
          _detectedLatitude = locProvider.latitude;
          _detectedLongitude = locProvider.longitude;
          _detectedDistrict = locProvider.district;
        } else if (user != null && user.district.isNotEmpty) {
          _locationController.text = user.district;
          final known = LocationService.lookupKnownCoordinates(user.district);
          if (known != null) {
            _detectedLatitude = known.latitude;
            _detectedLongitude = known.longitude;
            _detectedDistrict = known.district ?? user.district;
          }
        }
        _isLoadingCrops = false;
      });
    }
  }

  Future<void> _handleVoiceCropSelection(bool isHindi) async {
    final speechService = SpeechRecognitionService();
    speechService.setLanguage(isHindi ? VoiceLanguage.hindi : VoiceLanguage.english);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String recognizedWords = '';
        String? sheetError;
        bool isListening = false;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isHindi ? 'फसल का नाम बोलें (जैसे टमाटर, प्याज, आलू)' : 'Speak Crop Name (e.g. Tomato, Onion)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () async {
                      setSheetState(() {
                        recognizedWords = '';
                        sheetError = null;
                        isListening = true;
                      });

                      final ok = await speechService.startListening(
                        onResult: (words, isFinal) {
                          if (sheetCtx.mounted) {
                            setSheetState(() {
                              recognizedWords = words;
                              if (isFinal) isListening = false;
                            });
                          }
                          if (words.isNotEmpty) {
                            final matched = CropResolver.resolve(words, _availableCrops);
                            if (matched != null) {
                              if (mounted) {
                                setState(() {
                                  _selectedCrop = matched;
                                  _cropTextController.text = matched.localizedName(isHindi);
                                  _cropValidationError = null;
                                });
                              }
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isHindi
                                        ? 'फसल चुनी गई: ${matched.localizedName(isHindi)}'
                                        : 'Selected: ${matched.localizedName(isHindi)}',
                                  ),
                                  backgroundColor: AppColors.primaryGreen,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                          }
                        },
                      );

                      if (!ok && sheetCtx.mounted) {
                        setSheetState(() {
                          isListening = false;
                          sheetError = isHindi
                              ? (speechService.errorMessageHi ?? 'माइक्रोफ़ोन सेवा उपलब्ध नहीं है।')
                              : (speechService.errorMessageEn ?? 'Speech service unavailable on this device.');
                        });
                      }
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: isListening ? AppColors.riskHighBg : AppColors.riskLowBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isListening ? AppColors.riskHigh : AppColors.primaryGreen,
                          width: isListening ? 3 : 2,
                        ),
                      ),
                      child: Icon(
                        isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: isListening ? AppColors.riskHigh : AppColors.primaryGreen,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sheetError != null)
                    Text(
                      sheetError!,
                      style: const TextStyle(color: AppColors.riskHigh, fontSize: 13),
                      textAlign: TextAlign.center,
                    )
                  else if (recognizedWords.isNotEmpty)
                    Text(
                      recognizedWords,
                      style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600),
                    )
                  else
                    Text(
                      isListening
                          ? (isHindi ? 'सुन रहा हूँ... बोलिए' : 'Listening... Speak now')
                          : (isHindi ? 'बोलने के लिए माइक दबाएं' : 'Tap microphone to speak'),
                      style: TextStyle(
                        color: isListening ? AppColors.riskHigh : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: isListening ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAutoDetectLocation(bool isHindi) async {
    final currentText = _locationController.text.trim();
    final isCustomText = currentText.isNotEmpty &&
        currentText != 'Nashik, Maharashtra';

    if (isCustomText) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isHindi ? 'स्थान अपडेट करें?' : 'Auto-Detect Device GPS?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            content: Text(
              isHindi
                  ? 'आपने पहले "$currentText" दर्ज किया है। क्या आप इसे बदलकर वर्तमान डिवाइस जीपीएस स्थान करना चाहते हैं?'
                  : 'You previously entered "$currentText". Would you like to auto-detect your location using device GPS?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  isHindi ? 'पहले वाला रखें' : 'Keep Current',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(isHindi ? 'जीपीएस खोजें' : 'Detect GPS'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (shouldProceed != true) return;
    }

    setState(() => _isDetectingLocation = true);

    try {
      final locProvider = context.read<AppLocationProvider>();
      final success = await locProvider.autoDetectLocation(isHindi: isHindi);
      if (!mounted) return;

      if (!success) {
        final err = isHindi
            ? (locProvider.errorMessageHi ?? 'स्थान प्राप्त करने में समस्या हुई')
            : (locProvider.errorMessageEn ?? 'Could not acquire device GPS location');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.riskHigh,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() {
        _locationController.text = locProvider.formattedLocation;
        _detectedLatitude = locProvider.latitude;
        _detectedLongitude = locProvider.longitude;
        _detectedDistrict = locProvider.district ?? locProvider.locality;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHindi
                      ? 'वर्तमान स्थान सेट किया गया: ${locProvider.formattedLocation}'
                      : 'GPS Location detected: ${locProvider.formattedLocation}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHindi
                  ? 'स्थान पता करने में समस्या: $e'
                  : 'Error detecting location: $e',
            ),
            backgroundColor: AppColors.riskHigh,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  Future<void> _pickHarvestDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate.isAfter(now) ? now : _harvestDate,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now, // Prevents invalid future dates
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: AppColors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _harvestDate) {
      setState(() => _harvestDate = picked);
    }
  }

  Future<void> _runUnifiedAnalysis() async {
    if (_isAnalyzing) return;
    final isHindi = AppLocalizations.of(context).isHindi;

    if (_isManualCropEntry) {
      final typed = _cropTextController.text.trim();
      if (typed.isEmpty) {
        setState(() => _cropValidationError = isHindi ? 'कृपया फसल का नाम दर्ज करें।' : 'Please enter a crop name.');
        return;
      }
      final matched = CropResolver.resolve(typed, _availableCrops);
      if (matched == null) {
        setState(() => _cropValidationError = isHindi
            ? 'फसल "$typed" समर्थित नहीं है। कृपया नीचे दिए गए सुझावों में से चुनें।'
            : 'Crop "$typed" is not supported. Please select from the suggestions below.');
        return;
      }
      _selectedCrop = matched;
      _cropValidationError = null;
    }

    if (!_formKey.currentState!.validate() || _selectedCrop == null) return;

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive quantity.')),
      );
      return;
    }

    if (_harvestDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harvest date cannot be in the future.')),
      );
      return;
    }

    final locProvider = context.read<AppLocationProvider>();
    final enteredLocation = _locationController.text.trim();

    if (enteredLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi
              ? 'कृपया अपना जिला दर्ज करें या ऑटो-डिटेक्ट स्थान चुनें।'
              : 'Please enter your farm district or tap Auto-Detect Location.'),
        ),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final repo = context.read<AgricultureRepository>();

      // If user typed a manual location that differs from provider, geocode and update provider
      if (enteredLocation != locProvider.formattedLocation || _detectedLatitude == null) {
        await locProvider.setManualLocation(enteredLocation, isHindi: isHindi);
        if (!mounted) return;
        _detectedLatitude = locProvider.latitude;
        _detectedLongitude = locProvider.longitude;
        _detectedDistrict = locProvider.district;
      }

      final input = CropAnalysisInput(
        crop: _selectedCrop!,
        location: enteredLocation,
        quantity: quantity,
        quantityUnit: _selectedUnit,
        harvestDate: _harvestDate,
        condition: _selectedCondition,
        latitude: _detectedLatitude ?? locProvider.latitude,
        longitude: _detectedLongitude ?? locProvider.longitude,
      );
      final user = await context.read<AuthRepository>().getCurrentUser();
      final result = await repo.analyzeCrop(input, userPhone: user?.phone);

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.cropResults,
        arguments: result,
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isHindi = loc.isHindi;

    final bodyContent = _isLoadingCrops
        ? LoadingIndicator(message: loc.loading)
        : _isAnalyzing
            ? LoadingIndicator(message: loc.analyzingProgressText)
            : SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Header
                      Text(
                        loc.unifiedFormTitle,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.unifiedFormSubtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. CROP TYPE
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  loc.selectCropLabel,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.mic_rounded, color: AppColors.primaryGreen, size: 20),
                                  tooltip: isHindi ? 'फसल का नाम बोलें' : 'Speak crop name',
                                  onPressed: () => _handleVoiceCropSelection(isHindi),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Dual Option Chips: Select from List vs Type Name
                            Row(
                              children: [
                                ChoiceChip(
                                  label: Text(
                                    isHindi ? 'सूची से चुनें' : 'Select from List',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !_isManualCropEntry ? FontWeight.w700 : FontWeight.w500,
                                      color: !_isManualCropEntry ? AppColors.white : AppColors.textDark,
                                    ),
                                  ),
                                  selected: !_isManualCropEntry,
                                  selectedColor: AppColors.primaryGreen,
                                  backgroundColor: AppColors.surfaceMuted,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _isManualCropEntry = false;
                                        _cropValidationError = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text(
                                    isHindi ? 'नाम टाइप करें' : 'Type Crop Name',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _isManualCropEntry ? FontWeight.w700 : FontWeight.w500,
                                      color: _isManualCropEntry ? AppColors.white : AppColors.textDark,
                                    ),
                                  ),
                                  selected: _isManualCropEntry,
                                  selectedColor: AppColors.primaryGreen,
                                  backgroundColor: AppColors.surfaceMuted,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _isManualCropEntry = true;
                                        if (_selectedCrop != null && _cropTextController.text.isEmpty) {
                                          _cropTextController.text = _selectedCrop!.localizedName(isHindi);
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (!_isManualCropEntry)
                              DropdownButtonFormField<Crop>(
                                initialValue: _selectedCrop,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.eco_rounded,
                                    color: AppColors.primaryGreen,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                ),
                                items: _availableCrops.map((c) {
                                  return DropdownMenuItem<Crop>(
                                    value: c,
                                    child: Text(
                                      '${c.localizedName(isHindi)} (${c.category})',
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedCrop = val;
                                      _cropTextController.text = val.localizedName(isHindi);
                                      _cropValidationError = null;
                                    });
                                  }
                                },
                              )
                            else ...[
                              TextFormField(
                                controller: _cropTextController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.eco_rounded,
                                    color: AppColors.primaryGreen,
                                  ),
                                  hintText: isHindi ? 'उदा. टमाटर, प्याज, आलू, गेहूं' : 'e.g. Tomato, Onion, Potato, Wheat',
                                  suffixIcon: _cropTextController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _cropTextController.clear();
                                              _selectedCrop = null;
                                              _cropValidationError = null;
                                            });
                                          },
                                        )
                                      : null,
                                  errorText: _cropValidationError,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                ),
                                onChanged: (val) {
                                  final matched = CropResolver.resolve(val, _availableCrops);
                                  setState(() {
                                    if (matched != null) {
                                      _selectedCrop = matched;
                                      _cropValidationError = null;
                                    } else if (val.trim().isNotEmpty) {
                                      _selectedCrop = null;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: CropResolver.getSuggestions(_cropTextController.text, _availableCrops).map((crop) {
                                  final isCurrent = _selectedCrop?.id == crop.id;
                                  return ActionChip(
                                    avatar: Icon(
                                      Icons.eco_outlined,
                                      size: 14,
                                      color: isCurrent ? AppColors.white : AppColors.primaryGreen,
                                    ),
                                    label: Text(
                                      crop.localizedName(isHindi),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                        color: isCurrent ? AppColors.white : AppColors.textDark,
                                      ),
                                    ),
                                    backgroundColor: isCurrent ? AppColors.primaryGreen : AppColors.surfaceMuted,
                                    onPressed: () {
                                      setState(() {
                                        _selectedCrop = crop;
                                        _cropTextController.text = crop.localizedName(isHindi);
                                        _cropValidationError = null;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. LOCATION
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              controller: _locationController,
                              label: loc.locationLabel,
                              hint: loc.locationHint,
                              prefixIcon: Icons.location_on_rounded,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  VoiceInputButton(
                                    controller: _locationController,
                                    fieldNameEn: 'Farm Location',
                                    fieldNameHi: 'खेत का स्थान / जिला',
                                    spokenHintEn: 'Speak district e.g. Nashik, Kanpur',
                                    spokenHintHi: 'जिले का नाम बोलें जैसे नासिक, कानपुर',
                                    isHindi: isHindi,
                                  ),
                                  if (_isDetectingLocation)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 12.0),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return loc.nameRequiredError;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_detectedLatitude != null && _detectedLongitude != null) ...[
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.gps_fixed_rounded, size: 14, color: AppColors.primaryGreen),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _detectedDistrict != null && _detectedDistrict!.isNotEmpty
                                                ? '$_detectedDistrict (${_detectedLatitude!.toStringAsFixed(3)}, ${_detectedLongitude!.toStringAsFixed(3)})'
                                                : 'GPS: ${_detectedLatitude!.toStringAsFixed(3)}, ${_detectedLongitude!.toStringAsFixed(3)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primaryGreen,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const Spacer(),
                                ],
                                OutlinedButton.icon(
                                  icon: _isDetectingLocation
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.8,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                                          ),
                                        )
                                      : const Icon(Icons.my_location_rounded, size: 15),
                                  label: Text(
                                    _isDetectingLocation
                                        ? (isHindi ? 'स्थान खोज रहे हैं...' : 'Detecting...')
                                        : loc.useCurrentLocation,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryGreen,
                                    side: const BorderSide(color: AppColors.primaryGreen, width: 1.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: const Size(0, 34),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _isDetectingLocation
                                      ? null
                                      : () => _handleAutoDetectLocation(isHindi),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. QUANTITY & UNIT
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  loc.quantityLabel,
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                // Unit Switcher (Quintals / Kilograms)
                                Row(
                                  children: [
                                    _buildUnitChoice(
                                      'Qtl (क्विंटल)',
                                      QuantityUnit.quintal,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildUnitChoice(
                                      'Kg (किलो)',
                                      QuantityUnit.kilogram,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _quantityController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: loc.quantityHint,
                                prefixIcon: const Icon(
                                  Icons.scale_rounded,
                                  color: AppColors.primaryGreen,
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4.0),
                                      child: Text(
                                        _selectedUnit == QuantityUnit.quintal ? 'Qtl' : 'Kg',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    VoiceInputButton(
                                      controller: _quantityController,
                                      fieldNameEn: 'Harvest Quantity',
                                      fieldNameHi: 'फसल की मात्रा',
                                      spokenHintEn: 'Speak quantity e.g. 50 or forty',
                                      spokenHintHi: 'मात्रा बोलें जैसे पचास या 40',
                                      isNumericField: true,
                                      isHindi: isHindi,
                                    ),
                                  ],
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                final num = double.tryParse(val);
                                if (num == null || num <= 0) return 'Enter a positive quantity';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. HARVEST DATE
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        onTap: _pickHarvestDate,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.harvestDateLabel,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppColors.primaryGreen,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${_harvestDate.day.toString().padLeft(2, '0')}/${_harvestDate.month.toString().padLeft(2, '0')}/${_harvestDate.year}',
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  loc.selectHarvestDate,
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. CROP CONDITION (Good, Average, Poor)
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.cropConditionLabel,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildConditionOption(
                              title: loc.conditionGood,
                              condition: CropCondition.good,
                              icon: Icons.check_circle_outline_rounded,
                              activeColor: AppColors.primaryGreen,
                            ),
                            const SizedBox(height: 8),
                            _buildConditionOption(
                              title: loc.conditionAverage,
                              condition: CropCondition.average,
                              icon: Icons.info_outline_rounded,
                              activeColor: AppColors.riskMedium,
                            ),
                            const SizedBox(height: 8),
                            _buildConditionOption(
                              title: loc.conditionPoor,
                              condition: CropCondition.poor,
                              icon: Icons.warning_amber_rounded,
                              activeColor: AppColors.riskHigh,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Unified Analysis
                      AppButton(
                        label: loc.generateDecisionReportButton,
                        variant: AppButtonVariant.goldenYellow,
                        icon: Icons.insights_rounded,
                        onPressed: _runUnifiedAnalysis,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(loc.unifiedFormTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate_rounded),
            tooltip: loc.languageSetting,
            onPressed: () {
              final langProvider = context.read<AppLanguageProvider>();
              langProvider.toggleLanguage();
            },
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildUnitChoice(String label, QuantityUnit unit) {
    final isSelected = _selectedUnit == unit;
    return InkWell(
      onTap: () => setState(() => _selectedUnit = unit),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.textDark,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildConditionOption({
    required String title,
    required CropCondition condition,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedCondition == condition;
    return InkWell(
      onTap: () => setState(() => _selectedCondition = condition),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderLight,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.textDark : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? activeColor : AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
