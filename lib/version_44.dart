part of 'main.dart';

const zeroDepthWarning =
    'В створе обнаружены промеры с нулевой глубиной. Проверьте исходные данные. Если они соответствуют суше между разными рукавами в створе, выполните отдельное измерение для каждого рукава или выберите другой створ. Текущая версия приложения не умеет выполнять расчёты для нескольких рукавов в створе.';
const drySpeedWarning =
    'После учёта изменения уровня воды скоростные вертикали оказались на осушившемся участке. Проверьте уровни воды и исходные данные. Расчёт расхода недоступен, пока эти вертикали отмечены как скоростные. Введённые значения сохранены.';
const splitSectionWarning =
    'После учёта изменения уровня воды в створе образовалось несколько отдельных водных участков. Текущая версия приложения не поддерживает общий расчёт расхода для такого сечения. Проверьте исходные данные. Если разделение соответствует действительности, выполните отдельное измерение для каждого рукава или выберите другой створ. Введённые значения сохранены.';
const invalidSlopeWarning =
    'Невозможно продолжить крайний склон выбранного берега. Для экстраполяции нужны нулевая глубина на исходном урезе и увеличивающаяся к руслу глубина соседнего промера. Выберите вертикальный берег или проверьте промеры.';
const lowerLevelWarning =
    'Уровень воды снизился. Расчёт выполнен по водной части исходного профиля с новыми урезами. Исходные промеры сохранены; новое положение уровня показано пунктиром.';
const higherLevelWarning =
    'Уровень воды повысился. Выберите способ достраивания каждого берега. Достроенные участки являются расчётным предположением; исходные промеры сохранены.';

void updateZeroWarning(WdcMeasurement m) {
  m.warnings.removeWhere(
    (w) => [
      zeroDepthWarning,
      drySpeedWarning,
      splitSectionWarning,
      invalidSlopeWarning,
      lowerLevelWarning,
      higherLevelWarning,
    ].contains(w),
  );
  if (m.verticals.any((v) => v.bank == null && v.avgDepth == 0)) {
    m.warnings.add(zeroDepthWarning);
  }
}

double? levelDelta(WdcMeasurement m) {
  if ([
    m.levelSoundingStart,
    m.levelSoundingEnd,
    m.levelVelocityStart,
    m.levelVelocityEnd,
  ].any((v) => v == null)) {
    return null;
  }
  return roundTo(
    roundTo((m.levelVelocityStart! + m.levelVelocityEnd!) / 2, 3) -
        roundTo((m.levelSoundingStart! + m.levelSoundingEnd!) / 2, 3),
    3,
  );
}

// Calculated points never enter the list of field observations.
class SectionPoint44 {
  const SectionPoint44(this.x, this.depth);
  final double x;
  final double depth; // Relative to the original reference, positive downwards.
}

class WetSegment44 {
  const WetSegment44(this.a, this.b, this.ha, this.hb, this.row);
  final SectionPoint44 a, b;
  final double ha, hb;
  final int row;
  double get width => (b.x - a.x).abs();
  double get area => width * (ha + hb) / 2;
  double get perimeter => math.sqrt(width * width + math.pow(hb - ha, 2));
}

class Geometry44 {
  Geometry44(this.points, this.wet, this.delta, this.invalidSlope);
  final List<SectionPoint44> points;
  final List<WetSegment44> wet;
  final double delta;
  final bool invalidSlope;
  int get waterBodies {
    var count = 0;
    WetSegment44? previous;
    for (final s in wet) {
      if (previous == null ||
          (previous.b.x - s.a.x).abs() > 1e-8 ||
          (previous.hb == 0 && s.ha == 0)) {
        count++;
      }
      previous = s;
    }
    return count;
  }
}

Geometry44 sectionGeometry44(WdcMeasurement m) {
  final delta = levelDelta(m) ?? 0;
  final points = m.verticals
      .map((v) => SectionPoint44(v.distance ?? 0, v.avgDepth ?? 0))
      .toList();
  final rows = List.generate(points.length, (i) => i);
  var invalid = false;
  if (points.length >= 2 && delta > 0) {
    // Directions follow the labelled banks, including decreasing chainages.
    for (final left in [true, false]) {
      if (!(left ? m.leftExtrapolation : m.rightExtrapolation)) continue;
      final i = left ? 0 : points.length - 1;
      final j = left ? 1 : points.length - 2;
      final bank = points[i], near = points[j];
      final dx = bank.x - near.x;
      final dh = near.depth - bank.depth;
      if (bank.depth != 0 || dh <= 0 || dx == 0) {
        invalid = true;
        continue;
      }
      final outer = SectionPoint44(bank.x + dx * delta / dh, -delta);
      if (left) {
        points.insert(0, outer);
        rows.insert(0, 0);
      } else {
        points.add(outer);
        rows.add(m.verticals.length - 1);
      }
    }
  }
  final wet = <WetSegment44>[];
  for (var i = 1; i < points.length; i++) {
    var a = points[i - 1], b = points[i];
    var ha = a.depth + delta, hb = b.depth + delta;
    if (ha <= 0 && hb <= 0) continue;
    if (ha < 0) {
      a = SectionPoint44(a.x + (b.x - a.x) * (-ha) / (hb - ha), -delta);
      ha = 0;
    }
    if (hb < 0) {
      b = SectionPoint44(a.x + (b.x - a.x) * ha / (ha - hb), -delta);
      hb = 0;
    }
    wet.add(WetSegment44(a, b, ha, hb, rows[i]));
  }
  return Geometry44(points, wet, delta, invalid);
}

void calculateGeometry44(WdcMeasurement m) {
  final g = sectionGeometry44(m);
  for (final v in m.verticals) {
    v.correctedDepth = v.avgDepth == null
        ? null
        : roundTo(math.max(0, v.avgDepth! + g.delta), 3);
    v.correctedAreaBetween = 0;
    v.wettedBetween = 0;
  }
  var area = 0.0, width = 0.0, perimeter = 0.0, maxDepth = 0.0;
  for (final s in g.wet) {
    area += s.area;
    width += s.width;
    perimeter += s.perimeter;
    maxDepth = math.max(maxDepth, math.max(s.ha, s.hb));
    final v = m.verticals[s.row];
    v.correctedAreaBetween = (v.correctedAreaBetween ?? 0) + s.area;
    v.wettedBetween = (v.wettedBetween ?? 0) + s.perimeter;
  }
  if (g.wet.isNotEmpty) {
    perimeter += g.wet.first.ha + g.wet.last.hb;
    m.verticals.first.wettedBetween =
        (m.verticals.first.wettedBetween ?? 0) + g.wet.first.ha;
    m.verticals.last.wettedBetween =
        (m.verticals.last.wettedBetween ?? 0) + g.wet.last.hb;
  }
  if (m.iceCover) perimeter += width;
  m.width = roundTo(width, 3);
  m.area = roundTo(area, 6);
  m.maxDepth = roundTo(maxDepth, 3);
  m.wettedPerimeter = roundTo(perimeter, 3);
  m.meanDepth = width > 0 ? roundTo(area / width, 3) : null;
  m.hydraulicRadius = perimeter > 0 ? roundTo(area / perimeter, 3) : null;
  if (g.delta > 0) m.warnings.add(higherLevelWarning);
  if (g.delta < 0) m.warnings.add(lowerLevelWarning);
  if (g.invalidSlope) m.warnings.add(invalidSlopeWarning);
  if (m.verticals.any(
    (v) => v.isSpeedVertical && (v.correctedDepth ?? 0) <= 0,
  )) {
    m.warnings.add(drySpeedWarning);
  }
  if (g.waterBodies > 1) m.warnings.add(splitSectionWarning);
  if (calculationBlock44(m) != null) return;
  _computeVelocitySections(m);
}

String? calculationBlock44(WdcMeasurement m) {
  for (final w in [invalidSlopeWarning, drySpeedWarning, splitSectionWarning]) {
    if (m.warnings.contains(w)) return w;
  }
  return null;
}

bool canMeasureSpeed44(VerticalPoint v) =>
    v.bank == null && (v.avgDepth ?? 0) > 0;

bool changeDepth44(
  WdcMeasurement m,
  VerticalPoint v,
  double? value, {
  required bool second,
  required bool confirmed,
}) {
  final old = second ? v.depth2 : v.depth1;
  if (old == value) return false;
  final hasSpeed = v.velocityPoints.values.any((p) => p.value != null);
  if (hasSpeed && !confirmed) return false;
  if (hasSpeed) {
    for (final p in v.velocityPoints.values) {
      p.value = null;
      p.changedAt = null;
    }
    v.sectionArea = null;
    v.partialDischarge = null;
  }
  if (second) {
    v.depth2 = value;
    v.depth2At = measurementNow(m);
  } else {
    v.depth1 = value;
    v.depth1At = measurementNow(m);
  }
  recordSoundingInput(m);
  recalcAll(m);
  if (!canMeasureSpeed44(v)) v.isSpeedVertical = false;
  return true;
}

class Warning44 extends StatelessWidget {
  const Warning44(this.title, this.message, {super.key, this.child});
  final String title, message;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF472F36)
        : const Color(0xFFFFEBEE),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(title), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(tr(message)),
          if (child != null) child!,
        ],
      ),
    ),
  );
}

String bankMode44(bool slope) =>
    tr(slope ? 'Продолжить крайний склон' : 'Вертикальный берег');

class LevelOptions44 extends StatelessWidget {
  const LevelOptions44({super.key, required this.m, required this.onChanged});
  final WdcMeasurement m;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final delta = levelDelta(m);
    if (delta == null || delta == 0) return const SizedBox.shrink();
    return Warning44(
      delta > 0
          ? 'Выбор способа экстраполяции берегов'
          : 'Понижение уровня воды',
      delta > 0 ? higherLevelWarning : lowerLevelWarning,
      child: delta <= 0
          ? null
          : Column(
              children: [
                for (final left in [true, false])
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: DropdownButtonFormField<bool>(
                      key: ValueKey(
                        left ? 'left-bank-mode' : 'right-bank-mode',
                      ),
                      initialValue: left
                          ? m.leftExtrapolation
                          : m.rightExtrapolation,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: bankLabel(left ? 'ЛБ' : 'ПБ'),
                      ),
                      items: [
                        for (final slope in [false, true])
                          DropdownMenuItem(
                            value: slope,
                            child: Text(bankMode44(slope)),
                          ),
                      ],
                      onChanged: (slope) {
                        if (left) {
                          m.leftExtrapolation = slope!;
                        } else {
                          m.rightExtrapolation = slope!;
                        }
                        onChanged();
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class IceProfile44 extends StatelessWidget {
  const IceProfile44({super.key, required this.m});
  final WdcMeasurement m;
  @override
  Widget build(BuildContext context) =>
      !m.iceCover || !m.verticals.any((v) => v.iceThicknessCm != null)
      ? const SizedBox.shrink()
      : SizedBox(
          height: 210,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CustomPaint(
                painter: ProfilePainter44(
                  m,
                  ice: true,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
}

class ProfilePainter44 extends CustomPainter {
  ProfilePainter44(
    this.m, {
    this.ice = false,
    this.dark = false,
    this.picked = const {},
    this.velocities = true,
    this.discharges = false,
  });
  final WdcMeasurement m;
  final bool ice, dark, velocities, discharges;
  final Set<String> picked;
  @override
  void paint(Canvas c, Size size) {
    final source = m.verticals;
    if (source.length < 2) return;
    final g = sectionGeometry44(m);
    final pts = g.points;
    final minX = pts.map((p) => p.x).reduce(math.min),
        maxX = pts.map((p) => p.x).reduce(math.max);
    final invert =
        (m.leftBank?.distance ?? minX) > (m.rightBank?.distance ?? maxX);
    final delta = m.geometry44 ? (levelDelta(m) ?? 0) : 0.0;
    final minY = ice ? 0.0 : math.min(0.0, -delta);
    final maxY = ice
        ? math.max(
            1.0,
            source.map((v) => v.iceThicknessCm ?? 0).reduce(math.max),
          )
        : math.max(
            math.max(.1, -delta),
            source.map((v) => v.avgDepth ?? 0).reduce(math.max),
          );
    const left = 76.0, top = 62.0, right = 22.0, bottom = 30.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    double sx(double x) =>
        left + (invert ? maxX - x : x - minX) / math.max(.001, maxX - minX) * w;
    double sy(double y) => top + (y - minY) / math.max(.001, maxY - minY) * h;
    final ink = dark ? Colors.white : Colors.black87;
    final bedColor = dark ? const Color(0xFFD7B49E) : Colors.brown.shade700;
    final helper = CrossSectionPainter(measurement: m);
    void text(
      String t,
      Offset p, {
      double anchor = 0,
      double font = 11,
      Color? color,
    }) => helper._text(c, t, p, color ?? ink, font, anchorX: anchor);
    final axis = Paint()
      ..color = ink.withValues(alpha: .65)
      ..strokeWidth = 1;
    if (ice) {
      for (var i = 1; i < source.length; i++) {
        final a = source[i - 1], b = source[i];
        if (a.distance == null ||
            b.distance == null ||
            a.iceThicknessCm == null ||
            b.iceThicknessCm == null) {
          continue;
        }
        final p = Path()
          ..moveTo(sx(a.distance!), sy(0))
          ..lineTo(sx(a.distance!), sy(a.iceThicknessCm!))
          ..lineTo(sx(b.distance!), sy(b.iceThicknessCm!))
          ..lineTo(sx(b.distance!), sy(0))
          ..close();
        c.drawPath(
          p,
          Paint()
            ..color = dark ? const Color(0xFF426B7D) : const Color(0xFFD5EEF8),
        );
        c.drawLine(
          Offset(sx(a.distance!), sy(a.iceThicknessCm!)),
          Offset(sx(b.distance!), sy(b.iceThicknessCm!)),
          Paint()
            ..color = Colors.lightBlue
            ..strokeWidth = 2,
        );
      }
      for (final v in source) {
        if (v.iceThicknessCm != null && v.distance != null) {
          c.drawCircle(
            Offset(sx(v.distance!), sy(v.iceThicknessCm!)),
            3,
            Paint()..color = Colors.lightBlue,
          );
        }
      }
    } else {
      for (final s in g.wet) {
        final p = Path()
          ..moveTo(sx(s.a.x), sy(-delta))
          ..lineTo(sx(s.a.x), sy(s.a.depth))
          ..lineTo(sx(s.b.x), sy(s.b.depth))
          ..lineTo(sx(s.b.x), sy(-delta))
          ..close();
        c.drawPath(
          p,
          Paint()
            ..color = dark ? const Color(0xFF214557) : const Color(0xFFDCF3FD),
        );
      }
      c.drawLine(
        Offset(left, sy(0)),
        Offset(left + w, sy(0)),
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 1.4,
      );
      if (delta != 0) {
        for (var x = left; x < left + w; x += 10) {
          c.drawLine(
            Offset(x, sy(-delta)),
            Offset(math.min(x + 6, left + w), sy(-delta)),
            Paint()
              ..color = dark ? Colors.lightBlueAccent : Colors.blue.shade800
              ..strokeWidth = 1.8,
          );
        }
        final label = TextPainter(
          text: TextSpan(
            text: '${tr('Изменение уровня')}: ${inputNumber(delta)} ${tr('м')}',
            style: TextStyle(fontFamily: 'WdcReport', fontSize: 10, color: ink),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: w);
        label.paint(c, Offset(left + (w - label.width) / 2, top + h + 8));
      }
      // Velocity lines first; the bed and measured bed points remain in front.
      for (final v in source.where(
        (v) => v.isSpeedVertical || picked.contains(v.id),
      )) {
        if (v.distance == null) continue;
        final y = v.avgDepth ?? 0;
        final color = picked.contains(v.id)
            ? Colors.red
            : v.avgVelocity == null
            ? ink
            : Colors.green;
        c.drawLine(
          Offset(sx(v.distance!), sy(-delta)),
          Offset(sx(v.distance!), sy(y)),
          Paint()
            ..color = color
            ..strokeWidth = 2,
        );
        if (velocities) {
          for (final e in v.velocityPoints.entries) {
            if (e.value.value == null) continue;
            final height = math.max(0, y + delta);
            final d = m.rotorDiameter ?? 0;
            final pos = e.key == 'surface'
                ? d / 2 + .01
                : e.key == 'bottom'
                ? height - d / 2 - .01
                : double.parse('0.${e.key.substring(1)}') * height;
            if (pos < 0 || pos > height) continue;
            c.drawCircle(
              Offset(sx(v.distance!), sy(pos - delta)),
              3.5,
              Paint()..color = velocityPointColor(v, e.key, dark: dark),
            );
          }
        }
      }
      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1], b = pts[i];
        final extra =
            (i == 1 && pts.first.x != source.first.distance) ||
            (i == pts.length - 1 && pts.last.x != source.last.distance);
        c.drawLine(
          Offset(sx(a.x), sy(a.depth)),
          Offset(sx(b.x), sy(b.depth)),
          Paint()
            ..color = extra ? Colors.red : bedColor
            ..strokeWidth = 2.3,
        );
      }
      for (final v in source) {
        c.drawCircle(
          Offset(sx(v.distance ?? 0), sy(v.avgDepth ?? 0)),
          3.5,
          Paint()..color = bedColor,
        );
      }
      for (final edge in [pts.first, pts.last]) {
        if (edge.depth + delta > 0) {
          c.drawLine(
            Offset(sx(edge.x), sy(-delta)),
            Offset(sx(edge.x), sy(edge.depth)),
            Paint()
              ..color = delta > 0 ? Colors.red : bedColor
              ..strokeWidth = 2.3,
          );
        }
      }
    }
    if (!ice && discharges) {
      final speed = source.where((v) => v.isSpeedVertical).toList();
      final inner = speed
          .skip(1)
          .map((v) => v.partialDischarge)
          .whereType<double>()
          .toList();
      final mean = inner.isEmpty
          ? null
          : inner.reduce((a, b) => a + b) / inner.length;
      for (var i = 0; i < source.length; i++) {
        final v = source[i];
        final q = v.partialDischarge;
        if (q == null || v.distance == null) continue;
        final edge =
            (speed.isNotEmpty && v.id == speed.first.id) ||
            i == source.length - 1;
        final color = edge && mean != null && mean > 0 && q / mean > .3
            ? Colors.red
            : ink;
        helper._text(
          c,
          '${fmtAdaptive(q, small: 1)}\n${tr('м³/с')}',
          Offset(
            sx(v.distance!) + 4,
            sy(-delta + (v.correctedDepth ?? v.avgDepth ?? 0) * .55),
          ),
          color,
          11,
          bold: true,
        );
      }
    }
    c.drawLine(const Offset(left, top), Offset(left, top + h), axis);
    c.drawLine(const Offset(left, top), Offset(left + w, top), axis);
    final xStep = helper._niceStep((maxX - minX) / 5);
    for (
      double x = (minX / xStep).ceil() * xStep;
      x <= maxX + 1e-8;
      x += xStep
    ) {
      c.drawLine(Offset(sx(x), top), Offset(sx(x), top - 4), axis);
      text(helper._formatTick(x, xStep), Offset(sx(x), top - 21), anchor: .5);
    }
    final yStep = helper._niceStep((maxY - minY) / 4);
    for (
      double y = (minY / yStep).ceil() * yStep;
      y <= maxY + 1e-8;
      y += yStep
    ) {
      c.drawLine(Offset(left - 4, sy(y)), Offset(left, sy(y)), axis);
      text(
        helper._formatTick(y, yStep),
        Offset(left - 8, sy(y) - 6),
        anchor: 1,
      );
    }
    text(bankLabel('ЛБ'), const Offset(left, 8), font: 14);
    text(bankLabel('ПБ'), Offset(left + w, 8), anchor: 1, font: 14);
    text(tr('Расст., м'), Offset(left + w / 2, 8), anchor: .5, font: 12);
    helper._rotatedText(
      c,
      tr(
        ice
            ? 'Толщина льда, см'
            : m.iceCover
            ? 'Рабочая глубина, м'
            : 'Глуб., м',
      ),
      Offset(8, top + h / 2 + 40),
      ink,
      12,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Future<void> showInfo44(BuildContext context, String title, String text) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Закрыть')),
          ),
        ],
      ),
    );
const rotorHelp44 =
    'Выбор лопастного диаметра вертушки не влияет на расчёт расхода воды, а нужен лишь для подсказки рекомендуемых МИ 1759-87 горизонтов измерений на вертикали в зависимости от отношения h/D. Здесь h — рабочая глубина, D — лопастной диаметр вертушки.';

String? previewTheme44;

Future<void> shareFiles44(
  List<XFile> files, {
  String? text,
  String? subject,
}) async {
  if (Platform.isAndroid) {
    try {
      await const MethodChannel('krv.app/actions').invokeMethod<void>(
        'shareFiles',
        {
          'paths': files.map((f) => f.path).toList(),
          'text': text,
          'subject': subject,
        },
      );
      return;
    } on MissingPluginException {
      /* Other platforms and older test harnesses use the package implementation. */
    }
  }
  await Share.shareXFiles(files, text: text, subject: subject);
}

Future<Uint8List> icePng44(WdcMeasurement m) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(2);
  ProfilePainter44(m, ice: true).paint(canvas, const Size(720, 190));
  final picture = recorder.endRecording();
  final image = await picture.toImage(1440, 380);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

// Permanent machine-readable suffix; existing columns keep their order.
const csvExtraHeaders44 = <String>[
  'csv_schema_version',
  'app_version',
  'measurement_id',
  'vertical_id',
  'completed',
  'ice_thickness_cm',
  'geometry_method',
  'left_bank_mode',
  'right_bank_mode',
  'calculated_left_water_edge_m',
  'calculated_right_water_edge_m',
  'calculated_left_extension_area_m2',
  'calculated_right_extension_area_m2',
  'measurement_metadata_json',
  'vertical_data_json',
  'calculated_profile_json',
];
List<Object?> csvExtras44(
  WdcMeasurement m,
  VerticalPoint v,
  Map<String, dynamic> metadata,
  Geometry44? g,
) {
  final first = m.verticals.isEmpty || identical(v, m.verticals.first);
  return [
    '4.4',
    Project44.version,
    m.id,
    v.id,
    m.completed ? 1 : 0,
    v.iceThicknessCm == null ? '' : inputNumber(v.iceThicknessCm),
    m.geometry44 ? 'clipped_profile_v44' : 'legacy',
    m.leftExtrapolation ? 'slope' : 'vertical',
    m.rightExtrapolation ? 'slope' : 'vertical',
    g == null || g.wet.isEmpty ? '' : inputNumber(g.wet.first.a.x),
    g == null || g.wet.isEmpty ? '' : inputNumber(g.wet.last.b.x),
    g == null ||
            g.points.isEmpty ||
            g.points.first.x == m.verticals.first.distance
        ? ''
        : inputNumber(g.wet.first.area),
    g == null ||
            g.points.isEmpty ||
            g.points.last.x == m.verticals.last.distance
        ? ''
        : inputNumber(g.wet.last.area),
    first ? jsonEncode(metadata) : '',
    jsonEncode(v.toJson()),
    first && g != null
        ? jsonEncode({
            'reference': 'original_depth_m',
            'level_delta_m': g.delta,
            'points': g.points
                .map((p) => {'distance_m': p.x, 'depth_m': p.depth})
                .toList(),
            'wet_segments': g.wet
                .map(
                  (s) => {
                    'from_m': s.a.x,
                    'to_m': s.b.x,
                    'depth_from_m': s.ha,
                    'depth_to_m': s.hb,
                    'area_m2': s.area,
                  },
                )
                .toList(),
          })
        : '',
  ];
}

String csvHeader44(String label) => label;

const english44 = <String, String>{
  'Глубина с поправкой, м': 'Corrected depth, m',
  "Фото": "Photos",
  "Подпись к фото": "Photo caption",
  "Тема": "Theme",
  "Светлая": "Light",
  "Тёмная": "Dark",
  "О приложении": "About",
  "Проект": "Project",
  "Информация": "Information",
  "Правовая информация": "Legal information",
  "Исходный код": "Source code",
  "Открыть GitHub": "Open GitHub",
  "Обратная связь": "Feedback",
  "Создать Issue": "Create an issue",
  "Написать автору": "Email the author",
  "Цитировать КРВ": "Cite WDC",
  "Поддержать проект": "Support the project",
  "Методическая основа": "Methodological basis",
  "История версий": "Version history",
  "Полная история изменений": "Full changelog",
  "Лицензия Apache 2.0": "Apache License 2.0",
  "Политика конфиденциальности": "Privacy policy",
  "Условия использования": "Terms of use",
  "Лицензии стороннего ПО": "Third-party licences",
  "Сборка": "Build",
  "Версия": "Version",
  "Открыть DOI": "Open DOI",
  "Скопировано": "Copied",
  "Скопировать": "Copy",
  "Ссылка скопирована. Откройте её в браузере.":
      "Link copied. Open it in your browser.",
  "Толщина льда, см": "Ice thickness, cm",
  "Толщина льда": "Ice thickness",
  "Рабочая глубина, м": "Effective depth, m",
  "Необязательно": "Optional",
  "Допишите толщину льда на вертикалях":
      "Enter the missing ice thickness at verticals",
  "Закрыть": "Close",
  "Справка": "Help",
  "Промеры с глубиной 0": "Zero-depth soundings",
  "Расчёт недоступен": "Calculation unavailable",
  "Скоростная вертикаль вне воды": "Velocity vertical outside the water",
  "Сечение разделилось на несколько русел":
      "Cross section split into separate channels",
  "Проверьте форму берега": "Check the bank profile",
  "Выбор способа экстраполяции берегов": "Bank extrapolation method",
  "Понижение уровня воды": "Water level has fallen",
  "Вертикальный берег": "Vertical bank",
  "Продолжить крайний склон": "Extend the outer bed slope",
  "Способ достраивания ЛБ": "Left bank extrapolation",
  "Способ достраивания ПБ": "Right bank extrapolation",
  "Изменить глубину на скоростной вертикали?":
      "Change depth at a velocity vertical?",
  "Вы пытаетесь изменить глубину на скоростной вертикали с введёнными скоростями. Эти скорости будут удалены, если вы нажмёте «Да».":
      "You are changing the depth at a vertical with recorded velocities. These velocities will be deleted if you select Yes.",
  zeroDepthWarning:
      "Internal zero-depth soundings were found in the cross section. Check the input data. If they represent dry land between different channels, measure each channel separately or choose another cross section. This version does not support discharge calculation for multiple channels in one cross section.",
  drySpeedWarning:
      "After accounting for the water-level change, velocity verticals lie in a dry part of the cross section. Check water levels and observations. Discharge cannot be calculated while these verticals are designated as velocity verticals. All entered values have been preserved.",
  splitSectionWarning:
      "After accounting for the water-level change, the cross section contains separate water bodies. This version does not support a combined discharge calculation for this section. Check the inputs. If this separation is real, measure each channel separately or choose another section. All entered values have been preserved.",
  invalidSlopeWarning:
      "The selected bank slope cannot be extended. Extrapolation requires zero depth at the original water edge and increasing depth towards the neighbouring sounding. Select a vertical bank or check the observations.",
  lowerLevelWarning:
      "The water level has fallen. Calculations use the submerged part of the original profile and new water edges. Original soundings are preserved; the new water level is shown as a dashed line.",
  higherLevelWarning:
      "The water level has risen. Select an extrapolation method for each bank. Extended sections are an assumption; original observations are preserved.",
  rotorHelp44:
      "The current-meter rotor diameter does not affect discharge calculation. It is used only to suggest measuring horizons recommended by MI 1759-87 according to h/D, where h is the effective depth and D is the rotor diameter.",
};

String csvVelocity44(String key) => key == 'surface'
    ? 'Uпов'
    : key == 'bottom'
    ? 'Uдно'
    : 'U0.${key.substring(1)}h';
