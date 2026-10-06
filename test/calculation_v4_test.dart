import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppSettings.current = AppSettings(language: 'ru'));
  test('WMO hand-calculated normal and special examples', () {
    final config = CalculationConfig();
    final examples = <(Map<String, double?>, bool, String, double)>[
      ({'06': 1.2}, false, 'one06', 1.2),
      ({'surface': 2}, false, 'oneSurface', 1.7),
      ({'02': 2}, false, 'one02', 1.76),
      ({'02': 2, '08': 1}, false, 'two', 1.5),
      ({'02': 2, '06': 1, '08': .4}, false, 'three', 1.1),
      (
        {'surface': 2, '02': 1.8, '06': 1.2, '08': .8, 'bottom': .4},
        false,
        'five',
        1.3,
      ),
      (
        {'surface': 2, '02': 1.8, '04': 1.5, '06': 1.2, '08': .8, 'bottom': .4},
        false,
        'six',
        1.3,
      ),
      ({'015': 1.8, '05': 1.2, '085': .6}, true, 'threeSpecial', 1.2),
      ({'02': 1.8, '08': .8}, true, 'twoSpecial', 1.3),
      ({'05': 2}, true, 'oneSpecial', 1.76),
    ];
    for (final example in examples) {
      final result = calculateVelocity(
        example.$1,
        config,
        special: example.$2,
      )!;
      expect(result.method, example.$3);
      expect(result.value, closeTo(example.$4, 1e-10));
    }
  });
  test('MI and combined differ only at intended formulas', () {
    final values = {
      'surface': 2.0,
      '02': 1.8,
      '06': 1.2,
      '08': .8,
      'bottom': .4,
    };
    expect(
      calculateVelocity(
        values,
        CalculationConfig(preset: 'mi'),
        special: false,
      )!.value,
      1.3126,
    );
    expect(
      calculateVelocity(
        values,
        CalculationConfig(preset: 'combined'),
        special: false,
      )!.value,
      1.3,
    );
    for (final preset in ['mi', 'combined']) {
      expect(
        calculateVelocity(
          {'05': 2},
          CalculationConfig(preset: preset),
          special: true,
        )!.value,
        1.8,
      );
    }
    expect(
      calculateVelocity(
        {'surface': 2, '02': 1},
        CalculationConfig(preset: 'mi'),
        special: false,
      ),
      isNull,
    );
  });
  test('Priority follows conditions, not number of unrelated points', () {
    final v = {for (final key in velocityKeys) key: 1.0};
    final config = CalculationConfig();
    expect(calculateVelocity(v, config, special: true)!.method, 'six');
    v.remove('04');
    expect(calculateVelocity(v, config, special: false)!.method, 'five');
    expect(calculateVelocity(v, config, special: true)!.method, 'threeSpecial');
    v.remove('015');
    expect(calculateVelocity(v, config, special: true)!.method, 'twoSpecial');
    v.remove('02');
    expect(calculateVelocity(v, config, special: true)!.method, 'oneSpecial');
    v.remove('05');
    expect(calculateVelocity(v, config, special: true), isNull);
  });
  test('Zero is a measurement; empty and non-finite are not', () {
    for (final special in [false, true]) {
      final key = special ? '05' : '06';
      expect(
        calculateVelocity(
          {key: 0},
          CalculationConfig(),
          special: special,
        )!.value,
        0,
      );
      for (final value in [null, double.nan, double.infinity]) {
        expect(
          calculateVelocity(
            {key: value},
            CalculationConfig(),
            special: special,
          ),
          isNull,
        );
      }
    }
    expect(
      calculateVelocity(
        {'02': -1, '08': 1},
        CalculationConfig(),
        special: false,
      )!.value,
      0,
    );
  });
  test('Custom single-point weights are never cancelled by divisor', () {
    final config = CalculationConfig(preset: 'custom0');
    config.weights['one06']!['06'] = .5;
    final result = calculateVelocity({'06': 2}, config, special: false)!;
    expect(result.divisor, 1);
    expect(result.value, 1);
    config.weights['two']!['02'] = 3;
    expect(
      calculateVelocity({'02': 2, '08': 1}, config, special: false)!.value,
      1.75,
    );
  });
  test('Weight validation includes exact limits and rejected formats', () {
    for (final text in ['0.001', '0,001', '1000', '1000.000', '1.123']) {
      expect(parseWeight(text), isNotNull, reason: text);
    }
    for (final text in [
      '',
      '0',
      '-1',
      '1000.001',
      '1.1234',
      '1e2',
      'NaN',
      'Infinity',
      '1,2.3',
      '.',
    ]) {
      expect(parseWeight(text), isNull, reason: text);
    }
    final json = CalculationConfig().toJson();
    ((json['custom'] as List)[0] as Map)['two']['02'] = 0.0;
    expect(() => CalculationConfig.fromJson(json), throwsFormatException);
  });
  test('App, measurement and individual snapshots are independent', () {
    AppSettings.current.defaults.preset = 'custom0';
    final m = WdcMeasurement.empty()..verticals.addAll(sample().verticals);
    m.bindCalculation();
    final v = m.verticals[1];
    AppSettings.current.defaults.weights['five']!['surface'] = 10;
    expect(m.calculationConfig!.weights['five']!['surface'], 1);
    v.individualConfig = m.calculationConfig!.copy();
    m.calculationConfig!.weights['five']!['surface'] = 3;
    expect(v.effectiveConfig!.weights['five']!['surface'], 1);
    v.individualConfig = null;
    expect(v.effectiveConfig!.weights['five']!['surface'], 3);
    final loaded = WdcMeasurement.fromJson(jsonDecode(jsonEncode(m.toJson())));
    expect(loaded.verticals[1].effectiveConfig!.weights['five']!['surface'], 3);
    loaded.calculationConfig!.weights['five']!['surface'] = 9;
    expect(m.calculationConfig!.weights['five']!['surface'], 3);
  });
  test(
    'Every legacy point subset retains the 3.3.1 algorithm after reload',
    () {
      for (var mask = 0; mask < 32; mask++) {
        final m = sample();
        final v = m.verticals[1];
        final points = [v.uSurface, v.u02, v.u06, v.u08, v.uBottom];
        const values = [1.7, 1.9, 1.4, .8, .3];
        for (var i = 0; i < 5; i++) {
          points[i].value = mask & (1 << i) == 0 ? null : values[i];
        }
        double? expected;
        if (mask == 31) {
          expected = 1.35;
        } else if (mask & 14 == 14) {
          expected = 1.375;
        } else if (mask & 10 == 10) {
          expected = 1.35;
        } else if (mask & 4 != 0) {
          expected = 1.4;
        }
        final old = m.toJson()
          ..remove('calculationConfig')
          ..remove('schemaVersion')
          ..remove('iceCover');
        final restored = WdcMeasurement.fromJson(jsonDecode(jsonEncode(old)));
        expect(restored.calculationConfig, isNull);
        expect(
          restored.verticals[1].avgVelocity,
          expected,
          reason: 'mask=$mask',
        );
        expect(
          WdcMeasurement.fromJson(restored.toJson()).verticals[1].avgVelocity,
          expected,
        );
      }
    },
  );
  test(
    'Ice changes perimeter only; local phenomena do not change geometry',
    () {
      final m = sample()..calculationConfig = CalculationConfig();
      m.verticals[1].u05.value = 1;
      recalcAll(m, finalCalculation: true);
      final p = m.wettedPerimeter!;
      final area = m.area;
      m.verticals[1].localSpecial = true;
      recalcAll(m, finalCalculation: true);
      expect(m.wettedPerimeter, p);
      m.iceCover = true;
      recalcAll(m, finalCalculation: true);
      expect(m.wettedPerimeter, closeTo(p + 4, .001));
      expect(m.area, area);
      expect(m.hydraulicRadius, closeTo(area! / (p + 4), .001));
      m.iceCover = false;
      m.verticals[1].localSpecial = false;
      recalcAll(m, finalCalculation: true);
      expect(m.wettedPerimeter, p);
      expect(m.verticals[1].u05.value, 1);
    },
  );
  test('Incomplete speed vertical cannot silently disappear from new Q', () {
    final m = sample()..calculationConfig = CalculationConfig();
    m.verticals.add(
      VerticalPoint(id: 'empty', distance: 3, depth1: 1, isSpeedVertical: true),
    );
    recalcAll(m, finalCalculation: true);
    expect(m.discharge, isNull);
    m.verticals.lastWhere((v) => v.id == 'empty').u06.value = 0;
    recalcAll(m, finalCalculation: true);
    expect(m.discharge, isNotNull);
    expect(
      m.verticals
          .where((v) => v.isSpeedVertical)
          .every((v) => v.partialDischarge != null),
      isTrue,
    );
  });
  test('Formula and condition changes never alter field timestamps', () {
    final m = sample()..calculationConfig = CalculationConfig();
    final times = measurementTimes(m);
    final pointTime = m.verticals[1].u06.changedAt;
    m.calculationConfig!.preset = 'mi';
    m.iceCover = true;
    recalcAll(m, finalCalculation: true);
    expect(measurementTimes(m), times);
    expect(m.verticals[1].u06.changedAt, pointTime);
  });
  test('Instrument hints respect all threshold boundaries', () {
    for (final (key, multiple) in [
      ('015', 7.0),
      ('085', 7.0),
      ('02', 5.0),
      ('08', 5.0),
      ('04', 10.0),
      ('surface', 10.0),
      ('bottom', 10.0),
      ('06', 1.2),
      ('05', 1.5),
    ]) {
      expect(
        instrumentDepth(key, multiple * .05 - .00001, .05),
        isNull,
        reason: key,
      );
      final z = instrumentDepth(key, multiple * .05, .05)!;
      expect(z, inInclusiveRange(0, multiple * .05));
      expect(instrumentDepth(key, multiple * .05 + .00001, .05), isNotNull);
    }
    expect(instrumentDepth('015', 1, .05), .15);
    expect(instrumentDepth('085', 1, .05), .85);
    expect(instrumentDepth('06', 1, 0), isNull);
  });
  test(
    'Compact discharge protects small nonzero values and never changes data',
    () {
      expect(compactDischarge(.00001), '<0.0001');
      expect(compactDischarge(0), '0');
      expect(compactDischarge(null), '-');
      expect(compactDischarge(12.3456), '12.35');
      expect(compactDischarge(1234.56), '1235');
      expect(compactDischarge(.123456), '0.1235');
    },
  );
  test('Exports identify only used formulas, retain zeros and user text', () {
    final m = sample()
      ..calculationConfig = CalculationConfig()
      ..river = 'Берег'
      ..comment = 'Да; "Нет"\nRiver';
    m.verticals[1].u04.value = 0;
    recalcAll(m, finalCalculation: true);
    final groups = usedFormulaGroups(m);
    expect(groups.length, 1);
    expect(usedCalculation(m.verticals[1])!.method, 'six');
    final ru = csvContent(m);
    expect(ru, contains('U0.4h, м/с'));
    expect(ru, contains('F1'));
    expect(ru, contains('"Да; ""Нет""\nRiver"'));
    AppSettings.current.language = 'en';
    final en = csvContent(m);
    expect(en.split('\n').first, isNot(matches(RegExp('[А-Яа-я]'))));
    expect(en, contains('Берег'));
    expect(en, contains('"Да; ""Нет""\nRiver"'));
    expect(en, contains('WMO No. 168'));
    expect(m.river, 'Берег');
  });
}
