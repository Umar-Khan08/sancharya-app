/// Simulated daily mandi market price records for illustration.
class DemoMandiRecord {
  final String cropId;
  final String cropNameEn;
  final String cropNameHi;
  final String mandiNameEn;
  final String mandiNameHi;
  final double minPrice;
  final double maxPrice;
  final double modalPrice;
  final String arrivalQuintals;
  final String trend; // 'up', 'stable', 'down'

  const DemoMandiRecord({
    required this.cropId,
    required this.cropNameEn,
    required this.cropNameHi,
    required this.mandiNameEn,
    required this.mandiNameHi,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    required this.arrivalQuintals,
    required this.trend,
  });
}

class DemoMandiPrices {
  DemoMandiPrices._();

  static const List<DemoMandiRecord> records = [
    DemoMandiRecord(
      cropId: 'tomato',
      cropNameEn: 'Tomato',
      cropNameHi: 'टमाटर',
      mandiNameEn: 'Nashik Main Mandi',
      mandiNameHi: 'नासिक मुख्य मंडी',
      minPrice: 1500,
      maxPrice: 2200,
      modalPrice: 1850,
      arrivalQuintals: '1,420 qtl',
      trend: 'down',
    ),
    DemoMandiRecord(
      cropId: 'onion',
      cropNameEn: 'Onion (Red)',
      cropNameHi: 'प्याज (लाल)',
      mandiNameEn: 'Lasalgaon APMC',
      mandiNameHi: 'लासलगांव एपीएमसी',
      minPrice: 1900,
      maxPrice: 2550,
      modalPrice: 2200,
      arrivalQuintals: '3,850 qtl',
      trend: 'up',
    ),
    DemoMandiRecord(
      cropId: 'potato',
      cropNameEn: 'Potato (Jyoti)',
      cropNameHi: 'आलू (ज्योति)',
      mandiNameEn: 'Pune Gultekdi Mandi',
      mandiNameHi: 'पुणे गुलटेकड़ी मंडी',
      minPrice: 1200,
      maxPrice: 1650,
      modalPrice: 1400,
      arrivalQuintals: '2,100 qtl',
      trend: 'stable',
    ),
    DemoMandiRecord(
      cropId: 'cauliflower',
      cropNameEn: 'Cauliflower',
      cropNameHi: 'फूलगोभी',
      mandiNameEn: 'Vashi Wholesale Market',
      mandiNameHi: 'वाशी थोक बाज़ार',
      minPrice: 1350,
      maxPrice: 1900,
      modalPrice: 1600,
      arrivalQuintals: '860 qtl',
      trend: 'up',
    ),
    DemoMandiRecord(
      cropId: 'green_chilli',
      cropNameEn: 'Green Chilli',
      cropNameHi: 'हरी मिर्च',
      mandiNameEn: 'Nagpur Cotton Market Yard',
      mandiNameHi: 'नागपुर यार्ड',
      minPrice: 3100,
      maxPrice: 3950,
      modalPrice: 3500,
      arrivalQuintals: '410 qtl',
      trend: 'up',
    ),
    DemoMandiRecord(
      cropId: 'wheat',
      cropNameEn: 'Wheat (Sharbati)',
      cropNameHi: 'गेहूं (शरबती)',
      mandiNameEn: 'Indore Mandi',
      mandiNameHi: 'इंदौर मंडी',
      minPrice: 2150,
      maxPrice: 2480,
      modalPrice: 2275,
      arrivalQuintals: '5,200 qtl',
      trend: 'stable',
    ),
  ];
}
