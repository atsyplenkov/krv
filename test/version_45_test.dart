import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;
import 'version_44_test.dart' show triangle, csvRows;

WdcMeasurement mixedDepths() {
  final m = sample()
    ..geometry44 = true
    ..calculationConfig = CalculationConfig();
  m.verticals = List.generate(
    5,
    (i) => VerticalPoint(
      id: 'v$i',
      distance: i.toDouble(),
      bank: i == 0
          ? 'ЛБ'
          : i == 4
          ? 'ПБ'
          : null,
      depth1: [0, 1, 2, 1, 0][i].toDouble(),
      isSpeedVertical: i > 0 && i < 4,
      u06: VelocityPoint(
        value: i > 0 && i < 4 ? 1 : null,
        changedAt: '2026-10-01T12:00:00',
      ),
    ),
  );
  return m;
}

String observations(WdcMeasurement m) => jsonEncode({
  'times': [
    m.levelSoundingStartAt,
    m.levelSoundingEndAt,
    m.levelVelocityStartAt,
    m.levelVelocityEndAt,
  ],
  'config': m.calculationConfig?.toJson(),
  'banks': [m.leftExtrapolation, m.rightExtrapolation],
  'verticals': m.verticals
      .map(
        (v) => {
          'id': v.id,
          'distance': v.distance,
          'depth1': v.depth1,
          'depth2': v.depth2,
          'ice': v.iceThicknessCm,
          'bed': v.bottomType,
          'selected': v.isSpeedVertical,
          'individual': v.individualConfig?.toJson(),
          'velocities': {
            for (final e in v.velocityPoints.entries)
              e.key: [e.value.value, e.value.changedAt],
          },
        },
      )
      .toList(),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  final output = Directory('test-output/version-45');
  setUpAll(() async {
    await output.create(recursive: true);
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'WdcReport',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wdc45-');
    AppSettings.current = AppSettings(language: 'ru', autoGps: false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
  });
  tearDown(() async {
    await WdcStorage.instance.flush();
    await temp.delete(recursive: true);
  });

  test(
    'Dry exclusions and rewetting preserve all observations, methods and timestamps',
    () {
      final m = mixedDepths();
      final before = observations(m);
      m.levelVelocityStart = m.levelVelocityEnd = -1;
      recalcAll(m, finalCalculation: true);
      expect(m.area, 1);
      expect(m.discharge, .7);
      expect(m.verticals[1].partialDischarge, isNull);
      expect(m.verticals[3].sectionArea, isNull);
      expect(
        m.warnings.singleWhere((w) => w.startsWith(drySpeedWarning)),
        contains('Расстояния: 1 м, 3 м'),
      );
      expect(observations(m), before);
      m.levelVelocityStart = m.levelVelocityEnd = 0;
      recalcAll(m, finalCalculation: true);
      expect(m.discharge, 3.7);
      expect(observations(m), before);
      expect(m.warnings.any((w) => w.startsWith(drySpeedWarning)), isFalse);
    },
  );
  test(
    'Missing speeds on dry verticals do not block eligible wet verticals',
    () {
      final m = mixedDepths()
        ..levelVelocityStart = -1
        ..levelVelocityEnd = -1;
      m.verticals[1].u06.value = null;
      recalcAll(m, finalCalculation: true);
      expect(m.discharge, .7);
      m.levelVelocityStart = m.levelVelocityEnd = 0;
      recalcAll(m, finalCalculation: true);
      expect(m.discharge, isNull);
    },
  );
  for (final reverse in [false, true]) {
    test(
      'Independent bank fallback restores selected slope reverse=$reverse',
      () {
        final m = triangle(delta: 1, left: true, right: true, reverse: reverse);
        m.verticals.insert(
          1,
          VerticalPoint(id: 'flat', distance: reverse ? 3 : 1, depth1: 0),
        );
        final before = observations(m);
        recalcAll(m, finalCalculation: true);
        expect(sectionGeometry44(m).fallbackBanks, ['ЛБ']);
        expect(m.area, 7.5);
        expect(m.discharge, 5.25);
        expect(observations(m), before);
        expect(m.warnings, contains('$invalidSlopeWarning\nЛБ'));
        m.verticals[1].depth1 = 1;
        recalcAll(m, finalCalculation: true);
        expect(m.leftExtrapolation, isTrue);
        expect(sectionGeometry44(m).fallbackBanks, isEmpty);
        expect(m.area, 9);
        expect(m.discharge, 6.3);
      },
    );
  }
  test(
    'Undefined Q is null, warnings are refreshed, and CSV schema stays uniform',
    () async {
      final m = triangle(delta: -2)..completed = true;
      expect(m.discharge, isNull);
      expect(m.warnings, contains(undefinedDischargeWarning));
      final rows = csvRows(
        await (await WdcStorage.instance.exportCsv(m)).readAsString(),
      );
      expect(rows.first.length, 88);
      expect(rows.skip(1).every((r) => r.length == 88), isTrue);
      final profile = jsonDecode(
        rows[1][rows.first.indexOf('calculated_profile_json')],
      );
      expect(profile['discharge_defined'], false);
      expect(profile['excluded_velocity_vertical_ids'], ['v']);
      final metadata = jsonDecode(
        rows[1][rows.first.indexOf('measurement_metadata_json')],
      );
      expect(metadata['discharge'], isNull);
      expect(metadata['warnings'], contains(undefinedDischargeWarning));
      recalcAll(m, finalCalculation: true);
      expect(m.warnings.where((w) => w == undefinedDischargeWarning).length, 1);
      final path = await KrvTransfer.exportArchive(temp.path, [
        m.toJson(),
      ], temp.path);
      final plan = await KrvTransfer.inspect(
        path,
        '${temp.path}/target',
        temp.path,
      );
      final restored = WdcMeasurement.fromJson(plan.records.single.measurement);
      expect(observations(restored), observations(m));
      await plan.dispose();
    },
  );
  test(
    'Incomplete stage readings do not falsely mark every vertical excluded',
    () async {
      final m = triangle()..levelVelocityEnd = null;
      recalcAll(m, finalCalculation: true);
      final rows = csvRows(
        await (await WdcStorage.instance.exportCsv(m)).readAsString(),
      );
      final profile = jsonDecode(
        rows[1][rows.first.indexOf('calculated_profile_json')],
      );
      expect(profile['excluded_velocity_vertical_ids'], isEmpty);
      expect(profile['discharge_defined'], isFalse);
    },
  );
  test('Waterline geometry clips both directions and leaves a dry gap', () {
    final m = mixedDepths()
      ..levelVelocityStart = -1
      ..levelVelocityEnd = -1;
    recalcAll(m, finalCalculation: true);
    expect(sectionGeometry44(m).wet.first.a.x, 1);
    expect(sectionGeometry44(m).wet.last.b.x, 3);
    expect(sectionGeometry44(m, deltaOverride: 0).wet.first.a.x, 0);
    final rise = triangle(delta: 1, left: true, right: true);
    expect(sectionGeometry44(rise).wet.first.a.x, -1);
    expect(sectionGeometry44(rise, deltaOverride: 0).wet.first.a.x, 0);
    m.verticals[2].depth1 = 0;
    m.verticals[1].depth1 = m.verticals[3].depth1 = 2;
    recalcAll(m, finalCalculation: true);
    expect(sectionGeometry44(m).waterBodies, 2);
    expect(
      sectionGeometry44(m).wet.every(
        (s) => s.a.x <= 1.5 && s.b.x <= 1.5 || s.a.x >= 2.5 && s.b.x >= 2.5,
      ),
      isTrue,
    );
  });
  test('Citations use supplied local date and both required formats', () {
    final date = DateTime(2027, 1, 2);
    expect(citation45(iso: false, date: date), contains('02.01.2027'));
    expect(citation45(iso: true, date: date), contains('2 January 2027'));
    expect(citation45(iso: false, date: date), contains('О. Д. Лошков'));
  });
  test(
    'Every About paragraph and generated warning has an English version',
    () {
      expect(aboutEnglish45.keys.toSet(), aboutRussian45.keys.toSet());
      AppSettings.current.language = 'en';
      for (final w in [
        zeroDepthWarning,
        splitSectionWarning,
        undefinedDischargeWarning,
        '$drySpeedWarning\n1 м, 3 м',
        '$invalidSlopeWarning\nЛБ, ПБ',
        higherLevelWarning,
        lowerLevelWarning,
      ]) {
        expect(RegExp('[А-Яа-яЁё]').hasMatch(tr(w)), isFalse, reason: w);
      }
    },
  );
  test('License deduplication retains all attributions', () async {
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks([
        'package-A',
      ], 'Copyright Owner\n\nPermission is granted.');
      yield const LicenseEntryWithLineBreaks([
        'package-B',
      ], 'Copyright Owner\n\nPermission is granted.');
      yield const LicenseEntryWithLineBreaks([
        'package-A',
      ], 'Copyright Another Owner\n\nPermission is granted.');
    });
    final notices = await collectLicenses45();
    expect(notices['Copyright Owner\n\nPermission is granted.'], [
      'package-A',
      'package-B',
    ]);
    expect(notices['Copyright Another Owner\n\nPermission is granted.'], [
      'package-A',
    ]);
  });

  Future<void> shot(WidgetTester t, GlobalKey key, String name) async {
    await t.pump();
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await File('${output.path}/$name.png').writeAsBytes(
        (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      image.dispose();
    });
  }

  for (final lang in ['ru', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'Real app theme home, Settings, warnings and editor $lang dark=$dark',
        (t) async {
          t.view.physicalSize = const Size(390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          AppSettings.current = AppSettings(
            language: lang,
            autoGps: false,
            theme: dark ? 'dark' : 'light',
          );
          final m = triangle(delta: -2)
            ..completed = true
            ..calculationConfig = CalculationConfig();
          await t.runAsync(() => WdcStorage.instance.save(m));
          final key = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(key: key, child: const WaterDischargeApp()),
          );
          await settleIo(t);
          expect(find.byIcon(Icons.error_outline), findsOneWidget);
          expect(
            find.textContaining(tr('Расход не определён')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('import-krv')), findsNothing);
          await shot(t, key, 'home-$lang-$dark');
          await t.tap(find.byIcon(Icons.settings_outlined));
          await t.pumpAndSettle();
          expect(find.text(tr('Импортировать файл .krv')), findsOneWidget);
          await shot(t, key, 'settings-$lang-$dark');
          await t.tap(find.byType(BackButton));
          await settleIo(t);
          Navigator.of(t.element(find.byType(HomeScreen))).push(
            MaterialPageRoute(
              builder: (_) => ResultScreen(measurement: m, viewOnly: true),
            ),
          );
          await t.pumpAndSettle();
          await t.scrollUntilVisible(
            find.byWidgetPredicate(
              (w) => w is Warning44 && w.message == lowerLevelWarning,
            ),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await t.pumpAndSettle();
          expect(find.byType(Warning44), findsNWidgets(m.warnings.length));
          await shot(t, key, 'warnings-$lang-$dark');
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          final normal = mixedDepths();
          recalcAll(normal);
          await t.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
                fontFamily: 'WdcReport',
              ),
              home: RepaintBoundary(
                key: key,
                child: VelocityEditor(
                  measurement: normal,
                  vertical: normal.verticals[2],
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          await shot(t, key, 'editor-$lang-$dark');
          expect(
            find.text(presetTitle(normal.calculationConfig!.preset)),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
    testWidgets('Citation and About navigation $lang', (t) async {
      AppSettings.current.language = lang;
      await t.pumpWidget(const MaterialApp(home: CitationScreen45()));
      await t.pumpAndSettle();
      expect(find.text('ISO 690'), findsOneWidget);
      expect(find.text('ГОСТ'), lang == 'ru' ? findsOneWidget : findsNothing);
      await t.pumpWidget(const MaterialApp(home: AboutScreen44()));
      await t.pumpAndSettle();
      expect(find.text(tr('История версий')), findsNothing);
      expect(
        aboutRussian45['intro'],
        contains('Приложение навайбкожено в 2025—2026 гг.'),
      );
    });
    test('PDF exports all fallback and undefined-Q warnings $lang', () async {
      AppSettings.current.language = lang;
      for (final item in {
        'dry': triangle(delta: -2),
        'fallback': triangle(delta: 1, left: true)
          ..verticals.insert(
            1,
            VerticalPoint(id: 'flat', distance: 1, depth1: 0),
          ),
      }.entries) {
        recalcAll(item.value, finalCalculation: true);
        await File(
          '${output.path}/${item.key}-$lang.pdf',
        ).writeAsBytes(await pdfBytes(item.value));
      }
    });
  }
}
