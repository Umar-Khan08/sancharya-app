import '../data/interfaces/i_agriculture_service.dart';
import '../models/crop_analysis_input.dart';
import '../models/crop_analysis_result.dart';
import '../models/crop_model.dart';
import '../services/history/search_history_service.dart';

/// Single source of truth for Agricultural Intelligence in SANCHARYA.
/// Consumed by ViewModels / Screens, abstracting data source implementations.
class AgricultureRepository {
  final IAgricultureService _service;

  AgricultureRepository(this._service);

  bool get isDemonstration => _service.isDemonstrationProvider;

  Future<List<Crop>> getSupportedCrops() => _service.getSupportedCrops();

  Future<CombinedCropAnalysisResult> analyzeCrop(
    CropAnalysisInput input, {
    String? userPhone,
  }) async {
    final result = await _service.analyzeCrop(input);
    // Persist completed analysis to local farmer search history
    await SearchHistoryService.saveAnalysis(result, userPhone: userPhone);
    return result;
  }

  Future<List<CombinedCropAnalysisResult>> getRecentAnalyses({String? userPhone}) async {
    final persisted = await SearchHistoryService.getRecentAnalyses(userPhone: userPhone);
    if (persisted.isNotEmpty) {
      return persisted;
    }
    // Fallback to in-memory active session service if empty
    return _service.getRecentAnalyses();
  }
}
