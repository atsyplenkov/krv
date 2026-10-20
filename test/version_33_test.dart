import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  AppSettings.current = AppSettings(language: 'ru');
  TestWidgetsFlutterBinding.ensureInitialized();
  final runId = DateTime.now().microsecondsSinceEpoch;
  setUpAll(() async {
    await Directory('test-output/version-33').create(recursive: true);
    final font = FontLoader('WdcReport')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await font.load();
    final dir = Directory('test-output/version-33-$runId');
    await dir.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.absolute.path,
        );
  });

  test('Stage starts survive deletion, JSON reload and reopening', () {
    final m = WdcMeasurement.empty();
    const first = '2026-09-30T10:00:00.000';
    const second = '2026-09-30T10:05:00.000';
    recordSoundingInput(m, at: first);
    recordVelocityInput(m, at: second);
    m.verticals.addAll(sample().verticals);
    for (final v in m.verticals) {
      v.clearVelocities();
    }
    m.verticals.clear();
    final loaded = WdcMeasurement.fromJson(m.toJson());
    reopenMeasurement(loaded);
    recordSoundingInput(loaded, at: '2026-09-30T11:00:00.000');
    recordVelocityInput(loaded, at: '2026-09-30T11:05:00.000');
    expect(loaded.levelSoundingStartAt, first);
    expect(loaded.levelVelocityStartAt, second);
    expect(loaded.levelSoundingEndAt, '2026-09-30T11:00:00.000');
    expect(loaded.levelVelocityEndAt, '2026-09-30T11:05:00.000');
    recordSoundingInput(loaded, at: '2026-09-30T09:00:00.000');
    expect(loaded.levelSoundingEndAt, '2026-09-30T11:00:00.000');
  });

  test('Decimal input formatting preserves supported precision', () {
    expect(inputNumber(0.07 * 100), '7');
    expect(inputNumber(0.035 * 100), '3.5');
    expect(inputNumber(0.125 * 100), '12.5');
    expect(inputNumber(55.72922090), '55.7292209');
    expect(inputNumber(0), '0');
    expect(inputNumber(-0.0001), '-0.0001');
  });

  testWidgets('Phone input layout fits and dismissing an edit preserves data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final m = sample();
    final capture = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'WdcReport',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E86C1)),
          scaffoldBackgroundColor: const Color(0xFFF4FAFF),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: RepaintBoundary(
          key: capture,
          child: SoundingScreen(measurement: m),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('sounding-units')));
    await tester.tap(find.byKey(const ValueKey('sounding-units')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(250);
    await tester.pumpAndSettle();
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'test-output/version-33/sounding-phone.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.scrollUntilVisible(
      find.byType(DataTable),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final table = tester.widget<DataTable>(find.byType(DataTable));
    table.rows[1].cells[3].onTap!();
    await tester.pumpAndSettle();
    final end = m.levelSoundingEndAt;
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(m.levelSoundingEndAt, end);
    expect(m.verticals[1].depth2, isNull);
    await tester.pumpWidget(const SizedBox());
    await settleIo(tester);
  });

  testWidgets(
    'Centimetre drafts and both depths stay metres in storage and CSV',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final m = WdcMeasurement.empty();
      await tester.pumpWidget(
        MaterialApp(home: SoundingScreen(measurement: m)),
      );
      expect(
        find.text('Рекомендуется не менее 20 промерных вертикалей'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('sounding-units')))
            .value,
        false,
      );
      await tester.enterText(field('Уровень воды на начало промеров, м'), '0');
      expect(m.levelSoundingStartAt, isNull);
      await tester.enterText(field('Расст., м'), '1.25');
      final started = m.levelSoundingStartAt;
      expect(started, isNotNull);
      await tester.enterText(field('Глуб₁., м'), '0.07');
      await tester.tap(find.byKey(const ValueKey('sounding-units')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Расст., см')).controller!.text,
        '125',
      );
      expect(
        tester.widget<TextField>(field('Глуб₁., см')).controller!.text,
        '7',
      );
      await tester.enterText(field('Глуб₁., см'), '12,3');
      await tester.tap(find.text('Добавить'));
      await settleIo(tester);
      expect(m.verticals.single.distance, 1.25);
      expect(m.verticals.single.depth1, 0.123);
      expect(find.text('125.0'), findsOneWidget);
      final table = tester.widget<DataTable>(find.byType(DataTable));
      table.rows.single.cells[3].onTap!();
      await tester.pumpAndSettle();
      expect(find.text('Глубина 2, см'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '15',
      );
      await tester.tap(find.text('Сохранить'));
      await settleIo(tester);
      expect(m.verticals.single.depth2, 0.15);
      expect(m.levelSoundingStartAt, started);
      final header = csvContent(m).split('\n').first.split(';');
      final row = csvContent(m).split('\n')[1].split(';');
      expect(
        row[header.indexOf('Расстояние от постоянного начала, м')],
        '1.250',
      );
      expect(
        row[header.indexOf('Глубина на вертикали (1 измерение), м')],
        '0.123',
      );
      expect(
        row[header.indexOf('Глубина на вертикали (2 измерение), м')],
        '0.150',
      );
      await tester.tap(find.byKey(const ValueKey('sounding-units')));
      await tester.pumpAndSettle();
      expect(find.text('1.250'), findsOneWidget);
      expect(m.verticals.single.distance, 1.25);
      await tester.pumpWidget(const SizedBox());
      await settleIo(tester);
    },
  );

  testWidgets('Diameter 7 cm stays readable after focus change and reopening', (
    tester,
  ) async {
    final m = sample()..rotorDiameter = 0.07;
    await tester.pumpWidget(MaterialApp(home: VelocityScreen(measurement: m)));
    final diameter = field('Лопастной диаметр вертушки, см');
    expect(tester.widget<TextField>(diameter).controller!.text, '7');
    await tester.enterText(diameter, '7');
    await tester.tap(find.text('Измерение скоростей'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(diameter).controller!.text, '7');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: VelocityScreen(measurement: m)));
    expect(tester.widget<TextField>(diameter).controller!.text, '7');
    expect(m.rotorDiameter, 0.07);
    await tester.pumpWidget(const SizedBox());
    await settleIo(tester);
  });

  testWidgets(
    'First velocity keystroke sets start; water levels never overwrite it',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final m = sample()
        ..levelVelocityStartAt = null
        ..levelVelocityEndAt = null;
      final point = m.verticals[1].uSurface;
      point.value = null;
      await tester.pumpWidget(
        MaterialApp(home: VelocityScreen(measurement: m)),
      );
      await tester.enterText(
        field('Уровень воды на начало измерения скоростей течения'),
        '1',
      );
      expect(m.levelVelocityStartAt, isNull);
      await tester.tap(find.text('Ввести'));
      // Navigation awaits a real disk write; CI runners can take longer than
      // a fixed delay. Wait for the observable result with a bounded timeout.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (find.byType(VelocityEditor).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.byType(VelocityEditor), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('velocity-surface')),
        '0,219',
      );
      final started = m.levelVelocityStartAt;
      expect(started, isNotNull);
      await tester.pageBack();
      await settleIo(tester);
      expect(point.value, 0.219);
      final ended = m.levelVelocityEndAt;
      await tester.enterText(
        field('Уровень воды на конец измерения скоростей течения'),
        '2',
      );
      expect(m.levelVelocityStartAt, started);
      expect(m.levelVelocityEndAt, ended);
      await tester.pumpWidget(const SizedBox());
      await settleIo(tester);
    },
  );
}
