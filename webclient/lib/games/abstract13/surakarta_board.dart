import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class SurakartaBoard extends StatefulWidget {
  final GameContext g;
  const SurakartaBoard(this.g, {super.key});

  @override
  State<SurakartaBoard> createState() => _SurakartaBoardState();
}

class _SurakartaBoardState extends State<SurakartaBoard> {
  (int, int)? _selected;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawBoard = (v['board'] as List?) ?? const [];
    final captured = (v['captured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final remaining = (v['remaining'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [12, 12];
    final legalCapturesRaw = (v['legalCaptures'] as List?)?.cast<Map>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final board = List.generate(6, (r) {
      if (r < rawBoard.length && rawBoard[r] is List) {
        final row = rawBoard[r] as List;
        return List.generate(6, (c) => c < row.length ? (row[c] as num).toInt() : 0);
      }
      return List<int>.filled(6, 0);
    });

    final isMyTurn = !over && g.seat == turn;
    final myPiece = turn == 0 ? 1 : 2;

    if (_selected != null) {
      final (sr, sc) = _selected!;
      if (sr < 0 || sr >= 6 || sc < 0 || sc >= 6 || board[sr][sc] != myPiece) {
        _selected = null;
      }
    }

    final stepTargets = <(int, int)>{};
    final captureTargets = <(int, int), Map>{};
    if (isMyTurn && _selected != null) {
      final (sr, sc) = _selected!;
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = sr + dr;
          final nc = sc + dc;
          if (nr >= 0 && nr < 6 && nc >= 0 && nc < 6 && board[nr][nc] == 0) {
            stepTargets.add((nr, nc));
          }
        }
      }
      for (final cap in legalCapturesRaw) {
        final fr = (cap['fromR'] as num).toInt();
        final fc = (cap['fromC'] as num).toInt();
        if (fr == sr && fc == sc) {
          final tr = (cap['toR'] as num).toInt();
          final tc = (cap['toC'] as num).toInt();
          captureTargets[(tr, tc)] = cap;
        }
      }
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_selected == null) {
        final totalCaps = legalCapturesRaw.length;
        statusText = totalCaps > 0
            ? '轮到你：点击己方棋子（当前有 $totalCaps 条环轨吃子路线！）'
            : '轮到你：点击一枚己方棋子进行八向步进或环轨吃子';
      } else {
        statusText = captureTargets.isNotEmpty
            ? '已选 (${_selected!.$1 + 1},${_selected!.$2 + 1})：点击红圈敌子环轨狙击，或点击绿点迈步'
            : '已选 (${_selected!.$1 + 1},${_selected!.$2 + 1})：点击周围绿点迈出一步';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 走子…';
    }

    Widget buildPlayerPanel(int s) {
      final colorLabel = s == 0 ? '黑子' : '白子';
      final rem = s < remaining.length ? remaining[s] : 12;
      final cap = s < captured.length ? captured[s] : 0;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · 剩余 $rem · 俘获 $cap',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s == 0 ? const Color(0xFF22252A) : const Color(0xFFFDFBF7),
            border: Border.all(
              color: s == 0 ? Colors.grey.shade400 : Colors.brown.shade400,
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
          final cellStep = side / 9.2;
          final gridOrigin = Offset(
            (constraints.maxWidth - cellStep * 5) / 2,
            (constraints.maxHeight - cellStep * 5) / 2,
          );

          Offset nodePos(int r, int c) => Offset(
                gridOrigin.dx + c * cellStep,
                gridOrigin.dy + r * cellStep,
              );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn
                ? null
                : (details) {
                    final tap = details.localPosition;
                    (int, int)? hit;
                    var bestDist = cellStep * 0.48;
                    for (var r = 0; r < 6; r++) {
                      for (var c = 0; c < 6; c++) {
                        final d = (tap - nodePos(r, c)).distance;
                        if (d < bestDist) {
                          bestDist = d;
                          hit = (r, c);
                        }
                      }
                    }
                    if (hit == null) {
                      setState(() => _selected = null);
                      return;
                    }

                    final (hr, hc) = hit;
                    if (_selected != null) {
                      final (sr, sc) = _selected!;
                      if (captureTargets.containsKey(hit)) {
                        setState(() => _selected = null);
                        g.act({
                          'type': 'capture',
                          'fromR': sr,
                          'fromC': sc,
                          'toR': hr,
                          'toC': hc,
                        });
                        return;
                      }
                      if (stepTargets.contains(hit)) {
                        setState(() => _selected = null);
                        g.act({
                          'type': 'step',
                          'fromR': sr,
                          'fromC': sc,
                          'toR': hr,
                          'toC': hc,
                        });
                        return;
                      }
                    }

                    if (board[hr][hc] == myPiece) {
                      setState(() => _selected = _selected == hit ? null : hit);
                    } else {
                      setState(() => _selected = null);
                    }
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SurakartaPainter(
                board: board,
                selected: _selected,
                stepTargets: stepTargets,
                captureTargets: captureTargets,
                legalCapturesAll: isMyTurn ? legalCapturesRaw : const [],
                lastMove: lastMove,
                cellStep: cellStep,
                gridOrigin: gridOrigin,
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

class _SurakartaPainter extends CustomPainter {
  final List<List<int>> board;
  final (int, int)? selected;
  final Set<(int, int)> stepTargets;
  final Map<(int, int), Map> captureTargets;
  final List<Map> legalCapturesAll;
  final Map? lastMove;
  final double cellStep;
  final Offset gridOrigin;
  final ColorScheme cs;

  _SurakartaPainter({
    required this.board,
    required this.selected,
    required this.stepTargets,
    required this.captureTargets,
    required this.legalCapturesAll,
    required this.lastMove,
    required this.cellStep,
    required this.gridOrigin,
    required this.cs,
  });

  Offset _node(int r, int c) => Offset(
        gridOrigin.dx + c * cellStep,
        gridOrigin.dy + r * cellStep,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final boardRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cellStep * 8.6,
      height: cellStep * 8.6,
    );
    final rrect = RRect.fromRectAndRadius(boardRect, Radius.circular(cellStep * 0.7));

    canvas.drawShadow(Path()..addRRect(rrect), Colors.black54, 8, false);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF2C221E), const Color(0xFF1B1411)],
        ).createShader(boardRect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.55),
    );

    const outerColor = Color(0xFFFF8A65); // Outer orbit (row/col 0, 5)
    const innerColor = Color(0xFF4DD0E1); // Inner orbit (row/col 1, 4)
    final midColor = Colors.white.withValues(alpha: 0.28);

    // 1. Draw the 8 Corner Loops at the 4 corners:
    // Each corner (cornerR, cornerC) has:
    //  - Inner Loop: 270-degree arc centered at (cornerR, cornerC) with radius = 1.0 * cellStep
    //  - Outer Loop: circular loop centered outside the corner passing through (cornerR, cornerC)
    final corners = <(int, int, double, double, double)>[
      // (cornerR, cornerC, innerStartAngle, signX, signY)
      (0, 0, pi / 2, -1, -1), // TL: from (1,0) [pi/2] clockwise 270 deg to (0,1) [2*pi]
      (0, 5, pi, 1, -1), // TR: from (0,4) [pi] clockwise 270 deg to (1,5) [pi/2]
      (5, 5, 3 * pi / 2, 1, 1), // BR: from (4,5) [3*pi/2] clockwise 270 deg to (5,4) [pi]
      (5, 0, 0, -1, 1), // BL: from (5,1) [0] clockwise 270 deg to (4,0) [3*pi/2]
    ];

    for (final (cr, cc, startAngle, sx, sy) in corners) {
      final cornerPt = _node(cr, cc);

      // Inner loop arc (connects distance 1 on the two corner edges)
      final innerRect = Rect.fromCircle(center: cornerPt, radius: cellStep);
      canvas.drawArc(
        innerRect,
        startAngle,
        1.5 * pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = innerColor.withValues(alpha: 0.8),
      );

      // Outer loop circle (tangent to row 0/5 and col 0/5 at cornerPt, looping around the outside)
      final d = cellStep * 0.46;
      final outerCenter = cornerPt + Offset(sx * d, sy * d);
      final outerRadius = d * sqrt(2);
      canvas.drawCircle(
        outerCenter,
        outerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = outerColor.withValues(alpha: 0.85),
      );
    }

    // 2. Draw 6x6 grid lines color-coded by orbit
    for (var i = 0; i < 6; i++) {
      final lineColor = (i == 0 || i == 5)
          ? outerColor.withValues(alpha: 0.75)
          : ((i == 1 || i == 4) ? innerColor.withValues(alpha: 0.75) : midColor);
      final strokeW = (i == 2 || i == 3) ? 1.5 : 2.3;
      // Row i
      canvas.drawLine(
        _node(i, 0),
        _node(i, 5),
        Paint()
          ..color = lineColor
          ..strokeWidth = strokeW,
      );
      // Col i
      canvas.drawLine(
        _node(0, i),
        _node(5, i),
        Paint()
          ..color = lineColor
          ..strokeWidth = strokeW,
      );
    }

    // 3. Draw last move trajectory if any
    if (lastMove != null) {
      final wp = (lastMove!['waypoints'] as List?) ?? const [];
      if (wp.length >= 2) {
        final isCap = lastMove!['type'] == 'capture';
        final pathPaint = Paint()
          ..color = (isCap ? Colors.amberAccent : Colors.lightBlueAccent).withValues(alpha: 0.55)
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i + 1 < wp.length; i++) {
          final a = wp[i] as List;
          final b = wp[i + 1] as List;
          final p1 = _node((a[0] as num).toInt(), (a[1] as num).toInt());
          final p2 = _node((b[0] as num).toInt(), (b[1] as num).toInt());
          canvas.drawLine(p1, p2, pathPaint);
        }
      }
    }

    // 4. Draw selected piece's capture paths
    for (final cap in captureTargets.values) {
      final wp = (cap['waypoints'] as List?) ?? const [];
      for (var i = 0; i + 1 < wp.length; i++) {
        final a = wp[i] as List;
        final b = wp[i + 1] as List;
        final p1 = _node((a[0] as num).toInt(), (a[1] as num).toInt());
        final p2 = _node((b[0] as num).toInt(), (b[1] as num).toInt());
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = Colors.redAccent.withValues(alpha: 0.7)
            ..strokeWidth = 3.0,
        );
      }
    }

    final capturableSources = <(int, int)>{
      for (final cap in legalCapturesAll)
        ((cap['fromR'] as num).toInt(), (cap['fromC'] as num).toInt()),
    };

    // 5. Draw intersections, pebbles, and move indicators
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        final p = _node(r, c);
        final v = board[r][c];
        final isSel = selected == (r, c);
        final isStepTarget = stepTargets.contains((r, c));
        final isCapTarget = captureTargets.containsKey((r, c));

        // Intersection dot
        canvas.drawCircle(
          p,
          cellStep * 0.09,
          Paint()..color = Colors.white.withValues(alpha: 0.4),
        );

        if (v == 1 || v == 2) {
          final isBlack = v == 1;
          final radius = cellStep * 0.34;

          if (isSel || isCapTarget || capturableSources.contains((r, c))) {
            canvas.drawCircle(
              p,
              radius + 4,
              Paint()
                ..color = isCapTarget
                    ? Colors.redAccent.withValues(alpha: 0.85)
                    : (isSel
                        ? Colors.greenAccent.withValues(alpha: 0.8)
                        : Colors.amberAccent.withValues(alpha: 0.45)),
            );
          }

          canvas.drawCircle(
            p + const Offset(1.5, 2.5),
            radius,
            Paint()..color = Colors.black54,
          );
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: isBlack
                    ? [const Color(0xFF4B525E), const Color(0xFF14171C)]
                    : [const Color(0xFFFFFFFF), const Color(0xFFD9D2C5)],
              ).createShader(Rect.fromCircle(center: p, radius: radius)),
          );
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isSel ? 2.2 : 1.4
              ..color = isSel
                  ? Colors.greenAccent
                  : (isBlack ? const Color(0xFF707885) : const Color(0xFFB0A694)),
          );
        }

        if (isStepTarget) {
          canvas.drawCircle(
            p,
            cellStep * 0.18,
            Paint()..color = Colors.greenAccent.withValues(alpha: 0.85),
          );
        }

        if (isCapTarget) {
          canvas.drawCircle(
            p,
            cellStep * 0.40,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..color = Colors.redAccent,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SurakartaPainter oldDelegate) => true;
}
