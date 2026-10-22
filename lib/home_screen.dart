part of 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SettingsRefresh<HomeScreen> {
  final storage = WdcStorage.instance;
  final _listController = ScrollController();
  List<WdcMeasurement> _all = [];
  bool _loading = true;
  bool _starting = false;
  bool _transferring = false;
  int _loadGeneration = 0;
  SortField _sortField = SortField.date;
  bool _descending = true;
  final _search = SearchSettings();
  final Set<String> _selected = {};

  bool get _selectionMode => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    storage.savedMeasurement.addListener(_onMeasurementSaved);
    _recoverAndLoad();
  }

  Future<void> _recoverAndLoad() async {
    try {
      await PhotoStorage.recoverLostPhotos();
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          tr('Не удалось восстановить фото после закрытия камеры'),
        );
      }
    }
    if (mounted) await _load();
  }

  @override
  void dispose() {
    storage.savedMeasurement.removeListener(_onMeasurementSaved);
    _listController.dispose();
    super.dispose();
  }

  void _onMeasurementSaved() {
    final saved = storage.savedMeasurement.value;
    if (!mounted || saved == null) return;
    final wasLoading = _loading;
    _loadGeneration++;
    setState(() {
      final index = _all.indexWhere((m) => m.id == saved.id);
      if (index < 0) {
        _all.add(saved);
      } else {
        _all[index] = saved;
      }
      _loading = false;
    });
    if (wasLoading) unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    // Keep the existing list mounted while refreshing after navigation.
    // Replacing it with a spinner discards its scroll position.
    if (_all.isEmpty) setState(() => _loading = true);
    final all = await storage.loadAll();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  bool _matchText(String field, String query, bool exact) {
    final f = field.trim().toLowerCase();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (exact) return f == q;
    final tokens = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return tokens.every(f.contains);
  }

  List<WdcMeasurement> get _visible {
    final unfinished = _all.where((m) => !m.completed).toList()
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));

    var finished = _all.where((m) => m.completed).where((m) {
      if (!_matchText(m.river, _search.river, _search.riverExact)) return false;
      if (!_matchText(m.site, _search.site, _search.siteExact)) return false;
      if (!_matchText(m.project, _search.project, _search.projectExact)) {
        return false;
      }
      final d = DateTime(
        m.createdDate.year,
        m.createdDate.month,
        m.createdDate.day,
      );
      if (_search.from != null && d.isBefore(_search.from!)) return false;
      if (_search.to != null && d.isAfter(_search.to!)) return false;
      return true;
    }).toList();

    finished.sort(
      (a, b) => compareMeasurements46(a, b, _sortField, _descending),
    );
    return [...unfinished, ...finished];
  }

  Future<void> _startNew() async {
    if (_starting) return;
    setState(() => _starting = true);
    final progress = AppSettings.current.autoGps
        ? showWorkProgress(context, tr('Получаем координаты…'))
        : null;
    double? lat;
    double? lon;
    try {
      if (AppSettings.current.autoGps) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition().timeout(
            const Duration(seconds: 5),
          );
          lat = roundTo(pos.latitude, 8);
          lon = roundTo(pos.longitude, 8);
        }
      }
    } catch (_) {
      // Coordinates are optional.
    }
    final m = WdcMeasurement.empty(lat: lat, lon: lon);
    try {
      await storage.save(m);
    } catch (_) {
      if (mounted) showSnack(context, tr('Не удалось создать измерение'));
      return;
    } finally {
      progress?.call();
      if (mounted) setState(() => _starting = false);
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SoundingScreen(measurement: m)),
    );
    await _load();
  }

  Future<void> _exportKrv() async {
    if (_transferring) return;
    final records = _all
        .where((m) => _selected.contains(m.id))
        .map((m) => m.toJson())
        .toList();
    if (records.isEmpty) return;
    setState(() => _transferring = true);
    final close = showWorkProgress(context, tr('Создаём архив…'));
    try {
      await storage.flush();
      final base = (await storage._baseDir).path;
      final temp = (await getTemporaryDirectory()).path;
      final path = await KrvTransfer.exportInBackground(base, records, temp);
      close();
      if (!mounted) return;
      await shareFiles44([
        XFile(path, mimeType: 'application/octet-stream'),
      ], text: tr('Архив измерений КРВ'));
    } catch (e) {
      close();
      if (mounted) {
        showSnack(
          context,
          e is KrvException
              ? tr(e.message)
              : tr('Не удалось создать или отправить архив.'),
        );
      }
    } finally {
      close();
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _shareOne(WdcMeasurement m, {required bool pdf}) async {
    final close = showWorkProgress(
      context,
      pdf ? tr('Создаём PDF…') : tr('Создаём CSV…'),
    );
    try {
      final f = pdf ? await storage.exportPdf(m) : await storage.exportCsv(m);
      close();
      await shareFiles44([
        XFile(f.path),
      ], text: pdf ? tr('PDF-отчёт') : tr('CSV расчёта расхода воды'));
    } catch (_) {
      close();
      if (mounted) {
        showSnack(context, tr('Не удалось экспортировать измерение'));
      }
    }
  }

  Future<void> _shareSelected({bool pdf = false}) async {
    final items = _all.where((m) => _selected.contains(m.id)).toList();
    if (items.isEmpty) return;
    final files = <XFile>[];
    for (final m in items) {
      final f = pdf ? await storage.exportPdf(m) : await storage.exportCsv(m);
      files.add(XFile(f.path));
    }
    await shareFiles44(
      files,
      text: pdf
          ? tr('PDF-отчёты расчёта расхода воды')
          : tr('CSV-файлы расчёта расхода воды'),
    );
  }

  Future<void> _deleteSelected() async {
    final ok = await confirmDialog(
      context,
      title: tr('Удаление'),
      message: tr('Удалить безвозвратно выделенные измерения?'),
    );
    if (!ok) return;
    for (final id in _selected) {
      await storage.delete(id);
    }
    _selected.clear();
    await _load();
  }

  Future<void> _openMeasurement(WdcMeasurement m) async {
    Widget page;
    if (m.completed) {
      page = ResultScreen(measurement: m, viewOnly: true);
    } else {
      page = SoundingScreen(measurement: m);
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  Future<void> _showSearchDialog() async {
    final riverC = TextEditingController(text: _search.river);
    final siteC = TextEditingController(text: _search.site);
    final projectC = TextEditingController(text: _search.project);
    final fromC = TextEditingController(
      text: _search.from == null ? '' : dateHuman(_search.from!),
    );
    final toC = TextEditingController(
      text: _search.to == null ? '' : dateHuman(_search.to!),
    );
    var riverExact = _search.riverExact;
    var siteExact = _search.siteExact;
    var projectExact = _search.projectExact;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tr('Поиск')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: riverC,
                  decoration: InputDecoration(labelText: tr('Название реки')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: riverExact,
                  onChanged: (v) => setDialogState(() => riverExact = v),
                  title: Text(tr('Точное совпадение реки')),
                ),
                TextField(
                  controller: siteC,
                  decoration: InputDecoration(labelText: tr('Название створа')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: siteExact,
                  onChanged: (v) => setDialogState(() => siteExact = v),
                  title: Text(tr('Точное совпадение створа')),
                ),
                TextField(
                  key: const ValueKey('search-project'),
                  controller: projectC,
                  decoration: InputDecoration(labelText: tr('Проект')),
                ),
                SwitchListTile(
                  key: const ValueKey('search-project-exact'),
                  contentPadding: EdgeInsets.zero,
                  value: projectExact,
                  onChanged: (v) => setDialogState(() => projectExact = v),
                  title: Text(tr('Точное совпадение проекта')),
                ),
                TextField(
                  controller: fromC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('Дата с'),
                    hintText: tr('дд.мм.гггг'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: toC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('по'),
                    hintText: tr('дд.мм.гггг'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Закрыть')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('🔎 Поиск')),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final from = parseHumanDate(fromC.text);
      final to = parseHumanDate(toC.text);
      if ((fromC.text.trim().isNotEmpty && from == null) ||
          (toC.text.trim().isNotEmpty && to == null)) {
        if (mounted) showSnack(context, tr('Дата указана в неверном формате'));
        return;
      }
      setState(() {
        _search.river = riverC.text;
        _search.site = siteC.text;
        _search.project = projectC.text;
        _search.projectExact = projectExact;
        _search.riverExact = riverExact;
        _search.siteExact = siteExact;
        _search.from = from;
        _search.to = to;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final compactToolbar = MediaQuery.sizeOf(context).width < 380;
    return Scaffold(
      appBar: AppBar(
        bottom: _search.active
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _search.river = '';
                    _search.site = '';
                    _search.project = '';
                    _search.projectExact = false;
                    _search.from = null;
                    _search.to = null;
                    _search.riverExact = false;
                    _search.siteExact = false;
                  }),
                  icon: const Icon(Icons.clear),
                  label: Text(tr('Сбросить поиск')),
                ),
              )
            : null,
        title: Text(
          _selectionMode
              ? (compactToolbar
                    ? '${_selected.length}'
                    : '${tr('Выбрано')}: ${_selected.length}')
              : 'v4.6',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leadingWidth: _selectionMode ? 48 : 96,
        titleSpacing: 4,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteSelected,
              )
            : Row(
                children: [
                  IconButton(
                    tooltip: tr('Настройки'),
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                      if (mounted) await _load();
                    },
                  ),
                  IconButton(
                    tooltip: tr('О приложении'),
                    icon: const Icon(Icons.help_outline),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen44()),
                    ),
                  ),
                ],
              ),
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: tr('Снять выделение'),
                  onPressed: () => setState(_selected.clear),
                  icon: const Icon(Icons.close),
                ),
                IconButton(
                  tooltip: tr('Выбрать всё'),
                  onPressed: () => setState(
                    () => _selected.addAll(visible.map((m) => m.id)),
                  ),
                  icon: const Icon(Icons.select_all),
                ),
                IconButton(
                  key: const ValueKey('export-krv'),
                  tooltip: tr('Экспорт выбранных в .krv'),
                  onPressed: _transferring ? null : _exportKrv,
                  icon: const Icon(Icons.outbox_outlined),
                ),
                IconButton(
                  tooltip: tr('Поделиться CSV'),
                  onPressed: () => _shareSelected(pdf: false),
                  icon: const CsvExportIcon(),
                ),
                IconButton(
                  tooltip: tr('Экспорт выбранных в PDF'),
                  onPressed: () => _shareSelected(pdf: true),
                  icon: const PdfExportIcon(),
                ),
              ]
            : [
                IconButton(
                  key: const ValueKey('home-search'),
                  tooltip: _search.active ? tr('Изменить поиск') : tr('Поиск'),
                  onPressed: _showSearchDialog,
                  icon: _search.active
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: Stack(
                            children: [
                              Icon(Icons.search),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Icon(Icons.edit, size: 13),
                              ),
                            ],
                          ),
                        )
                      : const Icon(Icons.search),
                ),
                PopupMenuButton<SortField>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (v) => setState(() => _sortField = v),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: SortField.river,
                      child: Text(tr('По названию реки')),
                    ),
                    PopupMenuItem(
                      value: SortField.site,
                      child: Text(tr('По названию створа')),
                    ),
                    PopupMenuItem(
                      value: SortField.date,
                      child: Text(tr('По дате')),
                    ),
                    PopupMenuItem(
                      value: SortField.discharge,
                      child: Text(tr('По расходу воды')),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => setState(() => _descending = !_descending),
                  icon: Icon(
                    _descending ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
          ? Center(
              child: Text(
                _all.isEmpty
                    ? tr('Измерения отсутствуют')
                    : tr('Измерения не найдены,\nизмените настройки поиска'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                key: const PageStorageKey('home-measurements'),
                controller: _listController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final m = visible[i];
                  final selected = _selected.contains(m.id);
                  return Card(
                    color: selected
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : !m.completed
                        ? (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF39362A)
                              : const Color(0xFFFFF8E1))
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: .5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            onLongPress: () =>
                                setState(() => _selected.add(m.id)),
                            onTap: () {
                              if (_selectionMode) {
                                setState(
                                  () => selected
                                      ? _selected.remove(m.id)
                                      : _selected.add(m.id),
                                );
                              } else {
                                _openMeasurement(m);
                              }
                            },
                            leading: _selectionMode
                                ? Icon(
                                    selected
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        m.completed
                                            ? Icons.water_drop_outlined
                                            : Icons.edit_note,
                                      ),
                                      if (m.iceCover)
                                        Tooltip(
                                          message: tr('Ледостав'),
                                          child: const IceMark46(),
                                        ),
                                      if (m.completed && m.warnings.isNotEmpty)
                                        Tooltip(
                                          message: tr('Предупреждения'),
                                          child: Icon(
                                            Icons.error_outline,
                                            size: 18,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                    ],
                                  ),
                            title: Text(
                              m.titleRiver,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${m.titleSite}\n${m.completed ? (m.discharge == null ? tr('Расход не определён') : 'Q: ${compactDischarge(m.discharge)} ${tr('м³/с')}') : ''}\n${humanFromIso(m.createdAt)}${m.completed ? '' : tr('\nНезавершённое измерение')}${m.importedCopy ? '\n${tr('Импортированная копия')}' : ''}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                        if (!_selectionMode)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: tr('Экспорт PDF'),
                                icon: const PdfExportIcon(),
                                onPressed: () => _shareOne(m, pdf: true),
                              ),
                              IconButton(
                                tooltip: tr('Поделиться CSV'),
                                icon: const CsvExportIcon(),
                                onPressed: () => _shareOne(m, pdf: false),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _starting ? null : _startNew,
            icon: const Icon(Icons.add),
            label: Text(tr('Начать новое измерение')),
          ),
        ),
      ),
    );
  }
}
