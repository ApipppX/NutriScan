/// Maps raw machine-learning class labels to readable Indonesian names.
///
/// The TFLite model and its metadata can expose labels in different shapes
/// (`fried_noodles`, `Fried Noodles`, `fried-noodles`, …). The UI should never
/// show those raw keys, so every food name is resolved through this utility
/// before it is rendered or written to the diary.
abstract final class FoodLabelLocalizer {
  /// Canonical English/snake-case keys mapped to Indonesian display names.
  ///
  /// Keys are normalized with [_normalize], so `Fried Noodles`,
  /// `fried-noodles`, and `FRIED_NOODLES` all resolve to the same entry.
  static const Map<String, String> _indonesianNames = <String, String>{
    // Noodle dishes.
    'fried_noodles': 'Olahan Mie',
    'fried_noodle': 'Olahan Mie',
    'olahan_mie': 'Olahan Mie',
    'mie_goreng': 'Olahan Mie',
    'indomie_goreng': 'Olahan Mie',
    'noodle_soup': 'Mie Rebus',
    'mie_rebus': 'Mie Rebus',
    'chicken_noodles': 'Mie Ayam',
    'mie_ayam': 'Mie Ayam',

    // Rice dishes.
    'fried_rice': 'Nasi Goreng',
    'nasi_goreng': 'Nasi Goreng',
    'padang_rice': 'Nasi Padang',
    'nasi_padang': 'Nasi Padang',
    'white_rice': 'Nasi Putih',
    'steamed_rice': 'Nasi Putih',
    'nasi_putih': 'Nasi Putih',

    // Protein dishes.
    'fried_chicken': 'Ayam Goreng',
    'ayam_goreng': 'Ayam Goreng',
    'fried_fish': 'Ikan Goreng',
    'ikan_goreng': 'Ikan Goreng',
    'beef_rendang': 'Rendang',
    'rendang': 'Rendang',
    'satay': 'Sate Ayam',
    'sate': 'Sate Ayam',
    'sate_ayam': 'Sate Ayam',
    'chicken_satay': 'Sate Ayam',
    'meatball_soup': 'Bakso',
    'bakso': 'Bakso',
    'fried_egg': 'Telur Goreng',
    'telur_goreng': 'Telur Goreng',

    // Vegetables and soups.
    'gado_gado': 'Gado-Gado',
    'vegetable_salad': 'Gado-Gado',
    'rawon': 'Rawon',
    'soto': 'Soto',
    'soup': 'Soto',

    // Snacks and international dishes.
    'pizza': 'Pizza',
    'burger': 'Burger',
    'hamburger': 'Burger',
    'beef_burger': 'Burger',
    'french_fries': 'Kentang Goreng',
    'fries': 'Kentang Goreng',
    'kentang_goreng': 'Kentang Goreng',
    'banana_fritter': 'Pisang Goreng',
    'pisang_goreng': 'Pisang Goreng',

    // Beverages.
    'iced_tea': 'Es Teh',
    'es_teh': 'Es Teh',
    'sweet_iced_tea': 'Es Teh',
  };

  /// Returns the Indonesian display name for [rawLabel].
  ///
  /// Resolution order:
  /// 1. Known English/raw key in the dictionary.
  /// 2. A non-empty [displayName] supplied by the nutrition catalog.
  /// 3. A humanized version of [rawLabel] (e.g. `mystery_food` -> `Mystery Food`).
  static String resolve(String rawLabel, {String? displayName}) {
    final mapped = _indonesianNames[_normalize(rawLabel)];
    if (mapped != null) return mapped;

    final catalogName = displayName?.trim();
    if (catalogName != null && catalogName.isNotEmpty) return catalogName;

    final humanized = _humanize(rawLabel);
    return humanized.isEmpty ? 'Makanan' : humanized;
  }

  /// Looks up only the explicit dictionary entry, without a fallback.
  static String? lookup(String rawLabel) =>
      _indonesianNames[_normalize(rawLabel)];

  /// Lowercases and converts every non-alphanumeric run to a single underscore.
  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  /// Turns `mystery_food` or `Mystery-Food` into `Mystery Food`.
  static String _humanize(String value) {
    final words = _normalize(value).split('_').where((word) => word.isNotEmpty);
    return words
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
