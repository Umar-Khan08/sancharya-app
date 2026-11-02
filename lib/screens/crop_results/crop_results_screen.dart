import '../../services/phone/phone_call_service.dart';
import '../../core/routing/app_routes.dart';
import '../../models/weather_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_language_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/agri_resource.dart';
import '../../models/crop_analysis_input.dart';
import '../../models/crop_analysis_result.dart';
import '../../services/voice/tts_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/risk_level_badge.dart';
import '../../widgets/section_header.dart';

/// One Combined Crop Results Screen
/// Presents Crop Price Prediction, Spoilage Risk Assessment, Discovered Nearby Resources,
/// Smart Selling Advice, and Bilingual Voice TTS together on a single screen.
class CropResultsScreen extends StatefulWidget {
  final CombinedCropAnalysisResult result;

  const CropResultsScreen({super.key, required this.result});

  @override
  State<CropResultsScreen> createState() => _CropResultsScreenState();
}

class _CropResultsScreenState extends State<CropResultsScreen> {
  late final TtsService _ttsService;

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _ttsService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  void _toggleVoiceNarration(bool isHindi) {
    if (_ttsService.isPlaying) {
      _ttsService.stop();
    } else {
      final speechText = isHindi
          ? widget.result.speechSummaryHi
          : widget.result.speechSummaryEn;
      _ttsService.speak(text: speechText, isHindi: isHindi).then((_) {
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
    final result = widget.result;
    final spoilage = result.spoilageRisk;
    final benchmark = result.marketBenchmark;
    final rec = result.recommendation;

    Color recHeaderBg;
    Color recTextColor;
    IconData recIcon;

    switch (rec.action) {
      case SellingAction.sellNow:
        recHeaderBg = AppColors.riskHighBg;
        recTextColor = AppColors.riskHigh;
        recIcon = Icons.bolt_rounded;
        break;
      case SellingAction.storeColdStorage:
        recHeaderBg = AppColors.resourceBlueLight;
        recTextColor = AppColors.resourceBlue;
        recIcon = Icons.ac_unit_rounded;
        break;
      case SellingAction.transportSoon:
        recHeaderBg = AppColors.accentYellowLight;
        recTextColor = AppColors.deepGreen;
        recIcon = Icons.local_shipping_rounded;
        break;
      case SellingAction.holdNormal:
        recHeaderBg = AppColors.riskLowBg;
        recTextColor = AppColors.primaryGreen;
        recIcon = Icons.shield_rounded;
        break;
    }

    final quantity = result.input.quantity;
    final isKg = result.input.quantityUnit == QuantityUnit.kilogram;
    final unitLabel = isKg ? (isHindi ? 'किग्रा' : 'kg') : loc.quintalUnit;
    final unitPrice = isKg ? benchmark.pricePerKg : benchmark.currentAvgPricePerQuintal;
    final grossValue = result.grossCropValue;
    final calcBreakdown = '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} $unitLabel × ₹ ${unitPrice.toStringAsFixed(unitPrice < 100 ? 1 : 0)} / $unitLabel';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(loc.combinedResultsTitle),
        actions: [
          // In-place language switch button (Hindi/English)
          IconButton(
            icon: const Icon(Icons.translate_rounded),
            tooltip: isHindi ? 'Switch to English' : 'हिंदी में बदलें',
            onPressed: () {
              context.read<AppLanguageProvider>().toggleLanguage();
            },
          ),
          // Voice Assistant Speaker Button
          IconButton(
            icon: Icon(
              _ttsService.isPlaying
                  ? Icons.volume_up_rounded
                  : Icons.volume_mute_rounded,
              color: _ttsService.isPlaying
                  ? AppColors.primaryGreen
                  : AppColors.textDark,
              size: 26,
            ),
            tooltip: _ttsService.isPlaying ? loc.stopVoice : loc.listenReportVoice,
            onPressed: () => _toggleVoiceNarration(isHindi),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report ready for export/sharing.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mandatory Data Source Notice Banner
              if (benchmark.hasLiveRecord)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: benchmark.isLiveMandiData
                        ? AppColors.riskLowBg
                        : (benchmark.isDatabaseRecord
                            ? AppColors.surfaceMuted
                            : AppColors.accentYellowLight),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: benchmark.isLiveMandiData
                          ? AppColors.riskLow.withAlpha(100)
                          : (benchmark.isDatabaseRecord
                              ? AppColors.primaryGreen.withAlpha(80)
                              : AppColors.deepGreen.withAlpha(120)),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        benchmark.isLiveMandiData
                            ? Icons.verified_rounded
                            : (benchmark.isDatabaseRecord
                                ? Icons.storage_rounded
                                : Icons.history_rounded),
                        color: benchmark.isLiveMandiData
                            ? AppColors.riskLow
                            : (benchmark.isDatabaseRecord
                                ? AppColors.primaryGreen
                                : AppColors.deepGreen),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benchmark.isDatabaseRecord
                              ? (isHindi
                                  ? 'सत्यापित डेटाबेस मंडी अवलोकन (${benchmark.district ?? "data.gov.in"}${benchmark.arrivalDate != null ? " • ${benchmark.arrivalDate!}" : ""})'
                                  : 'Verified Database Market Observation (${benchmark.district ?? "data.gov.in"}${benchmark.arrivalDate != null ? " • ${benchmark.arrivalDate!}" : ""})')
                              : (benchmark.isDatasetRecord
                                  ? (isHindi
                                      ? 'सत्यापित स्थानीय मंडी डेटासेट रिकॉर्ड (${benchmark.district ?? "स्थानीय डेटासेट"}${benchmark.lastVerifiedDate != null ? " • ${benchmark.lastVerifiedDate!}" : ""})'
                                      : 'Verified Local Mandi Dataset Record (${benchmark.district ?? "Local Dataset"}${benchmark.lastVerifiedDate != null ? " • ${benchmark.lastVerifiedDate!}" : ""})')
                                  : (benchmark.isHistorical
                                      ? (isHindi
                                          ? 'ऐतिहासिक मंडी रिकॉर्ड (${benchmark.district ?? "CEDA"}${benchmark.arrivalDate != null ? " • ${benchmark.arrivalDate!}" : ""})'
                                          : 'Historical Mandi Record (${benchmark.district ?? "CEDA"}${benchmark.arrivalDate != null ? " • ${benchmark.arrivalDate!}" : ""})')
                                      : (isHindi
                                          ? 'लाइव सरकारी एगमार्कनेट मंडी भाव (${benchmark.district ?? "सत्यापित"})'
                                          : 'Verified District Live Mandi Price (${benchmark.district ?? "data.gov.in"})'))),
                          style: TextStyle(
                            color: benchmark.isLiveMandiData
                                ? AppColors.riskLow
                                : (benchmark.isDatabaseRecord
                                    ? AppColors.textDark
                                    : AppColors.deepGreen),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (benchmark.isNetworkError)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.riskHighBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.riskHigh.withAlpha(120), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.riskHigh, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHindi
                              ? 'डेटा प्राप्त करने में असमर्थ। कृपया पुनः प्रयास करें।'
                              : 'Unable to fetch data. Please try again.',
                          style: const TextStyle(
                            color: AppColors.riskHigh,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isHindi ? 'डेटा उपलब्ध नहीं है' : 'Data Not Available',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // Voice Assistant Prominent Action Bar
              AppCard(
                backgroundColor: _ttsService.isPlaying
                    ? AppColors.primaryGreenLight.withAlpha(25)
                    : AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: Border.all(
                  color: _ttsService.isPlaying
                      ? AppColors.primaryGreen
                      : AppColors.borderLight,
                  width: _ttsService.isPlaying ? 1.5 : 1.0,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _ttsService.isPlaying
                            ? AppColors.primaryGreen
                            : AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _ttsService.isPlaying
                            ? Icons.record_voice_over_rounded
                            : Icons.hearing_rounded,
                        color: _ttsService.isPlaying
                            ? AppColors.white
                            : AppColors.primaryGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _ttsService.isPlaying ? loc.voiceSpeaking : loc.listenReportVoice,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 13,
                          fontWeight: _ttsService.isPlaying ? FontWeight.w800 : FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: Icon(
                        _ttsService.isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _ttsService.isPlaying ? loc.stopVoice : (isHindi ? 'सुनें' : 'Listen'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ttsService.isPlaying
                            ? AppColors.riskHigh
                            : AppColors.accentYellow,
                        foregroundColor: _ttsService.isPlaying
                            ? AppColors.white
                            : AppColors.deepGreen,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => _toggleVoiceNarration(isHindi),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Crop Summary Header Bar
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withAlpha(35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.input.crop.localizedName(isHindi),
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${result.input.quantity.toStringAsFixed(0)} ${result.input.quantityUnit == QuantityUnit.kilogram ? "Kg" : loc.quintalUnit} • ${result.input.location}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RiskLevelBadge(riskLevel: spoilage.riskLevel),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // A. SMART RECOMMENDATION (Most important result on top)
              AppCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(20),
                backgroundColor: AppColors.white,
                border: Border.all(color: recTextColor.withAlpha(100), width: 1.8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: recHeaderBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(recIcon, color: recTextColor, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.smartRecommendationSection.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rec.getHeadline(isHindi),
                                style: TextStyle(
                                  color: recTextColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      rec.getRationale(isHindi),
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // B. CROP PRICE & RULE-BASED PREDICTION BENCHMARK
              SectionHeader(
                title: isHindi ? 'मंडी भाव एवं अनुमानित ट्रेंड' : 'Mandi Rates & Trend Estimate',
                subtitle: isHindi
                    ? 'Agmarknet सरकारी डेटा एवं सांकेतिक मौसमी प्रक्षेपण'
                    : 'Official Agmarknet Market Records & Seasonal Trend Estimate',
                icon: Icons.currency_rupee_rounded,
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: benchmark.hasLiveRecord
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.currentMarketPrice,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹ ${benchmark.currentAvgPricePerQuintal.toStringAsFixed(0)} ${loc.pricePerQuintalUnit}',
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹ ${benchmark.pricePerKg.toStringAsFixed(1)} / kg',
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      isHindi ? 'अनुमानित आगामी भाव (ट्रेंड)' : 'Estimated Future Rate (Trend)',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (benchmark.hasValidPrediction) ...[
                                      Text(
                                        '₹ ${benchmark.predictedFuturePricePerQuintal.toStringAsFixed(0)} ${loc.pricePerQuintalUnit}',
                                        style: const TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        benchmark.trend == PriceTrend.rising
                                            ? '+${benchmark.expectedPriceChangePercent.toStringAsFixed(1)}%'
                                            : '${benchmark.expectedPriceChangePercent.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: benchmark.trend == PriceTrend.rising
                                              ? AppColors.primaryGreen
                                              : benchmark.trend == PriceTrend.falling
                                                  ? AppColors.riskHigh
                                                  : AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        isHindi ? 'पूर्वानुमान उपलब्ध नहीं' : 'Prediction Unavailable',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        (benchmark.noticeMessage(isHindi) != null &&
                                                (benchmark.noticeMessage(isHindi)!.toLowerCase().contains('prediction') ||
                                                    benchmark.noticeMessage(isHindi)!.contains('पूर्वानुमान')))
                                            ? benchmark.noticeMessage(isHindi)!
                                            : (isHindi
                                                ? 'पर्याप्त ऐतिहासिक मूल्य डेटा उपलब्ध नहीं होने के कारण पूर्वानुमान उपलब्ध नहीं है।'
                                                : 'Prediction unavailable because sufficient historical price data is not available.'),
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (benchmark.hasValidPrediction && benchmark.minExpectedPrice > 0) ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${loc.estimatedPriceRange}: ₹${benchmark.minExpectedPrice.toStringAsFixed(0)} - ₹${benchmark.maxExpectedPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (benchmark.holdoutMape != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'MAPE: ${benchmark.holdoutMape!.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (benchmark.forecastModelName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${isHindi ? "मॉडल" : "Model"}: ${benchmark.forecastModelName} • ${isHindi ? "अवलोकन" : "History"}: ${benchmark.forecastPeriod ?? "${benchmark.historicalObservationCount ?? 7} days"}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              isHindi
                                  ? 'ऐतिहासिक डेटा स्रोत: सेंटर फॉर इकोनॉमिक डेटा एंड एनालिसिस (CEDA), अशोका यूनिवर्सिटी'
                                  : 'Data source: Centre for Economic Data and Analysis (CEDA), Ashoka University',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 15,
                                      color: AppColors.primaryGreen,
                                    ),
                                    Text(
                                      '${benchmark.market ?? ""}, ${benchmark.district ?? ""} (${benchmark.state ?? ""})',
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (benchmark.arrivalDate != null && benchmark.arrivalDate!.isNotEmpty) ...[
                                      Text(
                                        '• ${isHindi ? "आवक/दिनांक" : "Date"}: ${benchmark.arrivalDate}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '₹ ${benchmark.pricePerKg.toStringAsFixed(1)} / kg  (₹ ${benchmark.currentAvgPricePerQuintal.toStringAsFixed(0)} / quintal)',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (benchmark.sourceUrl != null || benchmark.dataQuality != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    '${isHindi ? "स्रोत" : "Source"}: ${benchmark.sourceUrl ?? "agmarknet.gov.in"} • ${isHindi ? "गुणवत्ता" : "Quality"}: ${benchmark.dataQuality ?? "verified"}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                benchmark.isNetworkError
                                    ? Icons.cloud_off_rounded
                                    : Icons.info_outline_rounded,
                                color: benchmark.isNetworkError
                                    ? AppColors.riskHigh
                                    : AppColors.textSecondary,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      benchmark.isNetworkError
                                          ? (isHindi ? 'डेटा प्राप्त करने में असमर्थ' : 'Unable to fetch data')
                                          : (isHindi ? 'डेटा उपलब्ध नहीं है' : 'Data Not Available'),
                                      style: TextStyle(
                                        color: benchmark.isNetworkError
                                            ? AppColors.riskHigh
                                            : AppColors.textDark,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      benchmark.isNetworkError
                                          ? (isHindi
                                              ? 'डेटा प्राप्त करने में असमर्थ। कृपया पुनः प्रयास करें।'
                                              : 'Unable to fetch data. Please try again.')
                                          : (isHindi
                                              ? '${benchmark.requestedDistrict ?? "चयनित स्थान"} के लिए मंडी भाव उपलब्ध नहीं है।'
                                              : 'No matching mandi price record found for ${benchmark.requestedDistrict ?? "selected location"}.'),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              benchmark.isNetworkError
                                  ? (isHindi
                                      ? 'नेटवर्क या सर्वर से संपर्क नहीं हो सका। कृपया इंटरनेट जांचें और पुनः प्रयास करें।'
                                      : 'Network or server communication failed. Please check connection and try again.')
                                  : (isHindi
                                      ? 'इस फसल व जिले के लिए आज कोई आधिकारिक नीलामी दर दर्ज नहीं है। दरों की पुष्टि के लिए सीधे स्थानीय APMC मंडी से संपर्क करें।'
                                      : 'No official auction prices recorded for this crop and location today. Please check directly with your local APMC yard.'),
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // ESTIMATED GROSS CROP VALUE (Quantity and Revenue Calculation - Algorithm Section 8 & 11)
              SectionHeader(
                title: isHindi ? 'अनुमानित फसल मूल्य (सकल राजस्व)' : 'Estimated Gross Crop Value',
                subtitle: isHindi
                    ? 'मात्रा एवं मंडी भाव के आधार पर सकल अनुमान'
                    : 'Gross valuation based on entered quantity and mandi rate',
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: benchmark.hasLiveRecord && grossValue != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreenLight.withAlpha(40),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.payments_rounded,
                                  color: AppColors.primaryGreen,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isHindi ? 'अनुमानित सकल मूल्य' : 'Estimated Gross Value',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '₹ ${grossValue.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          // Transparent calculation breakdown
                          Row(
                            children: [
                              const Icon(Icons.calculate_outlined, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isHindi
                                      ? 'गणना: $calcBreakdown = ₹ ${grossValue.toStringAsFixed(0)}'
                                      : 'Calculation: $calcBreakdown = ₹ ${grossValue.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Provenance: price date & price source
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isHindi
                                      ? 'भाव स्रोत: ${benchmark.market ?? benchmark.district ?? "APMC मंडी"} • आवक: ${benchmark.arrivalDate ?? "हालिया"}'
                                      : 'Price Source: ${benchmark.market ?? benchmark.district ?? "APMC Mandi"} • Arrival: ${benchmark.arrivalDate ?? "Recent"}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Mandatory Algorithm Label: Gross estimate before transport, storage, commission, handling
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderLight, width: 1.0),
                            ),
                            child: Text(
                              isHindi
                                  ? 'सूचना: यह केवल अनुमानित सकल मूल्य है (परिवहन, भंडारण, आढ़त/कमीशन व लोडिंग खर्च घटाने से पहले)। अंतिम प्राप्ति वास्तविक नीलामी गुणवत्ता पर निर्भर करेगी।'
                                  : 'Notice: This is an estimated gross crop value before transport, cold storage, commission/mandi cess, or loading costs. Final returns depend on actual auction grades.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isHindi
                                      ? 'सकल मूल्य गणना अनुपलब्ध'
                                      : 'Gross Value Calculation Unavailable',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isHindi
                                ? 'चयनित फसल व स्थान के लिए सत्यापित आधिकारिक मंडी भाव उपलब्ध न होने के कारण सकल मूल्य की गणना नहीं की गई है। कोई मनगढ़ंत या काल्पनिक मूल्य नहीं दिखाया जा रहा है।'
                                : 'Gross value cannot be calculated because no verified mandi price is available for this crop and location. Fabricated prices are never substituted.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // C. SPOILAGE RISK & SAFE DAYS
              SectionHeader(
                title: loc.spoilageRiskSection,
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 74,
                              height: 74,
                              child: CircularProgressIndicator(
                                value: (spoilage.riskScore / 100.0).clamp(0.0, 1.0),
                                strokeWidth: 8,
                                backgroundColor: AppColors.surfaceMuted,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  spoilage.riskScore >= 65
                                      ? AppColors.riskHigh
                                      : spoilage.riskScore >= 35
                                          ? AppColors.riskMedium
                                          : AppColors.riskLow,
                                ),
                              ),
                            ),
                            Text(
                              '${spoilage.riskScore}%',
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.safeDaysRemaining,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${spoilage.safeShelfLifeDaysRemaining} ${loc.daysUnit}',
                                style: TextStyle(
                                  color: spoilage.safeShelfLifeDaysRemaining <= 2
                                      ? AppColors.riskHigh
                                      : AppColors.primaryGreen,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                spoilage.getExplanation(isHindi),
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // WEATHER & MICRO-CLIMATE ADVISORY CARD
              SectionHeader(
                title: isHindi
                    ? 'स्थानीय मौसम एवं सूक्ष्म-जलवायु परामर्श'
                    : 'Local Weather & Micro-Climate Advisory',
                subtitle: isHindi
                    ? 'ओपन-मेटियो (Open-Meteo) वास्तविक समय कृषि अवलोकन'
                    : 'Verified Open-Meteo Real-Time Agro-Climatic Feed',
                icon: Icons.cloud_sync_rounded,
              ),
              const SizedBox(height: 8),
              _buildWeatherCard(result.weatherData, isHindi),
              const SizedBox(height: 20),

              // D. DISCOVERED NEARBY RESOURCES (Cold Storages & Mandis)
              SectionHeader(
                title: loc.nearbyResourcesSection,
                subtitle: loc.nearbyResourcesDesc,
                icon: Icons.warehouse_rounded,
              ),
              const SizedBox(height: 8),
              if (result.nearbyResources.isNotEmpty) ...[
                ...result.nearbyResources.map((res) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: res.type == AgriResourceType.mandi
                                      ? AppColors.primaryGreenLight.withAlpha(35)
                                      : AppColors.resourceBlueLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  res.type == AgriResourceType.mandi
                                      ? Icons.storefront_rounded
                                      : res.type == AgriResourceType.coldStorage
                                          ? Icons.ac_unit_rounded
                                          : Icons.warehouse_rounded,
                                  color: res.type == AgriResourceType.mandi
                                      ? AppColors.primaryGreen
                                      : AppColors.resourceBlue,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            res.localizedName(isHindi),
                                            style: const TextStyle(
                                              color: AppColors.textDark,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceMuted,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppColors.borderLight),
                                          ),
                                          child: Text(
                                            res.type == AgriResourceType.mandi
                                                ? (isHindi ? 'मंडी यार्ड' : 'APMC Yard')
                                                : (isHindi ? 'शीतगृह' : 'Cold Storage'),
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${res.distanceKm.toStringAsFixed(1)} km • ${res.localizedDistrict(isHindi)}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Provenance & notice
                          Text(
                            res.verificationNotice(isHindi),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if (res.type == AgriResourceType.coldStorage) ...[
                            const SizedBox(height: 4),
                            Text(
                              isHindi
                                  ? 'उपलब्धता असत्यापित — जाने से पहले परिचालन समय और स्थान की पुष्टि करें।'
                                  : 'Availability not verified — Confirm space & charges before visiting.',
                              style: const TextStyle(
                                color: AppColors.riskMedium,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (res.hasValidPhone) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.call_rounded, size: 14),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.resourceBlue,
                                  side: const BorderSide(color: AppColors.resourceBlue),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: () {
                                  PhoneCallService.promptAndLaunchCall(
                                    context: context,
                                    facilityName: res.localizedName(isHindi),
                                    rawPhoneNumber: res.contactPhone,
                                    isHindi: isHindi,
                                  );
                                },
                                label: Text(PhoneCallService.formatForDisplay(res.contactPhone), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ] else ...[
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.riskMedium, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isHindi
                                  ? 'खोजे गए क्षेत्र में कोई सत्यापित मंडी या कोल्ड स्टोरेज नहीं मिला'
                                  : 'No Mapped Agricultural Mandi or Cold-Storage Found in Searched Area',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isHindi
                            ? 'इसका अर्थ यह नहीं है कि वहाँ कोई सुविधा उपलब्ध नहीं है। ग्रामीण क्षेत्रों में कई कोल्ड स्टोरेज अभी ओपनस्ट्रीटमैप पर दर्ज नहीं हैं।'
                            : 'This does not necessarily mean none are available. Many rural facilities are not yet digitized on open maps.',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.search_rounded, size: 16),
                        label: Text(
                          isHindi ? 'कोल्ड स्टोरेज फाइंडर खोलें' : 'Open Cold Storage Finder',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.coldStorage),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // E. ACTIONABLE NEXT STEPS
              SectionHeader(
                title: loc.actionableSteps,
                icon: Icons.checklist_rounded,
              ),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: rec.getNextSteps(isHindi).asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final step = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '$idx',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // F. ALTERNATIVE RELIEF & NGO DONATION SECTION
              AppCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: AppColors.white,
                border: Border.all(color: AppColors.primaryGreen.withAlpha(90), width: 1.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                                loc.ngoTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isHindi
                                  ? 'अधिशेष उपज या जोखिम के समय सत्यापित एनजीओ खोजें'
                                  : 'Explore verified relief NGOs accepting surplus produce',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: loc.ngoDonateSurplus,
                      variant: AppButtonVariant.primaryGreen,
                      icon: Icons.search_rounded,
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.ngoDonation,
                          arguments: {
                            'crop': result.input.crop.nameEn,
                            'location': result.input.location,
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Primary Action: Re-analyze or return
              AppButton(
                label: loc.back,
                variant: AppButtonVariant.outline,
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildWeatherCard(WeatherData? weather, bool isHindi) {
    if (weather == null) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHindi
                        ? 'लाइव मौसम डेटा अनुपलब्ध'
                        : 'Live Weather Unavailable',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isHindi
                        ? 'इस स्थान के लिए लाइव मौसम प्राप्त नहीं हो सका। शेल्फ-लाइफ गणना मानक कृषि बेंचमार्क के अनुसार जारी है।'
                        : 'Real-time weather observation could not be retrieved. Spoilage risk calculation continues using calibrated crop benchmarks.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Current condition, temperature, feels like, badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenLight.withAlpha(35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  weather.conditionIcon,
                  color: AppColors.primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${weather.temperature.toStringAsFixed(1)}°C',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.riskLowBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.riskLow.withAlpha(80)),
                          ),
                          child: Text(
                            isHindi ? 'लाइव ओपन-मेटियो' : 'Open-Meteo Live',
                            style: const TextStyle(
                              color: AppColors.riskLow,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${weather.conditionDescription(isHindi)} • ${isHindi ? "महसूस" : "Feels like"} ${weather.apparentTemperature.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Metrics Strip (Humidity, Wind, Precipitation)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherMetric(
                  icon: Icons.water_drop_outlined,
                  label: isHindi ? 'आर्द्रता' : 'Humidity',
                  value: '${weather.relativeHumidity.toStringAsFixed(0)}%',
                  iconColor: AppColors.resourceBlue,
                ),
                Container(width: 1, height: 28, color: AppColors.borderLight),
                _buildWeatherMetric(
                  icon: Icons.air_rounded,
                  label: isHindi ? 'हवा की गति' : 'Wind Speed',
                  value: '${weather.windSpeed.toStringAsFixed(1)} km/h',
                  iconColor: AppColors.deepGreen,
                ),
                Container(width: 1, height: 28, color: AppColors.borderLight),
                _buildWeatherMetric(
                  icon: Icons.umbrella_outlined,
                  label: isHindi ? 'वर्षा' : 'Precipitation',
                  value: '${weather.precipitation.toStringAsFixed(1)} mm',
                  iconColor: weather.precipitation > 0 ? AppColors.riskHigh : AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 3: Scientifically grounded post-harvest micro-climate advisory
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: weather.isHighHeat || weather.isRainRisk
                  ? AppColors.riskMediumBg.withAlpha(120)
                  : AppColors.primaryGreenLight.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: weather.isHighHeat || weather.isRainRisk
                    ? AppColors.riskMedium.withAlpha(100)
                    : AppColors.primaryGreen.withAlpha(80),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  weather.isHighHeat || weather.isRainRisk
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
                  color: weather.isHighHeat || weather.isRainRisk
                      ? AppColors.riskMedium
                      : AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'फसल रखरखाव सूक्ष्म-जलवायु परामर्श' : 'Post-Harvest Micro-Climate Advisory',
                        style: TextStyle(
                          color: weather.isHighHeat || weather.isRainRisk
                              ? AppColors.riskMedium
                              : AppColors.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isHindi ? weather.weatherAdvisoryHi : weather.weatherAdvisoryEn,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Row 4: 3-Day Short-Term Forecast (if available)
          if (weather.dailyForecasts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              isHindi ? '३-दिवसीय मौसम पूर्वानुमान' : '3-Day Weather Forecast',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: weather.dailyForecasts.take(3).map((f) {
                final dayLabel = _formatForecastDay(f.date, isHindi);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(f.conditionIcon, size: 20, color: AppColors.primaryGreen),
                        const SizedBox(height: 4),
                        Text(
                          '${f.maxTemp.toStringAsFixed(0)}° / ${f.minTemp.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (f.precipitationProbability > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.water_drop, size: 10, color: AppColors.resourceBlue),
                              Text(
                                '${f.precipitationProbability}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.resourceBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatForecastDay(DateTime date, bool isHindi) {
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return isHindi ? 'आज' : 'Today';
    if (diff == 1) return isHindi ? 'कल' : 'Tomorrow';
    final weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdaysHi = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    final idx = (date.weekday - 1) % 7;
    return isHindi ? weekdaysHi[idx] : weekdaysEn[idx];
  }
}
