part of 'main.dart';

enum CalculationScope { application, measurement, vertical }

const aboutText =
    'Приложение навайбкожено студентом кафедры гидрологии суши географического факультета МГУ имени М. В. Ломоносова Олегом Лошковым в 2025-26 гг.\n\nМетодическая основа:\n- Методические указания МИ 1759-87;\n- Руководство по гидрологической практике ВМО № 168, шестая редакция\n\nОтзывы и предложения о поддержке и сотрудничестве:';
const coefficientsIntro =
    'Ниже представлены таблицы с весовыми коэффициентами для скоростей на разных глубинах при разных способах расчёта. Вы можете воспользоваться предлагаемыми приложением наборами или настроить свои.';
const coefficientsLimits =
    'Коэффициенты должны иметь значения больше нуля и не больше тысячи, а также не больше 3 знаков после запятой.';
const specialRules =
    'Для измерений в условиях ледовых явлений / наличия растительности используется отдельная таблица коэффициентов (ниже основной). В этих условиях приложение выбирает первую доступную схему сверху вниз только из этой таблицы. Если данных для её схем недостаточно, средняя скорость не рассчитывается; переход к таблице обычных условий не выполняется.';
const specialExample =
    'При расчёте средней скорости на вертикали при ледовых явлениях / растительности используются схемы для особых условий. Например, при введённых скоростях на глубинах 0.2h, 0.6h и 0.8h расчёт будет произведён по паре 0.2h и 0.8h. При недостатке данных для особых схем средняя скорость не рассчитывается.';
const iceDepthHelp =
    'Приложение считает, что вводимые при ледоставе значения глубины являются значениями рабочей толщины воды без учёта толщины льда. Ледяной покров учитывается при расчёте смоченного периметра.';

String calculationExplanation(CalculationScope scope) => [
  tr(coefficientsIntro),
  tr(switch (scope) {
    CalculationScope.application =>
      'Выбранный здесь набор коэффициентов будет использоваться по умолчанию для всех новых создаваемых измерений.',
    CalculationScope.measurement =>
      'Выбранный здесь набор коэффициентов будет использоваться для всех скоростных вертикалей в данном измерении расхода воды, кроме вертикалей с индивидуальным методом.',
    CalculationScope.vertical =>
      'Выбранный здесь набор коэффициентов будет использоваться для данной скоростной вертикали в данном измерении расхода воды.',
  }),
  tr(coefficientsLimits),
  '\n${tr(specialRules)}',
].join(' ');

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
              [if (ice) tr(iceDepthHelp), tr(specialExample)].join('\n\n'),
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
  const NotationText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final size = effective.fontSize ?? 14;
    return Text.rich(
      TextSpan(
        children: [
          for (final part in notationParts(text))
            if (!part.sub)
              TextSpan(text: part.text)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Transform.translate(
                  offset: Offset(0, size * .18),
                  child: Text(
                    part.text,
                    style: effective.copyWith(fontSize: size * .72),
                  ),
                ),
              ),
        ],
      ),
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

Color velocityPointColor(VerticalPoint v, String key) =>
    v.isSpeedVertical && (usedCalculation(v)?.weights.containsKey(key) ?? false)
    ? Colors.green.shade700
    : Colors.black;

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
    horizontalMargin: 10,
    columnSpacing: 18,
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

Widget resultSoundingTable(List<VerticalPoint> rows) {
  final headers = [
    tr('Берег'),
    tr('Расст., м'),
    tr('Глуб₁, м'),
    tr('Глуб₂, м'),
    tr('Глуб.ср, м'),
    tr('Тип дна'),
  ];
  final present = [
    rows.any((v) => v.bank != null),
    true,
    rows.any((v) => v.depth1 != null),
    rows.any((v) => v.depth2 != null),
    rows.any((v) => v.avgDepth != null),
    rows.any((v) => v.bottomType.trim().isNotEmpty),
  ];
  final indexes = [
    for (var i = 0; i < headers.length; i++)
      if (present[i]) i,
  ];
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      key: const ValueKey('result-sounding-table'),
      columns: [for (final i in indexes) DataColumn(label: Text(headers[i]))],
      rows: rows.map((v) {
        final cells = [
          bankLabel(v.bank),
          _numCell(v.distance, 3),
          _numCell(v.depth1, 3),
          _numCell(v.depth2, 3),
          _numCell(v.avgDepth, 3),
          v.bottomType,
        ];
        return DataRow(
          cells: [for (final i in indexes) DataCell(Text(cells[i]))],
        );
      }).toList(),
    ),
  );
}
