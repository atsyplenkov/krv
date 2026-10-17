import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Directory('test-output/version-4');
  final runId = DateTime.now().microsecondsSinceEpoch;
  setUpAll(() async {
    await dir.create(recursive: true);
    final loader = FontLoader('WdcReport')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => '${dir.absolute.path}/documents-$runId',
        );
  });
  setUp(() => AppSettings.current = AppSettings(language: 'ru'));
  Future<void> phone(
    WidgetTester tester,
    Widget child, {
    GlobalKey? capture,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        home: capture == null
            ? child
            : RepaintBoundary(key: capture, child: child),
      ),
    );
    await settleIo(tester);
    // Startup also checks interrupted imports on disk. Let real I/O finish
    // before waiting for animations in the test's virtual clock.
    for (
      var i = 0;
      i < 10 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      i++
    ) {
      await settleIo(tester);
    }
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(
    WidgetTester tester,
    GlobalKey key,
    String name,
  ) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await File('${dir.path}/$name.png').writeAsBytes(
        (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      image.dispose();
    });
  }

  testWidgets(
    'Invalid velocity draft is marked and restoring the value clears the error',
    (tester) async {
      final m = sample()..calculationConfig = CalculationConfig();
      recalcAll(m);
      final v = m.verticals[1];
      final started = m.levelVelocityStartAt;
      await phone(tester, VelocityEditor(measurement: m, vertical: v));
      final field = find.byKey(const ValueKey('velocity-surface'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '1..2');
      await tester.pumpAndSettle();
      expect(find.text('Некорректное число'), findsOneWidget);
      expect(v.uSurface.value, 1);
      expect(m.levelVelocityStartAt, started);
      await tester.enterText(field, '1');
      await tester.pumpAndSettle();
      expect(find.text('Некорректное число'), findsNothing);
      expect(v.uSurface.value, 1);
      expect(tester.takeException(), isNull);
    },
  );

  test('A failed write does not block subsequent saves', () async {
    final invalid = sample(id: 'missing-parent/invalid');
    await expectLater(
      WdcStorage.instance.save(invalid),
      throwsA(isA<FileSystemException>()),
    );
    final valid = sample(id: 'after-failed-write');
    await WdcStorage.instance.save(valid);
    await WdcStorage.instance.flush();
    expect(
      (await WdcStorage.instance.loadAll()).any((m) => m.id == valid.id),
      isTrue,
    );
  });
  test(
    'System language follows supported device locale with Russian fallback',
    () {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      addTearDown(dispatcher.clearLocalesTestValue);
      AppSettings.current.language = 'system';
      dispatcher.localesTestValue = [const Locale('de')];
      expect(appLanguage, 'ru');
      dispatcher.localesTestValue = [const Locale('en')];
      expect(appLanguage, 'en');
      AppSettings.current.language = 'ru';
      expect(appLanguage, 'ru');
    },
  );
  testWidgets(
    'Individual reset is explicit and inherited method survives reload',
    (tester) async {
      final m = sample()..calculationConfig = CalculationConfig(preset: 'mi');
      final v = m.verticals[1]
        ..individualConfig = CalculationConfig(preset: 'combined');
      recalcAll(m);
      await phone(
        tester,
        CalculationSettingsScreen(
          config: v.individualConfig,
          inherited: m.calculationConfig,
          allowReset: true,
          scope: CalculationScope.vertical,
          onSave: (config) async {
            v.individualConfig = config;
            await WdcStorage.instance.save(m);
          },
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Вернуть настройки по умолчанию'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Вернуть настройки по умолчанию'));
      await tester.pumpAndSettle();
      expect(v.effectiveConfig!.preset, 'combined');
      await tester.tap(find.text('Сохранить'));
      await settleIo(tester);
      expect(v.individualConfig, isNull);
      expect(v.effectiveConfig!.preset, 'mi');
      final restored = WdcMeasurement.fromJson(m.toJson());
      expect(restored.verticals[1].effectiveConfig!.preset, 'mi');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Search reset stays available with no matching records', (
    tester,
  ) async {
    final record = sample(id: 'search-v4')
      ..river = 'SearchTarget4'
      ..completed = true;
    recalcAll(record, finalCalculation: true);
    await tester.runAsync(() => WdcStorage.instance.save(record));
    await phone(tester, const HomeScreen());
    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pumpAndSettle();
    final river = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Название реки',
    );
    await tester.enterText(river, 'zzzz-no-river');
    await tester.tap(find.text('🔎 Поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить поиск'), findsOneWidget);
    expect(find.text('SearchTarget4'), findsNothing);
    await tester.tap(find.text('Сбросить поиск'));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить поиск'), findsNothing);
    expect(find.text('SearchTarget4'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Calculation draft changes neither original nor field data before Save',
    (tester) async {
      final original = CalculationConfig();
      CalculationConfig? applied;
      final capture = GlobalKey();
      await phone(
        tester,
        CalculationSettingsScreen(
          config: original,
          onSave: (value) async => applied = value,
        ),
        capture: capture,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Пользовательский I').last);
      await tester.pumpAndSettle();
      expect(original.preset, 'wmo');
      expect(applied, isNull);
      await screenshot(tester, capture, 'coefficients-ru');
      // The first coefficient is surface weight in the six-point row.
      await tester.ensureVisible(find.text('по 6 точкам').first);
      await tester.pumpAndSettle();
      final fixed = tester.getTopLeft(find.text('по 6 точкам').first);
      final scroll = find.byType(SingleChildScrollView).first;
      await tester.drag(scroll, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('по 6 точкам').first), fixed);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(applied!.preset, 'custom0');
      expect(original.preset, 'wmo');
      expect(find.text('Сохранить'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Invalid coefficient restores previous draft; cancelling whole screen discards it',
    (tester) async {
      final original = CalculationConfig(preset: 'custom0');
      original.weights['six']!['surface'] = 1.111;
      CalculationConfig? applied;
      await phone(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CalculationSettingsScreen(
                    config: original,
                    onSave: (value) async => applied = value,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.111').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(find.text('1.111'), findsWidgets);
      expect(find.text('Сохранить'), findsNothing);
      await tester.tap(find.text('1.111').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2,125');
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(find.text('2.125'), findsOneWidget);
      expect(original.weights['six']!['surface'], 1.111);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Выйти без сохранения?'), findsOneWidget);
      await tester.tap(find.text('Нет'));
      await tester.pumpAndSettle();
      expect(find.text('2.125'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Да'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(applied, isNull);
      expect(original.weights['six']!['surface'], 1.111);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Global settings Save persists language and GPS and remains on screen',
    (tester) async {
      final capture = GlobalKey();
      await phone(tester, const SettingsScreen(), capture: capture);
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>).first,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(AppSettings.current.language, 'ru');
      expect(AppSettings.current.autoGps, isTrue);
      await tester.tap(find.text('Сохранить'));
      await settleIo(tester);
      expect(AppSettings.current.language, 'en');
      expect(AppSettings.current.autoGps, isFalse);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.runAsync(AppSettings.load);
      expect(AppSettings.current.language, 'en');
      expect(AppSettings.current.autoGps, isFalse);
      await screenshot(tester, capture, 'settings-en');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Ice editor keeps hidden data, enforces global flag, fits both languages',
    (tester) async {
      final m = sample()
        ..calculationConfig = CalculationConfig()
        ..iceCover = true;
      recalcAll(m);
      final v = m.verticals[1];
      final capture = GlobalKey();
      await phone(
        tester,
        VelocityEditor(measurement: m, vertical: v),
        capture: capture,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('velocity-015')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const ValueKey('velocity-015')), '0');
      await tester.pump();
      expect(v.u015.value, 0);
      await screenshot(tester, capture, 'velocity-ru');
      await settleIo(tester);
      await tester.pumpWidget(const SizedBox());
      AppSettings.current.language = 'en';
      m.iceCover = false;
      recalcAll(m);
      await phone(
        tester,
        VelocityEditor(measurement: m, vertical: v),
        capture: capture,
      );
      expect(find.byKey(const ValueKey('velocity-015')), findsNothing);
      expect(v.u015.value, 0);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('velocity-015')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('velocity-015')))
            .controller!
            .text,
        '0',
      );
      await screenshot(tester, capture, 'velocity-en');
      await settleIo(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Disabled automatic GPS starts new measurement without a location request',
    (tester) async {
      AppSettings.current.autoGps = false;
      var locationCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/geolocator'),
            (_) async {
              locationCalls++;
              return null;
            },
          );
      await phone(tester, const HomeScreen());
      await settleIo(tester);
      await tester.tap(find.text('Начать новое измерение'));
      await settleIo(tester);
      expect(find.byType(SoundingScreen), findsOneWidget);
      expect(locationCalls, 0);
      final screen = tester.widget<SoundingScreen>(find.byType(SoundingScreen));
      expect(screen.measurement.calculationConfig!.preset, 'wmo');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'PDF and CSV export all nine horizons and only used formula tables in RU and EN',
    (tester) async {
      final m = sample(id: 'v4-full-report')
        ..calculationConfig = CalculationConfig();
      m.verticals[1].localSpecial = true;
      var value = .1;
      for (final point in m.verticals[1].velocityPoints.values) {
        point.value = value;
        point.changedAt = m.levelVelocityEndAt;
        value += .1;
      }
      final additional = VerticalPoint(
        id: 'v2',
        distance: 3,
        depth1: 1.3,
        isSpeedVertical: true,
        localSpecial: true,
        individualConfig: CalculationConfig(preset: 'combined'),
        u05: VelocityPoint(value: 1.2),
      );
      m.verticals.add(additional);
      recalcAll(m, finalCalculation: true);
      await tester.runAsync(() async {
        for (final lang in ['ru', 'en']) {
          AppSettings.current.language = lang;
          final bytes = await pdfBytes(m);
          await File('${dir.path}/report-$lang.pdf').writeAsBytes(bytes);
          await File(
            '${dir.path}/report-$lang.csv',
          ).writeAsString(csvContent(m));
          expect(bytes.take(4), [37, 80, 68, 70]);
        }
      });
      expect(usedFormulaGroups(m).length, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
