part of 'main.dart';

// =============================
// Result screen
// =============================

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.measurement,
    required this.viewOnly,
  });
  final WdcMeasurement measurement;
  final bool viewOnly;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SettingsRefresh<ResultScreen> {
  late WdcMeasurement m;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    m = widget.measurement;
    recalcAll(m, finalCalculation: true);
  }

  Future<void> _reopen() async {
    final ok = await confirmDialog(
      context,
      title: tr('Редактирование'),
      message: tr('Войти в режим редактирования?'),
    );
    if (!ok || !mounted) return;
    reopenMeasurement(m);
    await WdcStorage.instance.save(m);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SoundingScreen(measurement: m)),
    );
  }

  Future<void> _shareCsv() async {
    final f = await WdcStorage.instance.exportCsv(m);
    await shareFiles44([XFile(f.path)], text: tr('CSV расчёта расхода воды'));
  }

  Future<void> _sharePdf() async {
    try {
      final f = await WdcStorage.instance.exportPdf(m);
      await shareFiles44([
        XFile(f.path),
      ], text: tr('PDF-отчёт расчёта расхода воды'));
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          tr(
            'Не удалось создать PDF. Проверьте, что все фотографии доступны и на устройстве есть свободное место.',
          ),
        );
      }
    }
  }

  Future<void> _saveComplete() async {
    if (_saving) return;
    _saving = true;
    final ok = await confirmDialog(
      context,
      title: tr('Сохранение'),
      message: tr('Сохранить и выйти в главное меню?'),
      yesIsPrimary: true,
    );
    if (!ok || !mounted) {
      _saving = false;
      return;
    }
    final close = showWorkProgress(context, tr('Сохраняем измерение…'));
    final wasCompleted = m.completed;
    try {
      m.completed = true;
      await WdcStorage.instance.save(m);
      // Home receives the committed snapshot before navigation reveals it.
      close();
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      m.completed = wasCompleted;
      close();
      if (mounted) {
        showSnack(
          context,
          tr('Не удалось сохранить измерение. Попробуйте ещё раз.'),
        );
      }
    } finally {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final speedRows = m.verticals
        .where((v) => v.isSpeedVertical || v.partialDischarge != null)
        .toList();
    return PopScope(
      canPop: widget.viewOnly,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || widget.viewOnly) return;
        final ok = await confirmDialog(
          context,
          title: tr('Назад'),
          message: tr(
            'Вернуться на экран «Измерение скоростей течения»?\nРасчёт расхода потребуется выполнить заново.\nВведённый комментарий сохранится.',
          ),
        );
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Расход воды')),
          leading: widget.viewOnly
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: tr('Назад'),
                      message: tr(
                        'Вернуться на экран «Измерение скоростей течения»?\nРасчёт расхода потребуется выполнить заново.\nВведённый комментарий сохранится.',
                      ),
                    );
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                ),
          actions: [
            if (widget.viewOnly)
              IconButton(
                tooltip: tr('Редактировать измерение'),
                onPressed: _reopen,
                icon: const Icon(Icons.edit_note),
              ),
            IconButton(
              tooltip: tr('Поделиться CSV'),
              onPressed: _shareCsv,
              icon: const CsvExportIcon(),
            ),
            IconButton(
              tooltip: tr('Экспорт PDF'),
              onPressed: _sharePdf,
              icon: const PdfExportIcon(),
            ),
            if (!widget.viewOnly)
              IconButton(
                tooltip: tr('Сохранить'),
                onPressed: _saveComplete,
                icon: const Icon(Icons.save),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(measurementTimeZone(m)),
                    ...measurementTimes(
                      m,
                    ).entries.map((e) => Text('${e.key}: ${e.value}')),
                    Text(
                      '${m.titleRiver} — ${m.titleSite}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m.discharge == null
                          ? tr('Расход не определён')
                          : '${tr('Расход воды')}: ${_numCell(m.discharge, 6)} ${tr('м³/с')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MeasurementComment(measurement: m),
                    MeasurementPhotos(measurement: m, editable: true),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('${tr('Координаты')}: ${coordinatesText(m)}'),
                ),
                IconButton(
                  tooltip: tr('Скопировать координаты'),
                  icon: const Icon(Icons.copy),
                  onPressed: m.latitude == null || m.longitude == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: coordinatesText(m)),
                          );
                          if (context.mounted) {
                            showSnack(context, tr('Координаты скопированы'));
                          }
                        },
                ),
              ],
            ),
            Text(
              '${tr('Уровень воды во время промерных работ')}: ${_numCell(m.meanSoundingLevel, 3)} ${tr('м')}',
            ),
            Text(
              '${tr('Уровень воды во время измерения скоростей')}: ${_numCell(m.meanVelocityLevel, 3)} ${tr('м')}',
            ),
            Text(
              '${tr('Изменение уровня')}: ${_numCell(m.levelCorrection, 3)} ${tr('м')}',
            ),
            Text('${tr('Коэффициент ЛБ')}: ${_numCell(m.bankCoeffLeft, 2)}'),
            Text('${tr('Коэффициент ПБ')}: ${_numCell(m.bankCoeffRight, 2)}'),
            if (m.geometry44 && (m.levelCorrection ?? 0) > 0)
              Text(
                '${bankLabel('ЛБ')}: ${appliedBankMode45(m, true)}; ${bankLabel('ПБ')}: ${appliedBankMode45(m, false)}',
              ),
            Text(
              '${tr('Лопастной диаметр вертушки')}: ${_numCell(m.rotorDiameter == null ? null : m.rotorDiameter! * 100, 2)} ${tr('см')}',
            ),
            const SizedBox(height: 12),
            StatsCard(m: m),
            IceProfile44(m: m),
            for (final warning in m.warnings)
              Warning44('Предупреждение', warning),
            SizedBox(
              height: 340,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 8,
                    child: CustomPaint(
                      painter: CrossSectionPainter(
                        measurement: m,
                        dark: Theme.of(context).brightness == Brightness.dark,
                        showVelocities: true,
                        showDischarges: false,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Таблица промерных вертикалей'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            resultSoundingTable(m.verticals, showIce: m.iceCover),
            const SizedBox(height: 16),
            Text(
              tr('Таблица скоростных вертикалей'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            resultVelocityTable(context, speedRows),
          ],
        ),
      ),
    );
  }
}
