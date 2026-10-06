part of 'main.dart';

const velocityKeys = [
  'surface',
  '015',
  '02',
  '04',
  '05',
  '06',
  '08',
  '085',
  'bottom',
];
const methodKeys = [
  'six',
  'five',
  'three',
  'two',
  'one06',
  'one02',
  'oneSurface',
  'threeSpecial',
  'twoSpecial',
  'oneSpecial',
];

Map<String, Map<String, double>> presetWeights(String preset) {
  final weights = <String, Map<String, double>>{
    'six': {'surface': 1, '02': 2, '04': 2, '06': 2, '08': 2, 'bottom': 1},
    'five': {'surface': 1, '02': 3, '06': 3, '08': 2, 'bottom': 1},
    'three': {'02': 1, '06': 2, '08': 1},
    'two': {'02': 1, '08': 1},
    'one06': {'06': 1},
    'one02': {'02': .88},
    'oneSurface': {'surface': .85},
    'threeSpecial': {'015': 1, '05': 1, '085': 1},
    'twoSpecial': {'02': 1, '08': 1},
    'oneSpecial': {'05': preset == 'wmo' ? .88 : .9},
  };
  if (preset == 'mi') {
    weights['five'] = {
      'surface': .05,
      '02': .347,
      '06': .347,
      '08': .173,
      'bottom': .083,
    };
    weights.remove('one02');
    weights.remove('oneSurface');
  }
  return weights;
}

class CalculationConfig {
  CalculationConfig({
    this.preset = 'wmo',
    List<Map<String, Map<String, double>>>? custom,
  }) : custom = custom ?? List.generate(3, (_) => presetWeights('wmo'));
  String preset;
  final List<Map<String, Map<String, double>>> custom;
  bool get isCustom => preset.startsWith('custom');
  Map<String, Map<String, double>> get weights =>
      isCustom ? custom[int.parse(preset.substring(6))] : presetWeights(preset);
  CalculationConfig copy() => CalculationConfig.fromJson(toJson());
  Map<String, dynamic> toJson() => {'preset': preset, 'custom': custom};
  factory CalculationConfig.fromJson(Map<String, dynamic> json) {
    final preset = json['preset'] as String? ?? 'wmo';
    if (![
      'wmo',
      'mi',
      'combined',
      'custom0',
      'custom1',
      'custom2',
    ].contains(preset)) {
      throw const FormatException('Unknown calculation preset');
    }
    final result = CalculationConfig(preset: preset);
    final profiles = json['custom'] as List?;
    if (profiles != null) {
      if (profiles.length != 3) {
        throw const FormatException('Expected three profiles');
      }
      for (var i = 0; i < 3; i++) {
        final profile = profiles[i] as Map;
        for (final method in result.custom[i].entries) {
          final values = profile[method.key] as Map?;
          if (values == null) throw const FormatException('Missing method');
          for (final key in method.value.keys.toList()) {
            final value = (values[key] as num?)?.toDouble();
            if (!validWeight(value)) {
              throw const FormatException('Invalid weight');
            }
            method.value[key] = value!;
          }
        }
      }
    }
    return result;
  }
}

bool validWeight(double? value) =>
    value != null &&
    value.isFinite &&
    value > 0 &&
    value <= 1000 &&
    (value * 1000 - (value * 1000).round()).abs() < 1e-7;
double? parseWeight(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(normalized)) return null;
  final value = double.tryParse(normalized);
  return validWeight(value) ? value : null;
}

class VelocityCalculation {
  VelocityCalculation(this.method, this.weights, this.divisor, this.value);
  final String method;
  final Map<String, double> weights;
  final double divisor;
  final double value;
}

VelocityCalculation? calculateVelocity(
  Map<String, double?> values,
  CalculationConfig config, {
  required bool special,
}) {
  final priority = special
      ? ['six', 'threeSpecial', 'twoSpecial', 'oneSpecial']
      : ['six', 'five', 'three', 'two', 'one06', 'one02', 'oneSurface'];
  final formulas = config.weights;
  for (final method in priority) {
    final weights = formulas[method];
    if (weights == null ||
        weights.keys.any(
          (key) => values[key] == null || !values[key]!.isFinite,
        )) {
      continue;
    }
    final divisor = weights.length == 1
        ? 1.0
        : weights.values.fold<double>(0, (a, b) => a + b);
    final sum = weights.entries.fold<double>(
      0,
      (sum, e) => sum + e.value * values[e.key]!,
    );
    return VelocityCalculation(
      method,
      Map.of(weights),
      divisor,
      roundTo(sum / divisor, 4),
    );
  }
  return null;
}

extension VerticalCalculation on VerticalPoint {
  Map<String, VelocityPoint> get velocityPoints => {
    'surface': uSurface,
    '015': u015,
    '02': u02,
    '04': u04,
    '05': u05,
    '06': u06,
    '08': u08,
    '085': u085,
    'bottom': uBottom,
  };
  CalculationConfig? get effectiveConfig =>
      individualConfig ?? measurementConfig;
  bool get special => iceCover || localSpecial;
  VelocityCalculation? get calculation => effectiveConfig == null
      ? null
      : calculateVelocity(
          velocityPoints.map((key, point) => MapEntry(key, point.value)),
          effectiveConfig!,
          special: special,
        );
}

// Returns a location only when the agreed instrument-clearance rule permits a hint.
double? instrumentDepth(
  String key,
  double h,
  double diameter, {
  bool special = false,
}) {
  if (!h.isFinite || !diameter.isFinite || h <= 0 || diameter <= 0) return null;
  final multiple = special
      ? switch (key) {
          '05' => 1.2,
          '015' || '02' || '08' || '085' => 5.0,
          _ => 10.0,
        }
      : switch (key) {
          '06' => 1.2,
          'surface' || 'bottom' || '04' => 10.0,
          '02' || '08' => 5.0,
          '015' || '085' => 7.0,
          _ => 1.5,
        };
  if (h + 1e-10 < multiple * diameter) return null;
  final z = switch (key) {
    'surface' => diameter / 2 + .01,
    'bottom' => h - diameter / 2 - .01,
    _ => h * (double.parse('0.${key.substring(1)}')),
  };
  return z >= 0 && z <= h ? z : null;
}

String compactDischarge(double? value) {
  if (value == null) return '-';
  if (value == 0) return '0';
  if (value.abs() < .0001) {
    return value < 0 ? value.toStringAsExponential(2) : '<0.0001';
  }
  if (value.abs() >= 1e7) return value.toStringAsExponential(3);
  final places = (3 - (math.log(value.abs()) / math.ln10).floor()).clamp(0, 4);
  final result = value.toStringAsFixed(places);
  return result.contains('.')
      ? result.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : result;
}
