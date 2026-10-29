import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CannonBoard extends StatefulWidget {
  final GameContext g;
  const CannonBoard(this.g, {super.key});

  @override
  State<CannonBoard> createState() => _CannonBoardState();
}

class _CannonBoardState extends State<CannonBoard> {
  (int, int)? _selected;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final boardSize = (v['boardSize'] as num?)?.toInt() ?? 10;
    final phase = v['phase'] as String? ?? 'place_town';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawBoard = (v['board'] as List?) ?? const [];
    final captured = (v['captured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final soldiers = (v['soldiers'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [15, 15];
    final legalActionsRaw = (v['legalActions'] as List?)?.cast<Map>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final board = List.generate(boardSize, (r) {
      if (r < rawBoard.length && rawBoard[r] is List) {
        final row = rawBoard[r] as List;
        return List.generate(boardSize, (c) => c < row.length ? (row[c] as num).toInt() : 0);
      }
      return List<int>.filled(boardSize, 0);
    });

    final isMyTurn = !over && g.seat == turn;
    final mySoldier = turn == 0 ? 1 : 2;
    final myTownRow = turn == 0 ? boardSize - 1 : 0;

    if (phase != 'play' || (_selected != null && (
        _selected!.$1 < 0 ||
        _selected!.$1 >= boardSize ||
        _selected!.$2 < 0 ||
        _selected!.$2 >= boardSize ||
        board[_selected!.$1][_selected!.$2] != mySoldier))) {
      _selected = null;
    }

    final townTargets = <(int, int)>{};
    final moveTargets = <(int, int), Map>{};
    final shootTargets = <(int, int), Map>{};

    if (isMyTurn) {
      if (phase == 'place_town') {
        for (var c = 1; c <= boardSize - 2; c++) {
          if (board[myTownRow][c] == 0) {
            townTargets.add((myTownRow, c));
          }
        }
      } else if (_selected != null) {
        final (sr, sc) = _selected!;
        for (final act in legalActionsRaw) {
          final type = act['type'] as String? ?? '';
          final fr = (act['fromR'] as num?)?.toInt() ?? -1;
          final fc = (act['fromC'] as num?)?.toInt() ?? -1;
          if (fr == sr && fc == sc) {
            final tr = (act['toR'] as num).toInt();
            final tc = (act['toC'] as num).toInt();
            if (type == 'move') {
              moveTargets[(tr, tc)] = act;
            } else if (type == 'shoot') {
              shootTargets[(tr, tc)] = act;
            }
          }
        }
      }
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (phase == 'place_town') {
      statusText = isMyTurn
          ? '轮到你部署 🏰 王城：请点击己方底线（第 ${myTownRow + 1} 行）的高亮格放置王城'
          : '等待 ${g.name(turn)} 部署底线王城…';
    } else if (isMyTurn) {
      if (_selected == null) {
        final shootCount = legalActionsRaw.where((a) => a['type'] == 'shoot').length;
        statusText = shootCount > 0
            ? '轮到你：点击己方士兵走子，或点击三连火炮炮口士兵远程轰击（当前有 $shootCount 个可轰击目标！）'
            : '轮到你：点击己方士兵进行步进、近战吃子、战术撤退或三连火炮滑行';
      } else {
        statusText = shootTargets.isNotEmpty
            ? '已选火炮 (${_selected!.$1 + 1},${_selected!.$2 + 1})：点击红十字目标开炮轰击，或点击移动落点'
            : '已选士兵 (${_selected!.$1 + 1},${_selected!.$2 + 1})：点击高亮目标格执行行动';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    Widget buildPlayerPanel(int s) {
      final isBlue = s == 0;
      final sideName = isBlue ? '蓝军 (↑)' : '红军 (↓)';
      final sol = s < soldiers.length ? soldiers[s] : 0;
      final cap = s < captured.length ? captured[s] : 0;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideName · 士兵 $sol · 歼敌 $cap',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBlue ? const Color(0xFF1E88E5) : const Color(0xFFE53935),
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();
          final cellSize = side / (boardSize + 1.2);
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

                    if (phase == 'place_town') {
                      if (townTargets.contains((r, c))) {
                        g.act({'type': 'place_town', 'c': c});
                      }
                      return;
                    }

                    final hit = (r, c);
                    if (_selected != null) {
                      final (sr, sc) = _selected!;
                      if (shootTargets.containsKey(hit)) {
                        setState(() => _selected = null);
                        g.act({
                          'type': 'shoot',
                          'fromR': sr,
                          'fromC': sc,
                          'toR': r,
                          'toC': c,
                        });
                        return;
                      }
                      if (moveTargets.containsKey(hit)) {
                        setState(() => _selected = null);
                        g.act({
                          'type': 'move',
                          'fromR': sr,
                          'fromC': sc,
                          'toR': r,
                          'toC': c,
                        });
                        return;
                      }
                    }

                    if (board[r][c] == mySoldier) {
                      setState(() => _selected = _selected == hit ? null : hit);
                    } else {
                      setState(() => _selected = null);
                    }
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _CannonPainter(
                board: board,
                boardSize: boardSize,
                selected: _selected,
                townTargets: townTargets,
                moveTargets: moveTargets,
                shootTargets: shootTargets,
                legalActionsAll: isMyTurn ? legalActionsRaw : const [],
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

class _CannonPainter extends CustomPainter {
  final List<List<int>> board;
  final int boardSize;
  final (int, int)? selected;
  final Set<(int, int)> townTargets;
  final Map<(int, int), Map> moveTargets;
  final Map<(int, int), Map> shootTargets;
  final List<Map> legalActionsAll;
  final Map? lastMove;
  final double cellSize;
  final Offset origin;
  final ColorScheme cs;

  _CannonPainter({
    required this.board,
    required this.boardSize,
    required this.selected,
    required this.townTargets,
    required this.moveTargets,
    required this.shootTargets,
    required this.legalActionsAll,
    required this.lastMove,
    required this.cellSize,
    required this.origin,
    required this.cs,
  });

  Offset _center(int r, int c) => Offset(
        origin.dx + (c + 0.5) * cellSize,
        origin.dy + (r + 0.5) * cellSize,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final boardPx = cellSize * boardSize;
    final outerRect = Rect.fromLTWH(
      origin.dx - cellSize * 0.28,
      origin.dy - cellSize * 0.28,
      boardPx + cellSize * 0.56,
      boardPx + cellSize * 0.56,
    );
    final rrect = RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.35));
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black54, 8, false);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D251E), Color(0xFF1B1612)],
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
    final lastToR = (lastMove?['toR'] as num?)?.toInt() ?? (lastMove?['r'] as num?)?.toInt();
    final lastToC = (lastMove?['toC'] as num?)?.toInt() ?? (lastMove?['c'] as num?)?.toInt();

    final shootCapableMuzzles = <(int, int)>{
      for (final a in legalActionsAll)
        if (a['type'] == 'shoot')
          ((a['fromR'] as num).toInt(), (a['fromC'] as num).toInt()),
    };

    // Draw grid squares
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        );
        final isDark = (r + c).isOdd;
        final isTownRow = r == 0 || r == boardSize - 1;
        Color sqColor = isDark ? const Color(0xFF3A3128) : const Color(0xFF4C4034);
        if (isTownRow) {
          sqColor = Color.alphaBlend(
            (r == 0 ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.10),
            sqColor,
          );
        }
        if ((r == lastFromR && c == lastFromC) || (r == lastToR && c == lastToC)) {
          sqColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), sqColor);
        }
        if (selected == (r, c)) {
          sqColor = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.30), sqColor);
        }
        canvas.drawRect(rect, Paint()..color = sqColor);
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = Colors.white.withValues(alpha: 0.12),
        );

        // Town placement target highlight
        if (townTargets.contains((r, c))) {
          final p = _center(r, c);
          canvas.drawCircle(
            p,
            cellSize * 0.34,
            Paint()..color = Colors.amberAccent.withValues(alpha: 0.28),
          );
          canvas.drawCircle(
            p,
            cellSize * 0.34,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0
              ..color = Colors.amberAccent,
          );
          _drawLabel(canvas, '🏰', p, cellSize * 0.38, Colors.amberAccent);
        }
      }
    }

    // Draw last move / shoot line
    if (lastFromR != null && lastFromC != null && lastToR != null && lastToC != null) {
      final isShoot = lastMove?['type'] == 'shoot';
      canvas.drawLine(
        _center(lastFromR, lastFromC),
        _center(lastToR, lastToC),
        Paint()
          ..color = (isShoot ? Colors.deepOrangeAccent : Colors.lightBlueAccent).withValues(alpha: 0.65)
          ..strokeWidth = isShoot ? 3.4 : 2.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw selected piece's shoot trajectory lines
    if (selected != null) {
      final pFrom = _center(selected!.$1, selected!.$2);
      for (final target in shootTargets.keys) {
        final pTo = _center(target.$1, target.$2);
        canvas.drawLine(
          pFrom,
          pTo,
          Paint()
            ..color = Colors.redAccent.withValues(alpha: 0.75)
            ..strokeWidth = 2.8,
        );
      }
    }

    // Draw pieces and move/shoot indicators
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final p = _center(r, c);
        final v = board[r][c];
        final isSel = selected == (r, c);
        final moveAct = moveTargets[(r, c)];
        final shootAct = shootTargets[(r, c)];

        if (v != 0) {
          final isBlue = v == 1 || v == 3;
          final isTown = v == 3 || v == 4;
          final radius = cellSize * (isTown ? 0.41 : 0.36);

          if (isSel || shootAct != null || shootCapableMuzzles.contains((r, c))) {
            canvas.drawCircle(
              p,
              radius + 3.5,
              Paint()
                ..color = shootAct != null
                    ? Colors.redAccent.withValues(alpha: 0.9)
                    : (isSel
                        ? Colors.greenAccent.withValues(alpha: 0.85)
                        : Colors.orangeAccent.withValues(alpha: 0.55)),
            );
          }

          canvas.drawCircle(
            p + const Offset(1.2, 2.0),
            radius,
            Paint()..color = Colors.black54,
          );
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: isBlue
                    ? [const Color(0xFF42A5F5), const Color(0xFF0D47A1)]
                    : [const Color(0xFFEF5350), const Color(0xFFB71C1C)],
              ).createShader(Rect.fromCircle(center: p, radius: radius)),
          );
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isTown ? 2.4 : 1.5
              ..color = isTown ? const Color(0xFFFFD54F) : Colors.white.withValues(alpha: 0.75),
          );

          if (isTown) {
            _drawLabel(canvas, '🏰', p, cellSize * 0.42, Colors.white);
          } else {
            _drawLabel(
              canvas,
              isBlue ? '▲' : '▼',
              p,
              cellSize * 0.34,
              Colors.white.withValues(alpha: 0.9),
            );
          }
        }

        // Move target markers
        if (moveAct != null) {
          final kind = moveAct['kind'] as String? ?? 'step';
          if (v == 0) {
            final dotColor = kind == 'cannon_slide'
                ? Colors.cyanAccent
                : (kind == 'retreat' ? Colors.amberAccent : Colors.greenAccent);
            canvas.drawCircle(
              p,
              cellSize * 0.17,
              Paint()..color = dotColor.withValues(alpha: 0.85),
            );
            if (kind == 'cannon_slide' || kind == 'retreat') {
              canvas.drawCircle(
                p,
                cellSize * 0.27,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.8
                  ..color = dotColor.withValues(alpha: 0.85),
              );
            }
          } else {
            // Melee capture ring
            canvas.drawCircle(
              p,
              cellSize * 0.43,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.6
                ..color = Colors.amberAccent,
            );
          }
        }

        // Artillery shoot target crosshair
        if (shootAct != null) {
          final rCross = cellSize * 0.43;
          final crossPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..color = Colors.redAccent;
          canvas.drawCircle(p, rCross, crossPaint);
          canvas.drawLine(p + Offset(-rCross, 0), p + Offset(rCross, 0), crossPaint);
          canvas.drawLine(p + Offset(0, -rCross), p + Offset(0, rCross), crossPaint);
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
  bool shouldRepaint(covariant _CannonPainter oldDelegate) => true;
}
