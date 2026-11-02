/// Domain model for an agricultural crop
class Crop {
  final String id;
  final String nameEn;
  final String nameHi;
  final String category; // 'Vegetables', 'Grains', 'Oilseeds', etc.
  final int standardShelfLifeDays; // Baseline ambient shelf life
  final double benchmarkPricePerQuintal; // Benchmark baseline
  final String iconCode;

  const Crop({
    required this.id,
    required this.nameEn,
    required this.nameHi,
    required this.category,
    required this.standardShelfLifeDays,
    required this.benchmarkPricePerQuintal,
    this.iconCode = 'eco',
  });

  String localizedName(bool isHindi) => isHindi ? nameHi : nameEn;
}
