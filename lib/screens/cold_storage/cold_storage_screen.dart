import '../../services/phone/phone_call_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/location/app_location_provider.dart';
import '../../data/interfaces/i_resource_service.dart';
import '../../models/agri_resource.dart';
import '../../services/resources/demo_resource_service.dart';
import '../../services/voice/tts_service.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/loading_indicator.dart';

/// Screen listing nearby cold storages, warehouses, and APMC market yards
/// Designed with rigorous data provenance: distinguishes mapped vs verified,
/// handles missing facilities gracefully, and avoids fabricated capacities or contacts.
class ColdStorageScreen extends StatefulWidget {
  final bool isEmbedded;

  const ColdStorageScreen({super.key, this.isEmbedded = false});

  @override
  State<ColdStorageScreen> createState() => _ColdStorageScreenState();
}

class _ColdStorageScreenState extends State<ColdStorageScreen> {
  final IResourceService _resourceService = DemoResourceService();
  late final TtsService _ttsService;

  AgriResourceType? _selectedFilter = AgriResourceType.coldStorage;
  List<AgriResource> _resources = [];
  bool _isLoading = true;
  double _currentRadiusKm = 50.0;
  String? _lastQueriedLocation;

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _ttsService.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchResourcesForActiveLocation();
    });
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _fetchResourcesForActiveLocation({double? overrideRadius}) async {
    final locProvider = context.read<AppLocationProvider>();
    final radius = overrideRadius ?? _currentRadiusKm;

    setState(() {
      _isLoading = true;
      _currentRadiusKm = radius;
      _lastQueriedLocation = locProvider.formattedLocation;
    });

    try {
      final list = await _resourceService.getNearbyResources(
        filterType: _selectedFilter,
        maxDistanceKm: radius,
        latitude: locProvider.latitude,
        longitude: locProvider.longitude,
        district: locProvider.district,
      );

      if (mounted) {
        setState(() {
          _resources = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resources = [];
          _isLoading = false;
        });
      }
    }
  }

  void _onFilterChanged(AgriResourceType? filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    _fetchResourcesForActiveLocation();
  }

  void _speakText(String text, bool isHindi) {
    if (_ttsService.isPlaying) {
      _ttsService.stop();
    } else {
      _ttsService.speak(text: text, isHindi: isHindi).then((_) {
        if (mounted && _ttsService.errorMessage != null && !_ttsService.isPlaying) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_ttsService.errorMessage!),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isHindi = loc.isHindi;
    final locProvider = context.watch<AppLocationProvider>();

    // If location changed in provider since last query, refresh
    if (_lastQueriedLocation != null &&
        _lastQueriedLocation != locProvider.formattedLocation &&
        !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchResourcesForActiveLocation();
      });
    }

    final content = Column(
      children: [
        // 1. ACTIVE SEARCH LOCATION & RADIUS HEADER
        _buildLocationHeader(locProvider, isHindi),

        // 2. FILTER CHIPS ROW
        SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              _buildFilterChip(
                label: loc.filterColdStorage,
                isSelected: _selectedFilter == AgriResourceType.coldStorage,
                onTap: () => _onFilterChanged(AgriResourceType.coldStorage),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: loc.filterMandi,
                isSelected: _selectedFilter == AgriResourceType.mandi,
                onTap: () => _onFilterChanged(AgriResourceType.mandi),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: loc.filterWarehouse,
                isSelected: _selectedFilter == AgriResourceType.warehouse,
                onTap: () => _onFilterChanged(AgriResourceType.warehouse),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: loc.filterAll,
                isSelected: _selectedFilter == null,
                onTap: () => _onFilterChanged(null),
              ),
            ],
          ),
        ),

        // 3. FACILITY LIST OR EMPTY STATE
        Expanded(
          child: _isLoading
              ? LoadingIndicator(
                  message: isHindi
                      ? 'निकटतम कोल्ड स्टोरेज एवं मंडियों की खोज जारी है...'
                      : 'Searching nearby mapped facilities (${_currentRadiusKm.toInt()} km radius)...',
                )
              : _resources.isEmpty
                  ? _buildNotFoundView(locProvider, isHindi)
                  : _buildFacilityList(locProvider, isHindi),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(loc.coldStorageTitle),
        actions: [
          IconButton(
            icon: Icon(
              _ttsService.isPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
              color: _ttsService.isPlaying ? AppColors.primaryGreen : null,
            ),
            tooltip: _ttsService.isPlaying ? loc.stopVoice : loc.listenReportVoice,
            onPressed: () {
              if (_resources.isNotEmpty) {
                final first = _resources.first;
                final speech = isHindi
                    ? 'निकटतम कोल्ड स्टोरेज: ${first.nameHi}, दूरी ${first.distanceKm} किलोमीटर। जाने से पहले परिचालन समय और स्थान की पुष्टि अवश्य करें।'
                    : 'Nearest cold storage: ${first.nameEn}, distance ${first.distanceKm} km. Please verify space and charges before visiting.';
                _speakText(speech, isHindi);
              } else {
                final speech = isHindi
                    ? 'खोजे गए ${_currentRadiusKm.toInt()} किलोमीटर क्षेत्र में कोई सूचीबद्ध कोल्ड स्टोरेज नहीं मिला।'
                    : 'No mapped cold-storage found within ${_currentRadiusKm.toInt()} kilometers.';
                _speakText(speech, isHindi);
              }
            },
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildLocationHeader(AppLocationProvider locProvider, bool isHindi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Icon(
            locProvider.isAutoDetected ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
            size: 18,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isHindi ? 'खोज क्षेत्र: ' : 'Searching near: ',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_currentRadiusKm.toInt()} km',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.resourceBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  locProvider.formattedLocation,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
            tooltip: isHindi ? 'पुनः खोजें' : 'Refresh Search',
            onPressed: () => _fetchResourcesForActiveLocation(),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityList(AppLocationProvider locProvider, bool isHindi) {
    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _resources.length,
      itemBuilder: (context, index) {
        final res = _resources[index];
        final isNearestColdStorage = index == 0 && res.type == AgriResourceType.coldStorage;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Highlight if nearest
                if (isNearestColdStorage) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.resourceBlueLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.resourceBlue.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: AppColors.resourceBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isHindi
                                ? 'आपके नज़दीक सूचीबद्ध कोल्ड स्टोरेज'
                                : 'Nearest Mapped Cold Storage',
                            style: const TextStyle(
                              color: AppColors.resourceBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _ttsService.isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                            size: 18,
                            color: AppColors.resourceBlue,
                          ),
                          onPressed: () {
                            final speech = isHindi
                                ? 'निकटतम कोल्ड स्टोरेज: ${res.nameHi}, दूरी ${res.distanceKm} किलोमीटर। जाने से पहले उपलब्धता और शुल्क की पुष्टि करें।'
                                : 'Nearest cold storage: ${res.nameEn}, distance ${res.distanceKm} km. Please verify available space and rates before visiting.';
                            _speakText(speech, isHindi);
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // Main Facility Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: res.type == AgriResourceType.coldStorage
                            ? AppColors.resourceBlueLight
                            : res.type == AgriResourceType.mandi
                                ? AppColors.primaryGreenLight.withAlpha(40)
                                : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        res.type == AgriResourceType.coldStorage
                            ? Icons.ac_unit_rounded
                            : res.type == AgriResourceType.mandi
                                ? Icons.storefront_rounded
                                : Icons.warehouse_rounded,
                        color: res.type == AgriResourceType.coldStorage
                            ? AppColors.resourceBlue
                            : res.type == AgriResourceType.mandi
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            res.localizedName(isHindi),
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            res.localizedDistrict(isHindi),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.resourceBlueLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 13,
                            color: AppColors.resourceBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${res.distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Data Provenance Notice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        res.isGovernmentAccredited ? Icons.verified_rounded : Icons.info_outline_rounded,
                        size: 14,
                        color: res.isGovernmentAccredited ? AppColors.primaryGreen : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          res.verificationNotice(isHindi),
                          style: TextStyle(
                            color: res.isGovernmentAccredited ? AppColors.deepGreen : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Capacity / Availability Status (Honest: Never invent fake numbers)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHindi ? 'भंडारण उपलब्धता' : 'Storage Availability',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHindi ? 'उपलब्धता असत्यापित — संपर्क करें' : 'Availability not verified',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (res.type == AgriResourceType.mandi) ...[
                      AppBadge.demoBanner(
                        text: isHindi ? 'मंडी यार्ड' : 'APMC Yard',
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // MANDATORY OPERATING NOTICE WARNING
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.riskMediumBg.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.riskMedium.withAlpha(60)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.riskMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHindi
                              ? 'जाने से पहले परिचालन समय, शुल्क और उपलब्ध स्थान की पुष्टि के लिए सुविधा से संपर्क करें।'
                              : 'Contact the facility to confirm operating hours, charges and available storage space before visiting.',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ACTIONS ROW: Phone action ONLY if phone is verified
                Row(
                  children: [
                    if (res.hasValidPhone) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.call_rounded, size: 16),
                          label: Text(
                            res.contactPhone,
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.resourceBlue,
                            side: const BorderSide(color: AppColors.resourceBlue, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            PhoneCallService.promptAndLaunchCall(
                              context: context,
                              facilityName: res.localizedName(isHindi),
                              rawPhoneNumber: res.contactPhone,
                              isHindi: isHindi,
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_disabled_rounded, size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                isHindi ? 'फोन नंबर उपलब्ध नहीं है' : 'Phone number not available',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (res.latitude != null && res.longitude != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.resourceBlueLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.directions_rounded, color: AppColors.resourceBlue, size: 20),
                        tooltip: isHindi ? 'निर्देशांक देखें' : 'View Coordinates',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Coordinates: ${res.latitude!.toStringAsFixed(4)}, ${res.longitude!.toStringAsFixed(4)}',
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotFoundView(AppLocationProvider locProvider, bool isHindi) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.riskMediumBg.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    size: 36,
                    color: AppColors.riskMedium,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isHindi
                      ? 'खोजे गए क्षेत्र में कोई सूचीबद्ध कोल्ड स्टोरेज नहीं मिला'
                      : 'No Mapped Cold-Storage Found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isHindi
                      ? 'हमने ${_currentRadiusKm.toInt()} किमी के दायरे में खोज की। इसका अर्थ यह नहीं है कि यहाँ कोई कोल्ड स्टोरेज उपलब्ध नहीं है। ग्रामीण क्षेत्रों में कई कोल्ड स्टोरेज अभी ओपनस्ट्रीटमैप पर दर्ज नहीं हैं।'
                      : 'We couldn’t find a mapped cold-storage facility within ${_currentRadiusKm.toInt()} km of ${locProvider.formattedLocation}. This does not necessarily mean none are available; many rural facilities are not yet digitized on open maps.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Expand Search Button
                if (_currentRadiusKm < 100.0) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                      label: Text(
                        isHindi ? 'दायरा बढ़ाकर 100 किमी तक खोजें' : 'Expand Search to 100 km Radius',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _fetchResourcesForActiveLocation(overrideRadius: 100.0),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Helpful Guidance
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tips_and_updates_outlined, size: 16, color: AppColors.deepGreen),
                          const SizedBox(width: 6),
                          Text(
                            isHindi ? 'सुझाव एवं वैकल्पिक कदम:' : 'Recommended Farmer Actions:',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isHindi
                            ? '''• अपनी स्थानीय कृषि उपज मंडी समिति (APMC) के कार्यालय से पंजीकृत शीतगृह सूची मांगें।\n• जिला बागवानी अधिकारी (DHO) कार्यालय से संपर्क करें।\n• यदि तापमान अधिक है, तो फसल को हवादार छायादार स्थान पर सुरक्षित रखें।'''
                            : '''• Inquire at your local APMC Mandi Secretary office for registered cold-storage operators.\n• Contact your District Horticulture Officer (DHO) for government accredited facilities.\n• Keep produce in a shaded, well-ventilated farm shed to minimize heat build-up.''',
                        style: const TextStyle(fontSize: 11, color: AppColors.textDark, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.resourceBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.white : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.resourceBlue : AppColors.borderLight,
        ),
      ),
    );
  }
}
