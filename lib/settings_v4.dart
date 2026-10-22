part of 'main.dart';

mixin SettingsRefresh<T extends StatefulWidget> on State<T> {
  void _settingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    AppSettings.revision.addListener(_settingsChanged);
  }

  @override
  void dispose() {
    AppSettings.revision.removeListener(_settingsChanged);
    super.dispose();
  }
}

class AppSettings {
  AppSettings({
    this.language = 'system',
    this.theme = 'system',
    this.autoGps = true,
    CalculationConfig? defaults,
  }) : defaults = defaults ?? CalculationConfig();
  String language;
  String theme;
  bool autoGps;
  CalculationConfig defaults;
  static AppSettings current = AppSettings();
  static final revision = ValueNotifier<int>(0);
  Map<String, dynamic> toJson() => {
    'language': language,
    'theme': theme,
    'autoGps': autoGps,
    'defaults': defaults.toJson(),
  };
  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    language: json['language'] as String? ?? 'system',
    theme: json['theme'] as String? ?? 'system',
    autoGps: json['autoGps'] as bool? ?? true,
    defaults: CalculationConfig.fromJson(
      json['defaults'] as Map<String, dynamic>,
    ),
  );
  AppSettings copy() => AppSettings.fromJson(toJson());
  static Future<File> file() async => File(
    '${(await getApplicationDocumentsDirectory()).path}/wdc_settings_v4.json',
  );
  static Future<void> load() async {
    try {
      final f = await file();
      if (await f.exists()) {
        current = AppSettings.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      /* Keep the unreadable settings file; measurement files are independent. */
    }
  }

  Future<void> save() async {
    final snapshot = copy();
    final f = await file();
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
    await tmp.rename(f.path);
    current = snapshot;
    revision.value++;
  }
}

String presetTitle(String preset) => tr(switch (preset) {
  'wmo' => 'ВМО № 168',
  'mi' => 'МИ 1759-87',
  'combined' => 'Комбинированный',
  'custom0' => 'Пользовательский I',
  'custom1' => 'Пользовательский II',
  'custom2' => 'Пользовательский III',
  _ => 'Прежний алгоритм',
});
String methodTitle(String method) => tr(switch (method) {
  'six' || 'sixSpecial' => 'по 6 точкам',
  'five' => 'по 5 точкам',
  'three' => 'по 3 точкам',
  'two' => 'по 2 точкам',
  'one06' => 'по точке на 0.6h',
  'one02' => 'по точке на 0.2h',
  'oneSurface' => 'по точке на пов-ти',
  'threeSpecial' => 'по 3 точкам',
  'twoSpecial' => 'по 2 точкам',
  'oneSpecial' => 'по точке на 0.5h',
  _ => 'Прежний алгоритм',
});
String velocityTitle(String key) => switch (key) {
  'surface' => tr('Uпов'),
  'bottom' => tr('Uдно'),
  _ => 'U0.${key.substring(1)}h',
};

Future<bool> discardDraft(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Выйти без сохранения?')),
        content: Text(tr('Изменения настроек будут отменены.')),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Нет')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Да')),
          ),
        ],
      ),
    ) ??
    false;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SettingsRefresh<SettingsScreen> {
  late AppSettings draft = AppSettings.current.copy();
  late String saved = jsonEncode(draft.toJson());
  @override
  void dispose() {
    previewTheme44 = null;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppSettings.revision.value++,
    );
    super.dispose();
  }

  final storage = WdcStorage.instance;
  bool _transferring = false;
  Future<void> _importKrv() async {
    if (_transferring) return;
    setState(() => _transferring = true);
    KrvImportPlan? plan;
    Directory? incoming;
    VoidCallback? close;
    try {
      // Android document providers may expose a custom extension as octet-stream.
      // Validate the actual archive, rather than hiding it using a MIME filter.
      final selected = await fs.openFile();
      if (selected == null || !mounted) return;
      // Android may return a content URI ending in a document ID, not the
      // display filename. Recognize KRV by its validated manifest and contents.
      if (await selected.length() >
          KrvTransfer.maxTotal + KrvTransfer.maxManifest) {
        throw const KrvException(
          'Архив слишком большой. Выберите меньше измерений.',
        );
      }
      if (!mounted) return;
      close = showWorkProgress(context, tr('Проверяем архив…'));
      await storage.flush();
      final base = (await storage._baseDir).path;
      final temp = (await getTemporaryDirectory()).path;
      incoming = await Directory(temp).createTemp('krv-incoming-');
      final path = '${incoming.path}/input.krv';
      await selected.saveTo(path);
      plan = await KrvTransfer.inspectInBackground(path, base, temp);
      close();
      close = null;
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => KrvSummaryDialog(plan: plan!),
      );
      if (accepted != true || !mounted) return;
      close = showWorkProgress(context, tr('Добавляем измерения…'));
      final approved = plan;
      await KrvTransfer.commitInBackground(approved, base);
      close();
      close = null;
      if (mounted) {
        showSnack(
          context,
          '${tr('Добавлено измерений')}: ${approved.records.length}',
        );
      }
    } catch (e) {
      close?.call();
      close = null;
      if (mounted) {
        showSnack(
          context,
          e is KrvException
              ? tr(e.message)
              : tr('Импорт не выполнен. Исходные измерения сохранены.'),
        );
      }
    } finally {
      close?.call();
      try {
        await plan?.dispose();
        if (incoming != null && await incoming.exists()) {
          await incoming.delete(recursive: true);
        }
      } on FileSystemException {
        /* Temporary files are not measurement data. */
      }
      if (mounted) setState(() => _transferring = false);
    }
  }

  bool saving = false;
  bool get dirty => saved != jsonEncode(draft.toJson());
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop &&
          !saving &&
          await discardDraft(context) &&
          context.mounted) {
        setState(() => saved = jsonEncode(draft.toJson()));
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: Text(tr('Настройки'))),
      body: AbsorbPointer(
        absorbing: saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 112,
                height: 112,
              ),
            ),
            Text(
              tr('Калькулятор расходов воды 4.6'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: draft.language,
              decoration: InputDecoration(labelText: tr('Язык')),
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(tr('Как в системе')),
                ),
                const DropdownMenuItem(value: 'ru', child: Text('Русский')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) => setState(() => draft.language = value!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('theme-mode'),
              initialValue: draft.theme,
              decoration: InputDecoration(labelText: tr('Тема')),
              items: [
                for (final entry in {
                  'system': 'Как в системе',
                  'light': 'Светлая',
                  'dark': 'Тёмная',
                }.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(tr(entry.value)),
                  ),
              ],
              onChanged: (value) {
                setState(() => draft.theme = value!);
                previewTheme44 = value;
                AppSettings.revision.value++;
              },
            ),
            ListTile(
              key: const ValueKey('import-krv'),
              contentPadding: EdgeInsets.zero,
              title: Text(tr('Импортировать файл .krv')),
              trailing: const Icon(Icons.move_to_inbox_outlined),
              onTap: _transferring ? null : _importKrv,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr('Получать координаты при создании нового измерения'),
              ),
              value: draft.autoGps,
              onChanged: (value) => setState(() => draft.autoGps = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: NotationText(tr('Метод расчёта Uср')),
              subtitle: Text(presetTitle(draft.defaults.preset)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalculationSettingsScreen(
                      config: draft.defaults,
                      inherited: CalculationConfig(),
                      allowReset: true,
                      onSave: (value) async {
                        setState(() => draft.defaults = value!.copy());
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: dirty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            await draft.save();
                            if (mounted) {
                              setState(
                                () => saved = jsonEncode(draft.toJson()),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              showSnack(
                                context,
                                tr('Не удалось сохранить настройки'),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  child: Text(tr('Сохранить')),
                ),
              ),
            )
          : null,
    ),
  );
}

class CalculationSettingsScreen extends StatefulWidget {
  const CalculationSettingsScreen({
    super.key,
    required this.config,
    required this.onSave,
    this.inherited,
    this.allowReset = false,
    this.scope = CalculationScope.application,
  });
  final CalculationConfig? config;
  final CalculationConfig? inherited;
  final bool allowReset;
  final CalculationScope scope;
  final Future<void> Function(CalculationConfig?) onSave;
  @override
  State<CalculationSettingsScreen> createState() =>
      _CalculationSettingsScreenState();
}

class _CalculationSettingsScreenState extends State<CalculationSettingsScreen>
    with SettingsRefresh<CalculationSettingsScreen> {
  late CalculationConfig? draft =
      (widget.config ??
              (widget.scope == CalculationScope.vertical
                  ? widget.inherited
                  : null))
          ?.copy();
  bool resetRequested = false;
  CalculationConfig? beforeReset;
  void toggleReset(bool value) {
    setState(() {
      if (value) {
        beforeReset = draft?.copy();
        draft = widget.inherited?.copy();
      } else {
        draft = beforeReset?.copy();
      }
      resetRequested = value;
    });
  }

  Widget resetControl() => CheckboxListTile(
    key: const ValueKey('reset-calculation'),
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(
      tr(switch (widget.scope) {
        CalculationScope.application => 'Вернуть по умолчанию для приложения',
        CalculationScope.measurement =>
          'Вернуть по умолчанию для данного расчёта',
        CalculationScope.vertical =>
          'Вернуть по умолчанию для всех вертикалей в данном расчёте',
      }),
    ),
    value: resetRequested,
    onChanged: (value) => toggleReset(value ?? false),
  );
  late String saved = jsonEncode(draft?.toJson());
  bool saving = false;
  bool get dirty => resetRequested || saved != jsonEncode(draft?.toJson());
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop &&
          !saving &&
          await discardDraft(context) &&
          context.mounted) {
        setState(() {
          resetRequested = false;
          saved = jsonEncode(draft?.toJson());
        });
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: NotationText(tr('Метод расчёта Uср'))),
      body: AbsorbPointer(
        absorbing: saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (draft == null) ...[
              Text(
                tr(
                  'Прежний алгоритм сохранён. Результаты старого измерения не изменены.',
                ),
              ),
              FilledButton(
                onPressed: resetRequested
                    ? null
                    : () => setState(
                        () => draft = (widget.inherited ?? CalculationConfig())
                            .copy(),
                      ),
                child: Text(tr('Выбрать метод расчёта')),
              ),
              if (widget.allowReset) resetControl(),
            ] else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('preset-${draft!.preset}-$resetRequested'),
                initialValue: draft!.preset,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('Набор коэффициентов'),
                ),
                items:
                    ['wmo', 'mi', 'combined', 'custom0', 'custom1', 'custom2']
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(presetTitle(p)),
                          ),
                        )
                        .toList(),
                onChanged: resetRequested
                    ? null
                    : (value) => setState(() => draft!.preset = value!),
              ),
              if (widget.allowReset) resetControl(),
              const SizedBox(height: 12),
              calculationHelp46(widget.scope),
              const SizedBox(height: 12),
              Text(
                tr('Обычные условия'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _table(ordinaryMethods46, [
                'surface',
                '02',
                '04',
                '06',
                '08',
                'bottom',
              ]),
              ..._formulas(ordinaryMethods46),
              const SizedBox(height: 20),
              Text(
                tr('Ледовые явления / растительность'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _table(specialMethods46, velocityKeys),
              ..._formulas(specialMethods46),
              const SizedBox(height: 12),
              Text(
                tr(
                  draft!.isCustom
                      ? 'Нажмите на коэффициент k для его изменения'
                      : 'Коэффициенты этого набора доступны только для просмотра.',
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: dirty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            await widget.onSave(
                              resetRequested &&
                                      widget.scope == CalculationScope.vertical
                                  ? null
                                  : draft?.copy(),
                            );
                            resetRequested = false;
                            if (mounted) {
                              setState(
                                () => saved = jsonEncode(draft?.toJson()),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              showSnack(
                                context,
                                tr('Не удалось сохранить настройки'),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  child: Text(tr('Сохранить')),
                ),
              ),
            )
          : null,
    ),
  );
  List<Widget> _formulas(List<String> methods) => [
    const SizedBox(height: 10),
    for (final method in methods)
      if (draft!.weights[method] != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: NotationText(
            '${methodTitle(method)}: ${tr('Uср')} = ${weightsFormula46(draft!.weights[method]!)}',
            keepSymbolsTogether: true,
          ),
        ),
  ];

  Widget _table(List<String> methods, List<String> keys) {
    final rowHeight = math.max(
      72.0,
      MediaQuery.textScalerOf(context).scale(32) + 24,
    );
    DataTable table(List<DataColumn> columns, List<DataRow> rows) => DataTable(
      horizontalMargin: 6,
      columnSpacing: 12,
      headingRowHeight: rowHeight,
      dataRowMinHeight: rowHeight,
      dataRowMaxHeight: rowHeight,
      columns: columns,
      rows: rows,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        table(
          [DataColumn(label: Text(tr('Метод')))],
          methods
              .map(
                (method) => DataRow(
                  cells: [
                    DataCell(
                      SizedBox(width: 104, child: Text(methodTitle(method))),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table(
              [
                ...keys.map(
                  (key) => DataColumn(
                    label: NotationText('k(${velocityTitle(key)})'),
                  ),
                ),
                DataColumn(label: Text(tr('Делитель'))),
              ],
              methods.map((method) {
                final weights = draft!.weights[method];
                return DataRow(
                  cells: [
                    ...keys.map(
                      (key) => DataCell(
                        Text(
                          weights?[key] == null
                              ? '—'
                              : inputNumber(weights![key]),
                        ),
                        onTap:
                            !resetRequested &&
                                draft!.isCustom &&
                                weights?[key] != null
                            ? () => _edit(method, key)
                            : null,
                      ),
                    ),
                    DataCell(
                      Text(
                        weights == null
                            ? '—'
                            : inputNumber(
                                weights.length == 1
                                    ? 1
                                    : weights.values.fold<double>(
                                        0,
                                        (a, b) => a + b,
                                      ),
                              ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(String method, String key) async {
    final controller = TextEditingController(
      text: inputNumber(draft!.weights[method]![key]),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: NotationText(
          '${methodTitle(method)} · k(${velocityTitle(key)})',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(tr('Применить')),
          ),
        ],
      ),
    );
    // Dispose after the dialog's closing transition releases the field.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (result == null || !mounted) return;
    final value = parseWeight(result);
    if (value == null) {
      showSnack(
        context,
        tr('Недопустимый коэффициент. Сохранено предыдущее значение.'),
      );
      return;
    }
    setState(() => draft!.weights[method]![key] = value);
  }
}

class VelocityEditor extends StatefulWidget {
  const VelocityEditor({
    super.key,
    required this.measurement,
    required this.vertical,
  });
  final WdcMeasurement measurement;
  final VerticalPoint vertical;
  @override
  State<VelocityEditor> createState() => _VelocityEditorState();
}

class _VelocityEditorState extends State<VelocityEditor>
    with WidgetsBindingObserver, SettingsRefresh<VelocityEditor> {
  bool leaving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(persistSafely());
    }
  }

  Future<void> persistSafely() async {
    try {
      await persist();
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          tr('Не удалось сохранить измерение. Попробуйте ещё раз.'),
        );
      }
    }
  }

  late final controllers = {
    for (final e in widget.vertical.velocityPoints.entries)
      e.key: TextEditingController(text: inputNumber(e.value.value)),
  };
  bool validInput(String text) =>
      text.trim().isEmpty || (parseNumRu(text)?.isFinite ?? false);
  bool fromBottom = true;
  Timer? timer;
  WdcMeasurement get m => widget.measurement;
  VerticalPoint get v => widget.vertical;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> persist() async {
    timer?.cancel();
    recalcAll(m);
    await WdcStorage.instance.save(m);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || leaving) return;
      if (controllers.values.any((c) => !validInput(c.text))) {
        showSnack(context, tr('Исправьте некорректные значения скорости'));
        return;
      }
      leaving = true;
      try {
        await persist();
        if (context.mounted) Navigator.of(context).pop();
      } catch (_) {
        leaving = false;
        if (context.mounted) {
          showSnack(
            context,
            tr('Не удалось сохранить измерение. Попробуйте ещё раз.'),
          );
        }
      }
    },
    child: Scaffold(
      appBar: AppBar(title: Text(tr('Скоростная вертикаль'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${tr('Расстояние')}: ${_numCell(v.distance, 3)} ${tr('м')}'),
          const SizedBox(height: 8),
          Text(
            '${tr('Рабочая глубина')}: ${_numCell(v.avgDepth, 3)} ${tr('м')}',
          ),
          if (m.calculationConfig != null) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: conditionTitle(context),
              value: v.special,
              onChanged: m.iceCover
                  ? null
                  : (value) {
                      setState(() => v.localSpecial = value ?? false);
                      persistSafely();
                    },
            ),
            if (m.iceCover) Text(tr('Ледостав включён для всего створа.')),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(
                  v.individualConfig == null
                      ? 'Метод измерения'
                      : 'Индивидуальный метод',
                ),
              ),
              subtitle: Text(presetTitle(v.effectiveConfig!.preset)),
              trailing: const Icon(Icons.settings_outlined),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalculationSettingsScreen(
                      config: v.individualConfig,
                      scope: CalculationScope.vertical,
                      inherited: m.calculationConfig,
                      allowReset: true,
                      onSave: (config) async {
                        final old = v.individualConfig;
                        v.individualConfig = config?.copy();
                        try {
                          await persist();
                        } catch (_) {
                          v.individualConfig = old;
                          recalcAll(m);
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
          ],
          Text(tr('Режим подсказок:')),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(tr('Расстояние от дна'))),
              ButtonSegment(
                value: false,
                label: Text(tr('Глубина от поверхности')),
              ),
            ],
            selected: {fromBottom},
            onSelectionChanged: (s) => setState(() => fromBottom = s.first),
          ),
          const SizedBox(height: 16),
          NotationText(
            '${tr('Uср')}: ${v.avgVelocity == null ? tr('н/д') : _numCell(v.avgVelocity, 4)} ${tr('м/с')}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          for (final key in velocityKeys.where(
            (key) => m.calculationConfig == null
                ? !['015', '04', '05', '085'].contains(key)
                : v.special || !['015', '05', '085'].contains(key),
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey('velocity-$key'),
                      controller: controllers[key],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        numericFormatter,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: InputDecoration(
                        label: NotationText(
                          '${velocityTitle(key)}, ${tr('м/с')}',
                        ),
                        errorText: validInput(controllers[key]!.text)
                            ? null
                            : tr('Некорректное число'),
                      ),
                      onChanged: (text) {
                        final value = parseNumRu(text);
                        if (text.trim().isNotEmpty &&
                            (value == null || !value.isFinite)) {
                          setState(() {});
                          return;
                        }
                        final next = value == null ? null : roundTo(value, 4);
                        if (v.velocityPoints[key]!.value == next) {
                          setState(() {});
                          return;
                        }
                        setState(() {
                          v.velocityPoints[key]!.value = next;
                          recordVelocityInput(m);
                          v.velocityPoints[key]!.changedAt = measurementNow(m);
                        });
                        timer?.cancel();
                        timer = Timer(
                          const Duration(milliseconds: 350),
                          persistSafely,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 94,
                    child: Text(
                      _hint(key),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
  String _hint(String key) {
    if (m.rotorDiameter == null || v.avgDepth == null) {
      return tr('Диаметр не задан');
    }
    final depth = instrumentDepth(
      key,
      v.avgDepth!,
      m.rotorDiameter!,
      special: v.special,
    );
    return depth == null
        ? '—'
        : '${((fromBottom ? v.avgDepth! - depth : depth) * 100).toStringAsFixed(1)} ${tr('см')}';
  }
}
