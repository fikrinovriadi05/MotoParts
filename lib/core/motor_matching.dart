import 'package:motopart/models/product.dart';

/// Seberapa cocok sebuah sparepart dengan motor tertentu.
enum MotorFit {
  /// Disebut khusus untuk motor itu, mis. "Honda Beat" untuk motor Honda Beat.
  exact,

  /// Untuk jenis motornya, mis. "Honda Matic" untuk Honda Beat (motor matic).
  group,

  /// Universal / berbagai tipe: bisa dipakai di motor apa pun.
  universal,

  /// Tidak cocok.
  none,
}

/// Memecah isian tipe produk ("Honda Beat, Honda Vario") menjadi daftar motor.
List<String> splitCompatibleBikes(String type) {
  return type
      .split(RegExp(r'[,;/]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// Mencocokkan sparepart dengan tipe motor yang diketik/dipilih pembeli.
///
/// Aturan, dari paling spesifik:
/// 1. **Khusus**: kata-kata motor di produk termuat di pencarian atau
///    sebaliknya (tanpa membedakan huruf besar/kecil dan tanda baca), jadi
///    "Beat", "Honda Beat", dan "Honda Beat Street" semuanya cocok dengan
///    produk "Honda Beat".
/// 2. **Sejenis**: produk untuk jenis motor ("Honda Matic", "Matic") cocok
///    dengan motor yang diketahui termasuk jenis itu (daftar [_models]) dan
///    mereknya sama (bila produk menyebut merek).
/// 3. **Universal**: "Universal" / "Berbagai tipe" cocok dengan semua motor.
class MotorMatcher {
  const MotorMatcher._();

  static const _stopWords = {'motor', 'sepeda', 'untuk'};

  static const _brands = {
    'honda',
    'yamaha',
    'suzuki',
    'kawasaki',
    'tvs',
    'vespa',
    'piaggio',
    'kymco',
    'benelli',
    'viar',
  };

  /// Kata jenis motor di produk -> nama jenisnya.
  static const _groupWords = {
    'matic': 'matic',
    'skutik': 'matic',
    'bebek': 'bebek',
    'sport': 'sport',
  };

  /// Model yang umum dikenal: kata model -> (merek, jenis). Daftar bantu
  /// supaya "Honda Beat" cocok dengan produk "Honda Matic"; bisa dilengkapi.
  static const Map<String, (String, String)> _models = {
    // Honda matic
    'beat': ('honda', 'matic'),
    'vario': ('honda', 'matic'),
    'scoopy': ('honda', 'matic'),
    'genio': ('honda', 'matic'),
    'pcx': ('honda', 'matic'),
    'adv': ('honda', 'matic'),
    'spacy': ('honda', 'matic'),
    'stylo': ('honda', 'matic'),
    'forza': ('honda', 'matic'),
    // Honda bebek
    'supra': ('honda', 'bebek'),
    'revo': ('honda', 'bebek'),
    'blade': ('honda', 'bebek'),
    'karisma': ('honda', 'bebek'),
    'legenda': ('honda', 'bebek'),
    'grand': ('honda', 'bebek'),
    // Honda sport
    'cb150r': ('honda', 'sport'),
    'cbr150r': ('honda', 'sport'),
    'cbr250rr': ('honda', 'sport'),
    'verza': ('honda', 'sport'),
    'megapro': ('honda', 'sport'),
    'tiger': ('honda', 'sport'),
    // Yamaha
    'mio': ('yamaha', 'matic'),
    'nmax': ('yamaha', 'matic'),
    'aerox': ('yamaha', 'matic'),
    'fino': ('yamaha', 'matic'),
    'xride': ('yamaha', 'matic'),
    'lexi': ('yamaha', 'matic'),
    'fazzio': ('yamaha', 'matic'),
    'freego': ('yamaha', 'matic'),
    'gear': ('yamaha', 'matic'),
    'xmax': ('yamaha', 'matic'),
    'jupiter': ('yamaha', 'bebek'),
    'vega': ('yamaha', 'bebek'),
    'r15': ('yamaha', 'sport'),
    'vixion': ('yamaha', 'sport'),
    'byson': ('yamaha', 'sport'),
    'scorpio': ('yamaha', 'sport'),
    'mt15': ('yamaha', 'sport'),
    // Suzuki
    'nex': ('suzuki', 'matic'),
    'address': ('suzuki', 'matic'),
    'smash': ('suzuki', 'bebek'),
    'shogun': ('suzuki', 'bebek'),
    'satria': ('suzuki', 'sport'),
    'gsx': ('suzuki', 'sport'),
    // Kawasaki
    'ninja': ('kawasaki', 'sport'),
    'z250': ('kawasaki', 'sport'),
  };

  static const _universalTexts = {
    'universal',
    'berbagai tipe',
    'semua tipe',
    'semua motor',
    'all',
  };

  static List<String> _tokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .split(' ')
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();
  }

  /// "Universal", "Berbagai tipe", "Semua motor", dan sejenisnya.
  static bool _isUniversalText(String bike) {
    final tokens = _tokens(bike);
    if (tokens.isEmpty) return false;
    return tokens.contains('universal') ||
        _universalTexts.contains(tokens.join(' ')) ||
        tokens.first == 'berbagai' ||
        tokens.first == 'semua';
  }

  /// Produk berlaku untuk semua motor.
  static bool isUniversal(Product product) {
    final bikes = splitCompatibleBikes(product.type);
    return bikes.isEmpty || bikes.any(_isUniversalText);
  }

  static bool _isSubset(List<String> a, List<String> b) =>
      a.isNotEmpty && a.every(b.contains);

  /// Entri produk yang hanya menyebut merek dan/atau jenis ("Honda Matic").
  static bool _isGroupEntry(List<String> entry) =>
      entry.any(_groupWords.containsKey) &&
      entry.every((t) => _brands.contains(t) || _groupWords.containsKey(t));

  /// (merek, jenis) motor yang diketik, bila ada model yang dikenal.
  static (String, String)? _identify(List<String> query) {
    for (final token in query) {
      final model = _models[token];
      if (model != null) return model;
    }
    return null;
  }

  static MotorFit _fitForEntry(String bike, List<String> query) {
    final entry = _tokens(bike);
    if (entry.isEmpty) return MotorFit.none;

    if (_isGroupEntry(entry)) {
      final groupWords = entry
          .where(_groupWords.containsKey)
          .map((t) => _groupWords[t]!);
      final brand = entry.where(_brands.contains).firstOrNull;

      // Motor diketik langsung sebagai jenis ("Honda Matic", "matic").
      if (_isSubset(entry, query) || _isSubset(query, entry)) {
        return MotorFit.group;
      }
      final known = _identify(query);
      if (known == null) return MotorFit.none;
      final (modelBrand, modelGroup) = known;
      final queryBrand = query.where(_brands.contains).firstOrNull;
      if (queryBrand != null && queryBrand != modelBrand) return MotorFit.none;
      if (!groupWords.contains(modelGroup)) return MotorFit.none;
      if (brand != null && brand != modelBrand) return MotorFit.none;
      return MotorFit.group;
    }

    return _isSubset(entry, query) || _isSubset(query, entry)
        ? MotorFit.exact
        : MotorFit.none;
  }

  /// Kecocokan [product] dengan [motor]. [motor] kosong = semua cocok
  /// (dihitung [MotorFit.exact]).
  static MotorFit fit(Product product, String motor) {
    final query = _tokens(motor);
    if (query.isEmpty) return MotorFit.exact;

    // Entri paling spesifik yang cocok menang (exact < group).
    MotorFit? best;
    for (final bike in splitCompatibleBikes(product.type)) {
      if (_isUniversalText(bike)) continue;
      final f = _fitForEntry(bike, query);
      if (f == MotorFit.none) continue;
      if (best == null || f.index < best.index) best = f;
    }
    if (best != null) return best;
    return isUniversal(product) ? MotorFit.universal : MotorFit.none;
  }

  /// Apakah [product] cocok dengan [motor]; produk universal ikut bila
  /// [includeUniversal].
  static bool matches(
    Product product,
    String motor, {
    bool includeUniversal = true,
  }) {
    final f = fit(product, motor);
    if (f == MotorFit.none) return false;
    return f != MotorFit.universal || includeUniversal;
  }

  /// Motor yang disebut khusus oleh produk (tanpa universal dan tanpa entri
  /// jenis seperti "Honda Matic"), untuk saran pilihan; urut abjad, tanpa
  /// duplikat.
  static List<String> knownMotors(Iterable<Product> products) {
    final seen = <String, String>{};
    for (final product in products) {
      for (final bike in splitCompatibleBikes(product.type)) {
        final tokens = _tokens(bike);
        if (tokens.isEmpty || _isUniversalText(bike) || _isGroupEntry(tokens)) {
          continue;
        }
        seen.putIfAbsent(tokens.join(' '), () => bike);
      }
    }
    final list = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
