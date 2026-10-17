import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample, settleIo;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => AppSettings.current = AppSettings(language: 'ru', autoGps: false),
  );
  setUpAll(() async {
    final directory = await Directory(
      'test-output/scroll-451-${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
  });

  testWidgets('Home retains scrolled measurement after opening and returning', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        final m = sample(id: 'scroll-$i')
          ..river = 'Scroll $i'
          ..createdAt = DateTime(2026, 10, 1, i).toIso8601String();
        await WdcStorage.instance.save(m);
      }
    });
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await settleIo(tester);
    final list = find.byKey(const PageStorageKey('home-measurements'));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (list.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await settleIo(tester);
    }
    expect(list, findsOneWidget);
    final target = find.widgetWithText(ListTile, 'Scroll 15');
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    final before = tester.widget<ListView>(list).controller!.offset;
    expect(before, greaterThan(0));
    await tester.tap(target);
    await settleIo(tester);
    expect(find.byType(SoundingScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да'));
    await settleIo(tester);
    await settleIo(tester);
    expect(
      tester.widget<ListView>(list).controller!.offset,
      closeTo(before, 1),
    );
    expect(target.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settleIo(tester);
  });

  testWidgets('Licenses group repeated package names and open long notices', (
    tester,
  ) async {
    LicenseRegistry.addLicense(() async* {
      for (var i = 0; i < 40; i++) {
        yield LicenseEntryWithLineBreaks(
          ['000-regression-package'],
          'Copyright holder $i\n\nPermission notice $i. ${'Long notice text. ' * 30}',
        );
      }
    });
    await tester.pumpWidget(const MaterialApp(home: LicensesScreen45()));
    await tester.pumpAndSettle();
    expect(find.text('000-regression-package'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.tap(find.text('000-regression-package'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Copyright holder 0'), findsWidgets);
    await tester.scrollUntilVisible(
      find.textContaining('Copyright holder 39'),
      1000,
      maxScrolls: 100,
    );
    expect(find.textContaining('Copyright holder 39'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('000-regression-package'), findsOneWidget);
  });
}
