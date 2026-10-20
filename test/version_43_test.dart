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
  late Directory dir;
  final output = Directory('test-output/version-43');
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
    dir = await Directory.systemTemp.createTemp('wdc43-');
    AppSettings.current = AppSettings(language: 'ru', autoGps: false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
  });
  tearDown(() async {
    await WdcStorage.instance.flush();
    await dir.delete(recursive: true);
  });
  Future<void> open(
    WidgetTester t,
    Widget child, {
    Size size = const Size(390, 844),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'WdcReport'),
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

  test('Ordinary 0.6 threshold and all special boundaries', () {
    const d = .1;
    expect(instrumentDepth('06', .11999, d), isNull);
    expect(instrumentDepth('06', .12, d), closeTo(.072, 1e-12));
    final cases = <double, List<String>>{
      .11999: [],
      .12: ['05'],
      .49999: ['05'],
      .5: ['015', '02', '05', '08', '085'],
      .99999: ['015', '02', '05', '08', '085'],
      1: velocityKeys,
    };
    for (final c in cases.entries) {
      for (final k in velocityKeys) {
        expect(
          instrumentDepth(k, c.key, d, special: true) != null,
          c.value.contains(k),
          reason: '$k at ${c.key}',
        );
      }
    }
    expect(instrumentDepth('02', .49999, d), isNull);
    expect(instrumentDepth('015', .69999, d), isNull);
    expect(instrumentDepth('015', .7, d), isNotNull);
  });
  for (final language in ['ru', 'en']) {
    testWidgets(
      '$language ordinary sounding remains usable during bank entry and restores focus',
      (t) async {
        AppSettings.current.language = language;
        final m = sample()..verticals.removeLast();
        await open(
          t,
          SoundingScreen(measurement: m),
          size: const Size(1200, 2400),
        );
        final distance = find.byKey(const ValueKey('sounding-distance'));
        final depth = find.byKey(const ValueKey('sounding-depth'));
        await t.enterText(distance, '3');
        await t.enterText(depth, '1.2');
        await t.tap(
          find.text('${tr('Указать второй берег')} (${bankLabel('ПБ')})'),
        );
        await t.pump();
        expect(t.widget<TextField>(distance).controller!.text, '3');
        await t.enterText(
          find.byKey(const ValueKey('second-bank-distance')),
          '5',
        );
        await t.enterText(find.byKey(const ValueKey('second-bank-depth')), '0');
        await t.tap(find.byKey(const ValueKey('add-sounding')));
        await settleIo(t);
        expect(m.verticals.firstWhere((v) => v.distance == 3).bank, isNull);
        expect(m.hasBothBanks, isFalse);
        expect(t.widget<TextField>(distance).focusNode!.hasFocus, isTrue);
        expect(t.testTextInput.isVisible, isTrue);
        expect(
          t
              .widget<TextField>(
                find.byKey(const ValueKey('second-bank-distance')),
              )
              .controller!
              .text,
          '5',
        );
        await t.enterText(distance, '4');
        await t.enterText(depth, '1');
        await t.tap(find.byKey(const ValueKey('add-second-bank')));
        await settleIo(t);
        expect(m.rightBank!.distance, 5);
        expect(m.rightBank!.depth1, 0);
        expect(t.widget<TextField>(distance).controller!.text, '4');
        expect(
          find.byKey(const ValueKey('second-bank-distance')),
          findsNothing,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await settleIo(t);
      },
    );
    testWidgets(
      '$language home exports vertical and progress content centered',
      (t) async {
        AppSettings.current.language = language;
        await t.runAsync(() => WdcStorage.instance.save(sample()));
        final key = GlobalKey();
        await open(t, RepaintBoundary(key: key, child: const HomeScreen()));
        expect(
          t.getCenter(find.byType(PdfExportIcon)).dy,
          lessThan(t.getCenter(find.byType(CsvExportIcon)).dy),
        );
        expect(
          t.getCenter(find.byType(PdfExportIcon)).dx,
          t.getCenter(find.byType(CsvExportIcon)).dx,
        );
        await shot(t, key, 'home-$language');
        final close = showWorkProgress(
          t.element(find.byType(HomeScreen)),
          tr('Получаем координаты…'),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        final dialog = t.getRect(find.byType(AlertDialog));
        final text = t.getRect(find.text(tr('Получаем координаты…')));
        final spinner = t.getRect(find.byType(CircularProgressIndicator));
        expect((text.center.dy - dialog.center.dy).abs(), lessThan(1));
        expect((spinner.center.dy - dialog.center.dy).abs(), lessThan(1));
        close();
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$language Usur uses subscript and special hints depend on local flag',
      (t) async {
        AppSettings.current.language = language;
        final m = sample()
          ..calculationConfig = CalculationConfig()
          ..rotorDiameter = .1;
        m.verticals[1].depth1 = .5;
        m.verticals[1].localSpecial = true;
        recalcAll(m);
        final key = GlobalKey();
        await open(
          t,
          RepaintBoundary(
            key: key,
            child: VelocityEditor(measurement: m, vertical: m.verticals[1]),
          ),
          size: const Size(390, 2000),
        );
        expect(find.text('7.5 ${tr('см')}'), findsWidgets);
        expect(find.text('42.5 ${tr('см')}'), findsWidgets);
        expect(find.text('—'), findsNWidgets(4));
        expect(tr('Uпов'), language == 'en' ? 'Usur' : 'Uпов');
        expect(notationParts('Usur').last.text, 'sur');
        expect(notationParts('Usur').last.sub, isTrue);
        await shot(t, key, 'special-hints-$language');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await settleIo(t);
      },
    );
  }
  testWidgets(
    'Every measurement screen has editable photos immediately after comment',
    (t) async {
      final m = sample()..completed = true;
      for (final screen in [
        SoundingScreen(measurement: m),
        VelocityScreen(measurement: m),
        ResultScreen(measurement: m, viewOnly: true),
      ]) {
        await open(t, screen, size: const Size(1200, 2000));
        expect(find.byType(MeasurementPhotos), findsOneWidget);
        expect(
          t.widget<MeasurementPhotos>(find.byType(MeasurementPhotos)).editable,
          isTrue,
        );
        final comment = t.getRect(find.byType(MeasurementComment));
        final photos = t.getRect(find.byType(MeasurementPhotos));
        expect(photos.top, greaterThanOrEqualTo(comment.bottom));
        expect(photos.top - comment.bottom, lessThan(15));
        expect(m.completed, isTrue);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await settleIo(t);
      }
    },
  );
  testWidgets(
    'Result tables hide only empty columns and retain zero; CSV schema unchanged',
    (t) async {
      final m = sample()..calculationConfig = CalculationConfig();
      recalcAll(m);
      final header = csvContent(m).split('\n').first;
      m.verticals[1].uSurface.value = null;
      m.verticals[1].u02.value = null;
      m.verticals[1].u08.value = null;
      m.verticals[1].uBottom.value = null;
      m.verticals[1].u06.value = 0;
      await open(
        t,
        Scaffold(
          body: Column(
            children: [
              resultSoundingTable(m.verticals),
              Builder(builder: (c) => resultVelocityTable(c, m.verticals)),
            ],
          ),
        ),
      );
      final table = t.widget<DataTable>(
        find.byKey(const ValueKey('result-sounding-table')),
      );
      expect(table.columns.length, 4);
      expect(find.text('Глуб₂, м'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is NotationText && w.text == '${tr('Uпов')}, ${tr('м/с')}',
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is NotationText && w.text == 'U0.6h, ${tr('м/с')}',
        ),
        findsOneWidget,
      );
      m.verticals[1].depth2 = 0;
      await t.pumpWidget(
        MaterialApp(home: Scaffold(body: resultSoundingTable(m.verticals))),
      );
      expect(t.widget<DataTable>(find.byType(DataTable)).columns.length, 5);
      expect(csvContent(m).split('\n').first, header);
      expect(header.split(';').length, 89);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Saving language updates mounted home and sounding without discarding draft',
    (t) async {
      await t.pumpWidget(const WaterDischargeApp());
      await settleIo(t);
      final navigator = Navigator.of(t.element(find.byType(HomeScreen)));
      final m = sample();
      navigator.push(
        MaterialPageRoute(builder: (_) => SoundingScreen(measurement: m)),
      );
      await settleIo(t);
      // Use the TextField rendered by the form field so its draft remains visible.
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Название реки',
      );
      await t.ensureVisible(field);
      await t.enterText(field, 'Draft river');
      navigator.push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      await settleIo(t);
      await t.runAsync(
        () => AppSettings(language: 'en', autoGps: false).save(),
      );
      await t.pump();
      navigator.pop();
      await settleIo(t);
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'River name',
        ),
        findsOneWidget,
      );
      expect(find.text('Draft river'), findsOneWidget);
      expect(
        find.text('Start a new measurement', skipOffstage: false),
        findsOneWidget,
      );

      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await settleIo(t);
    },
  );
}
