part of 'main.dart';

enum CalculationScope { application, measurement, vertical }

const aboutText =
    'Приложение навайбкожено студентом кафедры гидрологии суши географического факультета МГУ имени М. В. Ломоносова Олегом Лошковым в 2025-26 гг.\n\nМетодическая основа:\n- Методические указания МИ 1759-87;\n- Руководство по гидрологической практике ВМО № 168, шестая редакция\n\nОтзывы и предложения о поддержке и сотрудничестве:';
const coefficientsIntro =
    'Ниже представлены таблицы с весовыми коэффициентами для измеренных скоростей течения на разных глубинах, используемыми для расчёта средней скорости на вертикали. Вы можете воспользоваться предлагаемыми приложением наборами или настроить свои.';
const coefficientsLimits =
    'Коэффициенты должны иметь значения больше нуля и не больше тысячи, а также не больше 3 знаков после запятой.';
const specialRules =
    'Для измерений в условиях ледовых явлений / наличия растительности используется отдельная таблица коэффициентов (ниже основной). В этих условиях приложение выбирает первую доступную схему сверху вниз только из этой таблицы. Если данных для её схем недостаточно, средняя скорость на вертикали не рассчитывается; переход к таблице обычных условий не выполняется.';
const specialExample =
    'При расчёте средней скорости на вертикали при ледовых явлениях / растительности используются схемы для особых условий. Например, при введённых скоростях на глубинах 0.2h, 0.6h и 0.8h расчёт будет произведён по паре 0.2h и 0.8h. При недостатке данных для особых схем средняя скорость на вертикали не рассчитывается.';
const iceDepthHelp =
    'Приложение считает, что вводимые при ледоставе значения глубины являются значениями рабочей глубины без учёта толщины льда.';

const icePerimeterHelp46 =
    'Ледяной покров учитывается при расчёте смоченного периметра.';

String calculationScopeText46(CalculationScope scope) => tr(switch (scope) {
  CalculationScope.application =>
    'Выбранный здесь набор коэффициентов для расчёта средней скорости на вертикали будет использоваться по умолчанию во всех новых измерениях расхода воды.',
  CalculationScope.measurement =>
    'Выбранный здесь набор коэффициентов для расчёта средней скорости на вертикали будет использоваться для всех скоростных вертикалей в данном измерении расхода воды, кроме вертикалей с индивидуальным методом.',
  CalculationScope.vertical =>
    'Выбранный здесь набор коэффициентов для расчёта средней скорости на вертикали будет использоваться только для данной скоростной вертикали в данном измерении расхода воды.',
});

Widget calculationHelp46(CalculationScope scope) => Text.rich(
  TextSpan(
    children: [
      TextSpan(text: '${tr(coefficientsIntro)}\n\n'),
      TextSpan(
        text: calculationScopeText46(scope),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      TextSpan(text: '\n\n${tr(coefficientsLimits)}\n\n${tr(specialRules)}'),
    ],
  ),
);

Widget conditionTitle(BuildContext context, {bool ice = false}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Flexible(
      child: Text(tr(ice ? 'Ледостав' : 'Ледовые явления / растительность')),
    ),
    IconButton(
      tooltip: tr('Справка'),
      icon: const Icon(Icons.help_outline),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('Справка')),
          content: SingleChildScrollView(
            child: Text(
              [
                if (ice) tr(iceDepthHelp),
                tr(specialExample),
                if (ice) tr(icePerimeterHelp46),
              ].join('\n\n'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('Закрыть')),
            ),
          ],
        ),
      ),
    ),
  ],
);

// One tokeniser for screen and report notation. Arbitrary user text is never passed here.
Iterable<({String text, bool sub})> notationParts(String text) sync* {
  final pattern = RegExp(
    r'(U)(0\.(?:15|85|2|4|5|6|8)h|пов|дно|ср|поп|sur|bed|mean|cross)|(h)(ср|max|mean)|(Глуб\.)(1|2|ср)|(Depth )(1|2)',
  );
  var offset = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > offset) {
      yield (text: text.substring(offset, match.start), sub: false);
    }
    for (var i = 1; i <= 7; i += 2) {
      if (match.group(i) != null) {
        yield (text: match.group(i)!, sub: false);
        yield (text: match.group(i + 1)!, sub: true);
      }
    }
    offset = match.end;
  }
  if (offset < text.length) yield (text: text.substring(offset), sub: false);
}

class NotationText extends StatelessWidget {
  const NotationText(
    this.text, {
    super.key,
    this.style,
    this.keepSymbolsTogether = false,
  });
  final String text;
  final TextStyle? style;
  final bool keepSymbolsTogether;
  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final size = effective.fontSize ?? 14;
    final parts = notationParts(text).toList();
    Widget subscript(String value) => Transform.translate(
      offset: Offset(0, size * .18),
      child: Text(value, style: effective.copyWith(fontSize: size * .72)),
    );
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (keepSymbolsTogether && i + 1 < parts.length && parts[i + 1].sub) {
        // A line may wrap between terms, never between U and its depth index.
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: MediaQuery.withNoTextScaling(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(part.text, style: effective),
                  subscript(parts[++i].text),
                ],
              ),
            ),
          ),
        );
      } else if (part.sub) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: subscript(part.text),
          ),
        );
      } else {
        spans.add(TextSpan(text: part.text));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      style: effective,
      semanticsLabel: text,
    );
  }
}

pw.Widget pdfNotation(String text, {double size = 10, bool bold = false}) =>
    pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        children: [
          for (final p in notationParts(text))
            pw.TextSpan(
              text: p.text,
              baseline: p.sub ? -size * .18 : 0,
              style: p.sub ? pw.TextStyle(fontSize: size * .72) : null,
            ),
        ],
      ),
    );

Color velocityPointColor(VerticalPoint v, String key, {bool dark = false}) =>
    v.isSpeedVertical && (usedCalculation(v)?.weights.containsKey(key) ?? false)
    ? Colors.green.shade700
    : (dark ? Colors.white : Colors.black);

Widget resultVelocityTable(BuildContext context, List<VerticalPoint> rows) {
  final keys = velocityKeys
      .where((k) => rows.any((v) => v.velocityPoints[k]!.value != null))
      .toList();
  final depth = rows.any((v) => v.avgDepth != null);
  final mean = rows.any((v) => v.avgVelocity != null);
  final area = rows.any((v) => v.sectionArea != null);
  final discharge = rows.any((v) => v.partialDischarge != null);
  final height = math.max(
    64.0,
    MediaQuery.textScalerOf(context).scale(32) + 24,
  );
  DataTable table(List<String> headers, List<List<String>> data) => DataTable(
    horizontalMargin: 6,
    columnSpacing: 12,
    headingRowHeight: height,
    dataRowMinHeight: height,
    dataRowMaxHeight: height,
    columns: headers.map((h) => DataColumn(label: NotationText(h))).toList(),
    rows: data
        .map((r) => DataRow(cells: r.map((s) => DataCell(Text(s))).toList()))
        .toList(),
  );
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      table([
        tr('Расст., м'),
      ], rows.map((v) => [_numCell(v.distance, 3)]).toList()),
      if (depth || mean || area || discharge || keys.isNotEmpty)
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('result-velocities-scroll'),
            scrollDirection: Axis.horizontal,
            child: table(
              [
                if (depth) tr('Глуб., м'),
                ...keys.map((k) => '${velocityTitle(k)}, ${tr('м/с')}'),
                if (mean) tr('Uср, м/с'),
                if (area) tr('Площадь отсека, м²'),
                if (discharge) tr('Частичный расход, м³/с'),
              ],
              rows
                  .map(
                    (v) => [
                      if (depth) _numCell(v.avgDepth, 3),
                      ...keys.map(
                        (k) => _numCell(v.velocityPoints[k]!.value, 4),
                      ),
                      if (mean) _numCell(v.avgVelocity, 4),
                      if (area) _numCell(v.sectionArea, 6),
                      if (discharge) _numCell(v.partialDischarge, 6),
                    ],
                  )
                  .toList(),
            ),
          ),
        ),
    ],
  );
}

Widget resultSoundingTable(List<VerticalPoint> rows, {bool showIce = false}) {
  final headers = [
    tr('Берег'),
    tr('Расст., м'),
    tr('Глуб₁, м'),
    tr('Глуб₂, м'),
    tr('Глуб.ср, м'),
    tr('Тип дна'),
    tr('Глубина с поправкой, м'),
    tr('Толщина льда, см'),
  ];
  final present = [
    rows.any((v) => v.bank != null),
    true,
    rows.any((v) => v.depth1 != null),
    rows.any((v) => v.depth2 != null),
    rows.any((v) => v.avgDepth != null),
    rows.any((v) => v.bottomType.trim().isNotEmpty),
    rows.any((v) => v.correctedDepth != null && v.correctedDepth != v.avgDepth),
    showIce && rows.any((v) => v.iceThicknessCm != null),
  ];
  final indexes = [
    for (var i = 0; i < headers.length; i++)
      if (present[i]) i,
  ];
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      key: const ValueKey('result-sounding-table'),
      horizontalMargin: 6,
      columnSpacing: 12,
      columns: [for (final i in indexes) DataColumn(label: Text(headers[i]))],
      rows: rows.map((v) {
        final cells = [
          bankLabel(v.bank),
          _numCell(v.distance, 3),
          _numCell(v.depth1, 3),
          _numCell(v.depth2, 3),
          _numCell(v.avgDepth, 3),
          v.bottomType,
          _numCell(v.correctedDepth, 3),
          v.iceThicknessCm == null ? tr('н/д') : _numCell(v.iceThicknessCm, 2),
        ];
        return DataRow(
          cells: [for (final i in indexes) DataCell(Text(cells[i]))],
        );
      }).toList(),
    ),
  );
}
