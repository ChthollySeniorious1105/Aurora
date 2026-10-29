import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class YavalathBoard extends StatefulWidget {
  final GameContext g;
  const YavalathBoard(this.g, {super.key});

  @override
  State<YavalathBoard> createState() => _YavalathBoardState();
}

class _YavalathBoardState extends State<YavalathBoard> {
  (int, int)? _confirmSuicideCell;

  Offset _axialToPixel(int q, int r, double step) {
    final x = step * 1.5 * q;
    final y = step * sqrt(3) * (r + q * 0.5);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final radius = (v['radius'] as num?)?.toInt() ?? 4;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final moveCount = (v['moveCount'] as num?)?.toInt() ?? 0;
    final totalCells = (v['totalCells'] as num?)?.toInt() ?? 61;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final endedBySuicide = v['endedBySuicide'] == true;
    final highlightRaw = (v['highlightLine'] as List?) ?? const [];
    final cellsList = (v['cells'] as List?)?.cast<Map>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final cellMap = <(int, int), Map>{};
    var whiteCount = 0;
    var blackCount = 0;
    for (final c in cellsList) {
      final q = (c['q'] as num).toInt();
      final r = (c['r'] as num).toInt();
      final col = (c['color'] as num).toInt();
      if (col == 0) whiteCount++;
      if (col == 1) blackCount++;
      cellMap[(q, r)] = c;
    }

    final highlightSet = <(int, int)>{
      for (final item in highlightRaw)
        if (item is List && item.length >= 2) ((item[0] as num).toInt(), (item[1] as num).toInt()),
    };

    final isMyTurn = !over && g.seat == turn;
    if (!isMyTurn) _confirmSuicideCell = null;

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_confirmSuicideCell != null) {
        statusText = '警告：$_confirmSuicideCell 会形成三连自杀判负！再次点击该格确认落子';
      } else {
        statusText = '轮到你落子：连成 4 子即胜，切勿连成 3 子（红叉格为三连禁手提示）';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 落子（第 ${moveCount + 1}/$totalCells 手）…';
    }

    Widget buildPlayerPanel(int s) {
      final colorLabel = s == 0 ? '白子' : '黑子';
      final count = s == 0 ? whiteCount : blackCount;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · 已落 $count 子',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s == 0 ? const Color(0xFFFDFBF7) : const Color(0xFF22252A),
            border: Border.all(
              color: s == 0 ? Colors.brown.shade400 : Colors.grey.shade400,
              width: 1.5,
            ),
          ),
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();
          final hexStep = side / (radius == 3 ? 12.2 : 15.2);
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn
                ? null
                : (details) {
                    final tap = details.localPosition - center;
                    (int, int)? hit;
                    var bestDist = hexStep * 0.85;
                    for (final pos in cellMap.keys) {
                      final d = (tap - _axialToPixel(pos.$1, pos.$2, hexStep)).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        hit = pos;
                      }
                    }
                    if (hit == null) {
                      setState(() => _confirmSuicideCell = null);
                      return;
                    }
                    final c = cellMap[hit]!;
                    if ((c['color'] as num).toInt() != -1) {
                      setState(() => _confirmSuicideCell = null);
                      return;
                    }
                    final isSuicide = c['suicideHint'] == true;
                    if (isSuicide && _confirmSuicideCell != hit) {
                      setState(() => _confirmSuicideCell = hit);
                      return;
                    }
                    setState(() => _confirmSuicideCell = null);
                    g.act({
                      'type': 'place',
                      'q': hit.$1,
                      'r': hit.$2,
                    });
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _YavalathPainter(
                cellMap: cellMap,
                radius: radius,
                highlightSet: highlightSet,
                endedBySuicide: endedBySuicide,
                confirmSuicideCell: _confirmSuicideCell,
                lastMove: lastMove,
                isMyTurn: isMyTurn,
                hexStep: hexStep,
                cs: cs,
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, outer) {
        final isWide = outer.maxWidth >= 680 && outer.maxWidth > outer.maxHeight * 1.15;

        return Stack(
          children: [
            Container(
              color: g.table,
              padding: const EdgeInsets.all(8),
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: min(235, outer.maxWidth * 0.28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildPlayerPanel(1),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: StatusBar(statusText, highlight: isMyTurn),
                                  ),
                                ),
                              ),
                              buildPlayerPanel(0),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: buildPlayerPanel(0)),
                            const SizedBox(width: 6),
                            Expanded(child: buildPlayerPanel(1)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    ),
            ),
            if (over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _YavalathPainter extends CustomPainter {
  final Map<(int, int), Map> cellMap;
  final int radius;
  final Set<(int, int)> highlightSet;
  final bool endedBySuicide;
  final (int, int)? confirmSuicideCell;
  final Map? lastMove;
  final bool isMyTurn;
  final double hexStep;
  final ColorScheme cs;

  _YavalathPainter({
    required this.cellMap,
    required this.radius,
    required this.highlightSet,
    required this.endedBySuicide,
    required this.confirmSuicideCell,
    required this.lastMove,
    required this.isMyTurn,
    required this.hexStep,
    required this.cs,
  });

  Offset _pos(int q, int r, Offset center) {
    final x = hexStep * 1.5 * q;
    final y = hexStep * sqrt(3) * (r + q * 0.5);
    return center + Offset(x, y);
  }

  Path _hexPolygon(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bgRadius = hexStep * (radius == 3 ? 5.6 : 7.3);

    final bgPath = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + pi / 6;
      final pt = Offset(center.dx + bgRadius * cos(a), center.dy + bgRadius * sin(a));
      if (i == 0) {
        bgPath.moveTo(pt.dx, pt.dy);
      } else {
        bgPath.lineTo(pt.dx, pt.dy);
      }
    }
    bgPath.close();

    canvas.drawShadow(bgPath, Colors.black54, 8, false);
    canvas.drawPath(
      bgPath,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF2E3B36), const Color(0xFF19221E)],
        ).createShader(Rect.fromCircle(center: center, radius: bgRadius)),
    );
    canvas.drawPath(
      bgPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.65),
    );

    final lastQ = (lastMove?['q'] as num?)?.toInt();
    final lastR = (lastMove?['r'] as num?)?.toInt();

    for (final entry in cellMap.entries) {
      final (q, r) = entry.key;
      final c = entry.value;
      final color = (c['color'] as num).toInt();
      final winHint = c['winHint'] == true;
      final suicideHint = c['suicideHint'] == true;
      final isHighlighted = highlightSet.contains((q, r));
      final isLast = lastQ == q && lastR == r;
      final isConfirming = confirmSuicideCell == (q, r);
      final p = _pos(q, r, center);
      final hexPath = _hexPolygon(p, hexStep * 0.54);

      Color cellFill = Colors.white.withValues(alpha: 0.07);
      if (isHighlighted) {
        cellFill = (endedBySuicide ? Colors.redAccent : Colors.amberAccent).withValues(alpha: 0.35);
      } else if (isConfirming) {
        cellFill = Colors.redAccent.withValues(alpha: 0.35);
      } else if (isMyTurn && winHint) {
        cellFill = Colors.greenAccent.withValues(alpha: 0.22);
      }

      canvas.drawPath(hexPath, Paint()..color = cellFill);
      canvas.drawPath(
        hexPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHighlighted ? 2.2 : 1.1
          ..color = isHighlighted
              ? (endedBySuicide ? Colors.redAccent : Colors.amberAccent)
              : Colors.white.withValues(alpha: 0.20),
      );

      if (color == -1) {
        if (isMyTurn && winHint) {
          canvas.drawCircle(
            p,
            hexStep * 0.18,
            Paint()..color = Colors.greenAccent.withValues(alpha: 0.8),
          );
        } else if (isMyTurn && suicideHint) {
          // Small cross warning on 3-in-a-row suicide hex
          final d = hexStep * 0.14;
          final xPaint = Paint()
            ..color = Colors.redAccent.withValues(alpha: isConfirming ? 0.95 : 0.55)
            ..strokeWidth = isConfirming ? 2.4 : 1.6
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(p + Offset(-d, -d), p + Offset(d, d), xPaint);
          canvas.drawLine(p + Offset(-d, d), p + Offset(d, -d), xPaint);
        } else {
          canvas.drawCircle(
            p,
            hexStep * 0.08,
            Paint()..color = Colors.white.withValues(alpha: 0.18),
          );
        }
      } else {
        final isWhite = color == 0;
        final stoneRadius = hexStep * 0.41;

        if (isHighlighted || isLast) {
          canvas.drawCircle(
            p,
            stoneRadius + 3.5,
            Paint()
              ..color = isHighlighted
                  ? (endedBySuicide ? Colors.redAccent : Colors.amberAccent).withValues(alpha: 0.85)
                  : Colors.lightBlueAccent.withValues(alpha: 0.55),
          );
        }

        canvas.drawCircle(
          p + const Offset(1.4, 2.2),
          stoneRadius,
          Paint()..color = Colors.black45,
        );
        canvas.drawCircle(
          p,
          stoneRadius,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: isWhite
                  ? [const Color(0xFFFFFFFF), const Color(0xFFD6CFC0)]
                  : [const Color(0xFF48505B), const Color(0xFF15181E)],
            ).createShader(Rect.fromCircle(center: p, radius: stoneRadius)),
        );
        canvas.drawCircle(
          p,
          stoneRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = isWhite ? const Color(0xFFADA492) : const Color(0xFF6B7380),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _YavalathPainter oldDelegate) => true;
}
