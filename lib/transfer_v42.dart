part of 'main.dart';

class KrvSummaryDialog extends StatelessWidget {
  const KrvSummaryDialog({super.key, required this.plan});
  final KrvImportPlan plan;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('Импорт измерений')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tr('Новых измерений')}: ${plan.fresh}'),
          Text('${tr('Уже имеются без изменений')}: ${plan.skipped}'),
          Text('${tr('Отличающихся версий')}: ${plan.conflicts}'),
          Text('${tr('Фотографий к добавлению')}: ${plan.photos}'),
          const SizedBox(height: 12),
          Text(
            tr(
              'Совпадающие записи будут пропущены. Отличающиеся версии добавятся отдельными копиями. Существующие измерения и настройки приложения не изменятся.',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(tr('Отмена')),
      ),
      FilledButton(
        onPressed: plan.records.isEmpty
            ? null
            : () => Navigator.pop(context, true),
        child: Text(tr('Добавить измерения')),
      ),
    ],
  );
}

class KrvException implements Exception {
  const KrvException(this.message);
  final String message;
}

class KrvRecord {
  KrvRecord(this.measurement, this.photos, this.conflict);
  final Map<String, dynamic> measurement;
  final Map<String, String> photos;
  final bool conflict;
}

class KrvImportPlan {
  KrvImportPlan(this.directory, this.records, this.skipped);
  final String directory;
  final List<KrvRecord> records;
  final int skipped;
  int get conflicts => records.where((r) => r.conflict).length;
  int get fresh => records.length - conflicts;
  int get photos => records.fold(0, (n, r) => n + r.photos.length);
  Future<void> dispose() async {
    final dir = Directory(directory);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

// Bounded output prevents forged ZIP sizes from expanding without limit.
class _KrvOutput extends arc.OutputMemoryStream {
  _KrvOutput(this.limit);
  final int limit;
  void check(int count) {
    if (count < 0 || length + count > limit) {
      throw const KrvException(
        'Архив слишком большой. Выберите меньше измерений.',
      );
    }
  }

  @override
  void writeByte(int value) {
    check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(arc.InputStream stream) {
    while (!stream.isEOS) {
      final count = math.min(65536, stream.length);
      writeBytes(stream.readBytes(count).toUint8List());
    }
  }
}

class KrvTransfer {
  // Keep isolate closures outside widget methods: their captured contexts may
  // otherwise retain a Navigator, animation controllers or other UI objects.
  static Future<String> exportInBackground(
    String base,
    List<Map<String, dynamic>> records,
    String temp,
  ) => Isolate.run(() => exportArchive(base, records, temp));
  static Future<KrvImportPlan> inspectInBackground(
    String path,
    String base,
    String temp,
  ) => Isolate.run(() => inspect(path, base, temp));
  static Future<void> commitInBackground(KrvImportPlan plan, String base) =>
      Isolate.run(() => commit(plan, base));
  static const maxTotal = 1024 * 1024 * 1024;
  static const maxPhoto = 64 * 1024 * 1024;
  static const maxManifest = 16 * 1024 * 1024;
  static const invalid = KrvException(
    'Файл повреждён или не является архивом КРВ.',
  );
  static final _name = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,159}$');
  static final _hash = RegExp(r'^[a-f0-9]{64}$');
  static String _token() =>
      '${DateTime.now().microsecondsSinceEpoch}_${math.Random.secure().nextInt(1 << 32)}';
  static bool safeName(String name) =>
      _name.hasMatch(name) && !name.contains('..');
  static void _require(bool condition) {
    if (!condition) throw invalid;
  }

  static Future<String> _digest(File file) async =>
      (await crypto.sha256.bind(file.openRead()).first).toString();
  static dynamic _sorted(dynamic value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: _sorted(value[k])};
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }

  static String fingerprint(
    Map<String, dynamic> json,
    Map<String, String> photos,
  ) {
    final copy = Map<String, dynamic>.from(json)
      ..remove('id')
      ..remove('archiveOriginId')
      ..remove('importedCopy');
    return crypto.sha256
        .convert(
          utf8.encode(jsonEncode(_sorted({'data': copy, 'photos': photos}))),
        )
        .toString();
  }

  static WdcMeasurement _measurement(dynamic source) {
    _require(source is Map<String, dynamic>);
    final j = source as Map<String, dynamic>;
    if (j['schemaVersion'] is num && (j['schemaVersion'] as num) > 6) {
      throw const KrvException(
        'Архив создан более новой версией. Обновите приложение.',
      );
    }
    _require(j['id'] is String && safeName(j['id'] as String));
    _require(
      j['createdAt'] is String && DateTime.tryParse(j['createdAt']) != null,
    );
    _require(
      j['verticals'] is List && (j['verticals'] as List).length <= 10000,
    );
    _require(
      (j['verticals'] as List).every(
        (v) => v is Map<String, dynamic> && v['id'] is String,
      ),
    );
    _require(
      j['photos'] == null ||
          (j['photos'] is List && (j['photos'] as List).length <= 10),
    );
    _require(
      j['photos'] == null ||
          (j['photos'] as List).every(
            (p) => p is Map<String, dynamic> && p['filename'] is String,
          ),
    );
    final m = WdcMeasurement.fromJson(j);
    _require(m.archiveOriginId == null || safeName(m.archiveOriginId!));
    _require(m.photos.every((p) => safeName(p.filename)));
    _require(m.photos.map((p) => p.filename).toSet().length == m.photos.length);
    _require(m.verticals.map((v) => v.id).toSet().length == m.verticals.length);
    return m;
  }

  static Future<String> exportArchive(
    String base,
    List<Map<String, dynamic>> records,
    String temp,
  ) async {
    if (records.isEmpty || records.length > 1000) throw invalid;
    final encoder = arc.ZipFileEncoder();
    final path =
        '$temp/KRV_${DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}_${_token()}.krv';
    final blobs = <String>{};
    final manifest = <Map<String, dynamic>>[];
    var total = 0;
    var closed = false;
    encoder.create(path);
    try {
      for (final json in records) {
        final m = _measurement(json);
        final photos = <String, String>{};
        for (final p in m.photos) {
          final file = File('$base/photos/${m.id}/${p.filename}');
          if (!await file.exists()) {
            throw const KrvException(
              'Не найдена фотография измерения. Экспорт отменён.',
            );
          }
          final size = await file.length();
          if (size > maxPhoto) {
            throw const KrvException(
              'Архив слишком большой. Выберите меньше измерений.',
            );
          }
          final hash = await _digest(file);
          photos[p.filename] = hash;
          if (blobs.add(hash)) {
            total += size;
            if (total > maxTotal - maxManifest) {
              throw const KrvException(
                'Архив слишком большой. Выберите меньше измерений.',
              );
            }
            await encoder.addFile(file, 'photos/$hash', 0);
          }
        }
        manifest.add({'measurement': m.toJson(), 'photos': photos});
      }
      final bytes = utf8.encode(
        jsonEncode({
          'format': 'krv',
          'version': 1,
          'appVersion': '4.4.0',
          'records': manifest,
        }),
      );
      if (bytes.length > maxManifest) {
        throw const KrvException(
          'Архив слишком большой. Выберите меньше измерений.',
        );
      }
      encoder.addArchiveFile(
        arc.ArchiveFile('manifest.json', bytes.length, bytes),
      );
      await encoder.close();
      closed = true;
      return path;
    } catch (_) {
      if (!closed) {
        await encoder.close();
        closed = true;
      }
      if (await File(path).exists()) await File(path).delete();
      rethrow;
    }
  }

  static Future<KrvImportPlan> inspect(
    String path,
    String base,
    String temp,
  ) async {
    final preview = await Directory(temp).createTemp('krv-preview-');
    arc.InputFileStream? input;
    try {
      if (await File(path).length() > maxTotal + maxManifest) {
        throw const KrvException(
          'Архив слишком большой. Выберите меньше измерений.',
        );
      }
      input = arc.InputFileStream(path);
      final directory = arc.ZipDirectory()..read(input);
      _require(
        directory.fileHeaders.isNotEmpty &&
            directory.fileHeaders.length <= 10001,
      );
      final headers = <String, arc.ZipFileHeader>{};
      var total = 0;
      for (final h in directory.fileHeaders) {
        _require(!headers.containsKey(h.filename));
        _require(
          h.filename == 'manifest.json' ||
              RegExp(r'^photos/[a-f0-9]{64}$').hasMatch(h.filename),
        );
        _require(((h.externalFileAttributes >> 16) & 0xf000) != 0xa000);
        _require(
          h.generalPurposeBitFlag & 1 == 0 &&
              [0, 8].contains(h.compressionMethod),
        );
        _require(
          h.file != null &&
              h.file!.filename == h.filename &&
              h.file!.uncompressedSize == h.uncompressedSize,
        );
        final limit = h.filename == 'manifest.json' ? maxManifest : maxPhoto;
        _require(h.uncompressedSize >= 0 && h.uncompressedSize <= limit);
        total += h.uncompressedSize;
        if (total > maxTotal) {
          throw const KrvException(
            'Архив слишком большой. Выберите меньше измерений.',
          );
        }
        headers[h.filename] = h;
      }
      List<int> read(arc.ZipFileHeader h) {
        final out = _KrvOutput(h.uncompressedSize);
        h.file!.decompress(out);
        final bytes = out.getBytes();
        _require(
          bytes.length == h.uncompressedSize && arc.getCrc32(bytes) == h.crc32,
        );
        return bytes;
      }

      _require(headers.containsKey('manifest.json'));
      final manifest = jsonDecode(utf8.decode(read(headers['manifest.json']!)));
      _require(manifest is Map && manifest['format'] == 'krv');
      if (manifest['version'] != 1) {
        throw const KrvException(
          'Архив создан более новой версией. Обновите приложение.',
        );
      }
      _require(
        manifest['records'] is List &&
            (manifest['records'] as List).isNotEmpty &&
            (manifest['records'] as List).length <= 1000,
      );
      final incoming = <KrvRecord>[];
      final requiredPhotos = <String>{};
      for (final record in manifest['records']) {
        _require(record is Map && record['photos'] is Map);
        final m = _measurement(record['measurement']);
        final photos = Map<String, String>.from(record['photos']);
        _require(photos.length == m.photos.length);
        for (final p in m.photos) {
          final hash = photos[p.filename];
          _require(
            hash != null &&
                _hash.hasMatch(hash) &&
                headers.containsKey('photos/$hash'),
          );
          requiredPhotos.add(hash!);
        }
        incoming.add(KrvRecord(m.toJson(), photos, false));
      }
      _require(headers.length == requiredPhotos.length + 1);
      for (final hash in requiredPhotos) {
        final bytes = read(headers['photos/$hash']!);
        _require(crypto.sha256.convert(bytes).toString() == hash);
        await File('${preview.path}/$hash').writeAsBytes(bytes, flush: true);
      }
      // Compare complete records, not cached import hashes: local edits and photo
      // changes must produce a conflict, while reimporting a copy must be a no-op.
      final existing = <String, Set<String>>{};
      final root = Directory(base);
      if (await root.exists()) {
        await for (final f in root.list()) {
          if (f is! File || !f.path.endsWith('.json')) continue;
          try {
            final m = _measurement(jsonDecode(await f.readAsString()));
            final origin = m.archiveOriginId ?? m.id;
            final known = existing.putIfAbsent(origin, () => <String>{});
            final photos = <String, String>{};
            for (final p in m.photos) {
              final photo = File('$base/photos/${m.id}/${p.filename}');
              photos[p.filename] = await photo.exists()
                  ? await _digest(photo)
                  : 'missing';
            }
            known.add(fingerprint(m.toJson(), photos));
          } catch (_) {
            /* Existing unreadable files are left untouched. */
          }
        }
      }
      final records = <KrvRecord>[];
      var skipped = 0;
      for (final r in incoming) {
        final origin =
            (r.measurement['archiveOriginId'] ?? r.measurement['id']) as String;
        final known = existing.putIfAbsent(origin, () => <String>{});
        final hash = fingerprint(r.measurement, r.photos);
        if (known.contains(hash)) {
          skipped++;
          continue;
        }
        records.add(KrvRecord(r.measurement, r.photos, known.isNotEmpty));
        known.add(hash);
      }
      return KrvImportPlan(preview.path, records, skipped);
    } on KrvException {
      await preview.delete(recursive: true);
      rethrow;
    } catch (_) {
      await preview.delete(recursive: true);
      throw invalid;
    } finally {
      await input?.close();
    }
  }

  static Future<void> recover(String base) async {
    final root = Directory(base);
    if (!await root.exists()) return;
    for (final entry in await root.list(followLinks: false).toList()) {
      if (entry is! Directory) continue;
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!RegExp(r'^\.krv-import-\d+_\d+$').hasMatch(name)) continue;
      if (!await File('${entry.path}/committed').exists()) {
        // Recover by the reserved transaction prefix even if a power loss
        // damaged the journal. Never touch identifiers from another import.
        final prefix = 'krv_${name.substring('.krv-import-'.length)}_';
        final pattern = RegExp('^${RegExp.escape(prefix)}[0-9]+\\.json\$');
        for (final file in await root.list(followLinks: false).toList()) {
          if (file is File && pattern.hasMatch(file.uri.pathSegments.last)) {
            await file.delete();
          }
        }
        final photosRoot = Directory('$base/photos');
        final photoPattern = RegExp('^${RegExp.escape(prefix)}[0-9]+\$');
        if (await photosRoot.exists()) {
          for (final photos
              in await photosRoot.list(followLinks: false).toList()) {
            final photoName = photos.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last;
            if (photos is Directory && photoPattern.hasMatch(photoName)) {
              await photos.delete(recursive: true);
            }
          }
        }
      }
      await entry.delete(recursive: true);
    }
  }

  static Future<void> commit(
    KrvImportPlan plan,
    String base, {
    int? failAfter,
  }) async {
    if (plan.records.isEmpty) return;
    final token = _token();
    final stage = await Directory(
      '$base/.krv-import-$token',
    ).create(recursive: true);
    final ids = <String>[];
    try {
      for (var i = 0; i < plan.records.length; i++) {
        final r = plan.records[i];
        final m = _measurement(r.measurement);
        m.archiveOriginId ??= m.id;
        m.id = 'krv_${token}_$i';
        m.importedCopy = r.conflict || m.importedCopy;
        ids.add(m.id);
        _require(
          !await File('$base/${m.id}.json').exists() &&
              !await Directory('$base/photos/${m.id}').exists(),
        );
        final dir = await Directory(
          '${stage.path}/photos/${m.id}',
        ).create(recursive: true);
        for (final p in m.photos) {
          final hash = r.photos[p.filename]!;
          final source = File('${plan.directory}/$hash');
          _require(await _digest(source) == hash);
          final copy = await source.copy('${dir.path}/${p.filename}');
          final handle = await copy.open(mode: FileMode.append);
          await handle.flush();
          await handle.close();
        }
        await File(
          '${stage.path}/${m.id}.json',
        ).writeAsString(jsonEncode(m.toJson()), flush: true);
      }
      // No existing files are replaced. The journal precedes the first move;
      // recovery removes only this transaction's generated identifiers.
      await File(
        '${stage.path}/journal.json',
      ).writeAsString(jsonEncode(ids), flush: true);
      await Directory('$base/photos').create(recursive: true);
      for (var i = 0; i < ids.length; i++) {
        final id = ids[i];
        await Directory('${stage.path}/photos/$id').rename('$base/photos/$id');
        await File('${stage.path}/$id.json').rename('$base/$id.json');
        if (failAfter == i + 1) {
          throw const FileSystemException('Simulated interrupted import');
        }
      }
      await File('${stage.path}/committed').writeAsString('ok', flush: true);
    } catch (_) {
      await recover(base);
      rethrow;
    }
    // A cleanup failure must not report a committed import as failed.
    try {
      await stage.delete(recursive: true);
    } on FileSystemException {
      /* recovery will clean this */
    }
  }
}
