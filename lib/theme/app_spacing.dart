/// Shared spacing scale so paddings/gaps stop being ad-hoc magic numbers.
/// Values chosen to match what was already the most common spacing in the
/// app, so adopting them is mostly a rename, not a relayout.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
}

/// Shared corner-radius scale. `md`/`lg` intentionally match the values
/// already used almost everywhere (inputs/buttons at 12, cards at 16).
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999.0;
}
