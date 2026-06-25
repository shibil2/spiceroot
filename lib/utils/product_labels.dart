import '../data/models/product_model.dart';

abstract final class ProductLabels {
  static String primaryName(ProductModel p, bool showMalayalam) {
    return showMalayalam ? p.nameEn : p.nameEn;
  }

  static String? secondaryName(ProductModel p, bool showMalayalam) {
    return showMalayalam ? p.nameMl : null;
  }

  static String displayTitle(ProductModel p, bool showMalayalam) {
    if (showMalayalam) return '${p.nameEn} · ${p.nameMl}';
    return p.nameEn;
  }
}
