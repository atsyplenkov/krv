part of 'main.dart';

Map<String, String> measurementTimes(WdcMeasurement m) => {
  tr('Начало промерных работ'): humanFromIso(m.levelSoundingStartAt).isEmpty
      ? tr('не начаты')
      : humanFromIso(m.levelSoundingStartAt),
  tr('Конец промерных работ'): humanFromIso(m.levelSoundingEndAt).isEmpty
      ? tr('не указано')
      : humanFromIso(m.levelSoundingEndAt),
  tr('Начало измерения скоростей'): humanFromIso(m.levelVelocityStartAt).isEmpty
      ? tr('не указано')
      : humanFromIso(m.levelVelocityStartAt),
  tr('Конец измерения скоростей'): humanFromIso(m.levelVelocityEndAt).isEmpty
      ? tr('не указано')
      : humanFromIso(m.levelVelocityEndAt),
};

String coordinatesText(WdcMeasurement m) =>
    m.latitude == null || m.longitude == null
    ? tr('не указаны')
    : '${_numCell(m.latitude, 8)}, ${_numCell(m.longitude, 8)}';

void reopenMeasurement(WdcMeasurement m) {
  m.completed = false;
  recalcAll(m);
}

class CsvExportIcon extends StatelessWidget {
  const CsvExportIcon({super.key});
  @override
  Widget build(BuildContext context) => const DocumentExportIcon(label: 'CSV');
}

class PdfExportIcon extends StatelessWidget {
  const PdfExportIcon({super.key});
  @override
  Widget build(BuildContext context) => const DocumentExportIcon(label: 'PDF');
}

class DocumentExportIcon extends StatelessWidget {
  const DocumentExportIcon({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: CustomPaint(
      painter: _DocumentIconPainter(
        label,
        IconTheme.of(context).color ?? Colors.black,
      ),
    ),
  );
}

class _DocumentIconPainter extends CustomPainter {
  _DocumentIconPainter(this.label, this.color);
  final String label;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
    final paint = Paint()..color = color;
    // Matching stacked-document shape for both formats; only lettering differs.
    canvas.drawPath(
      Path()
        ..moveTo(2, 6)
        ..lineTo(4, 6)
        ..lineTo(4, 20)
        ..lineTo(18, 20)
        ..lineTo(18, 22)
        ..lineTo(4, 22)
        ..quadraticBezierTo(2, 22, 2, 20)
        ..close(),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 2, 16, 16),
        const Radius.circular(2),
      ),
      paint,
    );
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'WdcReport',
          fontSize: 7,
          fontWeight: FontWeight.bold,
          foreground: Paint()
            ..color = Colors.white
            ..blendMode = BlendMode.dstOut,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(14 - text.width / 2, 10 - text.height / 2));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DocumentIconPainter old) =>
      old.label != label || old.color != color;
}

String measurementTimeZone(WdcMeasurement m) {
  final minutes = m.utcOffsetMinutes;
  if (minutes == null) return tr('UTC: не сохранён (старая запись)');
  final value = minutes.abs();
  return 'UTC${minutes < 0 ? '-' : '+'}${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

String measurementNow(WdcMeasurement m) {
  if (m.utcOffsetMinutes == null) return nowIso();
  return DateTime.now()
      .toUtc()
      .add(Duration(minutes: m.utcOffsetMinutes!))
      .toIso8601String()
      .replaceFirst(RegExp(r'Z$'), '');
}

// Stage timestamps are independent of water-level fields and survive deletions.
// Never move the end backwards if the device clock is adjusted during fieldwork.
String _latestMeasurementTime(String now, String? start, String? end) {
  var latest = DateTime.parse(now);
  for (final text in [start, end]) {
    final previous = text == null ? null : DateTime.tryParse(text);
    if (previous != null && previous.isAfter(latest)) latest = previous;
  }
  return latest.toIso8601String();
}

void recordSoundingInput(WdcMeasurement m, {String? at}) {
  final now = at ?? measurementNow(m);
  m.levelSoundingStartAt ??= now;
  m.levelSoundingEndAt = _latestMeasurementTime(
    now,
    m.levelSoundingStartAt,
    m.levelSoundingEndAt,
  );
}

void recordVelocityInput(WdcMeasurement m, {String? at}) {
  final now = at ?? measurementNow(m);
  m.levelVelocityStartAt ??= now;
  m.levelVelocityEndAt = _latestMeasurementTime(
    now,
    m.levelVelocityStartAt,
    m.levelVelocityEndAt,
  );
}

VoidCallback showWorkProgress(BuildContext context, String message) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: Row(
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(width: 18),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  navigator.push(route);
  var closed = false;
  return () {
    if (closed) return;
    closed = true;
    if (route.isActive) navigator.removeRoute(route);
  };
}

class MeasurementComment extends StatelessWidget {
  const MeasurementComment({super.key, required this.measurement});
  final WdcMeasurement measurement;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: TextFormField(
      initialValue: measurement.comment,
      maxLength: 512,
      minLines: 2,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(labelText: tr('Комментарий')),
      onChanged: (value) {
        measurement.comment = value;
        WdcStorage.instance.save(measurement).catchError((Object error) {
          if (context.mounted) {
            showSnack(context, tr('Не удалось сохранить комментарий'));
          }
        });
      },
    ),
  );
}

class MeasurementPhoto {
  MeasurementPhoto({required this.filename, this.caption = ''});
  final String filename;
  String caption;
  Map<String, dynamic> toJson() => {'filename': filename, 'caption': caption};
  factory MeasurementPhoto.fromJson(Map<String, dynamic> json) =>
      MeasurementPhoto(
        filename: json['filename'] as String,
        caption: json['caption'] as String? ?? '',
      );
}

class PhotoStorage {
  static final picker = ImagePicker();
  static Future<Directory> directory(WdcMeasurement m) async {
    final base = await WdcStorage.instance._baseDir;
    final dir = Directory('${base.path}/photos/${m.id}');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> file(WdcMeasurement m, MeasurementPhoto photo) async {
    // Store relative filenames: iOS may change the application container path.
    if (photo.filename.contains('/') || photo.filename.contains('\\')) {
      throw FormatException(tr('Некорректное имя фотографии'));
    }
    return File('${(await directory(m)).path}/${photo.filename}');
  }

  static Future<void> add(WdcMeasurement m, XFile source) async {
    if (m.photos.length >= 10) {
      throw StateError(tr('Можно добавить не более 10 фотографий'));
    }
    final extension = source.name.contains('.')
        ? source.name.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : 'jpg';
    final photo = MeasurementPhoto(filename: '${uid()}.$safeExtension');
    await source.saveTo((await file(m, photo)).path);
    m.photos.add(photo);
    await WdcStorage.instance.save(m);
  }

  static Future<void> remove(WdcMeasurement m, MeasurementPhoto photo) async {
    final index = m.photos.indexWhere((p) => p.filename == photo.filename);
    if (index < 0) return;
    final removed = m.photos.removeAt(index);
    try {
      await WdcStorage.instance.save(m);
    } catch (_) {
      m.photos.insert(math.min(index, m.photos.length), removed);
      rethrow;
    }
    // A locked or already missing file must not leave a ghost in the gallery.
    try {
      final f = await file(m, removed);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      /* The unreferenced file can be cleaned up later. */
    }
  }

  static Future<File> get pending async => File(
    '${(await getApplicationDocumentsDirectory()).path}/wdc_pending_photo.json',
  );
  static Future<void> clearPending() async {
    final f = await pending;
    if (await f.exists()) await f.delete();
  }

  static Future<void> recoverLostPhotos() async {
    if (!Platform.isAndroid) return;
    final f = await pending;
    if (!await f.exists()) return;
    final id =
        (jsonDecode(await f.readAsString())
            as Map<String, dynamic>)['measurementId'];
    final response = await picker.retrieveLostData();
    final all = await WdcStorage.instance.loadAll();
    final m = all.where((m) => m.id == id).firstOrNull;
    if (m != null) {
      for (final photo in response.files ?? <XFile>[]) {
        if (m.photos.length == 10) break;
        await add(m, photo);
      }
    }
    await clearPending();
    if (response.exception != null) throw response.exception!;
  }
}

class MeasurementPhotos extends StatefulWidget {
  const MeasurementPhotos({
    super.key,
    required this.measurement,
    required this.editable,
  });
  final WdcMeasurement measurement;
  final bool editable;
  @override
  State<MeasurementPhotos> createState() => _MeasurementPhotosState();
}

class _MeasurementPhotosState extends State<MeasurementPhotos> {
  PageController _pages = PageController();
  int _galleryVersion = 0;
  bool _busy = false;
  int _index = 0;
  WdcMeasurement get m => widget.measurement;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy || m.photos.length >= 10) return;
    setState(() => _busy = true);
    try {
      await WdcStorage.instance.save(m);
      await (await PhotoStorage.pending).writeAsString(
        jsonEncode({'measurementId': m.id}),
        flush: true,
      );
      // No imageQuality/maxWidth/maxHeight: preserve the supplied resolution.
      final photo = await PhotoStorage.picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
      if (photo != null) {
        await PhotoStorage.add(m, photo);
        if (mounted) {
          setState(() => _index = m.photos.length - 1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pages.hasClients) _pages.jumpToPage(_index);
          });
        }
      }
      await PhotoStorage.clearPending();
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          tr(
            'Не удалось добавить фото. Проверьте доступ к камере или галерее.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(MeasurementPhoto photo) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await confirmDialog(
      context,
      title: tr('Удаление фото'),
      message: tr('Удалить фотографию из измерения?'),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    try {
      await PhotoStorage.remove(m, photo);
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          tr('Не удалось удалить фотографию. Попробуйте ещё раз.'),
        );
      }
    } finally {
      if (mounted) {
        final previous = _pages;
        setState(() {
          _index = math.min(_index, math.max(0, m.photos.length - 1));
          _pages = PageController(initialPage: _index);
          _galleryVersion++;
          _busy = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    }
  }

  Future<void> _showPhoto(File file) => showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    barrierDismissible: true,
    barrierLabel: tr('Закрыть фотографию'),
    useSafeArea: false,
    builder: (dialogContext) => SizedBox.expand(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(dialogContext).pop(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 8,
              child: SizedBox.expand(
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final currentPhoto = m.photos.isEmpty
        ? null
        : m.photos[math.min(_index, m.photos.length - 1)];
    return AbsorbPointer(
      absorbing: _busy,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tr('Фотографии')} (${m.photos.length}/10)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (widget.editable) ...[
                    IconButton(
                      tooltip: tr('Сделать фото'),
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: _busy || m.photos.length >= 10
                          ? null
                          : () => _pick(ImageSource.camera),
                    ),
                    IconButton(
                      tooltip: tr('Добавить из галереи'),
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: _busy || m.photos.length >= 10
                          ? null
                          : () => _pick(ImageSource.gallery),
                    ),
                  ],
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
              if (m.photos.isEmpty) Text(tr('Фотографии не добавлены')),
              if (m.photos.isNotEmpty) ...[
                SizedBox(
                  height: 280,
                  child: PageView.builder(
                    key: ValueKey(_galleryVersion),
                    controller: _pages,
                    itemCount: m.photos.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final photo = m.photos[i];
                      return ClipRRect(
                        key: ValueKey(photo.filename),
                        borderRadius: BorderRadius.circular(16),
                        child: FutureBuilder<File>(
                          future: PhotoStorage.file(m, photo),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            return GestureDetector(
                              onTap: () => _showPhoto(snapshot.data!),
                              child: Center(
                                child: Image.file(
                                  snapshot.data!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      Text(tr('Фотография недоступна')),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Center(
                  child: Text(
                    '${_index + 1} / ${m.photos.length} · ${tr('Листайте фото свайпом')}',
                  ),
                ),
                Center(
                  child: Text(
                    tr('Нажмите на фото, чтобы увеличить'),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                if (widget.editable)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey(currentPhoto!.filename),
                          initialValue: currentPhoto.caption,
                          maxLength: 32,
                          decoration: InputDecoration(
                            labelText: tr('Подпись к фотографии'),
                          ),
                          onChanged: (value) {
                            currentPhoto.caption = value;
                            WdcStorage.instance.save(m);
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: tr('Удалить фото'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(currentPhoto),
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(currentPhoto!.caption),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<Uint8List> profilePng(WdcMeasurement m) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(2);
  CrossSectionPainter(
    measurement: m,
    showVelocities: true,
  ).paint(canvas, const Size(720, 330));
  final picture = recorder.endRecording();
  final image = await picture.toImage(1440, 660);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<pw.MemoryImage> photoForPdf(File file) async {
  final bytes = await file.readAsBytes();
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    // Decode formats unsupported by the PDF library at full resolution.
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    try {
      return pw.MemoryImage(
        (await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List(),
      );
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }
}

Future<List<int>> pdfBytes(WdcMeasurement m) async {
  final base = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Medium.ttf'),
  );
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/icon/app_icon.png')).buffer.asUint8List(),
  );
  final profile = pw.MemoryImage(await profilePng(m));
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(base: base, bold: bold);
  pw.Widget header(pw.Context context) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        tr('Калькулятор расходов воды · 4.3'),
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.Image(logo, width: 52, height: 42, fit: pw.BoxFit.contain),
    ],
  );
  pw.Widget footer(pw.Context context) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      '${context.pageNumber}',
      style: const pw.TextStyle(fontSize: 9),
    ),
  );
  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
  );
  final characteristics = <List<String>>[
    [tr('Ледостав'), tr(m.iceCover ? tr('Да') : tr('Нет'))],
    [tr('B — Ширина водного сечения, м'), fmtAdaptive(m.width)],
    [tr('ω — Площадь поперечного сечения, м²'), fmtAreaAdaptive(m.area)],
    [tr('hср — Средняя глубина, м'), fmtAdaptive(m.meanDepth)],
    [tr('hmax — Максимальная глубина, м'), fmtAdaptive(m.maxDepth)],
    [tr('χ — Смоченный периметр, м'), fmtAdaptive(m.wettedPerimeter)],
    [tr('R — Гидравлический радиус, м'), fmtAdaptive(m.hydraulicRadius)],
    [
      tr('Uпоп — средняя скорость на поперечном сечении, м/с'),
      _numCell(m.meanFlowVelocity, 6),
    ],
    [
      tr('Средний уровень во время промеров, м'),
      _numCell(m.meanSoundingLevel, 3),
    ],
    [
      tr('Средний уровень во время измерения скоростей, м'),
      _numCell(m.meanVelocityLevel, 3),
    ],
    [tr('Поправка уровня, м'), _numCell(m.levelCorrection, 3)],
    [tr('Коэффициент ЛБ'), _numCell(m.bankCoeffLeft, 2)],
    [tr('Коэффициент ПБ'), _numCell(m.bankCoeffRight, 2)],
    [
      tr('Лопастной диаметр вертушки, см'),
      _numCell(m.rotorDiameter == null ? null : m.rotorDiameter! * 100, 2),
    ],
  ];
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 200,
      header: header,
      footer: footer,
      build: (context) => [
        pw.Text(
          tr('Ведомость расчёта расхода воды'),
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '${m.titleRiver} — ${m.titleSite}',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          measurementTimeZone(m),
          style: const pw.TextStyle(fontSize: 10),
        ),
        ...measurementTimes(m).entries.map(
          (e) => pw.Text(
            '${e.key}: ${e.value}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        pw.Text(
          '${tr('Координаты')}: ${coordinatesText(m)}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '${tr('Расход воды')}: ${_numCell(m.discharge, 6)} ${tr('м³/с')}',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '${tr('Комментарий')}: ${m.comment.trim().isEmpty ? tr('не указан') : m.comment}',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.SizedBox(height: 8),
        pw.Image(profile, width: 539, height: 247, fit: pw.BoxFit.contain),
        pw.NewPage(freeSpace: 355),
        heading(tr('Характеристики створа')),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.2),
          },
          children: [
            for (final row in characteristics)
              pw.TableRow(
                children: [
                  for (final cell in row)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pdfNotation(cell, size: 11),
                    ),
                ],
              ),
          ],
        ),
        if (m.warnings.isNotEmpty) ...[
          heading(tr('Предупреждения')),
          ...m.warnings.map((w) => pw.Bullet(text: tr(w))),
        ],
        heading(tr('Таблица промерных вертикалей')),
        soundingReportTable(m),
      ],
    ),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 200,
      header: header,
      footer: footer,
      build: (_) => velocityReportTables(m),
    ),
  );
  // A dedicated A4 page keeps each complete photo and its caption together.
  for (var i = 0; i < m.photos.length; i++) {
    final photo = m.photos[i];
    final image = await photoForPdf(await PhotoStorage.file(m, photo));
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            header(context),
            heading('${tr('Фотография')} ${i + 1}'),
            pw.Expanded(child: pw.Image(image, fit: pw.BoxFit.contain)),
            pw.SizedBox(height: 8),
            pw.Text(
              photo.caption,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 8),
            footer(context),
          ],
        ),
      ),
    );
  }
  return doc.save();
}
