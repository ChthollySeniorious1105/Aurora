import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _woodTones = [
  Color(0xFFC89D66),
  Color(0xFFB5834C),
  Color(0xFFD6AD79),
  Color(0xFFA6743D),
  Color(0xFFBF9058),
  Color(0xFFCE9E62),
  Color(0xFFAF7E46),
];

class KulamiBoard extends StatelessWidget {
  final GameContext g;
  const KulamiBoard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;

    final rawPlanks = (v['plankId'] as List?) ?? const [];
    final rawBoard = (v['board'] as List?) ?? const [];
    final remaining = (v['remaining'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [28, 28];
    final plankScores = (v['plankScores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final territory = (v['largestTerritory'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final lineBonus = (v['lineBonus'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final plankOwners = (v['plankOwners'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(17, -1);
    final lastMove = v['lastMove'] as Map?;
    final lastPlankId = (v['lastPlankId'] as num?)?.toInt() ?? -1;
    final prevPlankId = (v['prevPlankId'] as num?)?.toInt() ?? -1;
    final rawLegal = (v['legalMoves'] as List?) ?? const [];

    final legalSet = <(int, int)>{};
    for (final item in rawLegal) {
      if (item is List && item.length >= 2) {
        legalSet.add(((item[0] as num).toInt(), (item[1] as num).toInt()));
      }
    }

    int plankAt(int r, int c) {
      if (r < 0 || r >= rawPlanks.length) return 0;
      final row = rawPlanks[r] as List?;
      if (row == null || c < 0 || c >= row.length) return 0;
      return (row[c] as num).toInt();
    }

    int cellAt(int r, int c) {
      if (r < 0 || r >= rawBoard.length) return -1;
      final row = rawBoard[r] as List?;
      if (row == null || c < 0 || c >= row.length) return -1;
      return (row[c] as num).toInt();
    }

    final isMyTurn = !over && g.seat == turn;
    final lastR = (lastMove?['r'] as num?)?.toInt();
    final lastC = (lastMove?['c'] as num?)?.toInt();

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      statusText = lastMove == null
          ? '轮到你（第一手）：点击棋盘上任意孔位放入弹珠'
          : '轮到你：点击十字准星绿圈孔位放入弹珠（避开最近两块木板）';
    } else {
      statusText = '等待 ${g.name(turn)} 放置弹珠…';
    }

    Widget buildPlayerPanel(int s) {
      final colorLabel = s == 0 ? '红珠' : '黑珠';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel 剩${remaining[s]} · 总分 ${scores[s]} (板${plankScores[s]}+领${territory[s]}+连${lineBonus[s]})',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: s == 0
                  ? [const Color(0xFFFF6B6B), const Color(0xFFB71C1C)]
                  : [const Color(0xFF545B64), const Color(0xFF14171A)],
            ),
            border: Border.all(color: Colors.white54, width: 1.2),
          ),
        ),
      );
    }

    Widget buildBoardWidget() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();

          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: !isMyTurn
                    ? null
                    : (details) {
                        final pad = side * 0.04;
                        final inner = side - pad * 2;
                        final cellSize = inner / 8;
                        final dx = details.localPosition.dx - pad;
                        final dy = details.localPosition.dy - pad;
                        if (dx < 0 || dy < 0 || dx >= inner || dy >= inner) return;
                        final c = (dx ~/ cellSize).clamp(0, 7);
                        final r = (dy ~/ cellSize).clamp(0, 7);
                        if (legalSet.contains((r, c))) {
                          g.act({'type': 'place', 'r': r, 'c': c});
                        }
                      },
                child: CustomPaint(
                  size: Size(side, side),
                  painter: _KulamiPainter(
                    plankAt: plankAt,
                    cellAt: cellAt,
                    plankOwners: plankOwners,
                    legalSet: legalSet,
                    lastR: lastR,
                    lastC: lastC,
                    lastPlankId: lastPlankId,
                    prevPlankId: prevPlankId,
                    isMyTurn: isMyTurn,
                  ),
                ),
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
                          width: min(245, outer.maxWidth * 0.30),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildPlayerPanel(1),
                              Flexible(
                                child: Center(
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
                        Expanded(child: buildBoardWidget()),
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                        const SizedBox(height: 4),
                        Expanded(child: buildBoardWidget()),
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

class _KulamiPainter extends CustomPainter {
  final int Function(int r, int c) plankAt;
  final int Function(int r, int c) cellAt;
  final List<int> plankOwners;
  final Set<(int, int)> legalSet;
  final int? lastR;
  final int? lastC;
  final int lastPlankId;
  final int prevPlankId;
  final bool isMyTurn;

  _KulamiPainter({
    required this.plankAt,
    required this.cellAt,
    required this.plankOwners,
    required this.legalSet,
    required this.lastR,
    required this.lastC,
    required this.lastPlankId,
    required this.prevPlankId,
    required this.isMyTurn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.04;
    final inner = size.width - pad * 2;
    final cellSize = inner / 8;

    // Outer frame
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(14),
    );
    canvas.drawRRect(outerRect, Paint()..color = const Color(0xFF3A2415));

    // Draw each cell's wooden plank background
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final pid = plankAt(r, c);
        final rect = Rect.fromLTWH(pad + c * cellSize, pad + r * cellSize, cellSize, cellSize);
        var baseColor = _woodTones[pid % _woodTones.length];
        if (pid == lastPlankId || pid == prevPlankId) {
          baseColor = Color.lerp(baseColor, const Color(0xFF4A3528), 0.38)!;
        }
        final owner = (pid >= 0 && pid < plankOwners.length) ? plankOwners[pid] : -1;
        if (owner == 0) {
          baseColor = Color.lerp(baseColor, const Color(0xFFD32F2F), 0.14)!;
        } else if (owner == 1) {
          baseColor = Color.lerp(baseColor, const Color(0xFF212121), 0.18)!;
        }
        canvas.drawRect(rect, Paint()..color = baseColor);
      }
    }

    // Highlight cross-hair row and column of lastMove
    if (lastR != null && lastC != null) {
      final rowRect = Rect.fromLTWH(pad, pad + lastR! * cellSize, inner, cellSize);
      final colRect = Rect.fromLTWH(pad + lastC! * cellSize, pad, cellSize, inner);
      final crossPaint = Paint()..color = Colors.amberAccent.withValues(alpha: 0.14);
      canvas.drawRect(rowRect, crossPaint);
      canvas.drawRect(colRect, crossPaint);
    }

    // Draw thick dark seams between different planks
    final seamPaint = Paint()
      ..color = const Color(0xFF26170C)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // Outer border of 8x8 grid
    canvas.drawRect(
      Rect.fromLTWH(pad, pad, inner, inner),
      seamPaint..style = PaintingStyle.stroke,
    );

    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final pid = plankAt(r, c);
        final x = pad + c * cellSize;
        final y = pad + r * cellSize;
        if (c < 7 && plankAt(r, c + 1) != pid) {
          canvas.drawLine(Offset(x + cellSize, y), Offset(x + cellSize, y + cellSize), seamPaint);
        }
        if (r < 7 && plankAt(r + 1, c) != pid) {
          canvas.drawLine(Offset(x, y + cellSize), Offset(x + cellSize, y + cellSize), seamPaint);
        }
      }
    }

    // Draw holes, legal move rings, and marbles
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final center = Offset(pad + (c + 0.5) * cellSize, pad + (r + 0.5) * cellSize);
        final holeRadius = cellSize * 0.34;
        final v = cellAt(r, c);

        // Recessed wooden socket
        canvas.drawCircle(
          center,
          holeRadius,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0.25, 0.25),
              colors: [
                Colors.black.withValues(alpha: 0.28),
                Colors.black.withValues(alpha: 0.52),
              ],
            ).createShader(Rect.fromCircle(center: center, radius: holeRadius)),
        );

        // Legal hole highlight
        if (isMyTurn && legalSet.contains((r, c))) {
          canvas.drawCircle(
            center,
            holeRadius * 0.88,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = const Color(0xFF69F0AE),
          );
          canvas.drawCircle(
            center,
            holeRadius * 0.28,
            Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.75),
          );
        }

        // Marble
        if (v == 0 || v == 1) {
          final isRed = v == 0;
          final mRadius = cellSize * 0.35;
          canvas.drawCircle(
            center + const Offset(1.2, 2.0),
            mRadius,
            Paint()..color = Colors.black45,
          );
          canvas.drawCircle(
            center,
            mRadius,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: isRed
                    ? [const Color(0xFFFF8A80), const Color(0xFFD32F2F), const Color(0xFF7F0000)]
                    : [const Color(0xFF78909C), const Color(0xFF263238), const Color(0xFF0D1114)],
                stops: const [0.0, 0.6, 1.0],
              ).createShader(Rect.fromCircle(center: center, radius: mRadius)),
          );

          if (lastR == r && lastC == c) {
            canvas.drawCircle(
              center,
              mRadius + 2.0,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.2
                ..color = Colors.amberAccent,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KulamiPainter oldDelegate) => true;
}
