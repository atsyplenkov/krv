// Exercises the Dart/plugin boundary; Android receiving-app checks are separate.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  final calls = <MethodCall>[];
  var result = 'target.application';
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('krv-pr4-share-');
    calls.clear();
    result = 'target.application';
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => root.path,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final paths = List<String>.from(call.arguments['paths'] as List);
      for (final path in paths) {
        expect(await File(path).length(), greaterThan(0));
      }
      return result;
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await root.delete(recursive: true);
  });

  Future<File> export(String extension) async {
    final m = sample()..project = 'Проект / Project 2026';
    recalcAll(m, finalCalculation: true);
    switch (extension) {
      case 'pdf':
        return WdcStorage.instance.exportPdf(m);
      case 'csv':
        return WdcStorage.instance.exportCsv(m);
      default:
        final source = await Directory('${root.path}/source').create();
        return File(
          await KrvTransfer.exportArchive(source.path, [m.toJson()], root.path),
        );
    }
  }

  for (final language in ['ru', 'en']) {
    for (final extension in ['pdf', 'csv', 'krv']) {
      test(
        '$language $extension export reaches new share method intact',
        () async {
          AppSettings.current = AppSettings(language: language);
          final generated = await export(extension);
          final file = await generated.copy(
            '${root.path}/Река с пробелом.$extension',
          );
          final bytes = await file.readAsBytes();
          final mime = {
            'pdf': 'application/pdf',
            'csv': 'text/csv',
            'krv': 'application/octet-stream',
          }[extension]!;
          if (extension == 'pdf') expect(bytes.take(4), [37, 80, 68, 70]);
          if (extension == 'csv') {
            expect(await file.readAsString(), contains('project'));
          }
          if (extension == 'krv') {
            final target = await Directory('${root.path}/target').create();
            final plan = await KrvTransfer.inspect(
              file.path,
              target.path,
              root.path,
            );
            expect(plan.fresh, 1);
            await plan.dispose();
          }
          final sharedFile = extension == 'krv'
              ? XFile(file.path, mimeType: mime)
              : XFile(file.path);
          await shareFiles44(
            [sharedFile],
            text: 'Экспорт / Export',
            subject: 'КРВ',
          );
          expect(calls.single.method, 'share');
          expect(calls.single.arguments['paths'], [file.path]);
          expect(calls.single.arguments['mimeTypes'], [mime]);
          expect(calls.single.arguments['text'], 'Экспорт / Export');
          expect(calls.single.arguments['subject'], 'КРВ');
          expect(await file.readAsBytes(), bytes);
          // A dismissed platform share sheet must leave the export intact.
          result = '';
          await shareFiles44([sharedFile]);
          expect(calls.length, 2);
          expect(await file.readAsBytes(), bytes);
        },
      );
    }
  }
  test('batch PDF and CSV retains all paths and content', () async {
    AppSettings.current = AppSettings(language: 'ru');
    for (final extension in ['pdf', 'csv']) {
      calls.clear();
      final first = await export(extension);
      final second = await first.copy('${root.path}/Второй створ.$extension');
      await shareFiles44([XFile(first.path), XFile(second.path)]);
      expect(calls.single.method, 'share');
      expect(calls.single.arguments['paths'], [first.path, second.path]);
      expect(await first.readAsBytes(), await second.readAsBytes());
    }
  });
}
