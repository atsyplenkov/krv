part of 'main.dart';

VelocityCalculation? usedCalculation(VerticalPoint v) {
  if (v.effectiveConfig != null) return v.calculation;
  if (v.avgVelocity == null) return null;
  final keys = v.velocityPoints;
  final String method;
  if ([
    'surface',
    '02',
    '06',
    '08',
    'bottom',
  ].every((k) => keys[k]!.value != null)) {
    method = 'five';
  } else if (['02', '06', '08'].every((k) => keys[k]!.value != null)) {
    method = 'three';
  } else if (keys['02']!.value != null && keys['08']!.value != null) {
    method = 'two';
  } else {
    method = 'one06';
  }
  final weights = presetWeights('wmo')[method]!;
  return VelocityCalculation(
    method,
    weights,
    weights.length == 1 ? 1 : weights.values.fold<double>(0, (a, b) => a + b),
    v.avgVelocity!,
  );
}

String formulaSignature(VerticalPoint v) {
  final calc = usedCalculation(v);
  if (calc == null) return '';
  return jsonEncode([
    v.effectiveConfig?.preset ?? 'legacy',
    v.special,
    calc.method,
    calc.weights,
    calc.divisor,
  ]);
}

Map<String, List<VerticalPoint>> usedFormulaGroups(WdcMeasurement m) {
  final groups = <String, List<VerticalPoint>>{};
  for (final v in m.verticals.where((v) => v.isSpeedVertical)) {
    final signature = formulaSignature(v);
    if (signature.isNotEmpty) (groups[signature] ??= []).add(v);
  }
  return groups;
}

String formulaId(WdcMeasurement m, VerticalPoint v) {
  final index = usedFormulaGroups(m).keys.toList().indexOf(formulaSignature(v));
  return index < 0 ? '' : 'F${index + 1}';
}

String formulaDescription(VerticalPoint v) {
  final c = usedCalculation(v);
  if (c == null) return tr('н/д');
  return '(${c.weights.entries.map((e) => '${inputNumber(e.value)} × ${velocityTitle(e.key)}').join(' + ')}) / ${inputNumber(c.divisor)}';
}

String csvContentV4(WdcMeasurement m) {
  m.bindCalculation();
  final rows = <List<Object?>>[];
  rows.add([
    tr('Название реки'),
    tr('Название створа'),
    tr('Часовой пояс (UTC)'),
    tr('Дата и время создания файла'),
    ...measurementTimes(m).keys,
    tr('Широта, °'),
    tr('Долгота, °'),
    tr('Ледостав'),
    tr('Лопастной диаметр вертушки, см'),
    tr('Уровень воды на начало промерных работ, м'),
    tr('Уровень воды на конец промерных работ, м'),
    tr('Уровень воды на начало измерения скоростей течения, м'),
    tr('Уровень воды на конец измерения скоростей течения, м'),
    tr('Средний уровень воды во время промерных работ, м'),
    tr('Средний уровень воды во время измерения скоростей, м'),
    tr('Поправка уровня воды, м'),
    tr('Берег'),
    tr('Расстояние от постоянного начала, м'),
    tr('Глубина на вертикали (1 измерение), м'),
    tr('Дата и время 1 промера'),
    tr('Глубина на вертикали (2 измерение), м'),
    tr('Дата и время 2 промера'),
    tr('Глубина на вертикали (средняя), м'),
    tr('Глубина на вертикали (средняя) с поправкой, м'),
    tr('Тип дна'),
    tr('Ледовые явления / растительность'),
    tr('Скоростная вертикаль'),
    for (final key in velocityKeys) ...[
      '${velocityTitle(key)}, ${tr('м/с')}',
      '${tr('Время измерения')} ${velocityTitle(key)}',
    ],
    tr('Источник метода'),
    tr('Набор формул'),
    tr('Схема'),
    tr('Код формулы'),
    tr('Формула'),
    tr('Делитель'),
    tr('Uср, м/с'),
    tr('Площадь водного сечения между промерными вертикалями, м2'),
    tr('Площадь водного сечения между промерными вертикалями с поправкой, м2'),
    tr('Смоченный периметр между промерными вертикалями, м'),
    tr('Площадь отсека, м²'),
    tr('Частичный расход, м³/с'),
    tr('Береговой коэффициент (ЛБ)'),
    tr('Береговой коэффициент (ПБ)'),
    tr('Ширина водного сечения, м'),
    tr('Площадь водного сечения потока, м2'),
    tr('Смоченный периметр, м'),
    tr('Гидравлический радиус, м'),
    tr('Средняя глубина, м'),
    tr('Максимальная глубина, м'),
    tr('Средняя скорость потока, м/с'),
    tr('Расход воды, м3/с'),
    tr('Комментарии'),
    tr('Предупреждения'),
  ]);
  for (final v in m.verticals) {
    final calc = usedCalculation(v);
    rows.add([
      m.river,
      m.site,
      measurementTimeZone(m),
      humanFromIso(m.createdAt),
      ...measurementTimes(m).values,
      _numCell(m.latitude, 8),
      _numCell(m.longitude, 8),
      m.iceCover ? 1 : 0,
      _numCell(m.rotorDiameter == null ? null : m.rotorDiameter! * 100, 2),
      _numCell(m.levelSoundingStart, 3),
      _numCell(m.levelSoundingEnd, 3),
      _numCell(m.levelVelocityStart, 3),
      _numCell(m.levelVelocityEnd, 3),
      _numCell(m.meanSoundingLevel, 3),
      _numCell(m.meanVelocityLevel, 3),
      _numCell(m.levelCorrection, 3),
      bankLabel(v.bank),
      _numCell(v.distance, 3),
      _numCell(v.depth1, 3),
      humanFromIso(v.depth1At),
      _numCell(v.depth2, 3),
      humanFromIso(v.depth2At),
      _numCell(v.avgDepth, 3),
      _numCell(v.correctedDepth, 3),
      v.bottomType,
      v.isSpeedVertical && v.special ? 1 : 0,
      v.isSpeedVertical ? 1 : 0,
      for (final p in v.velocityPoints.values) ...[
        _numCell(p.value, 4),
        humanFromIso(p.changedAt),
      ],
      v.isSpeedVertical
          ? tr(
              v.individualConfig == null
                  ? 'Метод измерения'
                  : 'Индивидуальный метод',
            )
          : '',
      v.isSpeedVertical
          ? presetTitle(v.effectiveConfig?.preset ?? 'legacy')
          : '',
      calc == null ? '' : methodTitle(calc.method),
      formulaId(m, v),
      calc == null ? '' : formulaDescription(v),
      calc == null ? '' : inputNumber(calc.divisor),
      _numCell(v.avgVelocity, 4),
      _numCell(v.areaBetween, 6),
      _numCell(v.correctedAreaBetween, 6),
      _numCell(v.wettedBetween, 3),
      _numCell(v.sectionArea, 6),
      _numCell(v.partialDischarge, 6),
      _numCell(m.bankCoeffLeft, 2),
      _numCell(m.bankCoeffRight, 2),
      _numCell(m.width, 3),
      _numCell(m.area, 6),
      _numCell(m.wettedPerimeter, 3),
      _numCell(m.hydraulicRadius, 3),
      _numCell(m.meanDepth, 3),
      _numCell(m.maxDepth, 3),
      _numCell(m.meanFlowVelocity, 6),
      _numCell(m.discharge, 6),
      m.comment,
      m.warnings.map(tr).join(' | '),
    ]);
  }
  return '\uFEFF${rows.map((row) => row.map(_csvCell).join(';')).join('\n')}';
}

pw.Widget reportTable(List<String> headers, List<List<String>> data) =>
    pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final h in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pdfNotation(h, bold: true),
              ),
          ],
        ),
        for (final row in data)
          pw.TableRow(
            children: [
              for (final cell in row)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pdfNotation(cell),
                ),
            ],
          ),
      ],
    );
pw.Widget soundingReportTable(WdcMeasurement m) {
  final depth2 = m.verticals.any((v) => v.depth2 != null);
  final bottom = m.verticals.any((v) => v.bottomType.trim().isNotEmpty);
  return reportTable(
    [
      tr('Берег'),
      tr('Расст., м'),
      tr('Глуб.1, м'),
      if (depth2) tr('Глуб.2, м'),
      tr('Глуб.ср, м'),
      if (bottom) tr('Тип дна'),
    ],
    m.verticals
        .map(
          (v) => [
            bankLabel(v.bank),
            _numCell(v.distance, 3),
            _numCell(v.depth1, 3),
            if (depth2) _numCell(v.depth2, 3),
            _numCell(v.avgDepth, 3),
            if (bottom) v.bottomType,
          ],
        )
        .toList(),
  );
}

List<pw.Widget> velocityReportTables(WdcMeasurement m) {
  final rows = m.verticals
      .where((v) => v.isSpeedVertical || v.partialDischarge != null)
      .toList();
  final keys = velocityKeys
      .where((key) => rows.any((v) => v.velocityPoints[key]!.value != null))
      .toList();
  final widgets = <pw.Widget>[];
  widgets.add(
    pw.Text(
      tr('Таблица скоростных вертикалей'),
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
  );
  widgets.add(pw.SizedBox(height: 6));
  widgets.add(
    reportTable(
      [
        tr('Расст., м'),
        tr('Глуб., м'),
        ...keys.map((k) => '${velocityTitle(k)}\n${tr('м/с')}'),
        tr('Uср, м/с'),
      ],
      rows
          .map(
            (v) => [
              _numCell(v.distance, 3),
              _numCell(v.correctedDepth ?? v.avgDepth, 3),
              ...keys.map((k) => _numCell(v.velocityPoints[k]!.value, 4)),
              _numCell(v.avgVelocity, 4),
            ],
          )
          .toList(),
    ),
  );
  widgets.add(pw.SizedBox(height: 14));
  widgets.add(
    pw.Text(
      tr('Таблица расчёта расхода воды'),
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
  );
  widgets.add(pw.SizedBox(height: 6));
  widgets.add(
    reportTable(
      [
        tr('Расст., м'),
        tr('Uср, м/с'),
        tr('Площадь отсека, м²'),
        tr('Частичный расход, м³/с'),
        tr('Код формулы'),
        tr('Ледовые явл. / раст.'),
      ],
      rows
          .map(
            (v) => [
              _numCell(v.distance, 3),
              _numCell(v.avgVelocity, 4),
              _numCell(v.sectionArea, 6),
              _numCell(v.partialDischarge, 6),
              '${formulaId(m, v)}${v.individualConfig != null ? ' *' : ''}',
              v.special ? tr('Да') : tr('Нет'),
            ],
          )
          .toList(),
    ),
  );
  if (rows.any((v) => v.individualConfig != null)) {
    widgets.add(pw.Text('* ${tr('Индивидуальный метод')}'));
  }
  widgets.add(
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        tr('Применённые формулы'),
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    ),
  );
  for (final group in usedFormulaGroups(m).values) {
    final v = group.first;
    widgets.add(
      pw.Inseparable(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${formulaId(m, v)} · ${presetTitle(v.effectiveConfig?.preset ?? 'legacy')} · ${methodTitle(usedCalculation(v)!.method)}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              reportTable(
                [tr('Горизонт'), tr('Коэффициент')],
                usedCalculation(v)!.weights.entries
                    .map((e) => [velocityTitle(e.key), inputNumber(e.value)])
                    .toList(),
              ),
              pdfNotation(formulaDescription(v)),
            ],
          ),
        ),
      ),
    );
  }
  return widgets;
}
