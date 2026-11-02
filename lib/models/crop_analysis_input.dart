import 'crop_model.dart';

enum QuantityUnit {
  quintal,
  kilogram,
}

enum CropCondition {
  good,
  average,
  poor,
}

/// Unified Crop Analysis Request Model
/// Holds the single submitted set of harvest details entered by the farmer.
class CropAnalysisInput {
  final Crop crop;
  final String location;
  final double quantity;
  final QuantityUnit quantityUnit;
  final DateTime harvestDate;
  final CropCondition condition;
  final double? latitude;
  final double? longitude;

  const CropAnalysisInput({
    required this.crop,
    required this.location,
    required this.quantity,
    this.quantityUnit = QuantityUnit.quintal,
    required this.harvestDate,
    required this.condition,
    this.latitude,
    this.longitude,
  });

  /// Quantity normalized to Quintals for standard mandi price calculations (1 Qtl = 100 kg)
  double get quantityInQuintals {
    if (quantityUnit == QuantityUnit.kilogram) {
      return quantity / 100.0;
    }
    return quantity;
  }

  /// Days elapsed between harvest and current analysis
  int get daysSinceHarvest {
    final now = DateTime.now();
    final difference = now.difference(harvestDate).inDays;
    return difference < 0 ? 0 : difference;
  }
}
