import 'package:fitgo/core/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnitSystem conversion', () {
    test('metric passes kilograms and millilitres through', () {
      const system = UnitSystem.metric;
      expect(system.weightFromKg(70), 70);
      expect(system.weightToKg(70), 70);
      expect(system.volumeFromMl(500), 500);
      expect(system.volumeToMl(500), 500);
      expect(system.weightLabel, 'kg');
      expect(system.volumeLabel, 'ml');
    });

    test('imperial converts kilograms to pounds and back', () {
      const system = UnitSystem.imperial;
      final pounds = system.weightFromKg(70);
      expect(pounds, closeTo(154.32, 0.01));
      expect(system.weightToKg(pounds), closeTo(70, 0.0001));
      expect(system.weightLabel, 'lb');
    });

    test('imperial converts millilitres to fluid ounces and back', () {
      const system = UnitSystem.imperial;
      final ounces = system.volumeFromMl(500);
      expect(ounces, closeTo(16.91, 0.01));
      expect(system.volumeToMl(ounces), closeTo(500, 0.0001));
      expect(system.volumeLabel, 'fl oz');
    });

    test('height converts centimetres to inches and back', () {
      const system = UnitSystem.imperial;
      final inches = system.heightFromCm(180);
      expect(inches, closeTo(70.87, 0.01));
      expect(system.heightToCm(inches), closeTo(180, 0.0001));
    });

    test('formatWeight and formatVolume include the right unit', () {
      expect(UnitSystem.metric.formatWeight(70), '70.0 kg');
      expect(UnitSystem.imperial.formatVolume(500), '16.9 fl oz');
      expect(formatFeetInches(180), '5 ft 11 in');
    });
  });
}
