part of 'main.dart';

// =============================
// Painter
// =============================

class CrossSectionPainter extends CustomPainter {
  CrossSectionPainter({
    required this.measurement,
    this.pickedIds = const {},
    this.showVelocities = false,
    this.showDischarges = false,
    this.yForVelocityPoint,
    this.dark = false,
  });

  final WdcMeasurement measurement;
  final bool dark;
  final Set<String> pickedIds;
  final bool showVelocities;
  final bool showDischarges;
  final double? Function(VerticalPoint, String)? yForVelocityPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final m = measurement;
    if (m.geometry44) {
      ProfilePainter44(
        m,
        dark: dark,
        picked: pickedIds,
        velocities: showVelocities,
        discharges: showDischarges,
      ).paint(canvas, size);
      return;
    }
    if (m.verticals.length < 2) {
      _text(
        canvas,
        tr('Недостаточно данных для графика'),
        const Offset(20, 20),
        dark ? Colors.white : Colors.black,
        14,
      );
      return;
    }
    final ink = dark ? Colors.white : Colors.black;
    final vertices = m.verticals;
    final minX = vertices.map((v) => v.distance ?? 0).reduce(math.min);
    final maxX = vertices.map((v) => v.distance ?? 0).reduce(math.max);
    final maxH = math.max(
      0.1,
      vertices.map((v) => v.correctedDepth ?? v.avgDepth ?? 0).reduce(math.max),
    );
    const left = 76.0;
    const top = 70.0;
    const right = 22.0;
    const bottom = 30.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final dxRange = math.max(0.001, maxX - minX);
    final lbDist = m.leftBank?.distance;
    final rbDist = m.rightBank?.distance;
    final invertX = lbDist != null && rbDist != null && lbDist > rbDist;

    double sx(double x) => invertX
        ? left + (maxX - x) / dxRange * w
        : left + (x - minX) / dxRange * w;
    double sy(double depth) => top + depth / maxH * h;

    final water = Path()..moveTo(sx(vertices.first.distance ?? minX), sy(0));
    for (final v in vertices) {
      water.lineTo(
        sx(v.distance ?? 0),
        sy(v.correctedDepth ?? v.avgDepth ?? 0),
      );
    }
    water.lineTo(sx(vertices.last.distance ?? maxX), sy(0));
    water.close();
    final waterPaint = Paint()
      ..color = const Color(0xFFBDEBFF).withValues(alpha: 0.55);
    canvas.drawPath(water, waterPaint);

    final surfacePaint = Paint()
      ..color = Colors.blue.shade800
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(sx(vertices.first.distance ?? minX), sy(0)),
      Offset(sx(vertices.last.distance ?? maxX), sy(0)),
      surfacePaint,
    );

    final bedPaint = Paint()
      ..color = (dark ? const Color(0xFFD7B49E) : Colors.brown.shade700)
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke;
    final bed = Path();
    for (var i = 0; i < vertices.length; i++) {
      final v = vertices[i];
      final p = Offset(
        sx(v.distance ?? 0),
        sy(v.correctedDepth ?? v.avgDepth ?? 0),
      );
      if (i == 0) {
        bed.moveTo(p.dx, p.dy);
      } else {
        bed.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(bed, bedPaint);

    for (final v in vertices) {
      final x = sx(v.distance ?? 0);
      final y = sy(v.correctedDepth ?? v.avgDepth ?? 0);
      canvas.drawCircle(
        Offset(x, y),
        3.5,
        Paint()
          ..color = (dark ? const Color(0xFFD7B49E) : Colors.brown.shade700),
      );
      if ((v.correctedDepth ?? v.avgDepth ?? 0) > 0 && v.bank != null) {
        canvas.drawLine(Offset(x, sy(0)), Offset(x, y), bedPaint);
      }
    }

    // Axes, ticks and labels
    final axis = Paint()
      ..color = dark ? Colors.white70 : Colors.black54
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(left, top), Offset(left, top + h), axis);
    canvas.drawLine(const Offset(left, top), Offset(left + w, top), axis);

    final xStep = _niceStep(dxRange / 5);
    final xStart = (minX / xStep).ceil() * xStep;
    for (double x = xStart; x <= maxX + xStep * 0.25; x += xStep) {
      final px = sx(x);
      if (px < left - 0.5 || px > left + w + 0.5) continue;
      canvas.drawLine(Offset(px, top), Offset(px, top - 5), axis);
      _text(
        canvas,
        _formatTick(x, xStep),
        Offset(px, top - 22),
        dark ? Colors.white70 : Colors.black87,
        11,
        anchorX: 0.5,
      );
    }

    final yStep = _niceStep(maxH / 5);
    for (double y = 0; y <= maxH + yStep * 0.25; y += yStep) {
      final py = sy(y);
      if (py < top - 0.5 || py > top + h + 0.5) continue;
      canvas.drawLine(Offset(left - 5, py), Offset(left, py), axis);
      _text(
        canvas,
        _formatTick(y, yStep),
        Offset(left - 9, py - 7),
        dark ? Colors.white70 : Colors.black87,
        11,
        anchorX: 1,
      );
    }

    _text(canvas, bankLabel('ЛБ'), const Offset(left, 10), ink, 17, bold: true);
    _text(
      canvas,
      bankLabel('ПБ'),
      Offset(left + w - 28, 10),
      ink,
      17,
      bold: true,
    );
    _rotatedText(canvas, tr('Глуб., м'), Offset(5, top + h / 2 + 32), ink, 14);
    _text(
      canvas,
      tr('Расст., м'),
      Offset(left + w / 2, 12),
      ink,
      14,
      anchorX: 0.5,
    );

    for (final v in vertices.where(
      (v) => pickedIds.contains(v.id) || v.isSpeedVertical,
    )) {
      final x = sx(v.distance ?? 0);
      final depth = v.correctedDepth ?? v.avgDepth ?? 0;
      Color color;
      if (pickedIds.contains(v.id) && !v.isSpeedVertical) {
        color = Colors.red;
      } else if (v.avgVelocity != null) {
        color = Colors.green.shade700;
      } else {
        color = ink;
      }
      canvas.drawLine(
        Offset(x, sy(0)),
        Offset(x, sy(depth)),
        Paint()
          ..color = color
          ..strokeWidth = 2.2,
      );

      if (showVelocities) {
        final points = v.velocityPoints;
        for (final entry in points.entries) {
          if (entry.value.value == null) continue;
          final yy =
              yForVelocityPoint?.call(v, entry.key) ??
              _defaultYFor(m, v, entry.key);
          if (yy == null) continue;
          canvas.drawCircle(
            Offset(x, sy(yy)),
            4,
            Paint()..color = velocityPointColor(v, entry.key, dark: dark),
          );
        }
      }
    }

    canvas.drawPath(bed, bedPaint);

    for (final v in vertices) {
      final x = sx(v.distance ?? 0);
      final y = sy(v.correctedDepth ?? v.avgDepth ?? 0);
      canvas.drawCircle(
        Offset(x, y),
        3.5,
        Paint()
          ..color = (dark ? const Color(0xFFD7B49E) : Colors.brown.shade700),
      );
      if ((v.correctedDepth ?? v.avgDepth ?? 0) > 0 && v.bank != null) {
        canvas.drawLine(Offset(x, sy(0)), Offset(x, y), bedPaint);
      }
    }

    if (showDischarges) {
      final internal = <double>[];
      final speed = vertices.where((v) => v.isSpeedVertical).toList();
      if (speed.length >= 2) {
        for (var i = 1; i < speed.length; i++) {
          final q = speed[i].partialDischarge;
          if (q != null) internal.add(q);
        }
      }
      final meanInternal = internal.isEmpty
          ? null
          : internal.reduce((a, b) => a + b) / internal.length;

      for (var i = 0; i < vertices.length; i++) {
        final v = vertices[i];
        final q = v.partialDischarge;
        if (q == null) continue;
        var color = ink;
        if (meanInternal != null && meanInternal > 0) {
          final firstSpeedId = speed.isNotEmpty ? speed.first.id : null;
          final isEdge = v.id == firstSpeedId || i == vertices.length - 1;
          if (isEdge && q / meanInternal > 0.3) color = Colors.red;
        }
        final x = sx(v.distance ?? 0);
        final y = sy((v.correctedDepth ?? v.avgDepth ?? 0) * 0.55);
        _text(
          canvas,
          '${fmtAdaptive(q, small: 1)}\n${tr('м³/с')}',
          Offset(x + 4, y),
          color,
          11,
          bold: true,
        );
      }
    }
  }

  double? _defaultYFor(WdcMeasurement m, VerticalPoint v, String key) {
    final h = v.correctedDepth ?? v.avgDepth;
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

  double _niceStep(double raw) {
    if (raw <= 0 || raw.isNaN || raw.isInfinite) return 1;
    final exponent = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final fraction = raw / exponent;
    double niceFraction;
    if (fraction <= 1) {
      niceFraction = 1;
    } else if (fraction <= 2) {
      niceFraction = 2;
    } else if (fraction <= 2.5) {
      niceFraction = 2.5;
    } else if (fraction <= 5) {
      niceFraction = 5;
    } else {
      niceFraction = 10;
    }
    return niceFraction * exponent;
  }

  String _formatTick(double value, double step) {
    final a = step.abs();
    int digits;
    if (a >= 1) {
      digits = 0;
    } else if (a >= 0.1) {
      digits = 1;
    } else if (a >= 0.01) {
      digits = 2;
    } else {
      digits = 3;
    }
    return roundTo(value, digits).toStringAsFixed(digits);
  }

  void _rotatedText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(-math.pi / 2);
    _text(canvas, text, Offset.zero, color, fontSize, bold: bold);
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    bool bold = false,
    double anchorX = 0,
  }) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'WdcReport',
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    );
    final tp = TextPainter(
      text: span,
      textDirection: ui.TextDirection.ltr,
      maxLines: 3,
    );
    tp.layout(maxWidth: 90);
    tp.paint(canvas, Offset(offset.dx - tp.width * anchorX, offset.dy));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
