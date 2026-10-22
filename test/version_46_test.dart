import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;
import 'version_44_test.dart' show csvRows;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  final output = Directory('test-output/version-46');
  setUpAll(() async {
    await output.create(recursive: true);
    for (final entry in {
      'WdcReport': 'assets/fonts/Roboto-Regular.ttf',
      'Roboto': 'assets/fonts/Roboto-Regular.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('wdc46-');
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
    'Six-point normal and ice weights migrate independently, at every scope',
    () {
      final legacy = CalculationConfig(preset: 'custom0').toJson();
      // This is the representation written by 4.5.1 and earlier.
      expect((legacy['custom'] as List).first, isNot(contains('sixSpecial')));
      final serialized = jsonEncode(legacy);
      final config = CalculationConfig.fromJson(jsonDecode(serialized));
      final values = <String, double?>{
        'surface': 1,
        '02': 2,
        '04': 4,
        '06': 6,
        '08': 8,
        'bottom': 10,
      };
      expect(calculateVelocity(values, config, special: false)!.value, 5.1);
      expect(calculateVelocity(values, config, special: true)!.value, 5.1);
      final copy = config.copy();
      config.weights['sixSpecial']!['surface'] = 3;
      expect(calculateVelocity(values, config, special: true)!.value, 4.4167);
      expect(calculateVelocity(values, config, special: false)!.value, 5.1);
      expect(copy.weights['sixSpecial']!['surface'], 1);
      expect(config.custom[1]['sixSpecial']!['surface'], 1);
      config.weights['six']!['bottom'] = 5;
      expect(config.weights['sixSpecial']!['bottom'], 1);
      expect(jsonEncode(legacy), serialized);
      final restored = CalculationConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())),
      );
      expect(restored.weights['six']!['bottom'], 5);
      expect(restored.weights['sixSpecial']!['surface'], 3);
      expect(restored.weights['sixSpecial']!['bottom'], 1);
    },
  );

  test(
    'Project and independent coefficients round trip without touching field observations',
    () {
      final m = sample()
        ..project = 'Арктика; "2026"\nЭтап 2'
        ..calculationConfig = CalculationConfig(preset: 'custom0');
      m.calculationConfig!.weights['sixSpecial']!['surface'] = 3;
      final before = jsonEncode(m.verticals.map((v) => v.toJson()).toList());
      final restored = WdcMeasurement.fromJson(
        jsonDecode(jsonEncode(m.toJson())),
      );
      expect(restored.toJson()['schemaVersion'], 7);
      expect(restored.project, m.project);
      expect(restored.calculationConfig!.weights['sixSpecial']!['surface'], 3);
      expect(
        jsonEncode(restored.verticals.map((v) => v.toJson()).toList()),
        before,
      );
      expect(restored.levelVelocityStartAt, m.levelVelocityStartAt);
      final rows = csvRows(csvContent(m));
      expect(rows.first.last, 'project');
      expect(rows.skip(1).every((r) => r.last == m.project), isTrue);
      m.project = '';
      final emptyRows = csvRows(csvContent(m));
      expect(emptyRows.first, rows.first);
      expect(emptyRows.skip(1).every((r) => r.last.isEmpty), isTrue);
      final old = sample().toJson();
      expect(old, isNot(contains('project')));
      expect(WdcMeasurement.fromJson(old).project, '');
    },
  );

  test(
    'KRV preserves new settings and project, identical imports remain duplicates',
    () async {
      final m = sample()
        ..project = 'Expedition A'
        ..calculationConfig = CalculationConfig(preset: 'custom0');
      m.calculationConfig!.weights['sixSpecial']!['02'] = 8;
      final base = Directory('${temp.path}/source')..createSync();
      final target = Directory('${temp.path}/target')..createSync();
      final path = await KrvTransfer.exportArchive(base.path, [
        m.toJson(),
      ], temp.path);
      final plan = await KrvTransfer.inspect(path, target.path, temp.path);
      await KrvTransfer.commit(plan, target.path);
      await plan.dispose();
      final duplicate = await KrvTransfer.inspect(path, target.path, temp.path);
      expect(duplicate.records, isEmpty);
      await duplicate.dispose();
      final files = target
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      final restored = WdcMeasurement.fromJson(
        jsonDecode(await files.single.readAsString()),
      );
      expect(restored.project, m.project);
      expect(restored.calculationConfig!.weights['six']!['02'], 2);
      expect(restored.calculationConfig!.weights['sixSpecial']!['02'], 8);
    },
  );

  for (final descending in [false, true]) {
    test(
      'Discharge sorting is numeric with stable alphabetical/time ties: $descending',
      () {
        WdcMeasurement record(
          String id,
          double? q,
          String river,
          String date,
        ) => sample(id: id)
          ..discharge = q
          ..river = river
          ..site = 'A'
          ..createdAt = date;
        final a = record('early', 2, 'A', '2026-01-01T12:00:00');
        final b = record('late', 2, 'A', '2026-01-02T12:00:00');
        final c = record('river', 2, 'B', '2025-01-01T12:00:00');
        final d = record('ten', 10, 'A', '2026-01-01T12:00:00');
        final n = record('unknown', null, 'A', '2026-01-01T12:00:00');
        final zero = record('zero', 0, 'A', '2026-01-01T12:00:00');
        final records = [n, c, b, d, a, zero]
          ..sort(
            (x, y) =>
                compareMeasurements46(x, y, SortField.discharge, descending),
          );
        expect(
          records.map((m) => m.id),
          descending
              ? ['ten', 'early', 'late', 'river', 'zero', 'unknown']
              : ['zero', 'early', 'late', 'river', 'ten', 'unknown'],
        );
      },
    );
  }

  test(
    'Only both bank thicknesses enable ice chart; zero is a valid observation',
    () {
      final m = sample()..iceCover = true;
      m.verticals[1].iceThicknessCm = 40;
      expect(hasIceProfile46(m), isFalse);
      m.leftBank!.iceThicknessCm = 0;
      expect(hasIceProfile46(m), isFalse);
      m.rightBank!.iceThicknessCm = 20;
      expect(hasIceProfile46(m), isTrue);
      m.verticals[1].iceThicknessCm = null;
      expect(hasIceProfile46(m), isTrue);
      final before = jsonEncode(m.toJson());
      recalcAll(m, finalCalculation: true);
      final withoutIce = m.discharge;
      m.verticals[1].iceThicknessCm = 999;
      recalcAll(m, finalCalculation: true);
      expect(m.discharge, withoutIce);
      expect(
        WdcMeasurement.fromJson(jsonDecode(before)).leftBank!.iceThicknessCm,
        0,
      );
    },
  );

  testWidgets('Editing either six-point table changes only that table', (
    t,
  ) async {
    CalculationConfig? saved;
    final original = CalculationConfig(preset: 'custom0');
    await t.pumpWidget(
      MaterialApp(
        home: CalculationSettingsScreen(
          config: original,
          onSave: (value) async => saved = value,
        ),
      ),
    );
    await t.pumpAndSettle();
    var tables = t.widgetList<DataTable>(find.byType(DataTable)).toList();
    tables[1].rows[0].cells[0].onTap!();
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '4.125');
    await t.tap(find.text('Применить'));
    await t.pumpAndSettle();
    tables = t.widgetList<DataTable>(find.byType(DataTable)).toList();
    expect((tables[1].rows[0].cells[0].child as Text).data, '4.125');
    await t.scrollUntilVisible(
      find.text('Ледовые явления / растительность'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    final special = t.widgetList<DataTable>(find.byType(DataTable)).last;
    expect((special.rows[0].cells[0].child as Text).data, '1');
    special.rows[0].cells[0].onTap!();
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '7.25');
    await t.tap(find.text('Применить'));
    await t.pumpAndSettle();
    await t.tap(find.text('Сохранить'));
    await t.pumpAndSettle();
    expect(saved!.weights['six']!['surface'], 4.125);
    expect(saved!.weights['sixSpecial']!['surface'], 7.25);
    expect(original.weights['six']!['surface'], 1);
    expect(original.weights['sixSpecial']!['surface'], 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('Ice mark fits between measurement and warning icons', (t) async {
    final m = sample()
      ..iceCover = true
      ..completed = true;
    m.warnings.add('Test warning');
    await t.runAsync(() => WdcStorage.instance.save(m));
    await t.pumpWidget(const MaterialApp(home: HomeScreen()));
    await settleIo(t);
    final ice = find.byKey(const ValueKey('ice-cover-mark'));
    expect(ice, findsOneWidget);
    expect(
      t.getTopLeft(ice).dy,
      greaterThan(t.getTopLeft(find.byIcon(Icons.water_drop_outlined)).dy),
    );
    expect(
      t.getBottomLeft(ice).dy,
      lessThanOrEqualTo(t.getTopLeft(find.byIcon(Icons.error_outline)).dy),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Ice profile connects available points in both chainage directions',
    (t) async {
      for (final reverse in [false, true]) {
        final m = sample()
          ..iceCover = true
          ..geometry44 = true;
        m.leftBank!.iceThicknessCm = 40;
        m.rightBank!.iceThicknessCm = 20;
        if (reverse) {
          for (final v in m.verticals) {
            v.distance = 4 - v.distance!;
          }
        }
        recalcAll(m, finalCalculation: true);
        final before = jsonEncode(m.toJson());
        await t.runAsync(() async {
          await File(
            '${output.path}/ice-$reverse.png',
          ).writeAsBytes(await icePng44(m));
        });
        expect(jsonEncode(m.toJson()), before);
        expect(m.verticals[1].iceThicknessCm, isNull);
      }
    },
  );

  for (final language in ['ru', 'en']) {
    testWidgets(
      'Optional ice entry, explicit missing data and clearing $language',
      (t) async {
        AppSettings.current.language = language;
        final m = WdcMeasurement.empty()..iceCover = true;
        await t.pumpWidget(MaterialApp(home: SoundingScreen(measurement: m)));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('sounding-distance')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await t.enterText(find.byKey(const ValueKey('sounding-distance')), '0');
        await t.enterText(find.byKey(const ValueKey('sounding-depth')), '1');
        await t.ensureVisible(find.byKey(const ValueKey('add-sounding')));
        await t.pump();
        expect(
          t
              .widget<FilledButton>(find.byKey(const ValueKey('add-sounding')))
              .onPressed,
          isNotNull,
        );
        await t.tap(find.byKey(const ValueKey('add-sounding')));
        await settleIo(t);
        expect(m.leftBank!.iceThicknessCm, isNull);
        final table = t.widget<DataTable>(find.byType(DataTable));
        expect((table.rows.single.cells[5].child as Text).data, tr('н/д'));
        expect(tr('н/д'), language == 'en' ? 'N/A' : 'н/д');
        table.rows.single.cells[5].onTap!();
        await t.pumpAndSettle();
        await t.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          '0',
        );
        await t.tap(find.text(tr('Сохранить')));
        await settleIo(t);
        expect(m.leftBank!.iceThicknessCm, 0);
        t
            .widget<DataTable>(find.byType(DataTable))
            .rows
            .single
            .cells[5]
            .onTap!();
        await t.pumpAndSettle();
        await t.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          '',
        );
        await t.tap(find.text(tr('Сохранить')));
        await settleIo(t);
        expect(m.leftBank!.iceThicknessCm, isNull);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await settleIo(t);
      },
    );

    testWidgets('Project entry and exact/partial search $language', (t) async {
      AppSettings.current.language = language;
      final a = sample(id: 'a')
        ..completed = true
        ..project = 'Arctic';
      final b = sample(id: 'b')
        ..completed = true
        ..project = 'Arctic 2026';
      await t.runAsync(() async {
        await WdcStorage.instance.save(a);
        await WdcStorage.instance.save(b);
      });
      await t.pumpWidget(const MaterialApp(home: HomeScreen()));
      await settleIo(t);
      expect(find.textContaining('Arctic'), findsNothing);
      await t.tap(find.byKey(const ValueKey('home-search')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('search-project')), 'arctic');
      await t.tap(find.text(tr('🔎 Поиск')));
      await t.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(2));
      await t.tap(find.byKey(const ValueKey('home-search')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('search-project-exact')));
      await t.tap(find.byKey(const ValueKey('search-project-exact')));
      await t.tap(find.text(tr('🔎 Поиск')));
      await t.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      await t.tap(find.text(tr('Сбросить поиск')));
      await t.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text(tr('Сбросить поиск')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await settleIo(t);
    });

    testWidgets(
      'Tables and help fit a small phone with enlarged text $language',
      (t) async {
        AppSettings.current.language = language;
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final config = CalculationConfig(preset: 'custom0');
        config.weights['sixSpecial']!['surface'] = 3;
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: RepaintBoundary(
                key: key,
                child: CalculationSettingsScreen(
                  config: config,
                  inherited: CalculationConfig(),
                  allowReset: true,
                  onSave: (_) async {},
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final help = t.widget<Text>(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.textSpan?.toPlainText().contains(tr(coefficientsIntro)) ==
                    true,
          ),
        );
        final spans = (help.textSpan! as TextSpan).children!
            .whereType<TextSpan>();
        expect(
          spans.singleWhere((s) => s.style?.fontWeight == FontWeight.bold).text,
          calculationScopeText46(CalculationScope.application),
        );
        await t.scrollUntilVisible(find.text(tr('Обычные условия')), 250);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1.5);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          image.dispose();
          await File(
            '${output.path}/coefficients-$language.png',
          ).writeAsBytes(bytes);
        });
        await t.drag(find.byType(ListView), const Offset(0, -1800));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );

    test('PDF portrait, wide, and partial ice exports $language', () async {
      AppSettings.current.language = language;
      for (final mode in ['narrow', 'wide', 'partial-ice']) {
        final m = sample()
          ..calculationConfig = CalculationConfig()
          ..project = mode == 'narrow' ? '' : 'Arctic / Арктика 2026';
        if (mode == 'wide') {
          for (final point in m.verticals[1].velocityPoints.values) {
            point.value = 12345.6789;
          }
        }
        if (mode == 'partial-ice') {
          m.iceCover = true;
          m.verticals[1].iceThicknessCm = 12.34;
          expect(hasIceProfile46(m), isFalse);
        }
        recalcAll(m, finalCalculation: true);
        final data = await pdfBytes(m);
        expect(data.take(4), [37, 80, 68, 70]);
        await File('${output.path}/$language-$mode.pdf').writeAsBytes(data);
      }
    });
  }
}
