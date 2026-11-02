import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/location/app_location_provider.dart';
import '../../models/ngo_record.dart';
import '../../services/phone/phone_call_service.dart';
import '../../services/resources/ngo_service.dart';
import '../../services/voice/tts_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/loading_indicator.dart';

/// Screen listing verified NGOs accepting produce donations
/// Connected directly to the 827-record ngos.json dataset.
class NgoDonationScreen extends StatefulWidget {
  final String? initialCrop;
  final String? initialLocation;

  const NgoDonationScreen({
    super.key,
    this.initialCrop,
    this.initialLocation,
  });

  @override
  State<NgoDonationScreen> createState() => _NgoDonationScreenState();
}

class _NgoDonationScreenState extends State<NgoDonationScreen> {
  final NgoService _ngoService = NgoService();
  late final TtsService _ttsService;
  final TextEditingController _locationController = TextEditingController();

  List<NgoWithDistance> _ngos = [];
  bool _isLoading = true;
  String _selectedCrop = 'all';
  bool _pickupOnly = false;
  String _demandLevelFilter = 'all';

  // Recognized produce categories in ngos.json
  static const List<String> _produceOptions = [
    'all',
    'potato',
    'tomato',
    'onion',
    'wheat',
    'rice',
    'banana',
    'fruits',
  ];

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _ttsService.addListener(() {
      if (mounted) setState(() {});
    });

    if (widget.initialCrop != null && widget.initialCrop!.isNotEmpty) {
      _selectedCrop = widget.initialCrop!.toLowerCase().trim();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppLocationProvider? locProvider;
      try {
        locProvider = context.read<AppLocationProvider>();
      } catch (_) {
        locProvider = null;
      }
      if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
        _locationController.text = widget.initialLocation!;
      } else if (locProvider != null && locProvider.hasUserLocation) {
        _locationController.text = locProvider.formattedLocation;
      }
      _fetchNgos();
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _fetchNgos() async {
    setState(() => _isLoading = true);
    AppLocationProvider? locProvider;
    try {
      locProvider = context.read<AppLocationProvider>();
    } catch (_) {
      locProvider = null;
    }

    try {
      final result = await _ngoService.searchNgos(
        locationQuery: _locationController.text.trim(),
        cropQuery: _selectedCrop == 'all' ? null : _selectedCrop,
        pickupOnly: _pickupOnly ? true : null,
        demandLevelFilter: _demandLevelFilter == 'all' ? null : _demandLevelFilter,
        userLatitude: locProvider?.latitude,
        userLongitude: locProvider?.longitude,
      );

      if (mounted) {
        setState(() {
          _ngos = result.ngos;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ngos = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onCropSelected(String crop) {
    if (_selectedCrop == crop) return;
    setState(() => _selectedCrop = crop);
    _fetchNgos();
  }

  void _togglePickupFilter() {
    setState(() => _pickupOnly = !_pickupOnly);
    _fetchNgos();
  }

  void _clearFilters() {
    setState(() {
      _selectedCrop = 'all';
      _pickupOnly = false;
      _demandLevelFilter = 'all';
      _locationController.clear();
    });
    _fetchNgos();
  }

  String _cropLabel(String crop, bool isHindi) {
    switch (crop) {
      case 'potato':
        return isHindi ? 'आलू' : 'Potato';
      case 'tomato':
        return isHindi ? 'टमाटर' : 'Tomato';
      case 'onion':
        return isHindi ? 'प्याज' : 'Onion';
      case 'wheat':
        return isHindi ? 'गेहूं' : 'Wheat';
      case 'rice':
        return isHindi ? 'चावल' : 'Rice';
      case 'banana':
        return isHindi ? 'केला' : 'Banana';
      case 'fruits':
        return isHindi ? 'फल' : 'Fruits';
      case 'all':
      default:
        return isHindi ? 'सभी फसलें' : 'All Produce';
    }
  }

  void _narrateNgo(NgoRecord ngo, bool isHindi) {
    if (_ttsService.isPlaying) {
      _ttsService.stop();
    } else {
      final contactText = ngo.hasValidContact
          ? (isHindi ? 'संपर्क: ${ngo.contact.trim()}' : 'Contact phone is ${ngo.contact.trim()}')
          : (isHindi ? 'मोबाइल नंबर उपलब्ध नहीं है' : 'No mobile number available');
      final text = isHindi
          ? '${ngo.nameHi}। स्थान: ${ngo.districtHi}, ${ngo.stateHi}। स्वीकार्य फसलें: ${ngo.acceptedProduce.join(", ")}। मांग स्तर: ${ngo.localizedDemandLevel(true)}। $contactText।'
          : '${ngo.nameEn} located in ${ngo.district}, ${ngo.state}. Accepted produce includes ${ngo.acceptedProduce.join(", ")}. Demand level is ${ngo.demandLevel}. $contactText.';
      _ttsService.speak(text: text, isHindi: isHindi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isHindi = loc.isHindi;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(loc.ngoTitle),
        actions: [
          IconButton(
            icon: Icon(
              _ttsService.isPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
              color: _ttsService.isPlaying ? AppColors.primaryGreen : AppColors.textDark,
            ),
            tooltip: _ttsService.isPlaying ? loc.stopVoice : loc.listenReportVoice,
            onPressed: () {
              if (_ngos.isNotEmpty) {
                _narrateNgo(_ngos.first.record, isHindi);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Filter Bar
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Responsive, properly aligned NGO Search Bar
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight, width: 1.2),
                    ),
                    child: TextField(
                      controller: _locationController,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) {
                        setState(() {});
                        _fetchNgos();
                      },
                      onSubmitted: (_) => _fetchNgos(),
                      decoration: InputDecoration(
                        hintText: loc.ngoSearchHint,
                        hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                        suffixIcon: _locationController.text.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                tooltip: isHindi ? 'साफ़ करें' : 'Clear',
                                onPressed: () {
                                  _locationController.clear();
                                  setState(() {});
                                  _fetchNgos();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Crop Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final crop in _produceOptions)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(_cropLabel(crop, isHindi)),
                              selected: _selectedCrop == crop,
                              selectedColor: AppColors.primaryGreen,
                              labelStyle: TextStyle(
                                color: _selectedCrop == crop ? AppColors.white : AppColors.textDark,
                                fontSize: 12,
                                fontWeight: _selectedCrop == crop ? FontWeight.w700 : FontWeight.w500,
                              ),
                              backgroundColor: AppColors.surfaceMuted,
                              onSelected: (_) => _onCropSelected(crop),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Secondary Filter: Pickup Availability Toggle
                  Row(
                    children: [
                      FilterChip(
                        avatar: Icon(
                          _pickupOnly ? Icons.check_circle_rounded : Icons.local_shipping_outlined,
                          size: 16,
                          color: _pickupOnly ? AppColors.white : AppColors.deepGreen,
                        ),
                        label: Text(loc.ngoPickupAvailableOnly),
                        selected: _pickupOnly,
                        selectedColor: AppColors.primaryGreen,
                        labelStyle: TextStyle(
                          color: _pickupOnly ? AppColors.white : AppColors.textDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: AppColors.surfaceMuted,
                        onSelected: (_) => _togglePickupFilter(),
                      ),
                      const Spacer(),
                      Text(
                        '${_ngos.length} ${isHindi ? "संस्थाएं उपलब्ध" : "NGOs Found"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: LoadingIndicator(message: 'Loading verified NGOs...'))
                  : _ngos.isEmpty
                      ? _buildEmptyState(loc, isHindi)
                      : ListView.separated(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: _ngos.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _ngos[index];
                            return _buildNgoCard(item, loc, isHindi);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations loc, bool isHindi) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volunteer_activism_outlined,
              size: 52,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.ngoNoResultsTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            loc.ngoNoResultsSubtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          AppButton(
            label: isHindi ? 'सभी फ़िल्टर साफ़ करें' : 'Clear All Filters',
            variant: AppButtonVariant.primaryGreen,
            icon: Icons.refresh_rounded,
            onPressed: _clearFilters,
          ),
          const SizedBox(height: 24),

          // Informative Help Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentYellowLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentYellowDark.withAlpha(60)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.deepGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.ngoAlternativeAdvice,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.deepGreen,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNgoCard(NgoWithDistance item, AppLocalizations loc, bool isHindi) {
    final ngo = item.record;
    final demandColor = _getDemandColor(ngo.demandLevel);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name and Audio Speaker
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight.withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ngo.localizedName(isHindi),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ngo.localizedDistrict(isHindi)}, ${ngo.localizedState(isHindi)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryGreen, size: 22),
                tooltip: isHindi ? 'सुनें' : 'Listen',
                onPressed: () => _narrateNgo(ngo, isHindi),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Address
          if (ngo.address.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ngo.address,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                  ),
                ),
                if (item.distanceKm != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${item.distanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Badges: Demand Level & Pickup
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Demand Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: demandColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: demandColor.withAlpha(90)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 14, color: demandColor),
                    const SizedBox(width: 4),
                    Text(
                      '${loc.ngoDemandLevel}: ${ngo.localizedDemandLevel(isHindi)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: demandColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Pickup Availability Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ngo.pickupAvailable ? AppColors.riskLowBg : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: ngo.pickupAvailable ? AppColors.riskLow.withAlpha(100) : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ngo.pickupAvailable ? Icons.local_shipping_rounded : Icons.info_outline_rounded,
                      size: 14,
                      color: ngo.pickupAvailable ? AppColors.riskLow : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ngo.pickupAvailable
                          ? (isHindi ? 'पिकअप उपलब्ध' : 'Pickup Available')
                          : (isHindi ? 'स्वयं पहुंचाएं' : 'Self Drop-off'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ngo.pickupAvailable ? AppColors.riskLow : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Verified Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.resourceBlueLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 13, color: AppColors.resourceBlue),
                    const SizedBox(width: 4),
                    Text(
                      loc.ngoVerified,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.resourceBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Accepted Produce List
          Text(
            '${loc.ngoAcceptedProduce}:',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: ngo.acceptedProduce.map((prod) {
              final isMatching = _selectedCrop != 'all' && ngo.acceptsCrop(_selectedCrop);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isMatching ? AppColors.primaryGreenLight.withAlpha(45) : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isMatching ? AppColors.primaryGreen : AppColors.borderLight,
                    width: isMatching ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  _cropLabel(prod, isHindi),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isMatching ? FontWeight.w800 : FontWeight.w600,
                    color: isMatching ? AppColors.deepGreen : AppColors.textDark,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Impact Note
          if (ngo.impactNote != null && ngo.impactNote!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.favorite_rounded, color: AppColors.riskHigh, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ngo.localizedImpactNote(isHindi) ?? '',
                      style: const TextStyle(fontSize: 11, color: AppColors.textDark, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Operating hours & Contact details
          Row(
            children: [
              if (ngo.operatingHours != null) ...[
                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  ngo.operatingHours!,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
              const Spacer(),
              if (ngo.lastVerifiedDate.isNotEmpty)
                Text(
                  '${loc.ngoLastVerified}: ${ngo.lastVerifiedDate}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Call Button or Missing Number Notice
          SizedBox(
            width: double.infinity,
            child: ngo.hasValidContact
                ? ElevatedButton.icon(
                    icon: const Icon(Icons.phone_rounded, size: 16),
                    label: Text(
                      '${loc.ngoCallNow} (${ngo.contact.trim()})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      PhoneCallService.promptAndLaunchCall(
                        context: context,
                        facilityName: ngo.localizedName(isHindi),
                        rawPhoneNumber: ngo.contact.trim(),
                        isHindi: isHindi,
                      );
                    },
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.phone_disabled_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.ngoNumberNotAvailable,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getDemandColor(String demandLevel) {
    switch (demandLevel.toLowerCase()) {
      case 'critical':
      case 'high':
        return AppColors.riskHigh;
      case 'moderate':
        return AppColors.riskMedium;
      case 'low':
      default:
        return AppColors.primaryGreen;
    }
  }
}
