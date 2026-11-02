import '../../models/crop_model.dart';

/// Resolves raw text or voice inputs to supported canonical crops using alias mapping.
/// Adheres to Section 3 of Sancharya Algorithm:
/// - Validates non-empty input
/// - Strips excess whitespace
/// - Matches aliases and canonical names
/// - Rejects ambiguous/unsupported crops without silent substitution
class CropResolver {
  CropResolver._();

  static const Map<String, String> _aliasMap = {
    // Tomato
    'tomato': 'tomato',
    'tamatar': 'tomato',
    'tamator': 'tomato',
    'tamato': 'tomato',
    'tmatr': 'tomato',
    'टमाटर': 'tomato',

    // Onion
    'onion': 'onion',
    'pyaz': 'onion',
    'pyaaz': 'onion',
    'pyaj': 'onion',
    'kanda': 'onion',
    'प्याज': 'onion',
    'कांदा': 'onion',

    // Potato
    'potato': 'potato',
    'aloo': 'potato',
    'alu': 'potato',
    'aalu': 'potato',
    'batata': 'potato',
    'आलू': 'potato',

    // Cauliflower
    'cauliflower': 'cauliflower',
    'phool gobhi': 'cauliflower',
    'phoolgobhi': 'cauliflower',
    'phul gobhi': 'cauliflower',
    'gobhi': 'cauliflower',
    'gobi': 'cauliflower',
    'फूलगोभी': 'cauliflower',

    // Green Chilli
    'green chilli': 'green_chilli',
    'green chili': 'green_chilli',
    'green chillies': 'green_chilli',
    'chilli': 'green_chilli',
    'chili': 'green_chilli',
    'mirchi': 'green_chilli',
    'mirch': 'green_chilli',
    'hari mirch': 'green_chilli',
    'hari mirchi': 'green_chilli',
    'हरी मिर्च': 'green_chilli',

    // Wheat
    'wheat': 'wheat',
    'gehu': 'wheat',
    'gehun': 'wheat',
    'gehoon': 'wheat',
    'kanak': 'wheat',
    'गेहूं': 'wheat',

    // Soybean
    'soybean': 'soybean',
    'soya bean': 'soybean',
    'soyabean': 'soybean',
    'soya': 'soybean',
    'सोयाबीन': 'soybean',
  };

  /// Resolves [query] against canonical crop IDs, English/Hindi names, or known aliases.
  /// Returns `null` if the crop is unsupported (prevents silent replacement).
  static Crop? resolve(String query, List<Crop> availableCrops) {
    final cleaned = query.trim().toLowerCase();
    if (cleaned.isEmpty) return null;

    // 1. Direct match on ID, English name, or Hindi name
    for (final crop in availableCrops) {
      if (crop.id.toLowerCase() == cleaned ||
          crop.nameEn.toLowerCase() == cleaned ||
          crop.nameHi == query.trim()) {
        return crop;
      }
    }

    // 2. Direct alias mapping
    final targetId = _aliasMap[cleaned];
    if (targetId != null) {
      for (final crop in availableCrops) {
        if (crop.id == targetId) return crop;
      }
    }

    // 3. Normalized substring / token match
    for (final entry in _aliasMap.entries) {
      if (cleaned.contains(entry.key) || entry.key.contains(cleaned)) {
        for (final crop in availableCrops) {
          if (crop.id == entry.value) return crop;
        }
      }
    }

    return null;
  }

  /// Returns matching crop suggestions for autocomplete as the user types.
  static List<Crop> getSuggestions(String query, List<Crop> availableCrops) {
    final cleaned = query.trim().toLowerCase();
    if (cleaned.isEmpty) return availableCrops;

    final matched = <Crop>{};
    for (final crop in availableCrops) {
      if (crop.nameEn.toLowerCase().contains(cleaned) ||
          crop.nameHi.contains(query.trim()) ||
          crop.category.toLowerCase().contains(cleaned)) {
        matched.add(crop);
      }
    }

    for (final entry in _aliasMap.entries) {
      if (entry.key.contains(cleaned)) {
        for (final crop in availableCrops) {
          if (crop.id == entry.value) {
            matched.add(crop);
          }
        }
      }
    }

    return matched.toList();
  }
}
