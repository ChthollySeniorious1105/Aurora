import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class DipoleBoard extends StatefulWidget {
  final GameContext g;
  const DipoleBoard(this.g, {super.key});

  @override
  State<DipoleBoard> createState() => _DipoleBoardState();
}

class _DipoleBoardState extends State<DipoleBoard> {
  (int, int)? _selected;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    const boardSize = 8;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawOwner = (v['owner'] as List?) ?? const [];
    final rawCounts = (v['counts'] as List?) ?? const [];
    final checkers = (v['checkers'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [12, 12];
    final captured = (v['captured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final legalActionsRaw = (v['legalActions'] as List?)?.cast<Map>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final owner = List.generate(boardSize, (r) {
      if (r < rawOwner.length && rawOwner[r] is List) {
        final row = rawOwner[r] as List;
        return List.generate(boardSize, (c) => c < row.length ? (row[c] as num).toInt() : 0);
      }
      return List<int>.filled(boardSize, 0);
    });

    final counts = List.generate(boardSize, (r) {
      if (r < rawCounts.length && rawCounts[r] is List) {
        final row = rawCounts[r] as List;
        return List.generate(boardSize, (c) => c < row.length ? (row[c] as num).toInt() : 0);
      }
      return List<int>.filled(boardSize, 0);
    });

    final isMyTurn = !over && g.seat == turn;
    final myColor = turn + 1;

    if (_selected != null) {
      final (sr, sc) = _selected!;
      if (!isMyTurn ||
          sr < 0 ||
          sr >= boardSize ||
          sc < 0 ||
          sc >= boardSize ||
          owner[sr][sc] != myColor ||
          counts[sr][sc] <= 0) {
        _selected = null;
      }
    }

    final targets = <(int, int), Map>{};
    if (isMyTurn && _selected != null) {
      final (sr, sc) = _selected!;
      for (final act in legalActionsRaw) {
        final fr = (act['fromR'] as num?)?.toInt() ?? -1;
        final fc = (act['fromC'] as num?)?.toInt() ?? -1;
        if (fr == sr && fc == sc) {
          final tr = (act['toR'] as num).toInt();
          final tc = (act['toC'] as num).toInt();
          targets[(tr, tc)] = act;
        }
      }
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_selected == null) {
        final capCount = legalActionsRaw.where((a) => a['type'] == 'capture').length;
        statusText = capCount > 0
            ? '轮到你：点击己方棋堆分兵移动（当前有 $capCount 个可全向强袭吃子的目标！）'
            : '轮到你：点击己方棋堆，按目标暗格距离分出对应数量棋子前推或合堆';
      } else {
        final (sr, sc) = _selected!;
        statusText = '已选棋堆 (${sr + 1},${sc + 1})［共 ${counts[sr][sc]} 子］：点击高亮暗格分出对应步距的棋子';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    Widget buildPlayerPanel(int s) {
      final isWhite = s == 0;
      final sideName = isWhite ? '白方 (↑)' : '黑方 (↓)';
      final chk = s < checkers.length ? checkers[s] : 0;
      final cap = s < captured.length ? captured[s] : 0;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideName · 棋子 $chk · 俘获 $cap',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF263238),
            border: Border.all(
              color: isWhite ? Colors.black54 : Colors.amberAccent,
              width: 1.6,
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
          final cellSize = side / (boardSize + 0.8);
          final boardPx = cellSize * boardSize;
          final origin = Offset(
            (constraints.maxWidth - boardPx) / 2,
            (constraints.maxHeight - boardPx) / 2,
          );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn
                ? null
                : (details) {
                    final local = details.localPosition - origin;
                    final c = (local.dx / cellSize).floor();
                    final r = (local.dy / cellSize).floor();
                    if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) {
                      setState(() => _selected = null);
                      return;
                    }

                    final hit = (r, c);
                    if (_selected != null && targets.containsKey(hit)) {
                      final act = targets[hit]!;
                      setState(() => _selected = null);
                      g.act({
                        'type': act['type'],
                        'fromR': act['fromR'],
                        'fromC': act['fromC'],
                        'toR': act['toR'],
                        'toC': act['toC'],
                        'count': act['count'],
                      });
                      return;
                    }

                    if (owner[r][c] == myColor && counts[r][c] > 0) {
                      setState(() => _selected = _selected == hit ? null : hit);
                    } else {
                      setState(() => _selected = null);
                    }
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _DipolePainter(
                owner: owner,
                counts: counts,
                selected: _selected,
                targets: targets,
                lastMove: lastMove,
                cellSize: cellSize,
                origin: origin,
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
                          width: min(240, outer.maxWidth * 0.28),
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

class _DipolePainter extends CustomPainter {
  final List<List<int>> owner;
  final List<List<int>> counts;
  final (int, int)? selected;
  final Map<(int, int), Map> targets;
  final Map? lastMove;
  final double cellSize;
  final Offset origin;
  final ColorScheme cs;

  _DipolePainter({
    required this.owner,
    required this.counts,
    required this.selected,
    required this.targets,
    required this.lastMove,
    required this.cellSize,
    required this.origin,
    required this.cs,
  });

  static const int boardSize = 8;

  Offset _center(int r, int c) => Offset(
        origin.dx + (c + 0.5) * cellSize,
        origin.dy + (r + 0.5) * cellSize,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final boardPx = cellSize * boardSize;
    final outerRect = Rect.fromLTWH(
      origin.dx - cellSize * 0.25,
      origin.dy - cellSize * 0.25,
      boardPx + cellSize * 0.50,
      boardPx + cellSize * 0.50,
    );
    final rrect = RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.28));
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black54, 8, false);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF31261E), Color(0xFF1D1611)],
        ).createShader(outerRect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.6),
    );

    final lastFromR = (lastMove?['fromR'] as num?)?.toInt();
    final lastFromC = (lastMove?['fromC'] as num?)?.toInt();
    final lastToR = (lastMove?['toR'] as num?)?.toInt();
    final lastToC = (lastMove?['toC'] as num?)?.toInt();

    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        );
        final isDark = (r + c) % 2 == 1;
        Color sqColor = isDark ? const Color(0xFF3E3227) : const Color(0xFF7D6B57);
        if ((r == lastFromR && c == lastFromC) || (r == lastToR && c == lastToC)) {
          sqColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.28), sqColor);
        }
        if (selected == (r, c)) {
          sqColor = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.32), sqColor);
        }
        canvas.drawRect(rect, Paint()..color = sqColor);
      }
    }

    // Draw last move trajectory line
    if (lastFromR != null && lastFromC != null && lastToR != null && lastToC != null) {
      final isCap = lastMove?['type'] == 'capture';
      canvas.drawLine(
        _center(lastFromR, lastFromC),
        _center(lastToR, lastToC),
        Paint()
          ..color = (isCap ? Colors.redAccent : Colors.amberAccent).withValues(alpha: 0.6)
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw stacks and target badges
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final p = _center(r, c);
        final own = owner[r][c];
        final cnt = counts[r][c];
        final isSel = selected == (r, c);
        final act = targets[(r, c)];

        if (own != 0 && cnt > 0) {
          final isWhite = own == 1;
          final radius = cellSize * 0.37;

          if (isSel) {
            canvas.drawCircle(
              p,
              radius + 3.5,
              Paint()..color = Colors.greenAccent.withValues(alpha: 0.85),
            );
          }

          // Draw visual layered stack discs (up to 4 layers visually)
          final layers = min(cnt, 4);
          for (var i = 0; i < layers; i++) {
            final dy = (layers - 1 - i) * 2.0 - (layers - 1) * 1.0;
            final layerCenter = p + Offset(0, dy);
            canvas.drawCircle(
              layerCenter + const Offset(1.0, 1.8),
              radius,
              Paint()..color = Colors.black54,
            );
            canvas.drawCircle(
              layerCenter,
              radius,
              Paint()
                ..shader = RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: isWhite
                      ? [const Color(0xFFFFFFFF), const Color(0xFFCFD8DC)]
                      : [const Color(0xFF455A64), const Color(0xFF1C262B)],
                ).createShader(Rect.fromCircle(center: layerCenter, radius: radius)),
            );
            canvas.drawCircle(
              layerCenter,
              radius,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = isWhite
                    ? const Color(0xFF546E7A)
                    : const Color(0xFFFFD54F).withValues(alpha: 0.85),
            );
          }

          final topCenter = p + Offset(0, -(layers - 1) * 1.0);
          _drawLabel(
            canvas,
            '$cnt',
            topCenter,
            cellSize * 0.34,
            isWhite ? const Color(0xFF1A237E) : Colors.white,
          );
        }

        if (act != null) {
          final isCap = act['type'] == 'capture';
          final reqCount = (act['count'] as num).toInt();
          final badgeColor = isCap ? Colors.redAccent : Colors.greenAccent;

          canvas.drawCircle(
            p,
            cellSize * 0.43,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..color = badgeColor,
          );

          final pillRect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p + Offset(0, own == 0 ? 0 : cellSize * 0.28),
              width: cellSize * 0.56,
              height: cellSize * 0.30,
            ),
            Radius.circular(cellSize * 0.12),
          );
          canvas.drawRRect(
            pillRect,
            Paint()..color = Colors.black.withValues(alpha: 0.78),
          );
          canvas.drawRRect(
            pillRect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = badgeColor,
          );
          _drawLabel(
            canvas,
            isCap ? '⚔$reqCount' : '×$reqCount',
            pillRect.center,
            cellSize * 0.21,
            badgeColor,
          );
        }
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset center, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          fontFamilyFallback: kFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DipolePainter oldDelegate) => true;
}
