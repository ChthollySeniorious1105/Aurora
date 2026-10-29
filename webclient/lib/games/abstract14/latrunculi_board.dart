import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class LatrunculiBoard extends StatefulWidget {
  final GameContext g;
  const LatrunculiBoard(this.g, {super.key});

  @override
  State<LatrunculiBoard> createState() => _LatrunculiBoardState();
}

class _LatrunculiBoardState extends State<LatrunculiBoard> {
  (int, int)? _selected;

  static bool _isFriendly(int seat, int v) =>
      seat == 0 ? (v == 1 || v == 3) : (v == 2 || v == 4);

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final targetCaptures = (v['targetCaptures'] as num?)?.toInt() ?? 7;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawBoard = (v['board'] as List?) ?? const [];
    final captured = (v['captured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final legionaries = (v['legionaries'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [8, 8];
    final legalMovesRaw = (v['legalMoves'] as List?)?.cast<Map>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final board = List.generate(8, (r) {
      if (r < rawBoard.length && rawBoard[r] is List) {
        final row = rawBoard[r] as List;
        return List.generate(8, (c) => c < row.length ? (row[c] as num).toInt() : 0);
      }
      return List<int>.filled(8, 0);
    });

    final isMyTurn = !over && g.seat == turn;

    if (_selected != null) {
      final (sr, sc) = _selected!;
      if (sr < 0 || sr >= 8 || sc < 0 || sc >= 8 || !_isFriendly(turn, board[sr][sc])) {
        _selected = null;
      }
    }

    final moveTargets = <(int, int), Map>{};
    if (isMyTurn && _selected != null) {
      final (sr, sc) = _selected!;
      for (final m in legalMovesRaw) {
        final fr = (m['fromR'] as num).toInt();
        final fc = (m['fromC'] as num).toInt();
        if (fr == sr && fc == sc) {
          final tr = (m['toR'] as num).toInt();
          final tc = (m['toC'] as num).toInt();
          moveTargets[(tr, tc)] = m;
        }
      }
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_selected == null) {
        statusText = '轮到你：点击己方 ⚔️ 军团兵或 🦅 统帅进行正交滑行与双子夹击';
      } else {
        final isDux = board[_selected!.$1][_selected!.$2] >= 3;
        statusText = isDux
            ? '已选 🦅 统帅 (${_selected!.$1 + 1},${_selected!.$2 + 1})：可正交滑行，或跃过相邻棋子落入青圈格'
            : '已选 ⚔️ 军团兵 (${_selected!.$1 + 1},${_selected!.$2 + 1})：点击绿点滑行并夹吃敌方军团兵';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 调遣军团…';
    }

    Widget buildPlayerPanel(int s) {
      final isWhite = s == 0;
      final sideName = isWhite ? '白方罗马军' : '黑方迦太基军';
      final leg = s < legionaries.length ? legionaries[s] : 8;
      final cap = s < captured.length ? captured[s] : 0;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideName · 军团 $leg · 俘获 $cap/$targetCaptures',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWhite ? const Color(0xFFFDFBF7) : const Color(0xFF22252A),
            border: Border.all(
              color: const Color(0xFFD4AF37),
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
          final cellSize = side / 9.2;
          final boardPx = cellSize * 8;
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
                    if (r < 0 || r >= 8 || c < 0 || c >= 8) {
                      setState(() => _selected = null);
                      return;
                    }

                    final hit = (r, c);
                    if (_selected != null && moveTargets.containsKey(hit)) {
                      final (sr, sc) = _selected!;
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

                    if (_isFriendly(turn, board[r][c])) {
                      setState(() => _selected = _selected == hit ? null : hit);
                    } else {
                      setState(() => _selected = null);
                    }
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _LatrunculiPainter(
                board: board,
                selected: _selected,
                moveTargets: moveTargets,
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

class _LatrunculiPainter extends CustomPainter {
  final List<List<int>> board;
  final (int, int)? selected;
  final Map<(int, int), Map> moveTargets;
  final Map? lastMove;
  final double cellSize;
  final Offset origin;
  final ColorScheme cs;

  _LatrunculiPainter({
    required this.board,
    required this.selected,
    required this.moveTargets,
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
    final boardPx = cellSize * 8;
    final outerRect = Rect.fromLTWH(
      origin.dx - cellSize * 0.3,
      origin.dy - cellSize * 0.3,
      boardPx + cellSize * 0.6,
      boardPx + cellSize * 0.6,
    );
    final rrect = RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.36));
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black54, 8, false);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A261E), Color(0xFF211410)],
        ).createShader(outerRect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.65),
    );

    final lastFromR = (lastMove?['fromR'] as num?)?.toInt();
    final lastFromC = (lastMove?['fromC'] as num?)?.toInt();
    final lastToR = (lastMove?['toR'] as num?)?.toInt();
    final lastToC = (lastMove?['toC'] as num?)?.toInt();
    final capturedRaw = (lastMove?['capturedCells'] as List?) ?? const [];
    final capturedSet = <(int, int)>{
      for (final item in capturedRaw)
        if (item is List && item.length >= 2)
          ((item[0] as num).toInt(), (item[1] as num).toInt()),
    };

    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        );
        final isDark = (r + c).isOdd;
        Color sqColor = isDark ? const Color(0xFF4B362A) : const Color(0xFF634838);
        if ((r == lastFromR && c == lastFromC) || (r == lastToR && c == lastToC)) {
          sqColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), sqColor);
        }
        if (capturedSet.contains((r, c))) {
          sqColor = Color.alphaBlend(Colors.redAccent.withValues(alpha: 0.35), sqColor);
        }
        if (selected == (r, c)) {
          sqColor = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.30), sqColor);
        }
        canvas.drawRect(rect, Paint()..color = sqColor);
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = const Color(0xFFD4AF37).withValues(alpha: 0.20),
        );
      }
    }

    if (lastFromR != null && lastFromC != null && lastToR != null && lastToC != null) {
      canvas.drawLine(
        _center(lastFromR, lastFromC),
        _center(lastToR, lastToC),
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: 0.55)
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final p = _center(r, c);
        final v = board[r][c];
        final isSel = selected == (r, c);
        final moveAct = moveTargets[(r, c)];

        if (v != 0) {
          final isWhite = v == 1 || v == 3;
          final isDux = v == 3 || v == 4;
          final radius = cellSize * (isDux ? 0.40 : 0.35);

          if (isSel) {
            canvas.drawCircle(
              p,
              radius + 3.5,
              Paint()..color = Colors.greenAccent.withValues(alpha: 0.85),
            );
          }

          canvas.drawCircle(
            p + const Offset(1.3, 2.2),
            radius,
            Paint()..color = Colors.black54,
          );
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: isWhite
                    ? [const Color(0xFFFFFFFF), const Color(0xFFD7CCC8)]
                    : [const Color(0xFF455A64), const Color(0xFF161B20)],
              ).createShader(Rect.fromCircle(center: p, radius: radius)),
          );
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isDux ? 2.4 : 1.5
              ..color = isDux
                  ? const Color(0xFFFFD54F)
                  : (isWhite ? const Color(0xFFA1887F) : const Color(0xFF78909C)),
          );

          final symbol = isDux ? '🦅' : '⚔';
          final tp = TextPainter(
            text: TextSpan(
              text: symbol,
              style: TextStyle(
                fontSize: cellSize * (isDux ? 0.40 : 0.34),
                fontWeight: FontWeight.bold,
                color: isWhite ? const Color(0xFF3E2723) : const Color(0xFFFFECB3),
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
        }

        if (moveAct != null) {
          final kind = moveAct['kind'] as String? ?? 'slide';
          final isJump = kind == 'dux_jump';
          final col = isJump ? Colors.cyanAccent : Colors.greenAccent;
          canvas.drawCircle(
            p,
            cellSize * 0.16,
            Paint()..color = col.withValues(alpha: 0.85),
          );
          if (isJump) {
            canvas.drawCircle(
              p,
              cellSize * 0.28,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0
                ..color = col.withValues(alpha: 0.9),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LatrunculiPainter oldDelegate) => true;
}
