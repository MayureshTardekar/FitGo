/// Metric vs imperial presentation.
///
/// Canonical values are always stored as kilograms (weight) and millilitres
/// (volume). Convert only at the UI edge.
enum UnitSystem { metric, imperial }

extension UnitSystemX on UnitSystem {
  bool get isMetric => this == UnitSystem.metric;

  String get weightLabel => isMetric ? 'kg' : 'lb';

  String get volumeLabel => isMetric ? 'ml' : 'fl oz';

  String get heightLabel => isMetric ? 'cm' : 'in';

  double weightFromKg(double kg) => isMetric ? kg : kg * 2.2046226218;

  double weightToKg(double value) => isMetric ? value : value / 2.2046226218;

  double volumeFromMl(double ml) => isMetric ? ml : ml / 29.5735;

  double volumeToMl(double value) => isMetric ? value : value * 29.5735;

  /// Converts centimetres to inches for imperial height fields.
  double heightFromCm(double cm) => isMetric ? cm : cm / 2.54;

  /// Converts a height field value back to centimetres.
  double heightToCm(double value) => isMetric ? value : value * 2.54;

  String formatWeight(double kg, {int decimals = 1}) {
    final value = weightFromKg(kg);
    return '${value.toStringAsFixed(decimals)} $weightLabel';
  }

  String formatVolume(double ml) {
    final value = volumeFromMl(ml);
    final decimals = isMetric ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} $volumeLabel';
  }
}

/// Formats a centimetre value as feet and inches.
String formatFeetInches(double cm) {
  final totalInches = cm / 2.54;
  final feet = totalInches ~/ 12;
  final inches = (totalInches % 12).round();
  if (inches == 12) return '${feet + 1} ft 0 in';
  return '$feet ft $inches in';
}
