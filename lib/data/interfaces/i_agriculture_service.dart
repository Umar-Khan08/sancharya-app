import '../../models/crop_model.dart';
import '../../models/crop_analysis_input.dart';
import '../../models/crop_analysis_result.dart';

/// Clean interface for agricultural prediction & decision support service.
/// Can be backed by Demo data initially, and later by Python ML models (FastAPI / Flask)
/// and real AGMARKNET / IMD weather APIs without touching the UI layer.
abstract class IAgricultureService {
  Future<List<Crop>> getSupportedCrops();
  
  Future<CombinedCropAnalysisResult> analyzeCrop(CropAnalysisInput input);

  Future<List<CombinedCropAnalysisResult>> getRecentAnalyses();

  bool get isDemonstrationProvider;
}
