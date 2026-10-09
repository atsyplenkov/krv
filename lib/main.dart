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
        geometry44 || verticals.any((v) => v.iceThicknessCm != null) ? 6 : 5,
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
    requireIceThickness: true,
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
        onError: (Object _, StackTrace __) => clearQueue(),
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

void _computeVelocitySections(WdcMeasurement m) {
  if (m.calculationConfig != null &&
      m.verticals.any(
        (v) => v.isSpeedVertical && v.bank == null && v.avgVelocity == null,
      )) {
    return;
  }
  final speedIndexes = <int>[];
  for (var i = 0; i < m.verticals.length; i++) {
    final v = m.verticals[i];
    if (v.isSpeedVertical && v.bank == null && v.avgVelocity != null) {
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

enum SortField { river, site, date }

class SearchSettings {
  String river = '';
  String site = '';
  bool riverExact = false;
  bool siteExact = false;
  DateTime? from;
  DateTime? to;

  bool get active =>
      river.trim().isNotEmpty ||
      site.trim().isNotEmpty ||
      from != null ||
      to != null;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SettingsRefresh<HomeScreen> {
  final storage = WdcStorage.instance;
  List<WdcMeasurement> _all = [];
  bool _loading = true;
  bool _starting = false;
  bool _transferring = false;
  int _loadGeneration = 0;
  SortField _sortField = SortField.date;
  bool _descending = true;
  final _search = SearchSettings();
  final Set<String> _selected = {};

  bool get _selectionMode => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    storage.savedMeasurement.addListener(_onMeasurementSaved);
    _recoverAndLoad();
  }

  Future<void> _recoverAndLoad() async {
    try {
      await PhotoStorage.recoverLostPhotos();
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          tr('Не удалось восстановить фото после закрытия камеры'),
        );
      }
    }
    if (mounted) await _load();
  }

  @override
  void dispose() {
    storage.savedMeasurement.removeListener(_onMeasurementSaved);
    super.dispose();
  }

  void _onMeasurementSaved() {
    final saved = storage.savedMeasurement.value;
    if (!mounted || saved == null) return;
    final wasLoading = _loading;
    _loadGeneration++;
    setState(() {
      final index = _all.indexWhere((m) => m.id == saved.id);
      if (index < 0) {
        _all.add(saved);
      } else {
        _all[index] = saved;
      }
      _loading = false;
    });
    if (wasLoading) unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    setState(() => _loading = true);
    final all = await storage.loadAll();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  bool _matchText(String field, String query, bool exact) {
    final f = field.trim().toLowerCase();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (exact) return f == q;
    final tokens = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return tokens.every(f.contains);
  }

  List<WdcMeasurement> get _visible {
    final unfinished = _all.where((m) => !m.completed).toList()
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));

    var finished = _all.where((m) => m.completed).where((m) {
      if (!_matchText(m.river, _search.river, _search.riverExact)) return false;
      if (!_matchText(m.site, _search.site, _search.siteExact)) return false;
      final d = DateTime(
        m.createdDate.year,
        m.createdDate.month,
        m.createdDate.day,
      );
      if (_search.from != null && d.isBefore(_search.from!)) return false;
      if (_search.to != null && d.isAfter(_search.to!)) return false;
      return true;
    }).toList();

    int cmp(WdcMeasurement a, WdcMeasurement b) {
      switch (_sortField) {
        case SortField.river:
          return a.river.toLowerCase().compareTo(b.river.toLowerCase());
        case SortField.site:
          return a.site.toLowerCase().compareTo(b.site.toLowerCase());
        case SortField.date:
          return a.createdDate.compareTo(b.createdDate);
      }
    }

    finished.sort((a, b) => _descending ? -cmp(a, b) : cmp(a, b));
    return [...unfinished, ...finished];
  }

  Future<void> _startNew() async {
    if (_starting) return;
    setState(() => _starting = true);
    final progress = AppSettings.current.autoGps
        ? showWorkProgress(context, tr('Получаем координаты…'))
        : null;
    double? lat;
    double? lon;
    try {
      if (AppSettings.current.autoGps) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition().timeout(
            const Duration(seconds: 5),
          );
          lat = roundTo(pos.latitude, 8);
          lon = roundTo(pos.longitude, 8);
        }
      }
    } catch (_) {
      // Coordinates are optional.
    }
    final m = WdcMeasurement.empty(lat: lat, lon: lon);
    try {
      await storage.save(m);
    } catch (_) {
      if (mounted) showSnack(context, tr('Не удалось создать измерение'));
      return;
    } finally {
      progress?.call();
      if (mounted) setState(() => _starting = false);
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SoundingScreen(measurement: m)),
    );
    await _load();
  }

  Future<void> _exportKrv() async {
    if (_transferring) return;
    final records = _all
        .where((m) => _selected.contains(m.id))
        .map((m) => m.toJson())
        .toList();
    if (records.isEmpty) return;
    setState(() => _transferring = true);
    final close = showWorkProgress(context, tr('Создаём архив…'));
    try {
      await storage.flush();
      final base = (await storage._baseDir).path;
      final temp = (await getTemporaryDirectory()).path;
      final path = await KrvTransfer.exportInBackground(base, records, temp);
      close();
      if (!mounted) return;
      await shareFiles44([
        XFile(path, mimeType: 'application/octet-stream'),
      ], text: tr('Архив измерений КРВ'));
    } catch (e) {
      close();
      if (mounted) {
        showSnack(
          context,
          e is KrvException
              ? tr(e.message)
              : tr('Не удалось создать или отправить архив.'),
        );
      }
    } finally {
      close();
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _importKrv() async {
    if (_transferring) return;
    setState(() => _transferring = true);
    KrvImportPlan? plan;
    Directory? incoming;
    VoidCallback? close;
    try {
      // Android document providers may expose a custom extension as octet-stream.
      // Validate the actual archive, rather than hiding it using a MIME filter.
      final selected = await fs.openFile();
      if (selected == null || !mounted) return;
      // Android may return a content URI ending in a document ID, not the
      // display filename. Recognize KRV by its validated manifest and contents.
      if (await selected.length() >
          KrvTransfer.maxTotal + KrvTransfer.maxManifest) {
        throw const KrvException(
          'Архив слишком большой. Выберите меньше измерений.',
        );
      }
      if (!mounted) return;
      close = showWorkProgress(context, tr('Проверяем архив…'));
      await storage.flush();
      final base = (await storage._baseDir).path;
      final temp = (await getTemporaryDirectory()).path;
      incoming = await Directory(temp).createTemp('krv-incoming-');
      final path = '${incoming.path}/input.krv';
      await selected.saveTo(path);
      plan = await KrvTransfer.inspectInBackground(path, base, temp);
      close();
      close = null;
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => KrvSummaryDialog(plan: plan!),
      );
      if (accepted != true || !mounted) return;
      close = showWorkProgress(context, tr('Добавляем измерения…'));
      final approved = plan;
      await KrvTransfer.commitInBackground(approved, base);
      close();
      close = null;
      await _load();
      if (mounted) {
        showSnack(
          context,
          '${tr('Добавлено измерений')}: ${approved.records.length}',
        );
      }
    } catch (e) {
      close?.call();
      close = null;
      if (mounted) {
        showSnack(
          context,
          e is KrvException
              ? tr(e.message)
              : tr('Импорт не выполнен. Исходные измерения сохранены.'),
        );
      }
    } finally {
      close?.call();
      try {
        await plan?.dispose();
        if (incoming != null && await incoming.exists()) {
          await incoming.delete(recursive: true);
        }
      } on FileSystemException {
        /* Temporary files are not measurement data. */
      }
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _shareOne(WdcMeasurement m, {required bool pdf}) async {
    final close = showWorkProgress(
      context,
      pdf ? tr('Создаём PDF…') : tr('Создаём CSV…'),
    );
    try {
      final f = pdf ? await storage.exportPdf(m) : await storage.exportCsv(m);
      close();
      await shareFiles44([
        XFile(f.path),
      ], text: pdf ? tr('PDF-отчёт') : tr('CSV расчёта расхода воды'));
    } catch (_) {
      close();
      if (mounted) {
        showSnack(context, tr('Не удалось экспортировать измерение'));
      }
    }
  }

  Future<void> _shareSelected({bool pdf = false}) async {
    final items = _all.where((m) => _selected.contains(m.id)).toList();
    if (items.isEmpty) return;
    final files = <XFile>[];
    for (final m in items) {
      final f = pdf ? await storage.exportPdf(m) : await storage.exportCsv(m);
      files.add(XFile(f.path));
    }
    await shareFiles44(
      files,
      text: pdf
          ? tr('PDF-отчёты расчёта расхода воды')
          : tr('CSV-файлы расчёта расхода воды'),
    );
  }

  Future<void> _deleteSelected() async {
    final ok = await confirmDialog(
      context,
      title: tr('Удаление'),
      message: tr('Удалить безвозвратно выделенные измерения?'),
    );
    if (!ok) return;
    for (final id in _selected) {
      await storage.delete(id);
    }
    _selected.clear();
    await _load();
  }

  Future<void> _openMeasurement(WdcMeasurement m) async {
    Widget page;
    if (m.completed) {
      page = ResultScreen(measurement: m, viewOnly: true);
    } else {
      page = SoundingScreen(measurement: m);
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  Future<void> _showSearchDialog() async {
    final riverC = TextEditingController(text: _search.river);
    final siteC = TextEditingController(text: _search.site);
    final fromC = TextEditingController(
      text: _search.from == null ? '' : dateHuman(_search.from!),
    );
    final toC = TextEditingController(
      text: _search.to == null ? '' : dateHuman(_search.to!),
    );
    var riverExact = _search.riverExact;
    var siteExact = _search.siteExact;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Поиск')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: riverC,
                  decoration: InputDecoration(labelText: tr('Название реки')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: riverExact,
                  onChanged: (v) => setDialogState(() => riverExact = v),
                  title: Text(tr('Точное совпадение реки')),
                ),
                TextField(
                  controller: siteC,
                  decoration: InputDecoration(labelText: tr('Название створа')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: siteExact,
                  onChanged: (v) => setDialogState(() => siteExact = v),
                  title: Text(tr('Точное совпадение створа')),
                ),
                TextField(
                  controller: fromC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('Дата с'),
                    hintText: tr('дд.мм.гггг'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: toC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('по'),
                    hintText: tr('дд.мм.гггг'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Закрыть')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('🔎 Поиск')),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final from = parseHumanDate(fromC.text);
      final to = parseHumanDate(toC.text);
      if ((fromC.text.trim().isNotEmpty && from == null) ||
          (toC.text.trim().isNotEmpty && to == null)) {
        if (mounted) showSnack(context, tr('Дата указана в неверном формате'));
        return;
      }
      setState(() {
        _search.river = riverC.text;
        _search.site = siteC.text;
        _search.riverExact = riverExact;
        _search.siteExact = siteExact;
        _search.from = from;
        _search.to = to;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final compactToolbar = MediaQuery.sizeOf(context).width < 380;
    return Scaffold(
      appBar: AppBar(
        bottom: _search.active
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _search.river = '';
                    _search.site = '';
                    _search.from = null;
                    _search.to = null;
                    _search.riverExact = false;
                    _search.siteExact = false;
                  }),
                  icon: const Icon(Icons.clear),
                  label: Text(tr('Сбросить поиск')),
                ),
              )
            : null,
        title: Text(
          _selectionMode
              ? (compactToolbar
                    ? '${_selected.length}'
                    : '${tr('Выбрано')}: ${_selected.length}')
              : 'v4.4',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leadingWidth: _selectionMode ? 48 : 148,
        titleSpacing: 4,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteSelected,
              )
            : Row(
                children: [
                  IconButton(
                    tooltip: tr('Настройки'),
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('О приложении'),
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen44()),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('import-krv'),
                    tooltip: tr('Импорт измерений'),
                    icon: const Icon(Icons.move_to_inbox_outlined),
                    onPressed: _transferring ? null : _importKrv,
                  ),
                ],
              ),
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: tr('Снять выделение'),
                  onPressed: () => setState(_selected.clear),
                  icon: const Icon(Icons.close),
                ),
                IconButton(
                  tooltip: tr('Выбрать всё'),
                  onPressed: () => setState(
                    () => _selected.addAll(visible.map((m) => m.id)),
                  ),
                  icon: const Icon(Icons.select_all),
                ),
                IconButton(
                  key: const ValueKey('export-krv'),
                  tooltip: tr('Экспорт выбранных в .krv'),
                  onPressed: _transferring ? null : _exportKrv,
                  icon: const Icon(Icons.outbox_outlined),
                ),
                IconButton(
                  tooltip: tr('Поделиться CSV'),
                  onPressed: () => _shareSelected(pdf: false),
                  icon: const CsvExportIcon(),
                ),
                IconButton(
                  tooltip: tr('Экспорт выбранных в PDF'),
                  onPressed: () => _shareSelected(pdf: true),
                  icon: const PdfExportIcon(),
                ),
              ]
            : [
                if (compactToolbar)
                  IconButton(
                    tooltip: _search.active
                        ? tr('Изменить поиск')
                        : tr('Поиск'),
                    onPressed: _showSearchDialog,
                    icon: const Icon(Icons.search),
                  )
                else
                  TextButton.icon(
                    onPressed: _showSearchDialog,
                    icon: const Icon(Icons.search),
                    label: Text(
                      _search.active ? tr('Изменить поиск') : tr('Поиск'),
                    ),
                  ),
                PopupMenuButton<SortField>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (v) => setState(() => _sortField = v),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: SortField.river,
                      child: Text(tr('По названию реки')),
                    ),
                    PopupMenuItem(
                      value: SortField.site,
                      child: Text(tr('По названию створа')),
                    ),
                    PopupMenuItem(
                      value: SortField.date,
                      child: Text(tr('По дате')),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => setState(() => _descending = !_descending),
                  icon: Icon(
                    _descending ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
          ? Center(
              child: Text(
                _all.isEmpty
                    ? tr('Измерения отсутствуют')
                    : tr('Измерения не найдены,\nизмените настройки поиска'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final m = visible[i];
                  final selected = _selected.contains(m.id);
                  return Card(
                    color: !m.completed
                        ? const Color(0xFFFFF8E1)
                        : selected
                        ? const Color(0xFFDFF1FF)
                        : Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            onLongPress: () =>
                                setState(() => _selected.add(m.id)),
                            onTap: () {
                              if (_selectionMode) {
                                setState(
                                  () => selected
                                      ? _selected.remove(m.id)
                                      : _selected.add(m.id),
                                );
                              } else {
                                _openMeasurement(m);
                              }
                            },
                            leading: _selectionMode
                                ? Icon(
                                    selected
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                  )
                                : Icon(
                                    m.completed
                                        ? Icons.water_drop_outlined
                                        : Icons.edit_note,
                                  ),
                            title: Text(
                              m.titleRiver,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${m.titleSite}\n${m.completed ? 'Q: ${compactDischarge(m.discharge)} ${tr('м³/с')}' : ''}\n${humanFromIso(m.createdAt)}${m.completed ? '' : tr('\nНезавершённое измерение')}${m.importedCopy ? '\n${tr('Импортированная копия')}' : ''}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                        if (!_selectionMode)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: tr('Экспорт PDF'),
                                icon: const PdfExportIcon(),
                                onPressed: () => _shareOne(m, pdf: true),
                              ),
                              IconButton(
                                tooltip: tr('Поделиться CSV'),
                                icon: const CsvExportIcon(),
                                onPressed: () => _shareOne(m, pdf: false),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _starting ? null : _startNew,
            icon: const Icon(Icons.add),
            label: Text(tr('Начать новое измерение')),
          ),
        ),
      ),
    );
  }
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
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
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
// Sounding screen
// =============================

class SoundingScreen extends StatefulWidget {
  const SoundingScreen({super.key, required this.measurement});
  final WdcMeasurement measurement;

  @override
  State<SoundingScreen> createState() => _SoundingScreenState();
}

class _SoundingScreenState extends State<SoundingScreen>
    with SettingsRefresh<SoundingScreen> {
  late WdcMeasurement m;
  Timer? _saveTimer;
  String _startBank = 'ЛБ';
  bool _addingSecondBank = false;
  bool _centimetres = false;
  String get _unit => _centimetres ? tr('см') : tr('м');
  double? _displayLength(double? value) =>
      value == null ? null : roundTo(value * (_centimetres ? 100 : 1), 3);
  double _metres(double value) => roundTo(value / (_centimetres ? 100 : 1), 3);

  void _recordInput(double? value) {
    if (value == null) return;
    recordSoundingInput(m);
    _scheduleSave();
  }

  void _changeUnits(bool centimetres) {
    if (_centimetres == centimetres) return;
    // Convert drafts as well as existing rows; switching units is not a measurement.
    final factor = centimetres ? 100.0 : 0.01;
    setState(() {
      for (final controller in [
        _distanceC,
        _depthC,
        _bankDistanceC,
        _bankDepthC,
      ]) {
        final value = parseNumRu(controller.text);
        if (value != null) controller.text = inputNumber(value * factor);
      }
      _centimetres = centimetres;
    });
  }

  final _distanceFocus = FocusNode();
  final _bankDistanceC = TextEditingController();
  final _bankDepthC = TextEditingController();
  final _distanceC = TextEditingController();
  final _depthC = TextEditingController();
  final _bottomC = TextEditingController();
  final _iceC = TextEditingController();
  final _bankBottomC = TextEditingController();
  final _bankIceC = TextEditingController();

  @override
  void initState() {
    super.initState();
    m = widget.measurement;
    m.geometry44 = true;
    recalcAll(m);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _distanceFocus.dispose();
    _bankDistanceC.dispose();
    _bankDepthC.dispose();
    _distanceC.dispose();
    _depthC.dispose();
    _bottomC.dispose();
    _iceC.dispose();
    _bankBottomC.dispose();
    _bankIceC.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      recalcAll(m);
      WdcStorage.instance.save(m);
    });
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    recalcAll(m);
    await WdcStorage.instance.save(m);
  }

  Future<void> _updateGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        if (mounted) showSnack(context, tr('Нет разрешения на геолокацию'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 8),
      );
      setState(() {
        m.latitude = roundTo(pos.latitude, 8);
        m.longitude = roundTo(pos.longitude, 8);
      });
      await _saveNow();
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          tr(
            'Координаты не получены. Их можно ввести вручную или обновить позже',
          ),
        );
      }
    }
  }

  bool _distanceExists(double d) => m.verticals.any(
    (v) => v.distance != null && (v.distance! - d).abs() < 0.0005,
  );

  Future<void> _addVertical({bool secondBank = false}) async {
    final distanceC = secondBank ? _bankDistanceC : _distanceC;
    final depthC = secondBank ? _bankDepthC : _depthC;
    final distance = parseNumRu(distanceC.text);
    final depth = parseNumRu(depthC.text);
    final bottomC = secondBank ? _bankBottomC : _bottomC;
    final iceC = secondBank ? _bankIceC : _iceC;
    final ice = parseNumRu(iceC.text);
    if (distance == null ||
        depth == null ||
        depth < 0 ||
        (m.iceCover && (ice == null || ice < 0))) {
      return;
    }
    final dd = _metres(distance);
    if (_distanceExists(dd)) {
      showSnack(
        context,
        tr('На введённом расстоянии уже есть промерная вертикаль'),
      );
      return;
    }

    String? bank;
    if (!m.hasLeftBank && !m.hasRightBank) {
      bank = _startBank;
    } else if (secondBank) {
      bank = m.hasLeftBank ? 'ПБ' : 'ЛБ';
    }

    setState(() {
      recordSoundingInput(m);
      m.verticals.add(
        VerticalPoint(
          id: uid(),
          bank: bank,
          distance: dd,
          depth1: _metres(depth),
          bottomType: bottomC.text.trim(),
          iceThicknessCm: m.iceCover ? roundTo(ice!, 2) : null,
          depth1At: measurementNow(m),
        ),
      );
      if (secondBank) _addingSecondBank = false;
      distanceC.clear();
      depthC.clear();
      bottomC.clear();
      iceC.clear();
    });
    await _saveNow();
    if (mounted && !secondBank) {
      _distanceFocus.requestFocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }

  Future<void> _deleteVertical(VerticalPoint v) async {
    if (v.bank != null) return;
    final ok = await confirmDialog(
      context,
      title: tr('Удаление'),
      message: tr(
        'Удалить промерную вертикаль?\nУдалятся и все измеренные на ней скорости.',
      ),
    );
    if (!ok) return;
    setState(() {
      m.verticals.removeWhere((x) => x.id == v.id);
    });
    await _saveNow();
  }

  Future<void> _editBankDistance(VerticalPoint v) async {
    final d = await editNumberDialog(
      context,
      title: '${tr('Расстояние')} ${bankLabel(v.bank)}, $_unit',
      initial: _displayLength(v.distance),
    );
    if (d == null || d.isNaN) return;
    final rd = _metres(d);
    if (rd == v.distance) return;
    final duplicates = m.verticals.where(
      (x) =>
          x.id != v.id &&
          x.distance != null &&
          (x.distance! - rd).abs() < 0.0005,
    );
    if (duplicates.isNotEmpty) {
      if (mounted) {
        showSnack(context, tr('Есть промерные вертикали на одном расстоянии'));
      }
      return;
    }
    setState(() {
      v.distance = rd;
      recordSoundingInput(m);
    });
    await _saveNow();
  }

  String? _validateBeforeVelocity() {
    if (m.iceCover &&
        m.requireIceThickness &&
        m.verticals.any((v) => v.iceThicknessCm == null)) {
      return '${tr('Допишите толщину льда на вертикалях')}: ${m.verticals.where((v) => v.iceThicknessCm == null).map((v) => inputNumber(v.distance)).join(', ')} ${tr('м')}';
    }
    if (m.river.trim().isEmpty ||
        m.site.trim().isEmpty ||
        m.levelSoundingStart == null ||
        m.levelSoundingEnd == null ||
        !m.hasBothBanks) {
      return tr('Не все обязательные поля заполнены');
    }
    final distances = <double>{};
    for (final v in m.verticals) {
      if (v.distance == null) return tr('Не все обязательные поля заполнены');
      final key = roundTo(v.distance!, 3);
      if (distances.contains(key)) {
        return tr('Есть промерные вертикали на одном расстоянии');
      }
      distances.add(key);
      if (v.depth1 == null && v.depth2 == null) {
        return tr('Есть промерные вертикали без глубины');
      }
    }
    final lb = m.leftBank;
    final rb = m.rightBank;
    if (lb?.distance == null ||
        rb?.distance == null ||
        lb!.distance == rb!.distance) {
      return tr('ЛБ и ПБ находятся не по берегам');
    }
    final minD = m.verticals.map((v) => v.distance!).reduce(math.min);
    final maxD = m.verticals.map((v) => v.distance!).reduce(math.max);
    final banksExtreme =
        (lb.distance == minD && rb.distance == maxD) ||
        (lb.distance == maxD && rb.distance == minD);
    if (!banksExtreme) return tr('ЛБ и ПБ находятся не по берегам');
    return null;
  }

  Future<void> _goVelocity() async {
    final error = _validateBeforeVelocity();
    if (error != null) {
      showSnack(context, error);
      return;
    }
    await _saveNow();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VelocityScreen(measurement: m)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _entryReady(false);
    final needSecondBank =
        (m.hasLeftBank ^ m.hasRightBank) && !_addingSecondBank;
    final secondBankReady = m.hasBothBanks;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await confirmDialog(
          context,
          title: tr('Выход'),
          message: tr(
            'Выйти на главный экран (все введённые данные сохранятся)?',
          ),
        );
        if (ok) {
          await _saveNow();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Промерные работы')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: tr('Выход'),
                message: tr(
                  'Выйти на главный экран (все введённые данные сохранятся)?',
                ),
              );
              if (ok) {
                await _saveNow();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          children: [
            Text(measurementTimeZone(m)),
            Text(
              '${tr('Дата и время начала промерных работ')} — ${humanFromIso(m.levelSoundingStartAt).isEmpty ? tr('не начаты') : humanFromIso(m.levelSoundingStartAt)}',
            ),
            MeasurementComment(key: ValueKey(m.comment), measurement: m),
            MeasurementPhotos(measurement: m, editable: true),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: m.river,
              decoration: InputDecoration(labelText: tr('Название реки')),
              inputFormatters: nameFormatters,
              onChanged: (v) {
                m.river = v.trim();
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: m.site,
              decoration: InputDecoration(labelText: tr('Название створа')),
              inputFormatters: nameFormatters,
              onChanged: (v) {
                m.site = v.trim();
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            NumField(
              label: tr('Уровень воды на начало промерных работ'),
              hint: tr('Значение в метрах'),
              initial: m.levelSoundingStart,
              maxLength: 10,
              onChanged: (v) {
                m.levelSoundingStart = v == null ? null : roundTo(v, 3);
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NumField(
                    label: tr('Широта, °'),
                    initial: m.latitude,
                    maxLength: 14,
                    onChanged: (v) {
                      if (v == null || (v >= -90 && v <= 90)) {
                        m.latitude = v == null ? null : roundTo(v, 8);
                        _scheduleSave();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NumField(
                    label: tr('Долгота, °'),
                    initial: m.longitude,
                    maxLength: 14,
                    onChanged: (v) {
                      if (v == null || (v >= -180 && v <= 180)) {
                        m.longitude = v == null ? null : roundTo(v, 8);
                        _scheduleSave();
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: _updateGps,
                  icon: const Icon(Icons.my_location),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(tr('Рекомендуется не менее 20 промерных вертикалей')),
            if (m.calculationConfig != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: conditionTitle(context, ice: true),
                value: m.iceCover,
                onChanged: (value) {
                  setState(() {
                    m.iceCover = value ?? false;
                    if (m.iceCover) m.requireIceThickness = true;
                    recalcAll(m);
                  });
                  _scheduleSave();
                },
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(child: Text(tr('Режим ввода'))),
                const SizedBox(width: 16),
                Text(tr('м')),
                Switch(
                  key: const ValueKey('sounding-units'),
                  value: _centimetres,
                  onChanged: _changeUnits,
                ),
                Text(tr('см')),
              ],
            ),
            const SizedBox(height: 18),
            if (!m.hasLeftBank && !m.hasRightBank) ...[
              Text(
                tr('Укажите начальный берег:'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ЛБ', label: Text(bankLabel('ЛБ'))),
                  ButtonSegment(value: 'ПБ', label: Text(bankLabel('ПБ'))),
                ],
                selected: {_startBank},
                onSelectionChanged: (s) => setState(() => _startBank = s.first),
              ),
            ] else ...[
              Text(
                tr('Добавьте промерные вертикали:'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 10),
            _entryFields(false, canAdd),
            if (needSecondBank) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => setState(() => _addingSecondBank = true),
                child: Text(
                  '${tr('Указать второй берег')} (${bankLabel(m.hasLeftBank ? 'ПБ' : 'ЛБ')})',
                ),
              ),
            ],
            if (_addingSecondBank && !m.hasBothBanks) ...[
              const SizedBox(height: 12),
              Text(
                '${tr('Укажите второй берег')} (${bankLabel(m.hasLeftBank ? 'ПБ' : 'ЛБ')}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _entryFields(true, _entryReady(true)),
            ],
            if (secondBankReady) ...[
              const SizedBox(height: 10),
              NumField(
                label: tr('Уровень воды на конец промерных работ'),
                hint: tr('Значение в метрах'),
                initial: m.levelSoundingEnd,
                maxLength: 10,
                onChanged: (v) {
                  m.levelSoundingEnd = v == null ? null : roundTo(v, 3);
                  _scheduleSave();
                },
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Таблица промерных вертикалей'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(tr('Подсказка')),
                      content: Text(
                        tr(
                          'Выполнять обратный ход промеров необязательно. Расчёт средних глубин на вертикалях произойдёт автоматически при переходе к измерению скоростей.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _soundingTable(),
            const SizedBox(height: 8),
            Text(
              tr('Перемещайте таблицу в стороны👉'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Нажмите на значение глубины, чтобы его изменить☝️'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _goVelocity,
              icon: const Icon(Icons.arrow_forward),
              label: Text(tr('Перейти к измерению скоростей')),
            ),
          ),
        ),
      ),
    );
  }

  bool _entryReady(bool bank) {
    final distance = parseNumRu((bank ? _bankDistanceC : _distanceC).text);
    final depth = parseNumRu((bank ? _bankDepthC : _depthC).text);
    final ice = parseNumRu((bank ? _bankIceC : _iceC).text);
    return distance != null &&
        depth != null &&
        depth >= 0 &&
        (!m.iceCover || (ice != null && ice >= 0));
  }

  Widget _entryFields(bool bank, bool ready) {
    final prefix = bank ? 'second-bank' : 'sounding';
    Widget number(
      String suffix,
      TextEditingController controller,
      String label, {
      bool length = true,
    }) => TextField(
      key: ValueKey('$prefix-$suffix'),
      focusNode: !bank && suffix == 'distance' ? _distanceFocus : null,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [numericFormatter, LengthLimitingTextInputFormatter(12)],
      decoration: InputDecoration(
        labelText: label,
        hintText: length
            ? tr(_centimetres ? 'Значение в сантиметрах' : 'Значение в метрах')
            : tr('Значение в сантиметрах'),
      ),
      onChanged: (text) => setState(() => _recordInput(parseNumRu(text))),
      onEditingComplete: () {
        if (!length) {
          final n = parseNumRu(controller.text);
          if (n != null && n >= 0) controller.text = inputNumber(roundTo(n, 2));
        }
        FocusScope.of(context).nextFocus();
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: number(
                'distance',
                bank ? _bankDistanceC : _distanceC,
                '${tr('Расст.')}, $_unit',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: number(
                'depth',
                bank ? _bankDepthC : _depthC,
                '${tr('Глуб₁.')}, $_unit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ValueKey('$prefix-bottom'),
                controller: bank ? _bankBottomC : _bottomC,
                inputFormatters: [LengthLimitingTextInputFormatter(32)],
                decoration: InputDecoration(
                  labelText: tr('Тип дна'),
                  hintText: tr('Необязательно'),
                ),
              ),
            ),
            if (m.iceCover) ...[
              const SizedBox(width: 8),
              Expanded(
                child: number(
                  'ice',
                  bank ? _bankIceC : _iceC,
                  tr('Толщина льда, см'),
                  length: false,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        FilledButton(
          key: ValueKey(bank ? 'add-second-bank' : 'add-sounding'),
          onPressed: ready ? () => _addVertical(secondBank: bank) : null,
          child: Text(tr('Добавить')),
        ),
      ],
    );
  }

  Future<void> _editDepth44(VerticalPoint v, bool second) async {
    final old = second ? v.depth2 : v.depth1;
    final value = await editNumberDialog(
      context,
      title: '${tr(second ? 'Глубина 2' : 'Глубина 1')}, $_unit',
      initial: _displayLength(old),
      allowEmpty: second,
      beforeSave: (value) async {
        if (value != null && value < 0) return false;
        final next = value == null ? null : _metres(value);
        if (next == old ||
            !v.velocityPoints.values.any((p) => p.value != null)) {
          return true;
        }
        return confirmDialog(
          context,
          title: tr('Изменить глубину на скоростной вертикали?'),
          message: tr(
            'Вы пытаетесь изменить глубину на скоростной вертикали с введёнными скоростями. Эти скорости будут удалены, если вы нажмёте «Да».',
          ),
        );
      },
    );
    if (value != null && (value.isNaN || value < 0)) return;
    if (value == null && !second) return;
    final next = value == null ? null : _metres(value);
    if (next == old || !mounted) return;
    if (!mounted) return;
    setState(() => changeDepth44(m, v, next, second: second, confirmed: true));
    await _saveNow();
  }

  Widget _soundingTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(tr('Берег'))),
          DataColumn(label: Text('${tr('Расст.')}, $_unit')),
          DataColumn(label: Text('${tr('Глуб₁.')}, $_unit')),
          DataColumn(label: Text('${tr('Глуб₂.')}, $_unit')),
          DataColumn(label: Text(tr('Тип дна'))),
          if (m.iceCover) DataColumn(label: Text(tr('Толщина льда, см'))),
          const DataColumn(label: Text('')),
        ],
        rows: m.verticals.map((v) {
          return DataRow(
            cells: [
              DataCell(Text(bankLabel(v.bank))),
              DataCell(
                Text(
                  _numCell(_displayLength(v.distance), _centimetres ? 1 : 3),
                ),
              ),
              DataCell(
                Text(
                  v.depth1 == null
                      ? tr('н/д')
                      : _numCell(
                          _displayLength(v.depth1),
                          _centimetres ? 1 : 3,
                        ),
                  style: TextStyle(
                    color: v.depth1 == null
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onSurface,
                    fontStyle: v.depth1 == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                onTap: () => _editDepth44(v, false),
              ),
              DataCell(
                Text(
                  v.depth2 == null
                      ? tr('н/д')
                      : _numCell(
                          _displayLength(v.depth2),
                          _centimetres ? 1 : 3,
                        ),
                  style: TextStyle(
                    color: v.depth2 == null
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onSurface,
                    fontStyle: v.depth2 == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                onTap: () => _editDepth44(v, true),
              ),
              DataCell(
                Text(
                  v.bottomType.isEmpty ? tr('н/д') : v.bottomType,
                  style: TextStyle(
                    color: v.bottomType.isEmpty
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onSurface,
                    fontStyle: v.bottomType.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                onTap: () async {
                  final value = await editTextDialog(
                    context,
                    title: tr('Тип дна'),
                    initial: v.bottomType,
                    maxLength: 32,
                  );
                  if (value == null) return;
                  setState(() => v.bottomType = value);
                  await _saveNow();
                },
              ),
              if (m.iceCover)
                DataCell(
                  Text(_numCell(v.iceThicknessCm, 2)),
                  onTap: () async {
                    final value = await editNumberDialog(
                      context,
                      title: tr('Толщина льда, см'),
                      initial: v.iceThicknessCm,
                    );
                    if (value == null || value.isNaN || value < 0 || !mounted) {
                      return;
                    }
                    setState(() => v.iceThicknessCm = roundTo(value, 2));
                    await _saveNow();
                  },
                ),
              DataCell(
                v.bank == null
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteVertical(v),
                      )
                    : IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editBankDistance(v),
                      ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// =============================
// Velocity screen
// =============================

enum HintMode { fromBottom, depth }

class VelocityScreen extends StatefulWidget {
  const VelocityScreen({super.key, required this.measurement});
  final WdcMeasurement measurement;

  @override
  State<VelocityScreen> createState() => _VelocityScreenState();
}

class _VelocityScreenState extends State<VelocityScreen>
    with SettingsRefresh<VelocityScreen> {
  late WdcMeasurement m;
  final Set<String> _picked = {};
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    m = widget.measurement;
    recalcAll(m, finalCalculation: true);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () async {
      recalcAll(m, finalCalculation: true);
      if (mounted) setState(() {});
      await WdcStorage.instance.save(m);
    });
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    recalcAll(m, finalCalculation: true);
    await WdcStorage.instance.save(m);
  }

  bool get _canAddSpeed =>
      m.levelVelocityStart != null &&
      m.rotorDiameter != null &&
      _picked.isNotEmpty;

  void _addSpeedVerticals() {
    setState(() {
      for (final id in _picked) {
        final v = m.verticals.firstWhere((x) => x.id == id);
        if (canMeasureSpeed44(v)) v.isSpeedVertical = true;
      }
      _picked.clear();
    });
    _saveNow();
  }

  Future<void> _deleteSpeedVertical(VerticalPoint v) async {
    final ok = await confirmDialog(
      context,
      title: tr('Удаление'),
      message: tr(
        'Удалить скоростную вертикаль?\nУдалятся все измеренные на ней скорости, результаты промерных работ сохранятся.',
      ),
    );
    if (!ok) return;
    setState(() {
      v.clearVelocities();
    });
    await _saveNow();
  }

  double? yForVelocityPoint(VerticalPoint v, String key) {
    final h = v.avgDepth;
    final d = m.rotorDiameter;
    if (h == null || d == null) return null;
    switch (key.replaceFirst(RegExp(r'^u'), '')) {
      case 'surface':
        return d / 2 + 0.01;
      case '015':
        return 0.15 * h;
      case '04':
        return 0.4 * h;
      case '05':
        return 0.5 * h;
      case '085':
        return 0.85 * h;
      case '02':
        return 0.2 * h;
      case '06':
        return 0.6 * h;
      case '08':
        return 0.8 * h;
      case 'bottom':
        return h - d / 2 - 0.01;
    }
    return null;
  }

  int recommendedSpeedVerticals() {
    final b = m.width ?? 0;
    if (b < 1) return 1;
    if (b < 3) return 3;
    if (b < 10) return 5;
    return 8;
  }

  String? _validateCalculation() {
    if (m.levelVelocityStart == null ||
        m.levelVelocityEnd == null ||
        m.bankCoeffLeft == null ||
        m.bankCoeffRight == null ||
        m.rotorDiameter == null) {
      return tr('Не все поля заполнены');
    }
    final speed = m.verticals.where((v) => v.isSpeedVertical).toList();
    if (speed.isEmpty) return tr('Добавьте хотя бы одну скоростную вертикаль');
    if (speed.any((v) => v.avgVelocity == null)) {
      return tr('Не все скоростные вертикали заполнены');
    }
    return null;
  }

  Future<void> _calculate() async {
    final error = _validateCalculation();
    if (error != null) {
      showSnack(context, error);
      return;
    }
    _saveTimer?.cancel();
    recalcAll(m, finalCalculation: true);
    final block = calculationBlock44(m);
    if (block != null) {
      if (mounted) {
        setState(() {});
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              tr(
                block == drySpeedWarning
                    ? 'Скоростная вертикаль вне воды'
                    : block == splitSectionWarning
                    ? 'Сечение разделилось на несколько русел'
                    : 'Проверьте форму берега',
              ),
            ),
            content: SingleChildScrollView(child: Text(tr(block))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Закрыть')),
              ),
            ],
          ),
        );
      }
      return;
    }
    await WdcStorage.instance.save(m);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(measurement: m, viewOnly: false),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasSpeed = m.verticals.any((v) => v.isSpeedVertical);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await confirmDialog(
          context,
          title: tr('Назад'),
          message: tr(
            'Вернуться на экран «Промерные работы»?\nВведённые данные будут сохранены.',
          ),
        );
        if (ok) {
          await _saveNow();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Измерение скоростей')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: tr('Назад'),
                message: tr(
                  'Вернуться на экран «Промерные работы»?\nВведённые данные будут сохранены.',
                ),
              );
              if (ok) {
                await _saveNow();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
          children: [
            MeasurementComment(key: ValueKey(m.comment), measurement: m),
            MeasurementPhotos(measurement: m, editable: true),
            const SizedBox(height: 18),
            NumField(
              label: tr('Уровень воды на начало измерения скоростей течения'),
              hint: tr('Значение в метрах'),
              initial: m.levelVelocityStart,
              maxLength: 10,
              onChanged: (v) {
                setState(() {
                  m.levelVelocityStart = v == null ? null : roundTo(v, 3);
                });
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NumField(
                    label: tr('Лопастной диаметр вертушки, см'),
                    initial: m.rotorDiameter == null
                        ? null
                        : roundTo(m.rotorDiameter! * 100, 4),
                    hint: tr('Диаметр в сантиметрах, например 5'),
                    maxLength: 10,
                    onChanged: (v) {
                      setState(
                        () => m.rotorDiameter = v == null || v <= 0
                            ? null
                            : roundTo(v / 100, 6),
                      );
                      _scheduleSave();
                    },
                  ),
                ),
                IconButton(
                  tooltip: tr('Справка'),
                  icon: const Icon(Icons.help_outline),
                  onPressed: () =>
                      showInfo44(context, tr('Справка'), tr(rotorHelp44)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StatsCard(m: m),
            IceProfile44(m: m),
            SizedBox(
              height: 320,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 8,
                    child: CustomPaint(
                      painter: CrossSectionPainter(
                        measurement: m,
                        dark: Theme.of(context).brightness == Brightness.dark,
                        pickedIds: _picked,
                        showVelocities: true,
                        yForVelocityPoint: yForVelocityPoint,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Таблица промерных вертикалей'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(tr('Подсказка')),
                      content: Text(
                        tr(
                          'Чтобы добавить промерную вертикаль в список скоростных, выберите её и нажмите ниже кнопку «Добавить». ЛБ и ПБ выбрать нельзя.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (m.warnings.contains(zeroDepthWarning))
              const Warning44('Промеры с глубиной 0', zeroDepthWarning),
            _shortPromerTable(),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _canAddSpeed
                  ? _addSpeedVerticals
                  : () {
                      if (m.levelVelocityStart == null) {
                        showSnack(
                          context,
                          tr(
                            'Введите уровень воды на начало измерения скоростей',
                          ),
                        );
                      } else if (m.rotorDiameter == null) {
                        showSnack(
                          context,
                          tr('Введите лопастной диаметр вертушки'),
                        );
                      } else {
                        showSnack(
                          context,
                          tr('Выберите промерные вертикали для добавления'),
                        );
                      }
                    },
              child: Text(tr('Добавить')),
            ),
            const SizedBox(height: 8),
            Text(
              '${tr('Рекомендуемое минимальное число скоростных вертикалей')}: ${recommendedSpeedVerticals()}',
            ),
            const SizedBox(height: 18),
            Text(
              tr('Таблица скоростных вертикалей'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: NotationText(tr('Метод расчёта Uср')),
              subtitle: Text(
                presetTitle(m.calculationConfig?.preset ?? 'legacy'),
              ),
              trailing: const Icon(Icons.settings_outlined),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalculationSettingsScreen(
                      config: m.calculationConfig,
                      scope: CalculationScope.measurement,
                      allowReset: true,
                      inherited: m.initialCalculationConfig,
                      onSave: (config) async {
                        final old = m.calculationConfig;
                        m.calculationConfig = config?.copy();
                        try {
                          await _saveNow();
                        } catch (_) {
                          m.calculationConfig = old;
                          recalcAll(m, finalCalculation: true);
                          rethrow;
                        }
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
            _speedTable(),
            if (hasSpeed) ...[
              const SizedBox(height: 12),
              NumField(
                label: tr('Уровень воды на конец измерения скоростей течения'),
                hint: tr('Значение в метрах'),
                initial: m.levelVelocityEnd,
                maxLength: 10,
                onChanged: (v) {
                  setState(() {
                    m.levelVelocityEnd = v == null ? null : roundTo(v, 3);
                  });
                  _scheduleSave();
                },
              ),
            ],
            LevelOptions44(
              m: m,
              onChanged: () {
                setState(() => recalcAll(m, finalCalculation: true));
                _scheduleSave();
              },
            ),
            for (final warning in [
              invalidSlopeWarning,
              drySpeedWarning,
              splitSectionWarning,
            ])
              if (m.warnings.contains(warning))
                Warning44('Расчёт недоступен', warning),
            if (m.levelVelocityEnd != null) ...[
              const SizedBox(height: 16),
              _coeffHelpTable(),
              const SizedBox(height: 10),
              NumField(
                label: tr('Коэффициент для ЛБ'),
                hint: tr('См. таблицу выше'),
                initial: m.bankCoeffLeft,
                maxLength: 5,
                onChanged: (v) {
                  if (v == null || (v >= 0 && v <= 1)) {
                    setState(
                      () => m.bankCoeffLeft = v == null ? null : roundTo(v, 2),
                    );
                    _scheduleSave();
                  }
                },
              ),
              const SizedBox(height: 10),
              NumField(
                label: tr('Коэффициент для ПБ'),
                hint: tr('См. таблицу выше'),
                initial: m.bankCoeffRight,
                maxLength: 5,
                onChanged: (v) {
                  if (v == null || (v >= 0 && v <= 1)) {
                    setState(
                      () => m.bankCoeffRight = v == null ? null : roundTo(v, 2),
                    );
                    _scheduleSave();
                  }
                },
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: Text(tr('Рассчитать расход воды')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _shortPromerTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(tr('Берег'))),
          DataColumn(label: Text(tr('Расст., м'))),
          DataColumn(label: Text(tr('Глуб., м'))),
        ],
        rows: m.verticals.map((v) {
          final disabled =
              !canMeasureSpeed44(v) ||
              v.isSpeedVertical ||
              m.levelVelocityStart == null ||
              m.rotorDiameter == null;
          final picked = _picked.contains(v.id);
          return DataRow(
            selected: picked || v.isSpeedVertical,
            color: WidgetStateProperty.resolveWith((_) {
              if (v.isSpeedVertical) {
                return Colors.green.withValues(alpha: 0.12);
              }
              if (picked) return Colors.red.withValues(alpha: 0.12);
              return null;
            }),
            cells: [
              DataCell(Text(bankLabel(v.bank))),
              DataCell(Text(_numCell(v.distance, 3))),
              DataCell(Text(_numCell(v.avgDepth, 3))),
            ],
            onSelectChanged: disabled
                ? null
                : (_) => setState(() {
                    if (picked) {
                      _picked.remove(v.id);
                    } else {
                      _picked.add(v.id);
                    }
                  }),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openVelocity(VerticalPoint v) async {
    await _saveNow();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VelocityEditor(measurement: m, vertical: v),
      ),
    );
    if (mounted) {
      setState(() {
        recalcAll(m, finalCalculation: true);
      });
    }
  }

  Widget _speedTable() {
    final speed = m.verticals.where((v) => v.isSpeedVertical).toList();
    if (speed.isEmpty) {
      return Text(tr('Скоростные вертикали пока не добавлены'));
    }
    final rowHeight = math.max(
      64.0,
      MediaQuery.textScalerOf(context).scale(24) + 28,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: DataTable(
            key: const ValueKey('fixed-distance-column'),
            horizontalMargin: 8,
            columnSpacing: 0,
            headingRowHeight: rowHeight,
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight,
            columns: [DataColumn(label: Text(tr('Расст., м')))],
            rows: speed
                .map(
                  (v) =>
                      DataRow(cells: [DataCell(Text(_numCell(v.distance, 3)))]),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('velocity-horizontal-scroll'),
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: rowHeight,
              dataRowMinHeight: rowHeight,
              dataRowMaxHeight: rowHeight,
              horizontalMargin: 8,
              columnSpacing: 14,
              columns: [
                DataColumn(label: Text(tr('Глуб., м'))),
                DataColumn(label: Text(tr('Скорости'))),
                DataColumn(label: NotationText(tr('Uср, м/с'))),
                const DataColumn(label: Text('')),
              ],
              rows: speed
                  .map(
                    (v) => DataRow(
                      cells: [
                        DataCell(Text(_numCell(v.avgDepth, 3))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _openVelocity(v),
                                child: Text(tr('Ввести')),
                              ),
                              if (v.individualConfig != null)
                                Tooltip(
                                  message: tr('Индивидуальный метод'),
                                  child: const Icon(Icons.tune, size: 18),
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            v.avgVelocity == null
                                ? tr('н/д')
                                : _numCell(v.avgVelocity, 4),
                            style: TextStyle(
                              color: v.avgVelocity == null
                                  ? Colors.grey
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteSpeedVertical(v),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _coeffHelpTable() {
    final rows = [
      ['0.5', tr('Мёртвое пространство')],
      [
        '0.7',
        tr(
          'Пологий берег с нулевой глубиной на урезе; вблизи границы скопления неподвижной шуги',
        ),
      ],
      [
        '0.8',
        tr('Обрывистый берег или неровная стенка (бут, неотёсанный камень)'),
      ],
      [
        '0.9',
        tr(
          'Гладкая бетонная или сплошь обшитая досками стенка; течение воды поверх льда',
        ),
      ],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Коэффициент для скоростей на прибрежных вертикалях'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        r[0],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: Text(r[1])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================
// Result screen
// =============================

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.measurement,
    required this.viewOnly,
  });
  final WdcMeasurement measurement;
  final bool viewOnly;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SettingsRefresh<ResultScreen> {
  late WdcMeasurement m;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    m = widget.measurement;
    recalcAll(m, finalCalculation: true);
  }

  Future<void> _reopen() async {
    final ok = await confirmDialog(
      context,
      title: tr('Редактирование'),
      message: tr('Войти в режим редактирования?'),
    );
    if (!ok || !mounted) return;
    reopenMeasurement(m);
    await WdcStorage.instance.save(m);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SoundingScreen(measurement: m)),
    );
  }

  Future<void> _shareCsv() async {
    final f = await WdcStorage.instance.exportCsv(m);
    await shareFiles44([XFile(f.path)], text: tr('CSV расчёта расхода воды'));
  }

  Future<void> _sharePdf() async {
    try {
      final f = await WdcStorage.instance.exportPdf(m);
      await shareFiles44([
        XFile(f.path),
      ], text: tr('PDF-отчёт расчёта расхода воды'));
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          tr(
            'Не удалось создать PDF. Проверьте, что все фотографии доступны и на устройстве есть свободное место.',
          ),
        );
      }
    }
  }

  Future<void> _saveComplete() async {
    if (_saving) return;
    _saving = true;
    final ok = await confirmDialog(
      context,
      title: tr('Сохранение'),
      message: tr('Сохранить и выйти в главное меню?'),
      yesIsPrimary: true,
    );
    if (!ok || !mounted) {
      _saving = false;
      return;
    }
    final close = showWorkProgress(context, tr('Сохраняем измерение…'));
    final wasCompleted = m.completed;
    try {
      m.completed = true;
      await WdcStorage.instance.save(m);
      // Home receives the committed snapshot before navigation reveals it.
      close();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      m.completed = wasCompleted;
      close();
      if (mounted) {
        showSnack(
          context,
          tr('Не удалось сохранить измерение. Попробуйте ещё раз.'),
        );
      }
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final speedRows = m.verticals
        .where((v) => v.isSpeedVertical || v.partialDischarge != null)
        .toList();
    return PopScope(
      canPop: widget.viewOnly,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || widget.viewOnly) return;
        final ok = await confirmDialog(
          context,
          title: tr('Назад'),
          message: tr(
            'Вернуться на экран «Измерение скоростей течения»?\nРасчёт расхода потребуется выполнить заново.\nВведённый комментарий сохранится.',
          ),
        );
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Расход воды')),
          leading: widget.viewOnly
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: tr('Назад'),
                      message: tr(
                        'Вернуться на экран «Измерение скоростей течения»?\nРасчёт расхода потребуется выполнить заново.\nВведённый комментарий сохранится.',
                      ),
                    );
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                ),
          actions: [
            if (widget.viewOnly)
              IconButton(
                tooltip: tr('Редактировать измерение'),
                onPressed: _reopen,
                icon: const Icon(Icons.edit_note),
              ),
            IconButton(
              tooltip: tr('Поделиться CSV'),
              onPressed: _shareCsv,
              icon: const CsvExportIcon(),
            ),
            IconButton(
              tooltip: tr('Экспорт PDF'),
              onPressed: _sharePdf,
              icon: const PdfExportIcon(),
            ),
            if (!widget.viewOnly)
              IconButton(
                tooltip: tr('Сохранить'),
                onPressed: _saveComplete,
                icon: const Icon(Icons.save),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(measurementTimeZone(m)),
                    ...measurementTimes(
                      m,
                    ).entries.map((e) => Text('${e.key}: ${e.value}')),
                    Text(
                      '${m.titleRiver} — ${m.titleSite}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tr('Расход воды')}: ${_numCell(m.discharge, 6)} ${tr('м³/с')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MeasurementComment(measurement: m),
                    MeasurementPhotos(measurement: m, editable: true),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('${tr('Координаты')}: ${coordinatesText(m)}'),
                ),
                IconButton(
                  tooltip: tr('Скопировать координаты'),
                  icon: const Icon(Icons.copy),
                  onPressed: m.latitude == null || m.longitude == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: coordinatesText(m)),
                          );
                          if (context.mounted) {
                            showSnack(context, tr('Координаты скопированы'));
                          }
                        },
                ),
              ],
            ),
            Text(
              '${tr('Уровень воды во время промерных работ')}: ${_numCell(m.meanSoundingLevel, 3)} ${tr('м')}',
            ),
            Text(
              '${tr('Уровень воды во время измерения скоростей')}: ${_numCell(m.meanVelocityLevel, 3)} ${tr('м')}',
            ),
            Text(
              '${tr('Изменение уровня')}: ${_numCell(m.levelCorrection, 3)} ${tr('м')}',
            ),
            Text('${tr('Коэффициент ЛБ')}: ${_numCell(m.bankCoeffLeft, 2)}'),
            Text('${tr('Коэффициент ПБ')}: ${_numCell(m.bankCoeffRight, 2)}'),
            if (m.geometry44 && (m.levelCorrection ?? 0) > 0)
              Text(
                '${bankLabel('ЛБ')}: ${bankMode44(m.leftExtrapolation)}; ${bankLabel('ПБ')}: ${bankMode44(m.rightExtrapolation)}',
              ),
            Text(
              '${tr('Лопастной диаметр вертушки')}: ${_numCell(m.rotorDiameter == null ? null : m.rotorDiameter! * 100, 2)} ${tr('см')}',
            ),
            const SizedBox(height: 12),
            StatsCard(m: m),
            IceProfile44(m: m),
            if (m.warnings.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Предупреждения'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...m.warnings.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(tr(w)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              height: 340,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 8,
                    child: CustomPaint(
                      painter: CrossSectionPainter(
                        measurement: m,
                        dark: Theme.of(context).brightness == Brightness.dark,
                        showVelocities: true,
                        showDischarges: false,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Таблица промерных вертикалей'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            resultSoundingTable(m.verticals, showIce: m.iceCover),
            const SizedBox(height: 16),
            Text(
              tr('Таблица скоростных вертикалей'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            resultVelocityTable(context, speedRows),
          ],
        ),
      ),
    );
  }
}

// =============================
// Painter
// =============================

class CrossSectionPainter extends CustomPainter {
  CrossSectionPainter({
    required this.measurement,
    this.pickedIds = const {},
    this.showVelocities = false,
    this.showDischarges = false,
    this.yForVelocityPoint,
    this.dark = false,
  });

  final WdcMeasurement measurement;
  final bool dark;
  final Set<String> pickedIds;
  final bool showVelocities;
  final bool showDischarges;
  final double? Function(VerticalPoint, String)? yForVelocityPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final m = measurement;
    if (m.geometry44) {
      ProfilePainter44(
        m,
        dark: dark,
        picked: pickedIds,
        velocities: showVelocities,
        discharges: showDischarges,
      ).paint(canvas, size);
      return;
    }
    if (m.verticals.length < 2) {
      _text(
        canvas,
        tr('Недостаточно данных для графика'),
        const Offset(20, 20),
        dark ? Colors.white : Colors.black,
        14,
      );
      return;
    }
    final ink = dark ? Colors.white : Colors.black;
    final vertices = m.verticals;
    final minX = vertices.map((v) => v.distance ?? 0).reduce(math.min);
    final maxX = vertices.map((v) => v.distance ?? 0).reduce(math.max);
    final maxH = math.max(
      0.1,
      vertices.map((v) => v.correctedDepth ?? v.avgDepth ?? 0).reduce(math.max),
    );
    const left = 76.0;
    const top = 70.0;
    const right = 22.0;
    const bottom = 30.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final dxRange = math.max(0.001, maxX - minX);
    final lbDist = m.leftBank?.distance;
    final rbDist = m.rightBank?.distance;
    final invertX = lbDist != null && rbDist != null && lbDist > rbDist;

    double sx(double x) => invertX
        ? left + (maxX - x) / dxRange * w
        : left + (x - minX) / dxRange * w;
    double sy(double depth) => top + depth / maxH * h;

    final water = Path()..moveTo(sx(vertices.first.distance ?? minX), sy(0));
    for (final v in vertices) {
      water.lineTo(
        sx(v.distance ?? 0),
        sy(v.correctedDepth ?? v.avgDepth ?? 0),
      );
    }
    water.lineTo(sx(vertices.last.distance ?? maxX), sy(0));
    water.close();
    final waterPaint = Paint()
      ..color = const Color(0xFFBDEBFF).withValues(alpha: 0.55);
    canvas.drawPath(water, waterPaint);

    final surfacePaint = Paint()
      ..color = Colors.blue.shade800
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(sx(vertices.first.distance ?? minX), sy(0)),
      Offset(sx(vertices.last.distance ?? maxX), sy(0)),
      surfacePaint,
    );

    final bedPaint = Paint()
      ..color = (dark ? const Color(0xFFD7B49E) : Colors.brown.shade700)
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke;
    final bed = Path();
    for (var i = 0; i < vertices.length; i++) {
      final v = vertices[i];
      final p = Offset(
        sx(v.distance ?? 0),
        sy(v.correctedDepth ?? v.avgDepth ?? 0),
      );
      if (i == 0) {
        bed.moveTo(p.dx, p.dy);
      } else {
        bed.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(bed, bedPaint);

    for (final v in vertices) {
      final x = sx(v.distance ?? 0);
      final y = sy(v.correctedDepth ?? v.avgDepth ?? 0);
      canvas.drawCircle(
        Offset(x, y),
        3.5,
        Paint()
          ..color = (dark ? const Color(0xFFD7B49E) : Colors.brown.shade700),
      );
      if ((v.correctedDepth ?? v.avgDepth ?? 0) > 0 && v.bank != null) {
        canvas.drawLine(Offset(x, sy(0)), Offset(x, y), bedPaint);
      }
    }

    // Axes, ticks and labels
    final axis = Paint()
      ..color = dark ? Colors.white70 : Colors.black54
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(left, top), Offset(left, top + h), axis);
    canvas.drawLine(const Offset(left, top), Offset(left + w, top), axis);

    final xStep = _niceStep(dxRange / 5);
    final xStart = (minX / xStep).ceil() * xStep;
    for (double x = xStart; x <= maxX + xStep * 0.25; x += xStep) {
      final px = sx(x);
      if (px < left - 0.5 || px > left + w + 0.5) continue;
      canvas.drawLine(Offset(px, top), Offset(px, top - 5), axis);
      _text(
        canvas,
        _formatTick(x, xStep),
        Offset(px, top - 22),
        dark ? Colors.white70 : Colors.black87,
        11,
        anchorX: 0.5,
      );
    }

    final yStep = _niceStep(maxH / 5);
    for (double y = 0; y <= maxH + yStep * 0.25; y += yStep) {
      final py = sy(y);
      if (py < top - 0.5 || py > top + h + 0.5) continue;
      canvas.drawLine(Offset(left - 5, py), Offset(left, py), axis);
      _text(
        canvas,
        _formatTick(y, yStep),
        Offset(left - 9, py - 7),
        dark ? Colors.white70 : Colors.black87,
        11,
        anchorX: 1,
      );
    }

    _text(canvas, bankLabel('ЛБ'), const Offset(left, 10), ink, 17, bold: true);
    _text(
      canvas,
      bankLabel('ПБ'),
      Offset(left + w - 28, 10),
      ink,
      17,
      bold: true,
    );
    _rotatedText(canvas, tr('Глуб., м'), Offset(5, top + h / 2 + 32), ink, 14);
    _text(
      canvas,
      tr('Расст., м'),
      Offset(left + w / 2, 12),
      ink,
      14,
      anchorX: 0.5,
    );

    for (final v in vertices.where(
      (v) => pickedIds.contains(v.id) || v.isSpeedVertical,
    )) {
      final x = sx(v.distance ?? 0);
      final depth = v.correctedDepth ?? v.avgDepth ?? 0;
      Color color;
      if (pickedIds.contains(v.id) && !v.isSpeedVertical) {
        color = Colors.red;
      } else if (v.avgVelocity != null) {
        color = Colors.green.shade700;
      } else {
        color = ink;
      }
      canvas.drawLine(
        Offset(x, sy(0)),
        Offset(x, sy(depth)),
        Paint()
          ..color = color
          ..strokeWidth = 2.2,
      );

      if (showVelocities) {
        final points = v.velocityPoints;
        for (final entry in points.entries) {
          if (entry.value.value == null) continue;
          final yy =
              yForVelocityPoint?.call(v, entry.key) ??
              _defaultYFor(m, v, entry.key);
          if (yy == null) continue;
          canvas.drawCircle(
            Offset(x, sy(yy)),
            4,
            Paint()..color = velocityPointColor(v, entry.key, dark: dark),
          );
        }
      }
    }

    canvas.drawPath(bed, bedPaint);

    for (final v in vertices) {
      final x = sx(v.distance ?? 0);
      final y = sy(v.correctedDepth ?? v.avgDepth ?? 0);
      canvas.drawCircle(
        Offset(x, y),
        3.5,
        Paint()
          ..color = (dark ? const Color(0xFFD7B49E) : Colors.brown.shade700),
      );
      if ((v.correctedDepth ?? v.avgDepth ?? 0) > 0 && v.bank != null) {
        canvas.drawLine(Offset(x, sy(0)), Offset(x, y), bedPaint);
      }
    }

    if (showDischarges) {
      final internal = <double>[];
      final speed = vertices.where((v) => v.isSpeedVertical).toList();
      if (speed.length >= 2) {
        for (var i = 1; i < speed.length; i++) {
          final q = speed[i].partialDischarge;
          if (q != null) internal.add(q);
        }
      }
      final meanInternal = internal.isEmpty
          ? null
          : internal.reduce((a, b) => a + b) / internal.length;

      for (var i = 0; i < vertices.length; i++) {
        final v = vertices[i];
        final q = v.partialDischarge;
        if (q == null) continue;
        var color = ink;
        if (meanInternal != null && meanInternal > 0) {
          final firstSpeedId = speed.isNotEmpty ? speed.first.id : null;
          final isEdge = v.id == firstSpeedId || i == vertices.length - 1;
          if (isEdge && q / meanInternal > 0.3) color = Colors.red;
        }
        final x = sx(v.distance ?? 0);
        final y = sy((v.correctedDepth ?? v.avgDepth ?? 0) * 0.55);
        _text(
          canvas,
          '${fmtAdaptive(q, small: 1)}\n${tr('м³/с')}',
          Offset(x + 4, y),
          color,
          11,
          bold: true,
        );
      }
    }
  }

  double? _defaultYFor(WdcMeasurement m, VerticalPoint v, String key) {
    final h = v.correctedDepth ?? v.avgDepth;
    final d = m.rotorDiameter;
    if (h == null || d == null) return null;
    switch (key.replaceFirst(RegExp(r'^u'), '')) {
      case 'surface':
        return d / 2 + 0.01;
      case '015':
        return 0.15 * h;
      case '04':
        return 0.4 * h;
      case '05':
        return 0.5 * h;
      case '085':
        return 0.85 * h;
      case '02':
        return 0.2 * h;
      case '06':
        return 0.6 * h;
      case '08':
        return 0.8 * h;
      case 'bottom':
        return h - d / 2 - 0.01;
    }
    return null;
  }

  double _niceStep(double raw) {
    if (raw <= 0 || raw.isNaN || raw.isInfinite) return 1;
    final exponent = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final fraction = raw / exponent;
    double niceFraction;
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 2.5) {
      niceFraction = 2.5;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
    return niceFraction * exponent;
  }

  String _formatTick(double value, double step) {
    final a = step.abs();
    int digits;
    if (a >= 1) {
      digits = 0;
    } else if (a >= 0.1) {
      digits = 1;
    } else if (a >= 0.01) {
      digits = 2;
    } else {
      digits = 3;
    }
    return roundTo(value, digits).toStringAsFixed(digits);
  }

  void _rotatedText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(-math.pi / 2);
    _text(canvas, text, Offset.zero, color, fontSize, bold: bold);
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool bold = false,
    double anchorX = 0,
  }) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'WdcReport',
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    final tp = TextPainter(
      text: span,
      textDirection: ui.TextDirection.ltr,
      maxLines: 3,
    );
    tp.layout(maxWidth: 90);
    tp.paint(canvas, Offset(offset.dx - tp.width * anchorX, offset.dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =============================
// Help
// =============================

class HelpScreen extends SettingsScreen {
  const HelpScreen({super.key});
}
