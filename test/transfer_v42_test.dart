import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wdc_3_0/main.dart';
import 'widget_test.dart' show sample;

void main() {
  late Directory root, source, target, temp;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('krv-tests-');
    source = await Directory('${root.path}/source').create();
    target = await Directory('${root.path}/target').create();
    temp = await Directory('${root.path}/temp').create();
  });
  tearDown(() async => root.delete(recursive: true));
  Future<void> save(WdcMeasurement m, Directory dir) =>
      File('${dir.path}/${m.id}.json').writeAsString(jsonEncode(m.toJson()));
  Future<List<WdcMeasurement>> load() async => [
    for (final f in await target.list().toList())
      if (f is File && f.path.endsWith('.json'))
        WdcMeasurement.fromJson(jsonDecode(await f.readAsString())),
  ];
  Future<String> archive(List<WdcMeasurement> ms) => KrvTransfer.exportArchive(
    source.path,
    ms.map((m) => m.toJson()).toList(),
    temp.path,
  );
  Future<KrvImportPlan> inspect(String path) =>
      KrvTransfer.inspect(path, target.path, temp.path);
  Future<void> photo(WdcMeasurement m, String name, List<int> bytes) async {
    m.photos.add(MeasurementPhoto(filename: name, caption: 'Берег / bank'));
    final dir = await Directory(
      '${source.path}/photos/${m.id}',
    ).create(recursive: true);
    await File('${dir.path}/$name').writeAsBytes(bytes);
  }

  Future<String> customZip(
    Map<String, dynamic> manifest, {
    String? extra,
  }) async {
    final a = Archive()
      ..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    if (extra != null) a.addFile(ArchiveFile.string(extra, 'malicious'));
    final f = File('${temp.path}/custom.krv');
    await f.writeAsBytes(ZipEncoder().encode(a));
    return f.path;
  }

  Map<String, dynamic> manifest(WdcMeasurement m) => {
    'format': 'krv',
    'version': 1,
    'records': [
      {'measurement': m.toJson(), 'photos': <String, String>{}},
    ],
  };

  test(
    'Full round trip retains all data and photos without recalculation',
    () async {
      final m = sample()
        ..completed = true
        ..iceCover = true;
      m.calculationConfig = CalculationConfig(preset: 'custom2');
      m.calculationConfig!.custom[0]['one06']!['06'] = .123;
      m.calculationConfig!.custom[2]['two']!['08'] = 999.999;
      m.verticals[1].individualConfig = CalculationConfig(preset: 'mi');
      m.verticals[1].u015.value = .43;
      recalcAll(m, finalCalculation: true);
      final bytes = List<int>.generate(4096, (i) => i % 256);
      await photo(m, 'photo.jpg', bytes);
      final expected = m.toJson();
      final path = await archive([m, sample(id: 'draft')]);
      final plan = await inspect(path);
      expect(plan.fresh, 2);
      expect(plan.photos, 1);
      await KrvTransfer.commit(plan, target.path);
      final imported = (await load()).firstWhere((x) => x.completed);
      expect(imported.archiveOriginId, m.id);
      final actual = imported.toJson()
        ..remove('archiveOriginId')
        ..['id'] = m.id;
      expect(actual, expected);
      expect(
        await File(
          '${target.path}/photos/${imported.id}/photo.jpg',
        ).readAsBytes(),
        bytes,
      );
      expect((await inspect(path)).skipped, 2);
    },
  );

  test(
    'Identical records skip; changed versions become copies; copies deduplicate',
    () async {
      final m = sample();
      await save(m, target);
      final original = await File('${target.path}/${m.id}.json').readAsString();
      final same = await inspect(await archive([m]));
      expect(same.records, isEmpty);
      expect(same.skipped, 1);
      m.comment = 'Изменено';
      final path = await archive([m]);
      final changed = await inspect(path);
      expect(changed.conflicts, 1);
      await KrvTransfer.commit(changed, target.path);
      expect((await load()).length, 2);
      expect(
        (await load()).where((m) => m.importedCopy).single.comment,
        'Изменено',
      );
      expect(
        await File('${target.path}/${m.id}.json').readAsString(),
        original,
      );
      expect((await inspect(path)).skipped, 1);
      final copied = (await load()).firstWhere((m) => m.importedCopy);
      expect((await inspect(await archive([copied]))).skipped, 1);
    },
  );

  test('Repeated photos occupy one blob; metadata is compressed', () async {
    final a = sample(id: 'a'), b = sample(id: 'b');
    final bytes = List<int>.generate(8192, (i) => i % 251);
    await photo(a, 'a.jpg', bytes);
    await photo(b, 'b.jpg', bytes);
    final path = await archive([a, b]);
    final zip = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    expect(zip.files.where((f) => f.name.startsWith('photos/')).length, 1);
    expect(await File(path).length(), lessThan(12000));
    final plan = await inspect(path);
    expect(plan.photos, 2);
    await plan.dispose();
    expect(await target.list().toList(), isEmpty);
  });

  test('Failed commit rolls back only new records and allows retry', () async {
    final old = sample(id: 'old');
    await save(old, target);
    final plan = await inspect(
      await archive([sample(id: 'a'), sample(id: 'b')]),
    );
    await expectLater(
      KrvTransfer.commit(plan, target.path, failAfter: 1),
      throwsA(isA<FileSystemException>()),
    );
    expect((await load()).map((m) => m.id), ['old']);
    expect(await Directory('${target.path}/photos').list().toList(), isEmpty);
    await KrvTransfer.commit(plan, target.path);
    expect((await load()).length, 3);
  });

  test(
    'Power loss with broken journal recovers only transaction prefix',
    () async {
      await save(sample(id: 'old'), target);
      final stage = await Directory(
        '${target.path}/.krv-import-123_456',
      ).create();
      await File('${stage.path}/journal.json').writeAsBytes([0, 0]);
      await save(sample(id: 'krv_123_456_0'), target);
      await save(sample(id: 'krv_123_4567_0'), target);
      await Directory(
        '${target.path}/photos/krv_123_456_0',
      ).create(recursive: true);
      await KrvTransfer.recover(target.path);
      expect((await load()).map((m) => m.id).toSet(), {
        'old',
        'krv_123_4567_0',
      });
      expect(await stage.exists(), isFalse);
    },
  );

  test('Committed import survives deferred cleanup', () async {
    final stage = await Directory(
      '${target.path}/.krv-import-123_456',
    ).create();
    await File('${stage.path}/committed').writeAsString('ok');
    await save(sample(id: 'krv_123_456_0'), target);
    await KrvTransfer.recover(target.path);
    expect((await load()).length, 1);
    expect(await stage.exists(), isFalse);
  });

  for (final kind in [
    'path',
    'extra',
    'future',
    'badId',
    'badPhoto',
    'missingPhoto',
    'badVertical',
    'truncated',
  ]) {
    test('Reject $kind archive without changing stored measurements', () async {
      await save(sample(id: 'old'), target);
      final m = sample();
      final data = manifest(m);
      final j = (data['records'] as List).first['measurement'] as Map;
      String? extra;
      switch (kind) {
        case 'path':
          extra = '../escape';
        case 'extra':
          extra = 'unknown';
        case 'future':
          data['version'] = 2;
        case 'badId':
          j['id'] = '../escape';
        case 'badPhoto':
          j['photos'] = [42];
        case 'missingPhoto':
          j['photos'] = [
            {'filename': 'p.jpg', 'caption': ''},
          ];
        case 'badVertical':
          j['verticals'] = [42];
      }
      final path = await customZip(data, extra: extra);
      if (kind == 'truncated') await File(path).writeAsBytes([80, 75, 3, 4]);
      await expectLater(inspect(path), throwsA(isA<KrvException>()));
      expect((await load()).map((m) => m.id), ['old']);
      expect((await temp.list().toList()).whereType<Directory>(), isEmpty);
    });
  }

  test('Photo hash mismatch rejected', () async {
    final m = sample();
    await photo(m, 'p.jpg', [1, 2, 3]);
    final path = await archive([m]);
    final zip = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final changed = Archive();
    for (final f in zip.files) {
      changed.addFile(
        f.name.startsWith('photos/') ? ArchiveFile(f.name, 3, [3, 2, 1]) : f,
      );
    }
    await File(path).writeAsBytes(ZipEncoder().encode(changed));
    await expectLater(inspect(path), throwsA(isA<KrvException>()));
  });

  test('Missing photo cancels export and removes partial archive', () async {
    final m = sample()..photos.add(MeasurementPhoto(filename: 'missing.jpg'));
    await expectLater(archive([m]), throwsA(isA<KrvException>()));
    expect(await temp.list().toList(), isEmpty);
  });

  test('Background workers support complete transfer', () async {
    final sourcePath = source.path,
        targetPath = target.path,
        tempPath = temp.path;
    final records = [sample().toJson()];
    final path = await Isolate.run(
      () => KrvTransfer.exportArchive(sourcePath, records, tempPath),
    );
    final plan = await Isolate.run(
      () => KrvTransfer.inspect(path, targetPath, tempPath),
    );
    await Isolate.run(() => KrvTransfer.commit(plan, targetPath));
    expect((await load()).length, 1);
  });
  test(
    'Immutable initial profiles and individual settings survive transfer',
    () async {
      AppSettings.current = AppSettings(language: 'en', autoGps: false);
      AppSettings.current.defaults = CalculationConfig(preset: 'custom1');
      AppSettings.current.defaults.custom[2]['two']!['08'] = 9.123;
      final m = WdcMeasurement.empty();
      m.calculationConfig = CalculationConfig(preset: 'mi');
      m.verticals.addAll(sample().verticals);
      m.verticals[1].individualConfig = CalculationConfig(preset: 'custom0');
      final plan = await inspect(await archive([m]));
      await KrvTransfer.commit(plan, target.path);
      final copied = (await load()).single;
      expect(
        copied.initialCalculationConfig!.toJson(),
        m.initialCalculationConfig!.toJson(),
      );
      expect(copied.calculationConfig!.preset, 'mi');
      expect(copied.verticals[1].individualConfig!.preset, 'custom0');
      expect(AppSettings.current.language, 'en');
      expect(AppSettings.current.autoGps, isFalse);
      expect(AppSettings.current.defaults.preset, 'custom1');
    },
  );
}
