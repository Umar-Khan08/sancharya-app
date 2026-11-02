import '../../models/crop_model.dart';

/// Demonstration crop catalogue with illustrative baseline parameters.
/// Explicitly labeled for demonstration; will be backed by real ICAR / APEDA datasets in production.
class DemoCrops {
  DemoCrops._();

  static const List<Crop> sampleCrops = [
    Crop(
      id: 'tomato',
      nameEn: 'Tomato',
      nameHi: 'टमाटर',
      category: 'Perishable Vegetable',
      standardShelfLifeDays: 5,
      benchmarkPricePerQuintal: 1850.0,
      iconCode: 'nutrition',
    ),
    Crop(
      id: 'onion',
      nameEn: 'Onion',
      nameHi: 'प्याज',
      category: 'Semi-Perishable Vegetable',
      standardShelfLifeDays: 45,
      benchmarkPricePerQuintal: 2200.0,
      iconCode: 'grass',
    ),
    Crop(
      id: 'potato',
      nameEn: 'Potato',
      nameHi: 'आलू',
      category: 'Semi-Perishable Tuber',
      standardShelfLifeDays: 60,
      benchmarkPricePerQuintal: 1400.0,
      iconCode: 'spa',
    ),
    Crop(
      id: 'cauliflower',
      nameEn: 'Cauliflower',
      nameHi: 'फूलगोभी',
      category: 'Perishable Vegetable',
      standardShelfLifeDays: 4,
      benchmarkPricePerQuintal: 1600.0,
      iconCode: 'park',
    ),
    Crop(
      id: 'green_chilli',
      nameEn: 'Green Chilli',
      nameHi: 'हरी मिर्च',
      category: 'Perishable Vegetable',
      standardShelfLifeDays: 7,
      benchmarkPricePerQuintal: 3500.0,
      iconCode: 'whatshot',
    ),
    Crop(
      id: 'wheat',
      nameEn: 'Wheat',
      nameHi: 'गेहूं',
      category: 'Non-Perishable Cereal',
      standardShelfLifeDays: 180,
      benchmarkPricePerQuintal: 2275.0,
      iconCode: 'grain',
    ),
    Crop(
      id: 'soybean',
      nameEn: 'Soybean',
      nameHi: 'सोयाबीन',
      category: 'Oilseed',
      standardShelfLifeDays: 120,
      benchmarkPricePerQuintal: 4600.0,
      iconCode: 'energy_savings_leaf',
    ),
  ];
}
