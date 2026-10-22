part of 'main.dart';

class VelocityScreen extends StatefulWidget {
  const VelocityScreen({super.key, required this.measurement});
  final WdcMeasurement measurement;

  @override
  State<VelocityScreen> createState() => _VelocityScreenState();
}

class _VelocityScreenState extends State<VelocityScreen>
    with SettingsRefresh<VelocityScreen> {
  late WdcMeasurement m;
  final Set<String> _picked = {};
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    m = widget.measurement;
    recalcAll(m, finalCalculation: true);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () async {
      recalcAll(m, finalCalculation: true);
      if (mounted) setState(() {});
      await WdcStorage.instance.save(m);
    });
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    recalcAll(m, finalCalculation: true);
    await WdcStorage.instance.save(m);
  }

  bool get _canAddSpeed =>
      m.levelVelocityStart != null &&
      m.rotorDiameter != null &&
      _picked.isNotEmpty;

  void _addSpeedVerticals() {
    setState(() {
      for (final id in _picked) {
        final v = m.verticals.firstWhere((x) => x.id == id);
        if (canMeasureSpeed44(v)) v.isSpeedVertical = true;
      }
      _picked.clear();
    });
    _saveNow();
  }

  Future<void> _deleteSpeedVertical(VerticalPoint v) async {
    final ok = await confirmDialog(
      context,
      title: tr('Удаление'),
      message: tr(
        'Удалить скоростную вертикаль?\nУдалятся все измеренные на ней скорости, результаты промерных работ сохранятся.',
      ),
    );
    if (!ok) return;
    setState(() {
      v.clearVelocities();
    });
    await _saveNow();
  }

  double? yForVelocityPoint(VerticalPoint v, String key) {
    final h = v.avgDepth;
    final d = m.rotorDiameter;
    if (h == null || d == null) return null;
    switch (key.replaceFirst(RegExp(r'^u'), '')) {
      case 'surface':
        return d / 2 + 0.01;
      case '015':
        return 0.15 * h;
      case '04':
        return 0.4 * h;
      case '05':
        return 0.5 * h;
      case '085':
        return 0.85 * h;
      case '02':
        return 0.2 * h;
      case '06':
        return 0.6 * h;
      case '08':
        return 0.8 * h;
      case 'bottom':
        return h - d / 2 - 0.01;
    }
    return null;
  }

  int recommendedSpeedVerticals() {
    final b = m.width ?? 0;
    if (b < 1) return 1;
    if (b < 3) return 3;
    if (b < 10) return 5;
    return 8;
  }

  String? _validateCalculation() {
    if (m.levelVelocityStart == null ||
        m.levelVelocityEnd == null ||
        m.bankCoeffLeft == null ||
        m.bankCoeffRight == null ||
        m.rotorDiameter == null) {
      return tr('Не все поля заполнены');
    }
    final speed = m.verticals.where((v) => v.isSpeedVertical).toList();
    if (speed.isEmpty) return tr('Добавьте хотя бы одну скоростную вертикаль');
    if (speed.any(
      (v) =>
          v.avgVelocity == null &&
          (!m.geometry44 || (v.avgDepth ?? 0) + (levelDelta(m) ?? 0) > 0),
    )) {
      return tr('Не все скоростные вертикали заполнены');
    }
    return null;
  }

  Future<void> _calculate() async {
    final error = _validateCalculation();
    if (error != null) {
      showSnack(context, error);
      return;
    }
    _saveTimer?.cancel();
    recalcAll(m, finalCalculation: true);
    await WdcStorage.instance.save(m);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(measurement: m, viewOnly: false),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasSpeed = m.verticals.any((v) => v.isSpeedVertical);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await confirmDialog(
          context,
          title: tr('Назад'),
          message: tr(
            'Вернуться на экран «Промерные работы»?\nВведённые данные будут сохранены.',
          ),
        );
        if (ok) {
          await _saveNow();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Измерение скоростей')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: tr('Назад'),
                message: tr(
                  'Вернуться на экран «Промерные работы»?\nВведённые данные будут сохранены.',
                ),
              );
              if (ok) {
                await _saveNow();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
          children: [
            MeasurementComment(key: ValueKey(m.comment), measurement: m),
            MeasurementPhotos(measurement: m, editable: true),
            const SizedBox(height: 18),
            NumField(
              label: tr('Уровень воды на начало измерения скоростей течения'),
              hint: tr('В метрах'),
              initial: m.levelVelocityStart,
              maxLength: 10,
              onChanged: (v) {
                setState(() {
                  m.levelVelocityStart = v == null ? null : roundTo(v, 3);
                });
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NumField(
                    label: tr('Лопастной диаметр вертушки, см'),
                    initial: m.rotorDiameter == null
                        ? null
                        : roundTo(m.rotorDiameter! * 100, 4),
                    hint: tr('В сантиметрах'),
                    maxLength: 10,
                    onChanged: (v) {
                      setState(
                        () => m.rotorDiameter = v == null || v <= 0
                            ? null
                            : roundTo(v / 100, 6),
                      );
                      _scheduleSave();
                    },
                  ),
                ),
                IconButton(
                  tooltip: tr('Справка'),
                  icon: const Icon(Icons.help_outline),
                  onPressed: () =>
                      showInfo44(context, tr('Справка'), tr(rotorHelp44)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StatsCard(m: m),
            IceProfile44(m: m),
            SizedBox(
              height: 320,
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
                        pickedIds: _picked,
                        showVelocities: true,
                        yForVelocityPoint: yForVelocityPoint,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Таблица промерных вертикалей'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(tr('Подсказка')),
                      content: Text(
                        tr(
                          'Чтобы добавить промерную вертикаль в список скоростных, выберите её и нажмите ниже кнопку «Добавить». ЛБ и ПБ выбрать нельзя.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (m.warnings.contains(zeroDepthWarning))
              const Warning44('Промеры с глубиной 0', zeroDepthWarning),
            _shortPromerTable(),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _canAddSpeed
                  ? _addSpeedVerticals
                  : () {
                      if (m.levelVelocityStart == null) {
                        showSnack(
                          context,
                          tr(
                            'Введите уровень воды на начало измерения скоростей',
                          ),
                        );
                      } else if (m.rotorDiameter == null) {
                        showSnack(
                          context,
                          tr('Введите лопастной диаметр вертушки'),
                        );
                      } else {
                        showSnack(
                          context,
                          tr('Выберите промерные вертикали для добавления'),
                        );
                      }
                    },
              child: Text(tr('Добавить')),
            ),
            const SizedBox(height: 8),
            Text(
              '${tr('Рекомендуемое минимальное число скоростных вертикалей')}: ${recommendedSpeedVerticals()}',
            ),
            const SizedBox(height: 18),
            Text(
              tr('Таблица скоростных вертикалей'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: NotationText(tr('Метод расчёта Uср')),
              subtitle: Text(
                presetTitle(m.calculationConfig?.preset ?? 'legacy'),
              ),
              trailing: const Icon(Icons.settings_outlined),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalculationSettingsScreen(
                      config: m.calculationConfig,
                      scope: CalculationScope.measurement,
                      allowReset: true,
                      inherited: m.initialCalculationConfig,
                      onSave: (config) async {
                        final old = m.calculationConfig;
                        m.calculationConfig = config?.copy();
                        try {
                          await _saveNow();
                        } catch (_) {
                          m.calculationConfig = old;
                          recalcAll(m, finalCalculation: true);
                          rethrow;
                        }
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
            _speedTable(),
            if (hasSpeed) ...[
              const SizedBox(height: 12),
              NumField(
                label: tr('Уровень воды на конец измерения скоростей течения'),
                hint: tr('В метрах'),
                initial: m.levelVelocityEnd,
                maxLength: 10,
                onChanged: (v) {
                  setState(() {
                    m.levelVelocityEnd = v == null ? null : roundTo(v, 3);
                  });
                  _scheduleSave();
                },
              ),
            ],
            LevelOptions44(
              m: m,
              onChanged: () {
                setState(() => recalcAll(m, finalCalculation: true));
                _scheduleSave();
              },
            ),
            for (final warning in [
              invalidSlopeWarning,
              drySpeedWarning,
              splitSectionWarning,
            ])
              if (m.warnings.contains(warning))
                Warning44('Расчёт недоступен', warning),
            if (m.levelVelocityEnd != null) ...[
              const SizedBox(height: 16),
              _coeffHelpTable(),
              const SizedBox(height: 10),
              NumField(
                label: tr('Коэффициент для ЛБ'),
                hint: tr('См. таблицу выше'),
                initial: m.bankCoeffLeft,
                maxLength: 5,
                onChanged: (v) {
                  if (v == null || (v >= 0 && v <= 1)) {
                    setState(
                      () => m.bankCoeffLeft = v == null ? null : roundTo(v, 2),
                    );
                    _scheduleSave();
                  }
                },
              ),
              const SizedBox(height: 10),
              NumField(
                label: tr('Коэффициент для ПБ'),
                hint: tr('См. таблицу выше'),
                initial: m.bankCoeffRight,
                maxLength: 5,
                onChanged: (v) {
                  if (v == null || (v >= 0 && v <= 1)) {
                    setState(
                      () => m.bankCoeffRight = v == null ? null : roundTo(v, 2),
                    );
                    _scheduleSave();
                  }
                },
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate),
              label: Text(tr('Рассчитать расход воды')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _shortPromerTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 6,
        columnSpacing: 12,
        columns: [
          DataColumn(label: Text(tr('Берег'))),
          DataColumn(label: Text(tr('Расст., м'))),
          DataColumn(label: Text(tr('Глуб., м'))),
        ],
        rows: m.verticals.map((v) {
          final disabled =
              !canMeasureSpeed44(v) ||
              v.isSpeedVertical ||
              m.levelVelocityStart == null ||
              m.rotorDiameter == null;
          final picked = _picked.contains(v.id);
          return DataRow(
            selected: picked || v.isSpeedVertical,
            color: WidgetStateProperty.resolveWith((_) {
              if (v.isSpeedVertical) {
                return Colors.green.withValues(alpha: 0.12);
              }
              if (picked) return Colors.red.withValues(alpha: 0.12);
              return null;
            }),
            cells: [
              DataCell(Text(bankLabel(v.bank))),
              DataCell(Text(_numCell(v.distance, 3))),
              DataCell(Text(_numCell(v.avgDepth, 3))),
            ],
            onSelectChanged: disabled
                ? null
                : (_) => setState(() {
                    if (picked) {
                      _picked.remove(v.id);
                    } else {
                      _picked.add(v.id);
                    }
                  }),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openVelocity(VerticalPoint v) async {
    await _saveNow();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VelocityEditor(measurement: m, vertical: v),
      ),
    );
    if (mounted) {
      setState(() {
        recalcAll(m, finalCalculation: true);
      });
    }
  }

  Widget _speedTable() {
    final speed = m.verticals.where((v) => v.isSpeedVertical).toList();
    if (speed.isEmpty) {
      return Text(tr('Скоростные вертикали пока не добавлены'));
    }
    final rowHeight = math.max(
      64.0,
      MediaQuery.textScalerOf(context).scale(24) + 28,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: DataTable(
            key: const ValueKey('fixed-distance-column'),
            horizontalMargin: 6,
            columnSpacing: 0,
            headingRowHeight: rowHeight,
            dataRowMinHeight: rowHeight,
            dataRowMaxHeight: rowHeight,
            columns: [DataColumn(label: Text(tr('Расст., м')))],
            rows: speed
                .map(
                  (v) =>
                      DataRow(cells: [DataCell(Text(_numCell(v.distance, 3)))]),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('velocity-horizontal-scroll'),
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: rowHeight,
              dataRowMinHeight: rowHeight,
              dataRowMaxHeight: rowHeight,
              horizontalMargin: 6,
              columnSpacing: 12,
              columns: [
                DataColumn(label: Text(tr('Глуб., м'))),
                DataColumn(label: Text(tr('Скорости'))),
                DataColumn(label: NotationText(tr('Uср, м/с'))),
                const DataColumn(label: Text('')),
              ],
              rows: speed
                  .map(
                    (v) => DataRow(
                      cells: [
                        DataCell(Text(_numCell(v.avgDepth, 3))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _openVelocity(v),
                                child: Text(tr('Ввести')),
                              ),
                              if (v.individualConfig != null)
                                Tooltip(
                                  message: tr('Индивидуальный метод'),
                                  child: const Icon(Icons.tune, size: 18),
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            v.avgVelocity == null
                                ? tr('н/д')
                                : _numCell(v.avgVelocity, 4),
                            style: TextStyle(
                              color: v.avgVelocity == null
                                  ? Colors.grey
                                  : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteSpeedVertical(v),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _coeffHelpTable() {
    final rows = [
      ['0.5', tr('Мёртвое пространство')],
      [
        '0.7',
        tr(
          'Пологий берег с нулевой глубиной на урезе; вблизи границы скопления неподвижной шуги',
        ),
      ],
      [
        '0.8',
        tr('Обрывистый берег или неровная стенка (бут, неотёсанный камень)'),
      ],
      [
        '0.9',
        tr(
          'Гладкая бетонная или сплошь обшитая досками стенка; течение воды поверх льда',
        ),
      ],
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Коэффициент для скоростей на прибрежных вертикалях'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        r[0],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: Text(r[1])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
