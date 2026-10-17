import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;

class Picker extends FileSelectorPlatform {
  XFile? result;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Picker picker;
  final shots = Directory('test-output/version-42');
  final boundary = GlobalKey();
  final storage = WdcStorage.instance;
  MethodCall? shared;
  setUpAll(() async {
    await shots.create(recursive: true);
    await (FontLoader(
      'WdcReport',
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('krv-ui-');
    picker = Picker();
    FileSelectorPlatform.instance = picker;
    AppSettings.current = AppSettings(language: 'ru');
    shared = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            shared = call;
            return 'success';
          },
        );
  });
  tearDown(() async {
    await storage.flush();
    await dir.delete(recursive: true);
  });
  Future<void> open(WidgetTester t, {double width = 390}) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'WdcReport'),
        home: RepaintBoundary(key: boundary, child: const HomeScreen()),
      ),
    );
    await settleIo(t);
  }

  Future<void> shot(WidgetTester t, String name) async {
    await t.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      await File('${shots.path}/$name.png').writeAsBytes(
        (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      image.dispose();
    });
  }

  Future<void> prepare(WidgetTester t) async {
    await t.runAsync(() async {
      final source = await Directory('${dir.path}/source').create();
      picker.result = XFile(
        await KrvTransfer.exportArchive(source.path, [
          sample().toJson(),
        ], dir.path),
      );
    });
  }

  Future<void> tapImport(WidgetTester t) async {
    if (find.byKey(const ValueKey('import-krv')).evaluate().isEmpty) {
      await t.tap(find.byIcon(Icons.settings_outlined));
      await t.pumpAndSettle();
    }
    final button = find.byKey(const ValueKey('import-krv'));
    await t.ensureVisible(button);
    // A record may appear before the previous import finishes temporary-file cleanup.
    // Wait for the real user action to become available, rather than tapping a disabled button.
    for (var i = 0; i < 15 && t.widget<ListTile>(button).onTap == null; i++) {
      await settleIo(t);
    }
    expect(t.widget<ListTile>(button).onTap, isNotNull);
    await t.tap(button);
  }

  Future<void> awaitTransfer(WidgetTester t, Finder until) async {
    for (var i = 0; i < 15 && until.evaluate().isEmpty; i++) {
      await settleIo(t);
    }
    expect(until, findsOneWidget);
    expect(t.takeException(), isNull);
  }

  for (final lang in ['ru', 'en']) {
    testWidgets('$lang home and selection toolbar on small phone', (t) async {
      AppSettings.current.language = lang;
      await t.runAsync(() async {
        final base = await Directory('${dir.path}/wdc_measurements').create();
        await File(
          '${base.path}/test-measurement.json',
        ).writeAsString(jsonEncode(sample().toJson()));
      });
      await open(t, width: 320);
      expect(find.text('v4.5.1'), findsOneWidget);
      expect(find.byKey(const ValueKey('import-krv')), findsNothing);
      await shot(t, 'home-$lang');
      await t.longPress(find.textContaining('Тестовая река').first);
      await t.pumpAndSettle();
      expect(
        t.getCenter(find.byKey(const ValueKey('export-krv'))).dx,
        lessThan(t.getCenter(find.byType(CsvExportIcon)).dx),
      );
      await shot(t, 'selection-$lang');
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const ValueKey('export-krv')));
      for (var i = 0; i < 15 && shared == null; i++) {
        await settleIo(t);
      }
      expect(shared?.method, 'shareFiles');
      final path = (shared!.arguments['paths'] as List).single as String;
      expect(path, endsWith('.krv'));
      expect(await t.runAsync(() => File(path).exists()), isTrue);
      expect(t.takeException(), isNull);
    });

    testWidgets('$lang import preview, cancel, confirm and repeated import', (
      t,
    ) async {
      AppSettings.current.language = lang;
      await prepare(t);
      await open(t);
      await tapImport(t);
      await awaitTransfer(t, find.byType(KrvSummaryDialog));
      expect(find.text('${tr('Новых измерений')}: 1'), findsOneWidget);
      // Dialog is on the navigator overlay, verified for layout in both languages.
      expect(t.takeException(), isNull);
      await t.tap(find.text(tr('Отмена')));
      await settleIo(t);
      expect(await t.runAsync(() => storage.loadAll()), isEmpty);
      await tapImport(t);
      await awaitTransfer(t, find.byType(KrvSummaryDialog));
      await t.tap(find.text(tr('Добавить измерения')));
      await awaitTransfer(t, find.text('${tr('Добавлено измерений')}: 1'));
      await t.pageBack();
      await settleIo(t);
      expect(find.textContaining('Тестовая река'), findsOneWidget);
      expect((await t.runAsync(() => storage.loadAll()))!.length, 1);
      expect(AppSettings.current.language, lang);
      await tapImport(t);
      await awaitTransfer(t, find.byType(KrvSummaryDialog));
      expect(
        find.text('${tr('Уже имеются без изменений')}: 1'),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, tr('Добавить измерения')),
            )
            .onPressed,
        isNull,
      );
      await t.tap(find.text(tr('Отмена')));
      await settleIo(t);
    });
  }

  testWidgets(
    'Picker cancellation and invalid contents leave records unchanged',
    (t) async {
      await open(t);
      await tapImport(t);
      await settleIo(t);
      expect(find.byType(KrvSummaryDialog), findsNothing);
      await t.runAsync(
        () => File('${dir.path}/wrong.krv').writeAsString('Not a KRV archive'),
      );
      picker.result = XFile('${dir.path}/wrong.krv');
      await tapImport(t);
      await awaitTransfer(
        t,
        find.text('Файл повреждён или не является архивом КРВ.'),
      );
      expect(await t.runAsync(() => storage.loadAll()), isEmpty);
    },
  );
  for (final language in ['ru', 'en']) {
    testWidgets('$language imports Android document URI without extension', (
      t,
    ) async {
      AppSettings.current.language = language;
      await prepare(t);
      await t.runAsync(() async {
        final bytes = await picker.result!.readAsBytes();
        picker.result = XFile.fromData(
          bytes,
          name: 'measurements.krv',
          path:
              'content://com.android.providers.downloads.documents/document/12345',
          mimeType: 'application/octet-stream',
          length: bytes.length,
        );
      });
      expect(picker.result!.name.endsWith('.krv'), isFalse);
      await open(t);
      await tapImport(t);
      await awaitTransfer(t, find.byType(KrvSummaryDialog));
      expect(find.text('${tr('Новых измерений')}: 1'), findsOneWidget);
      await t.tap(find.text(tr('Добавить измерения')));
      await awaitTransfer(t, find.text('${tr('Добавлено измерений')}: 1'));
      await t.pageBack();
      await settleIo(t);
      expect(find.textContaining('Тестовая река'), findsOneWidget);
      expect((await t.runAsync(() => storage.loadAll()))!.length, 1);
      expect(t.takeException(), isNull);
    });
  }
  for (final language in ['ru', 'en']) {
    testWidgets(
      '$language all instrument hints use centimetres with one decimal',
      (t) async {
        t.view.physicalSize = const Size(390, 2400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        AppSettings.current.language = language;
        final m = sample()
          ..calculationConfig = CalculationConfig()
          ..iceCover = true;
        recalcAll(m);
        await t.pumpWidget(
          MaterialApp(
            home: VelocityEditor(measurement: m, vertical: m.verticals[1]),
          ),
        );
        final unit = language == 'ru' ? 'см' : 'cm';
        for (final number in [
          '196.5',
          '170.0',
          '160.0',
          '120.0',
          '100.0',
          '80.0',
          '40.0',
          '30.0',
          '3.5',
        ]) {
          expect(find.text('$number $unit'), findsWidgets);
        }
        await t.ensureVisible(find.text(tr('Глубина от поверхности')));
        await t.tap(find.text(tr('Глубина от поверхности')));
        await t.pumpAndSettle();
        expect(find.text('3.5 $unit'), findsWidgets);
        expect(find.text('40.0 $unit'), findsWidgets);
        expect(m.verticals[1].avgDepth, 2);
        expect(m.rotorDiameter, .05);
        expect(tr(specialExample), isNot(contains('0.5h')));
        expect(t.takeException(), isNull);
        await settleIo(t);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
