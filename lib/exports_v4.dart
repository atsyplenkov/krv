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
    csvHeader44('Название реки'),
    csvHeader44('Название створа'),
    csvHeader44('Часовой пояс (UTC)'),
    csvHeader44('Дата и время создания файла'),
    ...[
      'Начало промерных работ',
      'Конец промерных работ',
      'Начало измерения скоростей',
      'Конец измерения скоростей',
    ],
    csvHeader44('Широта, °'),
    csvHeader44('Долгота, °'),
    csvHeader44('Ледостав'),
    csvHeader44('Лопастной диаметр вертушки, см'),
    csvHeader44('Уровень воды на начало промерных работ, м'),
    csvHeader44('Уровень воды на конец промерных работ, м'),
    csvHeader44('Уровень воды на начало измерения скоростей течения, м'),
    csvHeader44('Уровень воды на конец измерения скоростей течения, м'),
    csvHeader44('Средний уровень воды во время промерных работ, м'),
    csvHeader44('Средний уровень воды во время измерения скоростей, м'),
    csvHeader44('Поправка уровня воды, м'),
    csvHeader44('Берег'),
    csvHeader44('Расстояние от постоянного начала, м'),
    csvHeader44('Глубина на вертикали (1 измерение), м'),
    csvHeader44('Дата и время 1 промера'),
    csvHeader44('Глубина на вертикали (2 измерение), м'),
    csvHeader44('Дата и время 2 промера'),
    csvHeader44('Глубина на вертикали (средняя), м'),
    csvHeader44('Глубина на вертикали (средняя) с поправкой, м'),
    csvHeader44('Тип дна'),
    csvHeader44('Ледовые явления / растительность'),
    csvHeader44('Скоростная вертикаль'),
    for (final key in velocityKeys) ...[
      '${csvVelocity44(key)}, ${csvHeader44('м/с')}',
      '${csvHeader44('Время измерения')} ${csvVelocity44(key)}',
    ],
    csvHeader44('Источник метода'),
    csvHeader44('Набор формул'),
    csvHeader44('Схема'),
    csvHeader44('Код формулы'),
    csvHeader44('Формула'),
    csvHeader44('Делитель'),
    csvHeader44('Uср, м/с'),
    csvHeader44('Площадь водного сечения между промерными вертикалями, м2'),
    csvHeader44(
      'Площадь водного сечения между промерными вертикалями с поправкой, м2',
    ),
    csvHeader44('Смоченный периметр между промерными вертикалями, м'),
    csvHeader44('Площадь отсека, м²'),
    csvHeader44('Частичный расход, м³/с'),
    csvHeader44('Береговой коэффициент (ЛБ)'),
    csvHeader44('Береговой коэффициент (ПБ)'),
    csvHeader44('Ширина водного сечения, м'),
    csvHeader44('Площадь водного сечения потока, м2'),
    csvHeader44('Смоченный периметр, м'),
    csvHeader44('Гидравлический радиус, м'),
    csvHeader44('Средняя глубина, м'),
    csvHeader44('Максимальная глубина, м'),
    csvHeader44('Средняя скорость потока, м/с'),
    csvHeader44('Расход воды, м3/с'),
    csvHeader44('Комментарии'),
    csvHeader44('Предупреждения'),
    ...csvExtraHeaders44,
  ]);
  final metadata44 = Map<String, dynamic>.from(m.toJson())..remove('verticals');
  final geometry44 = m.geometry44 ? sectionGeometry44(m) : null;
  final formulaIds44 = {
    for (final entry in usedFormulaGroups(m).keys.indexed)
      entry.$2: 'F${entry.$1 + 1}',
  };
  for (final v in m.verticals.isEmpty ? [VerticalPoint(id: '')] : m.verticals) {
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
      formulaIds44[formulaSignature(v)] ?? '',
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
      ...csvExtras44(m, v, metadata44, geometry44),
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
      if (m.iceCover && m.verticals.any((v) => v.iceThicknessCm != null))
        tr('Толщина льда, см'),
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
            if (m.iceCover && m.verticals.any((v) => v.iceThicknessCm != null))
              _numCell(v.iceThicknessCm, 2),
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
