import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'package:image_picker/image_picker.dart';

WdcMeasurement sample({String id = 'test-measurement'}) => WdcMeasurement(
  id: id,
  createdAt: '2026-09-10T09:00:00',
  river: 'Тестовая река',
  site: 'Створ № 1',
  levelSoundingStart: 0,
  levelSoundingEnd: 0,
  levelVelocityStart: 0,
  levelVelocityEnd: 0,
  levelSoundingStartAt: '2026-09-10T09:01:00',
  levelSoundingEndAt: '2026-09-10T09:20:00',
  levelVelocityStartAt: '2026-09-10T09:25:00',
  levelVelocityEndAt: '2026-09-10T09:50:00',
  latitude: 65.83473330,
  longitude: 74.42258490,
  rotorDiameter: 0.05,
  bankCoeffLeft: 0.7,
  bankCoeffRight: 0.7,
  comment: 'Контрольный замер; вода прозрачная.',
  verticals: [
    VerticalPoint(id: 'lb', bank: 'ЛБ', distance: 0, depth1: 0),
    VerticalPoint(
      id: 'v',
      distance: 2,
      depth1: 2,
      isSpeedVertical: true,
      uSurface: VelocityPoint(value: 1),
      u02: VelocityPoint(value: 1),
      u06: VelocityPoint(value: 1),
      u08: VelocityPoint(value: 1),
      uBottom: VelocityPoint(value: 1),
    ),
    VerticalPoint(id: 'rb', bank: 'ПБ', distance: 4, depth1: 0),
  ],
);

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await tester.pump();
}

void main() {
  AppSettings.current = AppSettings(language: 'ru');
  TestWidgetsFlutterBinding.ensureInitialized();
  final qaDir = Directory('test-output');
  final runId = DateTime.now().microsecondsSinceEpoch;
  setUpAll(() async {
    await qaDir.create(recursive: true);
    final loader = FontLoader('WdcReport')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await loader.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '${qaDir.absolute.path}/documents-$runId',
        );
  });

  test('Old JSON stays compatible; diameter remains in metres', () {
    final old = sample().toJson()..remove('photos');
    final restored = WdcMeasurement.fromJson(jsonDecode(jsonEncode(old)));
    expect(restored.photos, isEmpty);
    expect(restored.rotorDiameter, 0.05);
    expect(restored.comment, sample().comment);
    expect(restored.levelVelocityEndAt, sample().levelVelocityEndAt);
  });

  test(
    'CSV includes Q / area after area on every row; diameter exported in cm',
    () {
      final m = sample();
      recalcAll(m, finalCalculation: true);
      expect(m.area, 4);
      expect(m.discharge, 2.8);
      expect(m.meanFlowVelocity, closeTo(0.7, 1e-9));
      final lines = csvContent(m).split('\n');
      final head = lines.first.split(';');
      final areaCol = head.indexOf('Площадь водного сечения потока, м2');
      expect(head[areaCol + 1], 'Средняя скорость потока, м/с');
      final diameterCol = head.indexOf('Лопастной диаметр вертушки, см');
      for (final line in lines.skip(1)) {
        expect(line.split(';')[areaCol + 1], '0.700000');
        expect(line.split(';')[diameterCol], '5.00');
      }
      expect(csvContent(m), contains('"Контрольный замер; вода прозрачная."'));
      m.area = 0;
      expect(m.meanFlowVelocity, isNull);
      expect(csvContent(m), isNot(contains('Infinity')));
    },
  );

  test(
    'Reopening preserves measurements, dates, comment and photos; recalculates new Q',
    () {
      final m = sample()..completed = true;
      m.photos.add(MeasurementPhoto(filename: 'example.jpg', caption: 'Берег'));
      recalcAll(m, finalCalculation: true);
      reopenMeasurement(m);
      expect(m.completed, isFalse);
      expect(m.discharge, isNull);
      expect(m.photos.single.caption, 'Берег');
      expect(m.verticals[1].uSurface.value, 1);
      expect(m.levelVelocityEndAt, '2026-09-10T09:50:00');
      m.bankCoeffLeft = 0.5;
      recalcAll(m, finalCalculation: true);
      expect(m.discharge, 2.4);
      m.levelVelocityEnd = null;
      recalcAll(m, finalCalculation: true);
      expect(m.levelCorrection, isNull);
      expect(m.discharge, isNull);
    },
  );

  test(
    'Concurrent saves keep the latest snapshot and remain readable',
    () async {
      final m = sample(id: 'save-test');
      final pending = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        m.comment = 'Комментарий $i';
        pending.add(WdcStorage.instance.save(m));
      }
      await Future.wait(pending);
      final saved = (await WdcStorage.instance.loadAll()).singleWhere(
        (v) => v.id == m.id,
      );
      expect(saved.comment, 'Комментарий 19');
    },
  );

  test(
    'Photos copied byte for byte, persist after reload, limit is ten',
    () async {
      final m = sample(id: 'photo-test');
      final source = File('assets/icon/app_icon.png');
      for (var i = 0; i < 10; i++) {
        await PhotoStorage.add(m, XFile(source.absolute.path));
      }
      expect(m.photos, hasLength(10));
      expect(
        await (await PhotoStorage.file(m, m.photos.first)).readAsBytes(),
        await source.readAsBytes(),
      );
      m.photos.first.caption = 'Подпись к фото';
      await WdcStorage.instance.save(m);
      final saved = (await WdcStorage.instance.loadAll()).singleWhere(
        (v) => v.id == m.id,
      );
      expect(saved.photos.first.caption, 'Подпись к фото');
      expect(saved.photos.first.filename, isNot(contains('/')));
      await expectLater(
        PhotoStorage.add(m, XFile(source.absolute.path)),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'Diameter field shows centimetres and stores metres; comment is present',
    (tester) async {
      final m = sample();
      await tester.pumpWidget(
        MaterialApp(home: VelocityScreen(measurement: m)),
      );
      final field = find.widgetWithText(TextField, '5');
      expect(field, findsOneWidget);
      expect(find.text('Комментарий'), findsOneWidget);
      await tester.enterText(field, '8');
      expect(m.rotorDiameter, 0.08);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Hints remain visible beside input and switch reference on phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final m = sample();
      recalcAll(m);
      await tester.pumpWidget(
        MaterialApp(
          home: VelocityEditor(measurement: m, vertical: m.verticals[1]),
        ),
      );
      expect(find.text('196.5 см'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('velocity-surface')),
        '0.25',
      );
      expect(find.text('196.5 см'), findsOneWidget);
      await tester.tap(find.text('Глубина от поверхности'));
      await tester.pumpAndSettle();
      expect(find.text('3.5 см'), findsWidgets);
      expect(tester.takeException(), isNull);
      await settleIo(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Finished result shows four labelled dates and edit confirmation',
    (tester) async {
      final m = sample()..completed = true;
      await tester.pumpWidget(
        MaterialApp(home: ResultScreen(measurement: m, viewOnly: true)),
      );
      expect(find.textContaining('Начало промерных работ:'), findsOneWidget);
      expect(find.textContaining('Конец промерных работ:'), findsOneWidget);
      expect(
        find.textContaining('Начало измерения скоростей:'),
        findsOneWidget,
      );
      expect(find.textContaining('Конец измерения скоростей:'), findsOneWidget);
      await tester.tap(find.byTooltip('Редактировать измерение'));
      await tester.pumpAndSettle();
      expect(find.text('Войти в режим редактирования?'), findsOneWidget);
      await tester.tap(find.text('Нет'));
      await tester.pumpAndSettle();
      expect(m.completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Render profile and representative report with full-size photo', (
    tester,
  ) async {
    final m = sample(id: 'pdf-test');
    recalcAll(m, finalCalculation: true);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 390,
              height: 340,
              child: CustomPaint(
                painter: CrossSectionPainter(
                  measurement: m,
                  showVelocities: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      await File('${qaDir.path}/profile.png').writeAsBytes(
        (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
      image.dispose();

      await PhotoStorage.add(
        m,
        XFile(File('assets/icon/app_icon.png').absolute.path),
      );

      m.photos.single.caption = 'Контроль подписи: тестовая эмблема';
      final bytes = await pdfBytes(m);

      await File('${qaDir.path}/report.pdf').writeAsBytes(bytes);
      expect(bytes.take(4), [37, 80, 68, 70]);
    });
    expect(tester.takeException(), isNull);
  });

  test('UTC offset persists; older records remain explicitly unknown', () {
    final modern = WdcMeasurement.fromJson(
      sample().toJson()..['utcOffsetMinutes'] = 345,
    );
    expect(measurementTimeZone(modern), 'UTC+05:45');
    expect(
      measurementTimeZone(WdcMeasurement.fromJson(modern.toJson())),
      'UTC+05:45',
    );
    expect(csvContent(modern), contains('UTC+05:45'));
    final negative = WdcMeasurement.fromJson(
      sample().toJson()..['utcOffsetMinutes'] = -210,
    );
    expect(measurementTimeZone(negative), 'UTC-03:30');
    expect(measurementTimeZone(sample()), contains('не сохранён'));
    final instant = DateTime.parse(measurementNow(modern));
    final wallUtc = DateTime.utc(
      instant.year,
      instant.month,
      instant.day,
      instant.hour,
      instant.minute,
      instant.second,
    );
    expect(
      wallUtc.difference(DateTime.now().toUtc()).inMinutes,
      closeTo(345, 1),
    );
    expect(
      WdcMeasurement.empty().utcOffsetMinutes,
      DateTime.now().timeZoneOffset.inMinutes,
    );
  });

  test(
    'Removing a missing image clears metadata and frees the tenth slot',
    () async {
      final m = sample(id: 'missing-photo');
      for (var i = 0; i < 10; i++) {
        m.photos.add(
          MeasurementPhoto(filename: 'missing-$i.jpg', caption: 'Подпись $i'),
        );
      }
      await WdcStorage.instance.save(m);
      await PhotoStorage.remove(m, m.photos[4]);
      expect(m.photos.length, 9);
      expect(m.photos.any((p) => p.caption == 'Подпись 4'), isFalse);
      await PhotoStorage.add(
        m,
        XFile(File('assets/icon/app_icon.png').absolute.path),
      );
      expect(m.photos.length, 10);
      final saved = (await WdcStorage.instance.loadAll()).singleWhere(
        (v) => v.id == m.id,
      );
      expect(saved.photos.length, 10);
      expect(saved.photos.any((p) => p.filename == 'missing-4.jpg'), isFalse);
    },
  );

  testWidgets(
    'Delete photo refreshes caption and counter; remaining photo still opens',
    (tester) async {
      final m = sample(id: 'gallery-delete');
      await tester.runAsync(() async {
        for (var i = 0; i < 3; i++) {
          await PhotoStorage.add(
            m,
            XFile(File('assets/icon/app_icon.png').absolute.path),
          );
          m.photos.last.caption = 'Снимок $i';
        }
        await WdcStorage.instance.save(m);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeasurementPhotos(measurement: m, editable: true),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settleIo(tester);
      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await settleIo(tester);
      final caption = find.byType(TextFormField);
      final before = (tester.widget<TextFormField>(caption)).initialValue;
      await tester.tap(find.byTooltip('Удалить фото'));
      await settleIo(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Да'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await settleIo(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settleIo(tester);
      expect(find.text('Фотографии (2/10)'), findsOneWidget);
      expect(m.photos.any((p) => p.caption == before), isFalse);
      expect(tester.widget<TextFormField>(caption).initialValue, isNot(before));
      await tester.tap(find.byType(Image).first);
      await settleIo(tester);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await settleIo(tester);
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Distance column stays fixed while velocity columns scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: VelocityScreen(measurement: sample())),
    );
    final fixed = find.byKey(const ValueKey('fixed-distance-column'));
    await tester.scrollUntilVisible(
      fixed,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(fixed), alignment: 0.35);
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(fixed);
    await tester.drag(
      find.byKey(const ValueKey('velocity-horizontal-scroll')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(fixed), before);
    expect(
      find.descendant(of: fixed, matching: find.text('2.000')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
