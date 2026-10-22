part of 'main.dart';

// =============================
// Sounding screen
// =============================

class SoundingScreen extends StatefulWidget {
  const SoundingScreen({super.key, required this.measurement});
  final WdcMeasurement measurement;

  @override
  State<SoundingScreen> createState() => _SoundingScreenState();
}

class _SoundingScreenState extends State<SoundingScreen>
    with SettingsRefresh<SoundingScreen> {
  late WdcMeasurement m;
  Timer? _saveTimer;
  String _startBank = 'ЛБ';
  bool _addingSecondBank = false;
  bool _centimetres = false;
  String get _unit => _centimetres ? tr('см') : tr('м');
  double? _displayLength(double? value) =>
      value == null ? null : roundTo(value * (_centimetres ? 100 : 1), 3);
  double _metres(double value) => roundTo(value / (_centimetres ? 100 : 1), 3);

  void _recordInput(double? value) {
    if (value == null) return;
    recordSoundingInput(m);
    _scheduleSave();
  }

  void _changeUnits(bool centimetres) {
    if (_centimetres == centimetres) return;
    // Convert drafts as well as existing rows; switching units is not a measurement.
    final factor = centimetres ? 100.0 : 0.01;
    setState(() {
      for (final controller in [
        _distanceC,
        _depthC,
        _bankDistanceC,
        _bankDepthC,
      ]) {
        final value = parseNumRu(controller.text);
        if (value != null) controller.text = inputNumber(value * factor);
      }
      _centimetres = centimetres;
    });
  }

  final _distanceFocus = FocusNode();
  final _bankDistanceC = TextEditingController();
  final _bankDepthC = TextEditingController();
  final _distanceC = TextEditingController();
  final _depthC = TextEditingController();
  final _bottomC = TextEditingController();
  final _iceC = TextEditingController();
  final _bankBottomC = TextEditingController();
  final _bankIceC = TextEditingController();

  @override
  void initState() {
    super.initState();
    m = widget.measurement;
    m.geometry44 = true;
    recalcAll(m);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _distanceFocus.dispose();
    _bankDistanceC.dispose();
    _bankDepthC.dispose();
    _distanceC.dispose();
    _depthC.dispose();
    _bottomC.dispose();
    _iceC.dispose();
    _bankBottomC.dispose();
    _bankIceC.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      recalcAll(m);
      WdcStorage.instance.save(m);
    });
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    recalcAll(m);
    await WdcStorage.instance.save(m);
  }

  Future<void> _updateGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        if (mounted) showSnack(context, tr('Нет разрешения на геолокацию'));
        return;
      }
      final pos = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 8),
      );
      setState(() {
        m.latitude = roundTo(pos.latitude, 8);
        m.longitude = roundTo(pos.longitude, 8);
      });
      await _saveNow();
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          tr(
            'Координаты не получены. Их можно ввести вручную или обновить позже',
          ),
        );
      }
    }
  }

  bool _distanceExists(double d) => m.verticals.any(
    (v) => v.distance != null && (v.distance! - d).abs() < 0.0005,
  );

  Future<void> _addVertical({bool secondBank = false}) async {
    final distanceC = secondBank ? _bankDistanceC : _distanceC;
    final depthC = secondBank ? _bankDepthC : _depthC;
    final distance = parseNumRu(distanceC.text);
    final depth = parseNumRu(depthC.text);
    final bottomC = secondBank ? _bankBottomC : _bottomC;
    final iceC = secondBank ? _bankIceC : _iceC;
    final ice = parseNumRu(iceC.text);
    if (distance == null ||
        depth == null ||
        depth < 0 ||
        (m.iceCover &&
            iceC.text.trim().isNotEmpty &&
            (ice == null || !ice.isFinite || ice < 0))) {
      return;
    }
    final dd = _metres(distance);
    if (_distanceExists(dd)) {
      showSnack(
        context,
        tr('На введённом расстоянии уже есть промерная вертикаль'),
      );
      return;
    }

    String? bank;
    if (!m.hasLeftBank && !m.hasRightBank) {
      bank = _startBank;
    } else if (secondBank) {
      bank = m.hasLeftBank ? 'ПБ' : 'ЛБ';
    }

    setState(() {
      recordSoundingInput(m);
      m.verticals.add(
        VerticalPoint(
          id: uid(),
          bank: bank,
          distance: dd,
          depth1: _metres(depth),
          bottomType: bottomC.text.trim(),
          iceThicknessCm: m.iceCover && ice != null ? roundTo(ice, 2) : null,
          depth1At: measurementNow(m),
        ),
      );
      if (secondBank) _addingSecondBank = false;
      distanceC.clear();
      depthC.clear();
      bottomC.clear();
      iceC.clear();
    });
    await _saveNow();
    if (mounted && !secondBank) {
      _distanceFocus.requestFocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }

  Future<void> _deleteVertical(VerticalPoint v) async {
    if (v.bank != null) return;
    final ok = await confirmDialog(
      context,
      title: tr('Удаление'),
      message: tr(
        'Удалить промерную вертикаль?\nУдалятся и все измеренные на ней скорости.',
      ),
    );
    if (!ok) return;
    setState(() {
      m.verticals.removeWhere((x) => x.id == v.id);
    });
    await _saveNow();
  }

  Future<void> _editBankDistance(VerticalPoint v) async {
    final d = await editNumberDialog(
      context,
      title: '${tr('Расстояние')} ${bankLabel(v.bank)}, $_unit',
      initial: _displayLength(v.distance),
    );
    if (d == null || d.isNaN) return;
    final rd = _metres(d);
    if (rd == v.distance) return;
    final duplicates = m.verticals.where(
      (x) =>
          x.id != v.id &&
          x.distance != null &&
          (x.distance! - rd).abs() < 0.0005,
    );
    if (duplicates.isNotEmpty) {
      if (mounted) {
        showSnack(context, tr('Есть промерные вертикали на одном расстоянии'));
      }
      return;
    }
    setState(() {
      v.distance = rd;
      recordSoundingInput(m);
    });
    await _saveNow();
  }

  String? _validateBeforeVelocity() {
    if (m.river.trim().isEmpty ||
        m.site.trim().isEmpty ||
        m.levelSoundingStart == null ||
        m.levelSoundingEnd == null ||
        !m.hasBothBanks) {
      return tr('Не все обязательные поля заполнены');
    }
    final distances = <double>{};
    for (final v in m.verticals) {
      if (v.distance == null) return tr('Не все обязательные поля заполнены');
      final key = roundTo(v.distance!, 3);
      if (distances.contains(key)) {
        return tr('Есть промерные вертикали на одном расстоянии');
      }
      distances.add(key);
      if (v.depth1 == null && v.depth2 == null) {
        return tr('Есть промерные вертикали без глубины');
      }
    }
    final lb = m.leftBank;
    final rb = m.rightBank;
    if (lb?.distance == null ||
        rb?.distance == null ||
        lb!.distance == rb!.distance) {
      return tr('ЛБ и ПБ находятся не по берегам');
    }
    final minD = m.verticals.map((v) => v.distance!).reduce(math.min);
    final maxD = m.verticals.map((v) => v.distance!).reduce(math.max);
    final banksExtreme =
        (lb.distance == minD && rb.distance == maxD) ||
        (lb.distance == maxD && rb.distance == minD);
    if (!banksExtreme) return tr('ЛБ и ПБ находятся не по берегам');
    return null;
  }

  Future<void> _goVelocity() async {
    final error = _validateBeforeVelocity();
    if (error != null) {
      showSnack(context, error);
      return;
    }
    await _saveNow();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VelocityScreen(measurement: m)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _entryReady(false);
    final needSecondBank =
        (m.hasLeftBank ^ m.hasRightBank) && !_addingSecondBank;
    final secondBankReady = m.hasBothBanks;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final ok = await confirmDialog(
          context,
          title: tr('Выход'),
          message: tr(
            'Выйти на главный экран (все введённые данные сохранятся)?',
          ),
        );
        if (ok) {
          await _saveNow();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Промерные работы')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: tr('Выход'),
                message: tr(
                  'Выйти на главный экран (все введённые данные сохранятся)?',
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          children: [
            Text(measurementTimeZone(m)),
            Text(
              '${tr('Дата и время начала промерных работ')} — ${humanFromIso(m.levelSoundingStartAt).isEmpty ? tr('не начаты') : humanFromIso(m.levelSoundingStartAt)}',
            ),
            MeasurementComment(key: ValueKey(m.comment), measurement: m),
            MeasurementPhotos(measurement: m, editable: true),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: m.river,
              decoration: InputDecoration(labelText: tr('Название реки')),
              inputFormatters: nameFormatters,
              onChanged: (v) {
                m.river = v.trim();
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: m.site,
              decoration: InputDecoration(labelText: tr('Название створа')),
              inputFormatters: nameFormatters,
              onChanged: (v) {
                m.site = v.trim();
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey('measurement-project'),
              initialValue: m.project,
              decoration: InputDecoration(
                labelText: tr('Проект'),
                hintText: tr('Опционально'),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(128)],
              onChanged: (value) {
                m.project = value.trim();
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            NumField(
              label: tr('Уровень воды на начало промеров, м'),
              hint: tr('В метрах'),
              initial: m.levelSoundingStart,
              maxLength: 10,
              onChanged: (v) {
                m.levelSoundingStart = v == null ? null : roundTo(v, 3);
                _scheduleSave();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NumField(
                    label: tr('Широта, °'),
                    initial: m.latitude,
                    maxLength: 14,
                    onChanged: (v) {
                      if (v == null || (v >= -90 && v <= 90)) {
                        m.latitude = v == null ? null : roundTo(v, 8);
                        _scheduleSave();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NumField(
                    label: tr('Долгота, °'),
                    initial: m.longitude,
                    maxLength: 14,
                    onChanged: (v) {
                      if (v == null || (v >= -180 && v <= 180)) {
                        m.longitude = v == null ? null : roundTo(v, 8);
                        _scheduleSave();
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: _updateGps,
                  icon: const Icon(Icons.my_location),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(tr('Рекомендуется не менее 20 промерных вертикалей')),
            if (m.calculationConfig != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: conditionTitle(context, ice: true),
                value: m.iceCover,
                onChanged: (value) {
                  setState(() {
                    m.iceCover = value ?? false;
                    recalcAll(m);
                  });
                  _scheduleSave();
                },
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(child: Text(tr('Режим ввода'))),
                const SizedBox(width: 16),
                Text(tr('м')),
                Switch(
                  key: const ValueKey('sounding-units'),
                  value: _centimetres,
                  onChanged: _changeUnits,
                ),
                Text(tr('см')),
              ],
            ),
            const SizedBox(height: 18),
            if (!m.hasLeftBank && !m.hasRightBank) ...[
              Text(
                tr('Укажите начальный берег:'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ЛБ', label: Text(bankLabel('ЛБ'))),
                  ButtonSegment(value: 'ПБ', label: Text(bankLabel('ПБ'))),
                ],
                selected: {_startBank},
                onSelectionChanged: (s) => setState(() => _startBank = s.first),
              ),
            ] else ...[
              Text(
                tr('Добавьте промерные вертикали:'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 10),
            _entryFields(false, canAdd),
            if (needSecondBank) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => setState(() => _addingSecondBank = true),
                child: Text(
                  '${tr('Указать второй берег')} (${bankLabel(m.hasLeftBank ? 'ПБ' : 'ЛБ')})',
                ),
              ),
            ],
            if (_addingSecondBank && !m.hasBothBanks) ...[
              const SizedBox(height: 12),
              Text(
                '${tr('Укажите второй берег')} (${bankLabel(m.hasLeftBank ? 'ПБ' : 'ЛБ')}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _entryFields(true, _entryReady(true)),
            ],
            if (secondBankReady) ...[
              const SizedBox(height: 10),
              NumField(
                label: tr('Уровень воды на конец промеров, м'),
                hint: tr('В метрах'),
                initial: m.levelSoundingEnd,
                maxLength: 10,
                onChanged: (v) {
                  m.levelSoundingEnd = v == null ? null : roundTo(v, 3);
                  _scheduleSave();
                },
              ),
            ],
            const SizedBox(height: 18),
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
                          'Выполнять обратный ход промеров необязательно. Расчёт средних глубин на вертикалях произойдёт автоматически при переходе к измерению скоростей.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _soundingTable(),
            const SizedBox(height: 8),
            Text(
              tr('Перемещайте таблицу в стороны👉'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('Нажмите на значение глубины, чтобы его изменить☝️'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _goVelocity,
              icon: const Icon(Icons.arrow_forward),
              label: Text(tr('Перейти к измерению скоростей')),
            ),
          ),
        ),
      ),
    );
  }

  bool _entryReady(bool bank) {
    final distance = parseNumRu((bank ? _bankDistanceC : _distanceC).text);
    final depth = parseNumRu((bank ? _bankDepthC : _depthC).text);
    final iceText = (bank ? _bankIceC : _iceC).text.trim();
    final ice = parseNumRu(iceText);
    return distance != null &&
        depth != null &&
        depth >= 0 &&
        (!m.iceCover ||
            iceText.isEmpty ||
            (ice != null && ice.isFinite && ice >= 0));
  }

  Widget _entryFields(bool bank, bool ready) {
    final prefix = bank ? 'second-bank' : 'sounding';
    Widget number(
      String suffix,
      TextEditingController controller,
      String label, {
      bool length = true,
    }) => TextField(
      key: ValueKey('$prefix-$suffix'),
      focusNode: !bank && suffix == 'distance' ? _distanceFocus : null,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [numericFormatter, LengthLimitingTextInputFormatter(12)],
      decoration: InputDecoration(
        labelText: label,
        hintText: length
            ? tr(_centimetres ? 'В сантиметрах' : 'В метрах')
            : tr('В сантиметрах'),
      ),
      onChanged: (text) => setState(() => _recordInput(parseNumRu(text))),
      onEditingComplete: () {
        if (!length) {
          final n = parseNumRu(controller.text);
          if (n != null && n >= 0) controller.text = inputNumber(roundTo(n, 2));
        }
        FocusScope.of(context).nextFocus();
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: number(
                'distance',
                bank ? _bankDistanceC : _distanceC,
                '${tr('Расст.')}, $_unit',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: number(
                'depth',
                bank ? _bankDepthC : _depthC,
                '${tr('Глуб₁.')}, $_unit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: ValueKey('$prefix-bottom'),
                controller: bank ? _bankBottomC : _bottomC,
                inputFormatters: [LengthLimitingTextInputFormatter(32)],
                decoration: InputDecoration(
                  labelText: tr('Тип дна'),
                  hintText: tr('Необязательно'),
                ),
              ),
            ),
            if (m.iceCover) ...[
              const SizedBox(width: 8),
              Expanded(
                child: number(
                  'ice',
                  bank ? _bankIceC : _iceC,
                  tr('Толщина льда, см'),
                  length: false,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        FilledButton(
          key: ValueKey(bank ? 'add-second-bank' : 'add-sounding'),
          onPressed: ready ? () => _addVertical(secondBank: bank) : null,
          child: Text(tr('Добавить')),
        ),
      ],
    );
  }

  Future<void> _editDepth44(VerticalPoint v, bool second) async {
    final old = second ? v.depth2 : v.depth1;
    final value = await editNumberDialog(
      context,
      title: '${tr(second ? 'Глубина 2' : 'Глубина 1')}, $_unit',
      initial: _displayLength(old),
      allowEmpty: second,
      beforeSave: (value) async {
        if (value != null && value < 0) return false;
        final next = value == null ? null : _metres(value);
        if (next == old ||
            !v.velocityPoints.values.any((p) => p.value != null)) {
          return true;
        }
        return confirmDialog(
          context,
          title: tr('Изменить глубину на скоростной вертикали?'),
          message: tr(
            'Вы пытаетесь изменить глубину на скоростной вертикали с введёнными скоростями. Эти скорости будут удалены, если вы нажмёте «Да».',
          ),
        );
      },
    );
    if (value != null && (value.isNaN || value < 0)) return;
    if (value == null && !second) return;
    final next = value == null ? null : _metres(value);
    if (next == old || !mounted) return;
    if (!mounted) return;
    setState(() => changeDepth44(m, v, next, second: second, confirmed: true));
    await _saveNow();
  }

  Widget _soundingTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 6,
        columnSpacing: 12,
        columns: [
          DataColumn(label: Text(tr('Берег'))),
          DataColumn(label: Text('${tr('Расст.')}, $_unit')),
          DataColumn(label: Text('${tr('Глуб₁.')}, $_unit')),
          DataColumn(label: Text('${tr('Глуб₂.')}, $_unit')),
          DataColumn(label: Text(tr('Тип дна'))),
          if (m.iceCover) DataColumn(label: Text(tr('Толщина льда, см'))),
          const DataColumn(label: Text('')),
        ],
        rows: m.verticals.map((v) {
          return DataRow(
            cells: [
              DataCell(Text(bankLabel(v.bank))),
              DataCell(
                Text(
                  _numCell(_displayLength(v.distance), _centimetres ? 1 : 3),
                ),
              ),
              DataCell(
                Text(
                  v.depth1 == null
                      ? tr('н/д')
                      : _numCell(
                          _displayLength(v.depth1),
                          _centimetres ? 1 : 3,
                        ),
                  style: TextStyle(
                    color: v.depth1 == null
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onSurface,
                    fontStyle: v.depth1 == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                onTap: () => _editDepth44(v, false),
              ),
              DataCell(
                Text(
                  v.depth2 == null
                      ? tr('н/д')
                      : _numCell(
                          _displayLength(v.depth2),
                          _centimetres ? 1 : 3,
                        ),
                  style: TextStyle(
                    color: v.depth2 == null
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onSurface,
                    fontStyle: v.depth2 == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                onTap: () => _editDepth44(v, true),
              ),
              DataCell(
                Text(
                  v.bottomType.isEmpty ? tr('н/д') : v.bottomType,
                  style: TextStyle(
                    color: v.bottomType.isEmpty
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onSurface,
                    fontStyle: v.bottomType.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                onTap: () async {
                  final value = await editTextDialog(
                    context,
                    title: tr('Тип дна'),
                    initial: v.bottomType,
                    maxLength: 32,
                  );
                  if (value == null) return;
                  setState(() => v.bottomType = value);
                  await _saveNow();
                },
              ),
              if (m.iceCover)
                DataCell(
                  Text(
                    v.iceThicknessCm == null
                        ? tr('н/д')
                        : _numCell(v.iceThicknessCm, 2),
                    style: v.iceThicknessCm == null
                        ? const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          )
                        : null,
                  ),
                  onTap: () async {
                    final value = await editNumberDialog(
                      context,
                      title: tr('Толщина льда, см'),
                      initial: v.iceThicknessCm,
                      allowEmpty: true,
                    );
                    if (!mounted ||
                        (value != null && (value.isNaN || value < 0))) {
                      return;
                    }
                    setState(
                      () => v.iceThicknessCm = value == null
                          ? null
                          : roundTo(value, 2),
                    );
                    await _saveNow();
                  },
                ),
              DataCell(
                v.bank == null
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteVertical(v),
                      )
                    : IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editBankDistance(v),
                      ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
