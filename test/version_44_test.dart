import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;

WdcMeasurement triangle({
  double delta = 0,
  bool left = false,
  bool right = false,
  bool reverse = false,
}) {
  final m = sample()
    ..geometry44 = true
    ..leftExtrapolation = left
    ..rightExtrapolation = right
    ..levelVelocityStart = delta
    ..levelVelocityEnd = delta;
  if (reverse) {
    for (final v in m.verticals) {
      v.distance = 4 - v.distance!;
    }
  }
  recalcAll(m, finalCalculation: true);
  return m;
}

// Quoted CSV fields can contain semicolons, escaped quotes and line breaks.
List<List<String>> csvRows(String csv) {
  final rows = <List<String>>[], row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < csv.length; i++) {
    final ch = csv[i];
    if (ch == '"') {
      if (quoted && i + 1 < csv.length && csv[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && (ch == ';' || ch == '\n')) {
      row.add(cell.toString());
      cell = StringBuffer();
      if (ch == '\n') {
        rows.add(List.of(row));
        row.clear();
      }
    } else {
      cell.write(ch);
    }
  }
  row.add(cell.toString());
  rows.add(row);
  return rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  final output = Directory('test-output/version-44');
  setUpAll(() async {
    await output.create(recursive: true);
    await (FontLoader(
      'WdcReport',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wdc44-');
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

  for (final reverse in [false, true]) {
    test(
      'Independent triangular geometry, both chainage directions $reverse',
      () {
        final m = triangle(reverse: reverse);
        expect(m.area, 4);
        expect(m.width, 4);
        expect(m.discharge, 2.8);
        expect(m.wettedPerimeter, closeTo(4 * math.sqrt(2), .0006));
        final rise = triangle(delta: 1, reverse: reverse);
        expect(rise.area, 8);
        expect(rise.width, 4);
        expect(rise.maxDepth, 3);
        expect(rise.meanDepth, 2);
        expect(rise.discharge, 5.6);
        expect(rise.wettedPerimeter, closeTo(4 * math.sqrt(2) + 2, .0006));
        final slope = triangle(
          delta: 1,
          left: true,
          right: true,
          reverse: reverse,
        );
        expect(slope.area, 9);
        expect(slope.width, 6);
        expect(slope.discharge, 6.3);
        expect(slope.wettedPerimeter, closeTo(6 * math.sqrt(2), .0006));
        final mixed = triangle(delta: 1, left: true, reverse: reverse);
        expect(mixed.area, 8.5);
        expect(mixed.width, 5);
        expect(mixed.discharge, 5.95);
        expect(mixed.wettedPerimeter, closeTo(5 * math.sqrt(2) + 1, .0006));
        final fall = triangle(delta: -1, reverse: reverse);
        expect(fall.area, 1);
        expect(fall.width, 2);
        expect(fall.meanDepth, .5);
        expect(fall.discharge, .7);
        expect(fall.wettedPerimeter, closeTo(2 * math.sqrt(2), .0006));
      },
    );
  }
  test('Asymmetric independent section and unequal edge coefficients', () {
    final m = sample()
      ..geometry44 = true
      ..bankCoeffLeft = .5
      ..bankCoeffRight = .9;
    m.verticals = List.generate(
      6,
      (i) => VerticalPoint(
        id: 'p$i',
        bank: i == 0
            ? 'ЛБ'
            : i == 5
            ? 'ПБ'
            : null,
        distance: [0, 1, 2, 4, 7, 8][i].toDouble(),
        depth1: [0, 1, 2, 3, 1, 0][i].toDouble(),
        isSpeedVertical: [1, 3, 4].contains(i),
        u06: VelocityPoint(value: {1: .4, 3: .8, 4: .6}[i]),
      ),
    );
    recalcAll(m, finalCalculation: true);
    // Areas: .5, 1.5, 5, 6, .5. Q=.1+3.9+4.2+.27.
    expect(m.area, 13.5);
    expect(m.discharge, 8.47);
    expect(m.width, 8);
    expect(m.meanDepth, 1.688);
    expect(m.verticals[3].sectionArea, 6.5);
    expect(m.verticals[4].partialDischarge, 4.2);
  });
  test(
    'Repeated level and bank changes never accumulate or alter field observations',
    () {
      final m = triangle();
      final originals = m.verticals
          .map(
            (v) => [
              v.distance,
              v.depth1,
              v.depth2,
              v.depth1At,
              v.depth2At,
              v.u06.toJson(),
            ],
          )
          .toList();
      for (final d in [1.0, -1.0, .4, 0.0, 1.0]) {
        m.levelVelocityStart = d;
        m.levelVelocityEnd = d;
        recalcAll(m, finalCalculation: true);
        recalcAll(m, finalCalculation: true);
      }
      expect(m.area, 8);
      expect(
        m.verticals
            .map(
              (v) => [
                v.distance,
                v.depth1,
                v.depth2,
                v.depth1At,
                v.depth2At,
                v.u06.toJson(),
              ],
            )
            .toList(),
        originals,
      );
      expect(m.warnings.where((w) => w == higherLevelWarning).length, 1);
      m.levelVelocityEnd = null;
      recalcAll(m, finalCalculation: true);
      expect(m.discharge, isNull);
      expect(m.levelCorrection, isNull);
    },
  );
  test('Mean levels, not the final readings alone, control correction', () {
    final m = sample()
      ..geometry44 = true
      ..levelSoundingStart = 2
      ..levelSoundingEnd = 0
      ..levelVelocityStart = 0
      ..levelVelocityEnd = 1;
    recalcAll(m, finalCalculation: true);
    expect(m.levelCorrection, -.5);
    expect(m.area, 2.25);
    expect(m.width, 3);
  });
  test('Dry speed vertical blocks final Q without deleting any speeds', () {
    final m = triangle(delta: -2);
    expect(m.discharge, isNull);
    expect(m.warnings, contains(drySpeedWarning));
    expect(m.verticals[1].u06.value, 1);
    expect(m.verticals[1].isSpeedVertical, isTrue);
    m.levelVelocityStart = 0;
    m.levelVelocityEnd = 0;
    recalcAll(m, finalCalculation: true);
    expect(m.discharge, 2.8);
    expect(m.warnings, isNot(contains(drySpeedWarning)));
  });
  test('Falling water splits a shallow saddle and blocks Q', () {
    final m = sample()
      ..geometry44 = true
      ..levelVelocityStart = -1
      ..levelVelocityEnd = -1;
    m.verticals = List.generate(
      5,
      (i) => VerticalPoint(
        id: 'p$i',
        bank: i == 0
            ? 'ЛБ'
            : i == 4
            ? 'ПБ'
            : null,
        distance: i.toDouble(),
        depth1: [0, 2, .5, 2, 0][i].toDouble(),
        isSpeedVertical: i == 1 || i == 3,
        u06: VelocityPoint(value: i == 1 || i == 3 ? 1 : null),
      ),
    );
    recalcAll(m, finalCalculation: true);
    expect(m.warnings, contains(splitSectionWarning));
    expect(m.discharge, isNull);
    expect(sectionGeometry44(m).waterBodies, 2);
    m.levelVelocityStart = 0;
    m.levelVelocityEnd = 0;
    recalcAll(m, finalCalculation: true);
    expect(m.warnings, isNot(contains(splitSectionWarning)));
    expect(m.discharge, isNotNull);
  });
  test(
    'Invalid flat bank extrapolation blocks Q and never generates infinity',
    () {
      final m = triangle(delta: 1, left: true);
      m.verticals.insert(1, VerticalPoint(id: 'flat', distance: 1, depth1: 0));
      recalcAll(m, finalCalculation: true);
      expect(m.discharge, isNull);
      expect(m.warnings, contains(invalidSlopeWarning));
      expect(m.area!.isFinite, isTrue);
      m.leftExtrapolation = false;
      recalcAll(m, finalCalculation: true);
      expect(m.warnings, isNot(contains(invalidSlopeWarning)));
    },
  );
  test('Ice thickness is independent of effective depth and discharge', () {
    final m = triangle(delta: 1, left: true, right: true)..iceCover = true;
    for (final v in m.verticals) {
      v.iceThicknessCm = 150;
    }
    recalcAll(m, finalCalculation: true);
    expect(m.area, 9);
    expect(m.discharge, 6.3);
    expect(m.wettedPerimeter, closeTo(6 * math.sqrt(2) + 6, .0006));
    expect(m.verticals[1].depth1, 2);
  });
  test(
    'Depth change confirmation includes zero velocities and first depth2',
    () {
      final m = triangle();
      final v = m.verticals[1];
      v.u06.value = 0;
      final start = m.levelVelocityStartAt, end = m.levelVelocityEndAt;
      expect(changeDepth44(m, v, 3, second: true, confirmed: false), isFalse);
      expect(v.depth2, isNull);
      expect(v.u06.value, 0);
      expect(changeDepth44(m, v, 3, second: true, confirmed: true), isTrue);
      expect(v.avgDepth, 2.5);
      expect(v.velocityPoints.values.every((p) => p.value == null), isTrue);
      expect(v.isSpeedVertical, isTrue);
      expect(m.levelVelocityStartAt, start);
      expect(m.levelVelocityEndAt, end);
      changeDepth44(m, v, null, second: true, confirmed: true);
      changeDepth44(m, v, 0, second: false, confirmed: true);
      expect(v.isSpeedVertical, isFalse);
      expect(canMeasureSpeed44(v), isFalse);
    },
  );
  test(
    'Legacy JSON preserves old geometry and 4.4 metadata survives round trip',
    () {
      final old = sample().toJson();
      old.remove('schemaVersion');
      final m = WdcMeasurement.fromJson(old);
      expect(m.geometry44, isFalse);
      recalcAll(m, finalCalculation: true);
      expect(m.discharge, 2.8);
      final current = triangle(delta: 1, left: true)
        ..requireIceThickness = true;
      current.verticals[1].iceThicknessCm = 12.34;
      final restored = WdcMeasurement.fromJson(
        jsonDecode(jsonEncode(current.toJson())),
      );
      recalcAll(restored, finalCalculation: true);
      expect(restored.discharge, current.discharge);
      expect(restored.leftExtrapolation, isTrue);
      expect(restored.requireIceThickness, isTrue);
      expect(restored.verticals[1].iceThicknessCm, 12.34);
    },
  );
  test(
    'CSV identical schema RU EN legacy new ice, quoted metadata and empty measurements',
    () {
      List<String>? headers;
      for (final lang in ['ru', 'en']) {
        for (final m in [
          sample(),
          triangle(delta: -1),
          WdcMeasurement.empty(),
        ]) {
          AppSettings.current.language = lang;
          m.comment = 'semicolon; quote " and\nnew line';
          if (m.verticals.isNotEmpty) {
            m.verticals.first.iceThicknessCm = 12.34;
          }
          final rows = csvRows(csvContent(m));
          headers ??= rows.first;
          expect(rows.first, headers);
          expect(rows.first, hasLength(88));
          for (final row in rows.skip(1)) {
            expect(row, hasLength(88));
          }
          final meta = jsonDecode(
            rows[1][headers.indexOf('measurement_metadata_json')],
          );
          expect(meta['comment'], m.comment);
          if (m.verticals.isNotEmpty) {
            final v = jsonDecode(
              rows[1][headers.indexOf('vertical_data_json')],
            );
            expect(v['iceThicknessCm'], 12.34);
          }
        }
      }
    },
  );
  test(
    'KRV export/import retains level modes, all ice and original measurements',
    () async {
      final m = triangle(delta: 1, left: true, right: true)
        ..iceCover = true
        ..requireIceThickness = true;
      for (final v in m.verticals) {
        v.iceThicknessCm = 12.34;
      }
      await WdcStorage.instance.save(m);
      final path = await KrvTransfer.exportArchive(temp.path, [
        m.toJson(),
      ], temp.path);
      final inspect = await KrvTransfer.inspect(
        path,
        "${temp.path}/empty",
        temp.path,
      );
      final restored = WdcMeasurement.fromJson(
        inspect.records.single.measurement,
      );
      expect(restored.toJson(), m.toJson());
    },
  );

  Future<void> open(WidgetTester t, Widget child, {bool dark = false}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          fontFamily: 'WdcReport',
        ),
        home: child,
      ),
    );
    await settleIo(t);
  }

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

  test(
    'Profile, exported correction and metrics share rounded mean levels',
    () {
      final m = triangle()
        ..levelSoundingStart = 0
        ..levelSoundingEnd = .001
        ..levelVelocityStart = .002
        ..levelVelocityEnd = .002;
      recalcAll(m, finalCalculation: true);
      expect(levelDelta(m), m.levelCorrection);
      expect(sectionGeometry44(m).delta, m.levelCorrection);
      expect(m.verticals[1].correctedDepth, 2 + m.levelCorrection!);
    },
  );
  test(
    'Geometry without stage readings uses original depths and includes ice boundary',
    () {
      final m = triangle()
        ..calculationConfig = CalculationConfig()
        ..levelVelocityEnd = null
        ..iceCover = true;
      recalcAll(m, finalCalculation: true);
      expect(m.area, 4);
      expect(m.width, 4);
      expect(m.wettedPerimeter, closeTo(4 * math.sqrt(2) + 4, .0006));
      expect(m.discharge, isNull);
      expect(levelDelta(m), isNull);
    },
  );
  test('Exports with identical titles and dates keep separate contents', () async {
    final first = triangle()..comment = 'FIRST ORIGINAL';
    final second = WdcMeasurement.fromJson(first.toJson())..comment = 'SECOND ORIGINAL';
    final a = await WdcStorage.instance.exportCsv(first);
    final b = await WdcStorage.instance.exportCsv(second);
    expect(a.path, isNot(b.path));
    expect(a.uri.pathSegments.last, b.uri.pathSegments.last);
    expect(await a.readAsString(), contains('FIRST ORIGINAL'));
    expect(await a.readAsString(), isNot(contains('SECOND ORIGINAL')));
    expect(await b.readAsString(), contains('SECOND ORIGINAL'));
    final pa = await WdcStorage.instance.exportPdf(first);
    final pb = await WdcStorage.instance.exportPdf(second);
    expect(pa.path, isNot(pb.path));
    expect(await pa.readAsBytes(), isNot(await pb.readAsBytes()));
  });
  test('Published version and citation agree with the build manifest', () {
    final yaml = File('pubspec.yaml').readAsStringSync();
    expect(yaml, contains('version: ${Project44.version}+${Project44.build}'));
    expect(
      File('CITATION.cff').readAsStringSync(),
      contains(Project44.version),
    );
    expect(AppSettings.fromJson(AppSettings().toJson()).theme, 'system');
  });

  testWidgets(
    'Depth edit cancel preserves observations; confirmed second depth clears only that vertical',
    (t) async {
      final m = triangle();
      final v = m.verticals[1];
      v.depth2 = null;
      v.u06.value = 0;
      recalcAll(m);
      await open(t, SoundingScreen(measurement: m));
      await t.scrollUntilVisible(
        find.byType(DataTable),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      final before = jsonEncode(v.toJson());
      final start = m.levelVelocityStartAt, end = m.levelVelocityEndAt;
      t
          .widget<DataTable>(find.byType(DataTable).first)
          .rows[1]
          .cells[3]
          .onTap!();
      await t.pumpAndSettle();
      final editor = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await t.enterText(editor, '3');
      await t.tap(find.widgetWithText(TextButton, 'Сохранить'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Нет'));
      await t.pumpAndSettle();
      expect(jsonEncode(v.toJson()), before);
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Отмена'));
      await t.pumpAndSettle();
      expect(jsonEncode(v.toJson()), before);
      t
          .widget<DataTable>(find.byType(DataTable).first)
          .rows[1]
          .cells[3]
          .onTap!();
      await t.pumpAndSettle();
      await t.enterText(editor, '3');
      await t.tap(find.widgetWithText(TextButton, 'Сохранить'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Да'));
      await settleIo(t);
      expect(v.depth2, 3);
      expect(v.velocityPoints.values.every((p) => p.value == null), isTrue);
      expect(v.isSpeedVertical, isTrue);
      expect(m.levelVelocityStartAt, start);
      expect(m.levelVelocityEndAt, end);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Theme previews immediately and saved preference survives reload',
    (t) async {
      await t.pumpWidget(const WaterDischargeApp());
      await settleIo(t);
      final navigator = t.state<NavigatorState>(find.byType(Navigator).first);
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('theme-mode')));
      await t.pumpAndSettle();
      await t.tap(find.text('Тёмная').last);
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
      expect(AppSettings.current.theme, 'system');
      await t.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await settleIo(t);
      expect(AppSettings.current.theme, 'dark');
      await t.runAsync(() async {
        AppSettings.current = AppSettings();
        await AppSettings.load();
      });
      expect(AppSettings.current.theme, 'dark');
      await t.pumpWidget(const SizedBox());
      await t.pump();
      expect(previewTheme44, isNull);
    },
  );

  for (final lang in ['ru', 'en']) {
    testWidgets('Both bank and ordinary entry store ice and bottom $lang', (
      t,
    ) async {
      AppSettings.current.language = lang;
      final m = WdcMeasurement.empty()..iceCover = true;
      await open(t, SoundingScreen(measurement: m));
      final distance = find.byKey(const ValueKey('sounding-distance'));
      await t.scrollUntilVisible(
        distance,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(distance, '0');
      await t.enterText(find.byKey(const ValueKey('sounding-depth')), '0');
      await t.enterText(find.byKey(const ValueKey('sounding-bottom')), 'sand');
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('add-sounding')))
            .onPressed,
        isNull,
      );
      await t.enterText(find.byKey(const ValueKey('sounding-ice')), '12.3456');
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('add-sounding')));
      await t.tap(find.byKey(const ValueKey('add-sounding')));
      await settleIo(t);
      expect(m.verticals.single.iceThicknessCm, 12.35);
      expect(m.verticals.single.bottomType, 'sand');
      final bank = find.textContaining(tr('Указать второй берег'));
      await t.ensureVisible(bank);
      await t.tap(bank);
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('second-bank-distance')));
      await t.enterText(
        find.byKey(const ValueKey('second-bank-distance')),
        '4',
      );
      await t.enterText(find.byKey(const ValueKey('second-bank-depth')), '0');
      await t.enterText(
        find.byKey(const ValueKey('second-bank-bottom')),
        'stone',
      );
      await t.enterText(find.byKey(const ValueKey('second-bank-ice')), '0');
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('add-second-bank')));
      await t.tap(find.byKey(const ValueKey('add-second-bank')));
      await settleIo(t);
      expect(m.rightBank!.bottomType, 'stone');
      expect(m.rightBank!.iceThicknessCm, 0);
      expect(t.takeException(), isNull);
    });
    for (final dark in [false, true]) {
      testWidgets('About and graph render $lang dark=$dark', (t) async {
        AppSettings.current.language = lang;
        final key = GlobalKey();
        await open(
          t,
          RepaintBoundary(key: key, child: const AboutScreen44()),
          dark: dark,
        );
        await shot(t, key, 'about-$lang-$dark');
        expect(t.takeException(), isNull);
        final m = triangle(delta: 1, left: true, right: true)..iceCover = true;
        for (final v in m.verticals) {
          v.iceThicknessCm = v.distance == 2 ? 40 : 0;
        }
        recalcAll(m, finalCalculation: true);
        await open(
          t,
          RepaintBoundary(
            key: key,
            child: Scaffold(
              body: Column(
                children: [
                  IceProfile44(m: m),
                  SizedBox(
                    height: 340,
                    child: CustomPaint(
                      painter: ProfilePainter44(m, dark: dark),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          dark: dark,
        );
        await shot(t, key, 'profile-$lang-$dark');
        final falling = triangle(delta: -1);
        await open(
          t,
          RepaintBoundary(
            key: key,
            child: Scaffold(
              body: SizedBox(
                height: 340,
                child: CustomPaint(
                  painter: CrossSectionPainter(
                    measurement: falling,
                    dark: dark,
                    showVelocities: true,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          dark: dark,
        );
        await shot(t, key, 'falling-$lang-$dark');
        await open(
          t,
          RepaintBoundary(
            key: key,
            child: VelocityScreen(measurement: m),
          ),
          dark: dark,
        );
        await shot(t, key, 'velocity-$lang-$dark');
        await open(
          t,
          RepaintBoundary(
            key: key,
            child: ResultScreen(measurement: m, viewOnly: true),
          ),
          dark: dark,
        );
        await shot(t, key, 'result-$lang-$dark');

        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          await File(
            '${output.path}/report-$lang.pdf',
          ).writeAsBytes(await pdfBytes(m));
        });
      });
    }
  }
}
