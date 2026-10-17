import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;

void main() {
  AppSettings.current = AppSettings(language: 'ru');
  TestWidgetsFlutterBinding.ensureInitialized();
  final runId = DateTime.now().microsecondsSinceEpoch;
  setUpAll(() async {
    final dir = Directory('test-output/final-save-documents-$runId');
    await dir.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.absolute.path,
        );
  });
  testWidgets(
    'Final save updates Home immediately and Home has both PDF export actions',
    (tester) async {
      final m = sample(id: 'final-save-regression')..river = 'Финальная запись';
      await tester.runAsync(() => WdcStorage.instance.save(m));
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await settleIo(tester);
      expect(find.text('v4.5'), findsOneWidget);
      final context = tester.element(find.byType(HomeScreen));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(measurement: m, viewOnly: false),
        ),
      );
      await settleIo(tester);
      await tester.tap(find.byTooltip('Сохранить'));
      await settleIo(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Да'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await settleIo(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await settleIo(tester);
      expect(find.byType(ResultScreen), findsNothing);
      final tile = find.widgetWithText(ListTile, 'Финальная запись');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.textContaining('Незавершённое измерение'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.ancestor(of: tile, matching: find.byType(Card)),
          matching: find.byTooltip('Экспорт PDF'),
        ),
        findsOneWidget,
      );
      await tester.longPress(tile);
      await settleIo(tester);
      expect(find.byTooltip('Экспорт выбранных в PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
