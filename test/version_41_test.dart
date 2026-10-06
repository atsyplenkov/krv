import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final output = Directory('test-output/version-41');
  setUpAll(() async {
    await output.create(recursive: true);
    await (FontLoader(
      'WdcReport',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => '${output.absolute.path}/documents',
        );
  });
  setUp(() => AppSettings.current = AppSettings(language: 'ru'));
  WdcMeasurement reload(WdcMeasurement m) =>
      WdcMeasurement.fromJson(jsonDecode(jsonEncode(m.toJson())));
  test('Creation baseline is isolated and persisted', () {
    AppSettings.current.defaults = CalculationConfig(preset: 'custom1');
    AppSettings.current.defaults.custom[1]['three']!['06'] = 7;
    final m = WdcMeasurement.empty();
    AppSettings.current.defaults.custom[1]['three']!['06'] = 9;
    m.calculationConfig!.preset = 'mi';
    m.calculationConfig!.custom[1]['three']!['06'] = 11;
    m.initialCalculationConfig!.custom[1]['three']!['06'] = 13;
    final r = reload(m);
    expect(r.calculationConfig!.preset, 'mi');
    expect(r.initialCalculationConfig!.preset, 'custom1');
    expect(r.initialCalculationConfig!.custom[1]['three']!['06'], 7);
  });
  test('4.0 baseline captures all profiles once', () {
    final old = sample().toJson()..remove('initialCalculationConfig');
    final c = CalculationConfig(preset: 'custom2');
    c.custom[0]['one06']!['06'] = .123;
    c.custom[2]['two']!['08'] = 8;
    old['calculationConfig'] = c.toJson();
    final m = WdcMeasurement.fromJson(old)
      ..calculationConfig = CalculationConfig(preset: 'mi');
    expect(reload(m).initialCalculationConfig!.toJson(), c.toJson());
  });
  test('Legacy reset remains null after reload and restores result', () {
    final m = WdcMeasurement.fromJson(
      sample().toJson()
        ..remove('initialCalculationConfig')
        ..remove('calculationConfig'),
    );
    recalcAll(m, finalCalculation: true);
    final q = m.discharge;
    m.calculationConfig = CalculationConfig(preset: 'mi');
    final r = reload(m);
    expect(r.initialCalculationConfig, isNull);
    r.calculationConfig = r.initialCalculationConfig;
    recalcAll(r, finalCalculation: true);
    expect(r.discharge, q);
  });
  test('Reset preserves individual method, values and field times', () {
    final m = sample();
    final v = m.verticals[1];
    v.individualConfig = CalculationConfig(preset: 'custom0');
    v.individualConfig!.weights['three']!['06'] = 4;
    final values = jsonEncode(
      v.velocityPoints.map((k, p) => MapEntry(k, [p.value, p.changedAt])),
    );
    final times = measurementTimes(m);
    m.calculationConfig = m.initialCalculationConfig;
    recalcAll(m, finalCalculation: true);
    expect(v.effectiveConfig!.weights['three']!['06'], 4);
    v.individualConfig = null;
    m.calculationConfig = CalculationConfig(preset: 'mi');
    recalcAll(m, finalCalculation: true);
    expect(v.effectiveConfig!.preset, 'mi');
    expect(measurementTimes(m), times);
    expect(
      jsonEncode(
        v.velocityPoints.map((k, p) => MapEntry(k, [p.value, p.changedAt])),
      ),
      values,
    );
  });
  test('Special pair wins and normal fallback is prohibited', () {
    final c = calculateVelocity(
      {'02': 2, '06': 9, '08': 0, '05': 8},
      CalculationConfig(),
      special: true,
    )!;
    expect(c.method, 'twoSpecial');
    expect(c.value, 1);
    expect(
      calculateVelocity({'06': 9}, CalculationConfig(), special: true),
      isNull,
    );
  });
  test('Point colours track selected formula and include zero', () {
    final v = VerticalPoint(
      id: 'v',
      isSpeedVertical: true,
      individualConfig: CalculationConfig(),
      localSpecial: true,
      u02: VelocityPoint(value: 2),
      u08: VelocityPoint(value: 0),
      u06: VelocityPoint(value: 9),
      u05: VelocityPoint(value: 8),
    );
    expect(velocityPointColor(v, '02'), Colors.green.shade700);
    expect(velocityPointColor(v, '08'), Colors.green.shade700);
    expect(velocityPointColor(v, '06'), Colors.black);
    expect(velocityPointColor(v, '05'), Colors.black);
    v.localSpecial = false;
    expect(velocityPointColor(v, '06'), Colors.green.shade700);
    v.localSpecial = true;
    v.u02.value = null;
    v.u05.value = null;
    expect(velocityPointColor(v, '06'), Colors.black);
  });
  Future<void> open(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'WdcReport'),
        home: child,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> choose(WidgetTester t, String s) async {
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text(s).last);
    await t.pumpAndSettle();
  }

  Future<void> reset(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('reset-calculation')));
    await t.pumpAndSettle();
  }

  Future<void> save(WidgetTester t) async {
    await t.tap(find.text('Сохранить'));
    await t.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester t, GlobalKey key, String name) async {
    await t.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await File('${output.path}/$name.png').writeAsBytes(
        (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
        flush: true,
      );
      image.dispose();
    });
  }

  testWidgets('Inherited table opens directly without override', (t) async {
    var calls = 0;
    await open(
      t,
      CalculationSettingsScreen(
        config: null,
        inherited: CalculationConfig(preset: 'mi'),
        scope: CalculationScope.vertical,
        allowReset: true,
        onSave: (_) async {
          calls++;
        },
      ),
    );
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Используется метод измерения'), findsNothing);
    expect(find.text('Сохранить'), findsNothing);
    await choose(t, 'ВМО № 168');
    await choose(t, 'МИ 1759-87');
    expect(find.text('Сохранить'), findsNothing);
    expect(calls, 0);
  });
  testWidgets('Vertical reset is reversible until Save then clears override', (
    t,
  ) async {
    CalculationConfig? applied = CalculationConfig(preset: 'custom0');
    await open(
      t,
      CalculationSettingsScreen(
        config: applied,
        inherited: CalculationConfig(preset: 'mi'),
        scope: CalculationScope.vertical,
        allowReset: true,
        onSave: (c) async {
          applied = c;
        },
      ),
    );
    await choose(t, 'Комбинированный');
    await reset(t);
    expect(applied!.preset, 'custom0');
    expect(
      t
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged,
      isNull,
    );
    await reset(t);
    expect(
      t
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'combined',
    );
    await reset(t);
    await save(t);
    expect(applied, isNull);
    expect(find.text('Сохранить'), findsNothing);
  });
  testWidgets('Measurement reset restores all profiles', (t) async {
    final initial = CalculationConfig(preset: 'custom2');
    initial.custom[1]['one06']!['06'] = .321;
    CalculationConfig? applied;
    await open(
      t,
      CalculationSettingsScreen(
        config: CalculationConfig(preset: 'mi'),
        inherited: initial,
        scope: CalculationScope.measurement,
        allowReset: true,
        onSave: (c) async {
          applied = c;
        },
      ),
    );
    await reset(t);
    await save(t);
    expect(applied!.toJson(), initial.toJson());
    expect(AppSettings.current.defaults.preset, 'wmo');
  });
  testWidgets('Legacy reset saves null', (t) async {
    CalculationConfig? applied = CalculationConfig();
    await open(
      t,
      CalculationSettingsScreen(
        config: applied,
        inherited: null,
        scope: CalculationScope.measurement,
        allowReset: true,
        onSave: (c) async {
          applied = c;
        },
      ),
    );
    await reset(t);
    await save(t);
    expect(applied, isNull);
    expect(find.text('Выбрать метод расчёта'), findsOneWidget);
    expect(find.text('Сохранить'), findsNothing);
  });
  testWidgets('Failed reset remains pending', (t) async {
    await open(
      t,
      CalculationSettingsScreen(
        config: CalculationConfig(preset: 'mi'),
        inherited: CalculationConfig(),
        scope: CalculationScope.measurement,
        allowReset: true,
        onSave: (_) async {
          throw const FileSystemException('test');
        },
      ),
    );
    await reset(t);
    await save(t);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('Не удалось сохранить настройки'), findsOneWidget);
    expect(
      t
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('reset-calculation')),
          )
          .value,
      isTrue,
    );
  });
  testWidgets('Result first column stays fixed', (t) async {
    await open(
      t,
      Scaffold(
        body: Builder(
          builder: (c) => SingleChildScrollView(
            child: resultVelocityTable(c, sample().verticals),
          ),
        ),
      ),
    );
    final first = find.byType(DataTable).first;
    final p = t.getTopLeft(first);
    await t.drag(
      find.byKey(const ValueKey('result-velocities-scroll')),
      const Offset(-600, 0),
    );
    await t.pumpAndSettle();
    expect(t.getTopLeft(first), p);
    expect(t.takeException(), isNull);
  });
  testWidgets('Safe bottom and enlarged text fit both languages', (t) async {
    for (final lang in ['ru', 'en']) {
      AppSettings.current.language = lang;
      final key = GlobalKey();
      await open(
        t,
        RepaintBoundary(
          key: key,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(bottom: 48),
              textScaler: TextScaler.linear(1.3),
            ),
            child: SafeArea(
              top: false,
              child: CalculationSettingsScreen(
                config: CalculationConfig(preset: 'custom0'),
                inherited: CalculationConfig(),
                scope: CalculationScope.vertical,
                allowReset: true,
                onSave: (_) async {},
              ),
            ),
          ),
        ),
      );
      await reset(t);
      expect(
        t.getBottomLeft(find.text(lang == 'ru' ? 'Сохранить' : 'Save')).dy,
        lessThan(796),
      );
      expect(t.takeException(), isNull);
      await screenshot(t, key, 'reset-$lang');
      await t.pumpWidget(const SizedBox());
    }
  });
  testWidgets('Long wide reports paginate with 65 formula groups', (t) async {
    final m = sample(id: 'long-report')
      ..calculationConfig = CalculationConfig();
    m.verticals = [
      m.verticals.first,
      for (var i = 1; i <= 65; i++)
        VerticalPoint(
          id: 'v$i',
          distance: i.toDouble(),
          depth1: 2,
          isSpeedVertical: true,
          individualConfig: CalculationConfig(preset: 'custom0')
            ..custom[0]['six']!['02'] = i.toDouble(),
          uSurface: VelocityPoint(value: .1),
          u015: VelocityPoint(value: .2),
          u02: VelocityPoint(value: .3),
          u04: VelocityPoint(value: .4),
          u05: VelocityPoint(value: .5),
          u06: VelocityPoint(value: .6),
          u08: VelocityPoint(value: .7),
          u085: VelocityPoint(value: .8),
          uBottom: VelocityPoint(value: .9),
        ),
      m.verticals.last..distance = 66,
    ];
    recalcAll(m, finalCalculation: true);
    await t.runAsync(() async {
      for (final lang in ['ru', 'en']) {
        AppSettings.current.language = lang;
        await File(
          '${output.path}/long-$lang.pdf',
        ).writeAsBytes(await pdfBytes(m), flush: true);
      }
    });
    expect(usedFormulaGroups(m).length, 65);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Hint mode label precedes toggle and speed fields have subscripts',
    (t) async {
      final m = sample()
        ..calculationConfig = CalculationConfig()
        ..iceCover = true;
      recalcAll(m);
      final key = GlobalKey();
      await open(
        t,
        RepaintBoundary(
          key: key,
          child: VelocityEditor(measurement: m, vertical: m.verticals[1]),
        ),
      );
      expect(find.text('Режим подсказок:'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Режим подсказок:')).dy,
        lessThan(t.getTopLeft(find.byType(SegmentedButton<bool>)).dy),
      );
      for (final k in velocityKeys) {
        final f = find.byKey(ValueKey('velocity-$k'));
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        expect(t.widget<TextField>(f).decoration!.label, isA<NotationText>());
        expect(
          find.descendant(of: f, matching: find.byType(Transform)),
          findsWidgets,
        );
      }
      await t.ensureVisible(find.text('Режим подсказок:'));
      await t.pumpAndSettle();
      await screenshot(t, key, 'velocity-hints-ru');
      expect(t.takeException(), isNull);
      await settleIo(t);
      await t.pumpWidget(const SizedBox());
    },
  );
}
