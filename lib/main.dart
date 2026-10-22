import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart' as arc;
import 'package:crypto/crypto.dart' as crypto;
import 'package:file_selector/file_selector.dart' as fs;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

part 'features_v31.dart';
part 'calculation_v4.dart';
part 'settings_v4.dart';
part 'localization_v4.dart';
part 'exports_v4.dart';
part 'presentation_v41.dart';
part 'transfer_v42.dart';
part 'version_44.dart';
part 'about_44.dart';
part 'home_screen.dart';
part 'sounding_screen.dart';
part 'velocity_screen.dart';
part 'result_screen.dart';
part 'cross_section_painter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Roboto',
    ], await rootBundle.loadString('assets/fonts/LICENSE-Roboto.txt'));
  });
  await AppSettings.load();
  runApp(const WaterDischargeApp());
}

class WaterDischargeApp extends StatefulWidget {
  const WaterDischargeApp({super.key});
  @override
  State<WaterDischargeApp> createState() => _WaterDischargeAppState();
}

class _WaterDischargeAppState extends State<WaterDischargeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (AppSettings.current.language == 'system') AppSettings.revision.value++;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppSettings.revision,
      builder: (context, revision, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(appLanguage),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        title: tr('Калькулятор Расходов Воды'),
        themeMode: switch (previewTheme44 ?? AppSettings.current.theme) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        },
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF80C9EE),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF101B24),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: const Color(0xFF1A2B37),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1A2B37),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E86C1),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF4FAFF),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFDDF1FF),
            foregroundColor: Colors.black,
            centerTitle: false,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: Colors.white,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 1,
          ),
        ),
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(top: false, child: child ?? const SizedBox.shrink()),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

// =============================
// Helpers
// =============================

String uid() => DateTime.now().microsecondsSinceEpoch.toString();

String nowIso() => DateTime.now().toIso8601String();

String dtHuman(DateTime dt) => DateFormat('dd.MM.yyyy HH:mm:ss').format(dt);

String dateHuman(DateTime dt) => DateFormat('dd.MM.yyyy').format(dt);

String fileDt(DateTime dt) => DateFormat('yyyy_MM_dd&HH_mm_ss').format(dt);

DateTime? parseHumanDate(String input) {
  final t = input.trim();
  if (t.isEmpty) return null;
  try {
    return DateFormat('dd.MM.yyyy').parseStrict(t);
  } catch (_) {
    return null;
  }
}

String humanFromIso(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  return dt == null ? '' : dtHuman(dt);
}

double? parseNumRu(String value) {
  final t = value.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

double roundTo(double value, int digits) {
  final p = math.pow(10, digits).toDouble();
  final r = (value * p).roundToDouble() / p;
  if (r == -0.0) return 0;
  return r;
}

// Keep binary floating point artefacts out of editable decimal fields.
String inputNumber(double? value) => value == null
    ? ''
    : roundTo(value, 8).toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');

String fmtNum(double? value, int digits) {
  if (value == null || value.isNaN || value.isInfinite) return '';
  return roundTo(value, digits).toStringAsFixed(digits);
}

String fmtAdaptive(double? value, {int small = 2}) {
  if (value == null || value.isNaN || value.isInfinite) return tr('н/д');
  final a = value.abs();
  int digits = small;
  if (a >= 1000) {
    digits = 0;
  } else if (a >= 100) {
    digits = 0;
  } else if (a >= 10) {
    digits = math.max(0, small - 1);
  }
  return roundTo(value, digits).toStringAsFixed(digits);
}

String fmtAreaAdaptive(double? value) {
  if (value == null || value.isNaN || value.isInfinite) return tr('н/д');
  final a = value.abs();
  int digits = 4;
  if (a >= 1000) {
    digits = 0;
  } else if (a >= 100) {
    digits = 1;
  } else if (a >= 10) {
    digits = 2;
  } else if (a >= 1) {
    digits = 3;
  }
  return roundTo(value, digits).toStringAsFixed(digits);
}

String sanitizeFilenamePart(String s) {
  var v = s.trim().replaceAll(RegExp(r'[&/\\:*?"<>|\x00-\x1F]'), '');
  v = v.replaceAll(RegExp(r'\s+'), '_');
  if (v.isEmpty) v = tr('Без_названия');
  return v;
}

List<TextInputFormatter> get nameFormatters => [
  FilteringTextInputFormatter.deny(RegExp(r'[&/\\:*?"<>|\x00-\x1F]')),
  LengthLimitingTextInputFormatter(32),
];

final numericFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9,\.\-]'),
);

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String noText = 'Нет',
  String yesText = 'Да',
  bool yesIsPrimary = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          style: !yesIsPrimary
              ? TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green.shade700,
                )
              : null,
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr(noText)),
        ),
        TextButton(
          style: yesIsPrimary
              ? TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green.shade700,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr(yesText)),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<double?> editNumberDialog(
  BuildContext context, {
  required String title,
  double? initial,
  String? helper,
  bool allowEmpty = false,
  ValueChanged<double?>? onValueChanged,
  Future<bool> Function(double?)? beforeSave,
}) async {
  final c = TextEditingController(text: inputNumber(initial));
  final result = await showDialog<({double? value})>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: [numericFormatter],
        decoration: InputDecoration(helperText: helper),
        onChanged: (text) {
          final value = parseNumRu(text);
          if (value != null) onValueChanged?.call(value);
        },
        onSubmitted: (_) async {
          final v = parseNumRu(c.text);
          if (v == null && (!allowEmpty || c.text.trim().isNotEmpty)) return;
          if (beforeSave != null && !await beforeSave(v)) return;
          if (context.mounted) Navigator.pop(context, (value: v));
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (value: double.nan)),
          child: Text(tr('Отмена')),
        ),
        TextButton(
          onPressed: () async {
            final v = parseNumRu(c.text);
            if (v == null && (!allowEmpty || c.text.trim().isNotEmpty)) return;
            if (beforeSave != null && !await beforeSave(v)) return;
            if (context.mounted) Navigator.pop(context, (value: v));
          },
          child: Text(tr('Сохранить')),
        ),
      ],
    ),
  );
  return result == null ? double.nan : result.value;
}

Future<String?> editTextDialog(
  BuildContext context, {
  required String title,
  String? initial,
  int maxLength = 32,
}) async {
  final c = TextEditingController(text: initial ?? '');
  final result = await showDialog<String?>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: maxLength,
        decoration: const InputDecoration(counterText: ''),
        onSubmitted: (_) => Navigator.pop(context, c.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(tr('Отмена')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, c.text.trim()),
          child: Text(tr('Сохранить')),
        ),
      ],
    ),
  );
  return result;
}

// =============================
// Data model
// =============================

class VelocityPoint {
  VelocityPoint({this.value, this.changedAt});

  double? value;
  String? changedAt;

  Map<String, dynamic> toJson() => {'value': value, 'changedAt': changedAt};

  factory VelocityPoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VelocityPoint();
    return VelocityPoint(
      value: (json['value'] as num?)?.toDouble(),
      changedAt: json['changedAt'] as String?,
    );
  }
}

class VerticalPoint {
  VerticalPoint({
    required this.id,
    this.bank,
    this.distance,
    this.depth1,
    this.depth1At,
    this.depth2,
    this.depth2At,
    this.bottomType = '',
    this.iceThicknessCm,
    this.isSpeedVertical = false,
    VelocityPoint? uSurface,
    VelocityPoint? u015,
    VelocityPoint? u04,
    VelocityPoint? u05,
    VelocityPoint? u085,
    this.localSpecial = false,
    this.individualConfig,
    VelocityPoint? u02,
    VelocityPoint? u06,
    VelocityPoint? u08,
    VelocityPoint? uBottom,
    this.avgDepth,
    this.areaBetween,
    this.wettedBetween,
    this.correctedDepth,
    this.correctedAreaBetween,
    this.sectionArea,
    this.partialDischarge,
  }) : uSurface = uSurface ?? VelocityPoint(),
       u015 = u015 ?? VelocityPoint(),
       u04 = u04 ?? VelocityPoint(),
       u05 = u05 ?? VelocityPoint(),
       u085 = u085 ?? VelocityPoint(),
       u02 = u02 ?? VelocityPoint(),
       u06 = u06 ?? VelocityPoint(),
       u08 = u08 ?? VelocityPoint(),
       uBottom = uBottom ?? VelocityPoint();

  String id;
  String? bank; // ЛБ / ПБ / null
  double? distance;
  double? depth1;
  String? depth1At;
  double? depth2;
  String? depth2At;
  String bottomType;
  double? iceThicknessCm;
  bool isSpeedVertical;

  bool localSpecial;
  bool iceCover = false;
  CalculationConfig? individualConfig;
  CalculationConfig? measurementConfig;
  VelocityPoint u015;
  VelocityPoint u04;
  VelocityPoint u05;
  VelocityPoint u085;
  VelocityPoint uSurface;
  VelocityPoint u02;
  VelocityPoint u06;
  VelocityPoint u08;
  VelocityPoint uBottom;

  double? avgDepth;
  double? areaBetween;
  double? wettedBetween;
  double? correctedDepth;
  double? correctedAreaBetween;
  double? sectionArea;
  double? partialDischarge;

  double? get avgVelocity {
    if (effectiveConfig != null) return calculation?.value;
    final a = uSurface.value;
    final b = u02.value;
    final c = u06.value;
    final d = u08.value;
    final e = uBottom.value;

    if ([a, b, c, d, e].every((x) => x != null)) {
      return roundTo(0.1 * (a! + 3 * b! + 3 * c! + 2 * d! + e!), 4);
    }
    if (b != null && c != null && d != null) {
      return roundTo(0.25 * (b + 2 * c + d), 4);
    }
    if (b != null && d != null && c == null) {
      return roundTo(0.5 * (b + d), 4);
    }
    if (c != null && !(b != null && d != null)) {
      return roundTo(c, 4);
    }
    return null;
  }

  void clearVelocities() {
    isSpeedVertical = false;
    for (final point in velocityPoints.values) {
      point.value = null;
      point.changedAt = null;
    }
    individualConfig = null;
    localSpecial = false;
    uSurface = VelocityPoint();
    u02 = VelocityPoint();
    u06 = VelocityPoint();
    u08 = VelocityPoint();
    uBottom = VelocityPoint();
    sectionArea = null;
    partialDischarge = null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bank': bank,
    'distance': distance,
    'depth1': depth1,
    'depth1At': depth1At,
    'depth2': depth2,
    'depth2At': depth2At,
    'bottomType': bottomType,
    if (iceThicknessCm != null) 'iceThicknessCm': iceThicknessCm,
    'isSpeedVertical': isSpeedVertical,
    'localSpecial': localSpecial,
    'individualConfig': individualConfig?.toJson(),
    'u015': u015.toJson(),
    'u04': u04.toJson(),
    'u05': u05.toJson(),
    'u085': u085.toJson(),
    'uSurface': uSurface.toJson(),
    'u02': u02.toJson(),
    'u06': u06.toJson(),
    'u08': u08.toJson(),
    'uBottom': uBottom.toJson(),
    'avgDepth': avgDepth,
    'areaBetween': areaBetween,
    'wettedBetween': wettedBetween,
    'correctedDepth': correctedDepth,
    'correctedAreaBetween': correctedAreaBetween,
    'sectionArea': sectionArea,
    'partialDischarge': partialDischarge,
  };

  factory VerticalPoint.fromJson(Map<String, dynamic> json) => VerticalPoint(
    id: json['id'] as String? ?? uid(),
    bank: json['bank'] as String?,
    distance: (json['distance'] as num?)?.toDouble(),
    depth1: (json['depth1'] as num?)?.toDouble(),
    depth1At: json['depth1At'] as String?,
    depth2: (json['depth2'] as num?)?.toDouble(),
    depth2At: json['depth2At'] as String?,
    bottomType: json['bottomType'] as String? ?? '',
    iceThicknessCm: (json['iceThicknessCm'] as num?)?.toDouble(),
    isSpeedVertical: json['isSpeedVertical'] as bool? ?? false,
    localSpecial: json['localSpecial'] as bool? ?? false,
    individualConfig: json['individualConfig'] == null
        ? null
        : CalculationConfig.fromJson(
            json['individualConfig'] as Map<String, dynamic>,
          ),
    u015: VelocityPoint.fromJson(json['u015'] as Map<String, dynamic>?),
    u04: VelocityPoint.fromJson(json['u04'] as Map<String, dynamic>?),
    u05: VelocityPoint.fromJson(json['u05'] as Map<String, dynamic>?),
    u085: VelocityPoint.fromJson(json['u085'] as Map<String, dynamic>?),
    uSurface: VelocityPoint.fromJson(json['uSurface'] as Map<String, dynamic>?),
    u02: VelocityPoint.fromJson(json['u02'] as Map<String, dynamic>?),
    u06: VelocityPoint.fromJson(json['u06'] as Map<String, dynamic>?),
    u08: VelocityPoint.fromJson(json['u08'] as Map<String, dynamic>?),
    uBottom: VelocityPoint.fromJson(json['uBottom'] as Map<String, dynamic>?),
    avgDepth: (json['avgDepth'] as num?)?.toDouble(),
    areaBetween: (json['areaBetween'] as num?)?.toDouble(),
    wettedBetween: (json['wettedBetween'] as num?)?.toDouble(),
    correctedDepth: (json['correctedDepth'] as num?)?.toDouble(),
    correctedAreaBetween: (json['correctedAreaBetween'] as num?)?.toDouble(),
    sectionArea: (json['sectionArea'] as num?)?.toDouble(),
    partialDischarge: (json['partialDischarge'] as num?)?.toDouble(),
  );
}

class WdcMeasurement {
  WdcMeasurement({
    required this.id,
    required this.createdAt,
    this.utcOffsetMinutes,
    this.calculationConfig,
    this.archiveOriginId,
    this.importedCopy = false,
    CalculationConfig? initialCalculationConfig,
    bool initialConfigCaptured = false,
    this.iceCover = false,
    this.geometry44 = false,
    this.leftExtrapolation = false,
    this.rightExtrapolation = false,
    this.requireIceThickness = false,
    this.completed = false,
    this.river = '',
    this.site = '',
    this.project = '',
    this.levelSoundingStart,
    this.levelSoundingStartAt,
    this.levelSoundingEnd,
    this.levelSoundingEndAt,
    this.levelVelocityStart,
    this.levelVelocityStartAt,
    this.levelVelocityEnd,
    this.levelVelocityEndAt,
    this.meanSoundingLevel,
    this.meanVelocityLevel,
    this.levelCorrection,
    this.latitude,
    this.longitude,
    this.rotorDiameter,
    this.width,
    this.area,
    this.wettedPerimeter,
    this.meanDepth,
    this.maxDepth,
    this.hydraulicRadius,
    this.bankCoeffLeft,
    this.bankCoeffRight,
    this.discharge,
    this.comment = '',
    List<VerticalPoint>? verticals,
    List<String>? warnings,
    List<MeasurementPhoto>? photos,
  }) : _initialCalculationConfig =
           (initialConfigCaptured
                   ? initialCalculationConfig
                   : calculationConfig)
               ?.copy(),
       verticals = verticals ?? [],
       warnings = warnings ?? [],
       photos = photos ?? [] {
    bindCalculation();
  }

  String id;
  String createdAt;
  final int? utcOffsetMinutes;
  CalculationConfig? calculationConfig;
  String? archiveOriginId;
  bool importedCopy;
  final CalculationConfig? _initialCalculationConfig;
  CalculationConfig? get initialCalculationConfig =>
      _initialCalculationConfig?.copy();
  bool iceCover;
  bool geometry44;
  bool leftExtrapolation;
  bool rightExtrapolation;
  // Historical metadata is retained for archive identity, never used to
  // require ice observations in 4.6.
  bool requireIceThickness;
  void bindCalculation() {
    for (final v in verticals) {
      v.measurementConfig = calculationConfig;
      v.iceCover = iceCover;
    }
  }

  bool completed;
  String river;
  String site;
  String project;

  double? levelSoundingStart;
  String? levelSoundingStartAt;
  double? levelSoundingEnd;
  String? levelSoundingEndAt;
  double? levelVelocityStart;
  String? levelVelocityStartAt;
  double? levelVelocityEnd;
  String? levelVelocityEndAt;
  double? meanSoundingLevel;
  double? meanVelocityLevel;
  double? levelCorrection;

  double? latitude;
  double? longitude;
  double? rotorDiameter;

  double? width;
  double? area;
  double? wettedPerimeter;
  double? meanDepth;
  double? maxDepth;
  double? hydraulicRadius;
  double? bankCoeffLeft;
  double? bankCoeffRight;
  double? discharge;
  String comment;

  List<VerticalPoint> verticals;
  List<String> warnings;
  List<MeasurementPhoto> photos;

  double? get meanFlowVelocity => area != null && area! > 0 && discharge != null
      ? discharge! / area!
      : null;

  String get titleRiver =>
      river.trim().isEmpty ? tr('Без названия реки') : river.trim();
  String get titleSite =>
      site.trim().isEmpty ? tr('Без названия створа') : site.trim();
  DateTime get createdDate => DateTime.tryParse(createdAt) ?? DateTime.now();

  bool get hasLeftBank => verticals.any((v) => v.bank == 'ЛБ');
  bool get hasRightBank => verticals.any((v) => v.bank == 'ПБ');
  bool get hasBothBanks => hasLeftBank && hasRightBank;
  VerticalPoint? get leftBank =>
      verticals.where((v) => v.bank == 'ЛБ').firstOrNull;
  VerticalPoint? get rightBank =>
      verticals.where((v) => v.bank == 'ПБ').firstOrNull;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt,
    'utcOffsetMinutes': utcOffsetMinutes,
    'calculationConfig': calculationConfig?.toJson(),
    'iceCover': iceCover,
    'schemaVersion':
        project.isNotEmpty ||
            [
              calculationConfig,
              _initialCalculationConfig,
              ...verticals.map((v) => v.individualConfig),
            ].any((config) => config?.hasIndependentSixWeights == true)
        ? 7
        : geometry44 || verticals.any((v) => v.iceThicknessCm != null)
        ? 6
        : 5,
    if (geometry44) 'geometry44': true,
    if (geometry44) 'leftExtrapolation': leftExtrapolation,
    if (geometry44) 'rightExtrapolation': rightExtrapolation,
    if (requireIceThickness) 'requireIceThickness': true,
    if (archiveOriginId != null) 'archiveOriginId': archiveOriginId,
    if (importedCopy) 'importedCopy': true,
    'initialCalculationConfig': _initialCalculationConfig?.toJson(),
    'completed': completed,
    'river': river,
    'site': site,
    if (project.isNotEmpty) 'project': project,
    'levelSoundingStart': levelSoundingStart,
    'levelSoundingStartAt': levelSoundingStartAt,
    'levelSoundingEnd': levelSoundingEnd,
    'levelSoundingEndAt': levelSoundingEndAt,
    'levelVelocityStart': levelVelocityStart,
    'levelVelocityStartAt': levelVelocityStartAt,
    'levelVelocityEnd': levelVelocityEnd,
    'levelVelocityEndAt': levelVelocityEndAt,
    'meanSoundingLevel': meanSoundingLevel,
    'meanVelocityLevel': meanVelocityLevel,
    'levelCorrection': levelCorrection,
    'latitude': latitude,
    'longitude': longitude,
    'rotorDiameter': rotorDiameter,
    'width': width,
    'area': area,
    'wettedPerimeter': wettedPerimeter,
    'meanDepth': meanDepth,
    'maxDepth': maxDepth,
    'hydraulicRadius': hydraulicRadius,
    'bankCoeffLeft': bankCoeffLeft,
    'bankCoeffRight': bankCoeffRight,
    'discharge': discharge,
    'comment': comment,
    'verticals': verticals.map((v) => v.toJson()).toList(),
    'warnings': warnings,
    'photos': photos.map((p) => p.toJson()).toList(),
  };

  factory WdcMeasurement.empty({double? lat, double? lon}) => WdcMeasurement(
    geometry44: true,
    id: uid(),
    createdAt: nowIso(),
    utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    calculationConfig: AppSettings.current.defaults.copy(),
    latitude: lat,
    longitude: lon,
  );

  factory WdcMeasurement.fromJson(Map<String, dynamic> json) => WdcMeasurement(
    id: json['id'] as String? ?? uid(),
    createdAt: json['createdAt'] as String? ?? nowIso(),
    utcOffsetMinutes: (json['utcOffsetMinutes'] as num?)?.toInt(),
    calculationConfig: json['calculationConfig'] == null
        ? null
        : CalculationConfig.fromJson(
            json['calculationConfig'] as Map<String, dynamic>,
          ),
    initialConfigCaptured: json.containsKey('initialCalculationConfig'),
    initialCalculationConfig: json['initialCalculationConfig'] == null
        ? null
        : CalculationConfig.fromJson(
            json['initialCalculationConfig'] as Map<String, dynamic>,
          ),
    archiveOriginId: json['archiveOriginId'] as String?,
    importedCopy: json['importedCopy'] as bool? ?? false,
    iceCover: json['iceCover'] as bool? ?? false,
    geometry44: json['geometry44'] == true,
    leftExtrapolation: json['leftExtrapolation'] == true,
    rightExtrapolation: json['rightExtrapolation'] == true,
    requireIceThickness: json['requireIceThickness'] == true,
    completed: json['completed'] as bool? ?? false,
    river: json['river'] as String? ?? '',
    site: json['site'] as String? ?? '',
    project: json['project'] as String? ?? '',
    levelSoundingStart: (json['levelSoundingStart'] as num?)?.toDouble(),
    levelSoundingStartAt: json['levelSoundingStartAt'] as String?,
    levelSoundingEnd: (json['levelSoundingEnd'] as num?)?.toDouble(),
    levelSoundingEndAt: json['levelSoundingEndAt'] as String?,
    levelVelocityStart: (json['levelVelocityStart'] as num?)?.toDouble(),
    levelVelocityStartAt: json['levelVelocityStartAt'] as String?,
    levelVelocityEnd: (json['levelVelocityEnd'] as num?)?.toDouble(),
    levelVelocityEndAt: json['levelVelocityEndAt'] as String?,
    meanSoundingLevel: (json['meanSoundingLevel'] as num?)?.toDouble(),
    meanVelocityLevel: (json['meanVelocityLevel'] as num?)?.toDouble(),
    levelCorrection: (json['levelCorrection'] as num?)?.toDouble(),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    rotorDiameter: (json['rotorDiameter'] as num?)?.toDouble(),
    width: (json['width'] as num?)?.toDouble(),
    area: (json['area'] as num?)?.toDouble(),
    wettedPerimeter: (json['wettedPerimeter'] as num?)?.toDouble(),
    meanDepth: (json['meanDepth'] as num?)?.toDouble(),
    maxDepth: (json['maxDepth'] as num?)?.toDouble(),
    hydraulicRadius: (json['hydraulicRadius'] as num?)?.toDouble(),
    bankCoeffLeft: (json['bankCoeffLeft'] as num?)?.toDouble(),
    bankCoeffRight: (json['bankCoeffRight'] as num?)?.toDouble(),
    discharge: (json['discharge'] as num?)?.toDouble(),
    comment: json['comment'] as String? ?? '',
    verticals: ((json['verticals'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VerticalPoint.fromJson)
        .toList(),
    warnings: ((json['warnings'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
    photos: ((json['photos'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MeasurementPhoto.fromJson)
        .toList(),
  );
}

extension FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

// =============================
// Storage and export
// =============================

class WdcStorage {
  WdcStorage._();
  static final WdcStorage instance = WdcStorage._();
  final savedMeasurement = ValueNotifier<WdcMeasurement?>(null);

  Future<Directory> get _baseDir async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory('${doc.path}/wdc_measurements');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(String id) async {
    final dir = await _baseDir;
    return File('${dir.path}/$id.json');
  }

  Future<void>? _writeQueue;

  Future<void> flush() async {
    await _writeQueue;
  }

  Future<void> save(WdcMeasurement measurement) {
    final snapshot = jsonEncode(measurement.toJson());
    final id = measurement.id;
    final previous = _writeQueue;
    final operation = (() async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          /* A failed save does not block later saves. */
        }
      }
      final file = await _fileFor(id);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(snapshot, flush: true);
      for (var attempt = 0; ; attempt++) {
        try {
          await tmp.rename(file.path);
          savedMeasurement.value = WdcMeasurement.fromJson(
            jsonDecode(snapshot) as Map<String, dynamic>,
          );
          break;
        } on FileSystemException {
          // Windows indexers may briefly hold a file after a previous save.
          if (!Platform.isWindows || attempt >= 4) rethrow;
          await Future<void>.delayed(
            Duration(milliseconds: 40 * (attempt + 1)),
          );
        }
      }
    })();
    _writeQueue = operation;
    void clearQueue() {
      if (identical(_writeQueue, operation)) _writeQueue = null;
    }

    unawaited(
      operation.then(
        (_) => clearQueue(),
        onError: (Object _, StackTrace _) => clearQueue(),
      ),
    );
    return operation;
  }

  Future<void> delete(String id) async {
    final file = await _fileFor(id);
    if (await file.exists()) await file.delete();
  }

  Future<List<WdcMeasurement>> loadAll() async {
    await _writeQueue;
    final dir = await _baseDir;
    await KrvTransfer.recover(dir.path);
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.json'))
        .cast<File>()
        .toList();
    final list = <WdcMeasurement>[];
    for (final file in files) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        list.add(WdcMeasurement.fromJson(json));
      } catch (_) {
        // Ignore corrupted measurement, but do not delete it automatically.
      }
    }
    return list;
  }

  Future<File> exportCsv(WdcMeasurement m) async {
    recalcAll(m, finalCalculation: true);
    final temp = await getTemporaryDirectory();
    final name =
        '${sanitizeFilenamePart(m.river)}&${sanitizeFilenamePart(m.site)}&${fileDt(m.createdDate)}.csv';
    final folder = await temp.createTemp('wdc-export-');
    final file = File('${folder.path}/$name');
    await file.writeAsString(csvContent(m), flush: true);
    return file;
  }

  Future<File> exportPdf(WdcMeasurement m) async {
    recalcAll(m, finalCalculation: true);
    final temp = await getTemporaryDirectory();
    final name =
        '${sanitizeFilenamePart(m.river)}_${sanitizeFilenamePart(m.site)}_${DateFormat('yyyy_MM_dd_HH_mm_ss').format(m.createdDate)}.pdf';
    final folder = await temp.createTemp('wdc-export-');
    final file = File('${folder.path}/$name');
    final bytes = await pdfBytes(m);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

String _csvCell(Object? value) {
  final s = value == null ? '' : value.toString();
  if (s.contains(';') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _numCell(double? value, int digits) =>
    value == null ? '' : roundTo(value, digits).toStringAsFixed(digits);

String csvContent(WdcMeasurement m) => csvContentV4(m);

void sortLeftToRight(WdcMeasurement m) {
  final lb = m.leftBank;
  final rb = m.rightBank;
  if (lb?.distance == null || rb?.distance == null) {
    m.verticals.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    return;
  }
  final ascending = lb!.distance! < rb!.distance!;
  m.verticals.sort((a, b) {
    final da = a.distance ?? 0;
    final db = b.distance ?? 0;
    return ascending ? da.compareTo(db) : db.compareTo(da);
  });
}

void recalcAll(WdcMeasurement m, {bool finalCalculation = false}) {
  m.bindCalculation();
  m.discharge = null;
  m.width = null;
  m.area = null;
  m.wettedPerimeter = null;
  m.meanDepth = null;
  m.maxDepth = null;
  m.hydraulicRadius = null;
  m.meanSoundingLevel = null;
  m.meanVelocityLevel = null;
  m.levelCorrection = null;
  m.warnings.removeWhere(
    (w) =>
        w.startsWith('После поправки уровня') ||
        w.startsWith('Обозначенные краевые отсеки') ||
        w.startsWith('Краевые отсеки') ||
        w.startsWith('Краевой отсек'),
  );
  sortLeftToRight(m);

  for (final v in m.verticals) {
    if (v.depth1 != null && v.depth2 != null) {
      v.avgDepth = roundTo((v.depth1! + v.depth2!) / 2, 3);
    } else if (v.depth1 != null) {
      v.avgDepth = roundTo(v.depth1!, 3);
    } else if (v.depth2 != null) {
      v.avgDepth = roundTo(v.depth2!, 3);
    } else {
      v.avgDepth = null;
    }
    v.areaBetween = null;
    v.wettedBetween = null;
    v.correctedDepth = null;
    v.correctedAreaBetween = null;
    v.sectionArea = null;
    v.partialDischarge = null;
  }

  if (m.levelSoundingStart != null && m.levelSoundingEnd != null) {
    m.meanSoundingLevel = roundTo(
      (m.levelSoundingStart! + m.levelSoundingEnd!) / 2,
      3,
    );
  }
  if (m.levelVelocityStart != null && m.levelVelocityEnd != null) {
    m.meanVelocityLevel = roundTo(
      (m.levelVelocityStart! + m.levelVelocityEnd!) / 2,
      3,
    );
  }
  if (m.meanSoundingLevel != null && m.meanVelocityLevel != null) {
    m.levelCorrection = roundTo(m.meanVelocityLevel! - m.meanSoundingLevel!, 3);
  }

  updateZeroWarning(m);
  _computeGeometry(m, useCorrected: false);
  if (finalCalculation && m.geometry44 && m.levelCorrection != null) {
    calculateGeometry44(m);
    return;
  }
  if (finalCalculation && m.levelCorrection != null) {
    var hadNegative = false;
    for (final v in m.verticals) {
      final h = v.avgDepth;
      if (h == null) continue;
      final corrected = h + m.levelCorrection!;
      if (corrected < 0) {
        v.correctedDepth = 0;
        hadNegative = true;
      } else {
        v.correctedDepth = roundTo(corrected, 3);
      }
    }
    if (hadNegative) {
      m.warnings.add(
        'После поправки уровня часть глубин стала меньше нуля и была принята равной 0. Проверьте изменение уровня воды и форму береговой зоны.',
      );
    }
    _computeGeometry(m, useCorrected: true);
    _computeVelocitySections(m);
  }
}

void _computeGeometry(WdcMeasurement m, {required bool useCorrected}) {
  if (m.verticals.isEmpty) return;
  sortLeftToRight(m);
  double totalArea = 0;
  double totalWetted = 0;
  double maxDepth = 0;

  double? depth(VerticalPoint v) =>
      useCorrected ? v.correctedDepth : v.avgDepth;

  for (var i = 0; i < m.verticals.length; i++) {
    final v = m.verticals[i];
    final h = depth(v);
    if (h != null) maxDepth = math.max(maxDepth, h);

    if (i == 0) {
      if (useCorrected) {
        v.correctedAreaBetween = 0;
      } else {
        v.areaBetween = 0;
      }
      v.wettedBetween = roundTo(h ?? 0, 3);
      totalWetted += h ?? 0;
    } else {
      final prev = m.verticals[i - 1];
      final h0 = depth(prev) ?? 0;
      final h1 = h ?? 0;
      final dx = ((v.distance ?? 0) - (prev.distance ?? 0)).abs();
      final area = 0.5 * (h0 + h1) * dx;
      if (useCorrected) {
        v.correctedAreaBetween = roundTo(area, 6);
      } else {
        v.areaBetween = roundTo(area, 6);
      }
      totalArea += area;

      var wetted = math.sqrt(dx * dx + math.pow(h1 - h0, 2));
      if (i == m.verticals.length - 1) wetted += h1;
      v.wettedBetween = roundTo(wetted, 3);
      totalWetted += wetted;
    }
  }

  final lb = m.leftBank;
  final rb = m.rightBank;
  if (lb?.distance != null && rb?.distance != null) {
    m.width = roundTo((lb!.distance! - rb!.distance!).abs(), 3);
  }
  if (m.calculationConfig != null && m.iceCover) totalWetted += m.width ?? 0;
  m.area = roundTo(totalArea, 6);
  m.wettedPerimeter = roundTo(totalWetted, 3);
  m.maxDepth = roundTo(maxDepth, 3);
  if ((m.width ?? 0) > 0) m.meanDepth = roundTo(totalArea / m.width!, 3);
  if (totalWetted > 0) m.hydraulicRadius = roundTo(totalArea / totalWetted, 3);
}

void _computeVelocitySections(WdcMeasurement m, {bool excludeDry = false}) {
  bool eligible(VerticalPoint v) =>
      v.isSpeedVertical &&
      v.bank == null &&
      (!excludeDry || (v.correctedDepth ?? 0) > 0);
  if (m.calculationConfig != null &&
      m.verticals.any((v) => eligible(v) && v.avgVelocity == null)) {
    return;
  }
  final speedIndexes = <int>[];
  for (var i = 0; i < m.verticals.length; i++) {
    final v = m.verticals[i];
    if (eligible(v) && v.avgVelocity != null) {
      speedIndexes.add(i);
    }
  }
  if (speedIndexes.isEmpty) {
    m.discharge = null;
    return;
  }

  double areaAt(int i) =>
      m.verticals[i].correctedAreaBetween ?? m.verticals[i].areaBetween ?? 0;

  // Left edge and internal sections. The area for the section ending at a speed vertical
  // is written into the row of that speed vertical.
  var start = 0;
  for (final speedIndex in speedIndexes) {
    var sum = 0.0;
    for (var i = start; i <= speedIndex; i++) {
      sum += areaAt(i);
    }
    m.verticals[speedIndex].sectionArea = roundTo(sum, 6);
    start = speedIndex + 1;
  }

  // Right edge section is written into the right-bank row.
  if (m.verticals.isNotEmpty) {
    var rightSum = 0.0;
    for (var i = start; i < m.verticals.length; i++) {
      rightSum += areaAt(i);
    }
    m.verticals.last.sectionArea = roundTo(rightSum, 6);
  }

  var totalQ = 0.0;
  for (var si = 0; si < speedIndexes.length; si++) {
    final idx = speedIndexes[si];
    final v = m.verticals[idx];
    final area = v.sectionArea ?? 0;
    double q;
    if (si == 0) {
      q = area * (v.avgVelocity ?? 0) * (m.bankCoeffLeft ?? 0);
    } else {
      final prev = m.verticals[speedIndexes[si - 1]];
      q = area * (((prev.avgVelocity ?? 0) + (v.avgVelocity ?? 0)) / 2);
    }
    v.partialDischarge = roundTo(q, 6);
    totalQ += q;
  }

  if (m.verticals.isNotEmpty) {
    final lastSpeed = m.verticals[speedIndexes.last];
    final rb = m.verticals.last;
    final qRight =
        (rb.sectionArea ?? 0) *
        (lastSpeed.avgVelocity ?? 0) *
        (m.bankCoeffRight ?? 0);
    rb.partialDischarge = roundTo(qRight, 6);
    totalQ += qRight;
  }

  m.discharge = roundTo(totalQ, 6);

  final internalQ = <double>[];
  if (speedIndexes.length >= 2) {
    for (var si = 1; si < speedIndexes.length; si++) {
      final q = m.verticals[speedIndexes[si]].partialDischarge;
      if (q != null) internalQ.add(q);
    }
  }
  if (internalQ.isNotEmpty) {
    final meanInternal = internalQ.reduce((a, b) => a + b) / internalQ.length;
    if (meanInternal > 0) {
      final leftQ = m.verticals[speedIndexes.first].partialDischarge ?? 0;
      final rightQ = m.verticals.last.partialDischarge ?? 0;
      if (leftQ / meanInternal > 0.3 || rightQ / meanInternal > 0.3) {
        m.warnings.add(
          'Краевые отсеки имеют частичные расходы, превышающие 30% от частичных расходов основной зоны живого сечения [прибрежные скоростные вертикали выбраны слишком далеко от берега].',
        );
      }
    }
  }
}

// =============================
// Home
// =============================

enum SortField { river, site, date, discharge }

int compareMeasurements46(
  WdcMeasurement a,
  WdcMeasurement b,
  SortField field,
  bool descending,
) {
  int names(String x, String y) =>
      x.trim().toLowerCase().compareTo(y.trim().toLowerCase());
  // Unknown discharge follows numeric results, in either sort direction.
  if (field == SortField.discharge &&
      (a.discharge == null || b.discharge == null)) {
    if (a.discharge != b.discharge) return a.discharge == null ? 1 : -1;
  }
  final primary = switch (field) {
    SortField.river => names(a.river, b.river),
    SortField.site => names(a.site, b.site),
    SortField.date => a.createdDate.compareTo(b.createdDate),
    SortField.discharge => (a.discharge ?? 0).compareTo(b.discharge ?? 0),
  };
  if (primary != 0) return descending ? -primary : primary;
  final river = names(a.river, b.river);
  if (river != 0) return river;
  final site = names(a.site, b.site);
  if (site != 0) return site;
  final date = a.createdDate.compareTo(b.createdDate);
  return date != 0 ? date : a.id.compareTo(b.id);
}

class SearchSettings {
  String river = '';
  String site = '';
  String project = '';
  bool projectExact = false;
  bool riverExact = false;
  bool siteExact = false;
  DateTime? from;
  DateTime? to;

  bool get active =>
      river.trim().isNotEmpty ||
      site.trim().isNotEmpty ||
      project.trim().isNotEmpty ||
      from != null ||
      to != null;
}

// =============================
// Common UI widgets
// =============================

class NumField extends StatefulWidget {
  const NumField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.maxLength = 12,
  });

  final String label;
  final double? initial;
  final String? hint;
  final int maxLength;
  final ValueChanged<double?> onChanged;

  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String _lastExternalText = '';

  String _textFromValue(double? value) => inputNumber(value);

  @override
  void initState() {
    super.initState();
    _lastExternalText = _textFromValue(widget.initial);
    _controller = TextEditingController(text: _lastExternalText);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant NumField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextExternalText = _textFromValue(widget.initial);
    if (!_focusNode.hasFocus && nextExternalText != _lastExternalText) {
      _lastExternalText = nextExternalText;
      _controller.text = nextExternalText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        numericFormatter,
        LengthLimitingTextInputFormatter(widget.maxLength),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
      ),
      onChanged: (v) {
        _lastExternalText = v;
        widget.onChanged(parseNumRu(v));
      },
    );
  }
}

class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.m});
  final WdcMeasurement m;

  InlineSpan _metricSpan(
    String symbol,
    String value,
    String unit, {
    String? sub,
  }) {
    return TextSpan(
      children: [
        TextSpan(text: symbol),
        if (sub != null)
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Transform.translate(
              offset: const Offset(0, 3),
              child: Text(
                sub,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        TextSpan(text: ' = $value $unit'),
      ],
    );
  }

  Widget _metric(InlineSpan span) => Padding(
    padding: const EdgeInsets.all(6),
    child: Text.rich(
      TextSpan(
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        children: [span],
      ),
    ),
  );

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Обозначения')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('B – Ширина водного сечения')),
            const SizedBox(height: 6),
            Text(tr('ω – Площадь поперечного сечения')),
            const SizedBox(height: 6),
            NotationText(tr('hср – Средняя глубина')),
            const SizedBox(height: 6),
            NotationText(tr('hmax – Максимальная глубина')),
            const SizedBox(height: 6),
            Text(tr('χ – Смоченный периметр')),
            const SizedBox(height: 6),
            Text(tr('R – Гидравлический радиус')),
            const SizedBox(height: 6),
            NotationText(tr('Uпоп – средняя скорость на поперечном сечении')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      [
        _metricSpan('B', fmtAdaptive(m.width), tr('м')),
        _metricSpan('ω', fmtAreaAdaptive(m.area), tr('м²')),
      ],
      [
        _metricSpan('h', fmtAdaptive(m.meanDepth), tr('м'), sub: tr('ср')),
        _metricSpan('h', fmtAdaptive(m.maxDepth), tr('м'), sub: 'max'),
      ],
      [
        _metricSpan('χ', fmtAdaptive(m.wettedPerimeter), tr('м')),
        _metricSpan('R', fmtAdaptive(m.hydraulicRadius), tr('м')),
      ],
      [
        _metricSpan(
          'U',
          fmtAdaptive(m.meanFlowVelocity, small: 3),
          tr('м/с'),
          sub: tr('поп'),
        ),
        const TextSpan(),
      ],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Table(
              children: rows
                  .asMap()
                  .entries
                  .map(
                    (e) => TableRow(
                      children: [
                        _metric(e.value[0]),
                        if (e.key == rows.length - 1)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: tr('Обозначения'),
                              icon: const Icon(Icons.help_outline),
                              onPressed: () => _showHelp(context),
                            ),
                          )
                        else
                          _metric(e.value[1]),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================
// Velocity screen
// =============================

enum HintMode { fromBottom, depth }

// =============================
// Help
// =============================

class HelpScreen extends SettingsScreen {
  const HelpScreen({super.key});
}
