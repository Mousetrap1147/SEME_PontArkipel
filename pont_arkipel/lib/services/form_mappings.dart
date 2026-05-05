class FormMappings {
  static const Map<String, int> _typeMenageCategory = {
    'Personne seule': 1,
    'Couple': 2,
    'Monoparentale': 3,
    'Famille': 4,
  };

  static String? sourceRevenu(String? excel) => _clean(excel);
  static String? raisonRecours(String? excel) => _clean(excel);
  static String? habitation(String? excel) => _clean(excel);

  /// Falls back to 5 (Autre ménage) for unrecognized values.
  static int typeMenageCategoryId(String? excel) {
    final s = _clean(excel);
    if (s == null) return 5;
    return _typeMenageCategory[s] ?? 5;
  }

  static bool parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    final s = v.toString().trim();
    return s == '1' || s.toLowerCase() == 'true';
  }

  static String? _clean(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return (t.isEmpty || t == '0') ? null : t;
  }
}
