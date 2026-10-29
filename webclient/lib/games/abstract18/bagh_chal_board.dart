import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class BaghChalBoard extends StatefulWidget {
  final GameContext g;
  const BaghChalBoard(this.g, {super.key});

  @override
  State<BaghChalBoard> createState() => _BaghChalBoardState();
}

class _BaghChalBoardState extends State<BaghChalBoard> {
  (int, int)? _selected;
  (int, int)? _hovered;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final targetCaptures = (v['targetCaptures'] as num?)?.toInt() ?? 5;
    final goatsInReserve = (v['goatsInReserve'] as num?)?.toInt() ?? 20;
    final goatsOnBoard = (v['goatsOnBoard'] as num?)?.toInt() ?? 0;
    final goatsCaptured = (v['goatsCaptured'] as num?)?.toInt() ?? 0;
    final tigerMobility = (v['tigerMobility'] as num?)?.toInt() ?? 0;
    final turn = (v['turn'] as num?)?.toInt() ?? 1;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final lastMove = v['lastMove'] as Map?;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = List.generate(5, (r) {
      final row = r < rawBoard.length ? (rawBoard[r] as List) : const [];
      return List.generate(5, (c) => c < row.length ? (row[c] as num).toInt() : 0);
    });

    final isMyTurn = !over && g.seat == turn;
    final isGoatPlacePhase = turn == 1 && goatsInReserve > 0;

    final rawLegal = (v['legalMoves'] as List?)?.cast<Map>() ?? const [];
    final movesBySource = <(int, int), Map<(int, int), Map>>{};
    for (final m in rawLegal) {
      if (m['type'] == 'move') {
        final fr = (m['fromR'] as num?)?.toInt() ?? -1;
        final fc = (m['fromC'] as num?)?.toInt() ?? -1;
        final tr = (m['toR'] as num?)?.toInt() ?? -1;
        final tc = (m['toC'] as num?)?.toInt() ?? -1;
        if (fr >= 0 && fc >= 0 && tr >= 0 && tc >= 0) {
          movesBySource.putIfAbsent((fr, fc), () => {})[(tr, tc)] = m;
        }
      }
    }

    if (!isMyTurn || isGoatPlacePhase || !movesBySource.containsKey(_selected)) {
      _selected = null;
    }

    final activeTargets = _selected != null
        ? (movesBySource[_selected] ?? const <(int, int), Map>{})
        : const <(int, int), Map>{};

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (turn == 1) {
        if (goatsInReserve > 0) {
          statusText = '【山羊方🐐·布阵阶段】轮到你：点击任意空交叉点放置山羊（储备剩余 $goatsInReserve 只）';
        } else if (_selected == null) {
          statusText = '【山羊方🐐·移羊阶段】轮到你：点击场上山羊沿米字格线移动 1 步围困猛虎';
        } else {
          statusText = '已选山羊 (${_selected!.$1}, ${_selected!.$2})：点击绿色相邻空交叉点移动';
        }
      } else {
        if (_selected == null) {
          statusText = '【猛虎方🐅】轮到你：点击场上猛虎移动 1 步或直线跳过相邻山羊扑杀！（已吃 $goatsCaptured/$targetCaptures）';
        } else {
          statusText = '已选猛虎 (${_selected!.$1}, ${_selected!.$2})：点击高亮交叉点移动或红色交叉点跳吃山羊';
        }
      }
    } else {
      final roleLabel = turn == 0 ? '猛虎方🐅' : '山羊方🐐';
      statusText = '等待 ${g.name(turn)}（$roleLabel）行动…';
    }

    Widget buildPlayerPanel(int s) {
      final isTiger = s == 0;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: isTiger
            ? '🐅 猛虎方 (4虎) · 已吃 $goatsCaptured/$targetCaptures 羊 · 可动 $tigerMobility 步'
            : '🐐 山羊方 · 储备 $goatsInReserve · 场上 $goatsOnBoard · 困死四虎即胜',
        trailing: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isTiger ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
          child: Text(
            isTiger ? '🐅' : '🐐',
            style: const TextStyle(fontSize: 11, fontFamilyFallback: kFontFallback),
          ),
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 20 || h <= 20) return const SizedBox.shrink();

          final boardSide = min(w, h) * 0.88;
          final step = boardSide / 4.0;
          final origin = Offset((w - boardSide) / 2, (h - boardSide) / 2);

          Offset nodePos(int r, int c) => Offset(origin.dx + c * step, origin.dy + r * step);

          (int, int)? hitNodeAt(Offset pos) {
            (int, int)? best;
            var bestDist = step * 0.44;
            for (var r = 0; r < 5; r++) {
              for (var c = 0; c < 5; c++) {
                final d = (pos - nodePos(r, c)).distance;
                if (d < bestDist) {
                  bestDist = d;
                  best = (r, c);
                }
              }
            }
            return best;
          }

          return MouseRegion(
            onHover: !isMyTurn
                ? null
                : (e) {
                    final hit = hitNodeAt(e.localPosition);
                    if (hit != _hovered) setState(() => _hovered = hit);
                  },
            onExit: (_) {
              if (_hovered != null) setState(() => _hovered = null);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: !isMyTurn
                  ? null
                  : (details) {
                      final hit = hitNodeAt(details.localPosition);
                      if (hit == null) {
                        setState(() => _selected = null);
                        return;
                      }
                      final (r, c) = hit;

                      if (isGoatPlacePhase) {
                        if (board[r][c] == 0) {
                          g.act({'type': 'place', 'r': r, 'c': c});
                        }
                        return;
                      }

                      if (_selected != null && activeTargets.containsKey(hit)) {
                        final (fr, fc) = _selected!;
                        setState(() => _selected = null);
                        g.act({
                          'type': 'move',
                          'fromR': fr,
                          'fromC': fc,
                          'toR': r,
                          'toC': c,
                        });
                        return;
                      }

                      if (movesBySource.containsKey(hit)) {
                        setState(() => _selected = hit);
                      } else {
                        setState(() => _selected = null);
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _BaghChalPainter(
                  board: board,
                  movableSources: movesBySource.keys.toSet(),
                  selected: _selected,
                  activeTargets: activeTargets,
                  hovered: _hovered,
                  lastMove: lastMove,
                  isMyTurn: isMyTurn,
                  isGoatPlacePhase: isGoatPlacePhase,
                  origin: origin,
                  boardSide: boardSide,
                  step: step,
                  cs: cs,
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
                          width: min(260, outer.maxWidth * 0.32),
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
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

class _BaghChalPainter extends CustomPainter {
  final List<List<int>> board;
  final Set<(int, int)> movableSources;
  final (int, int)? selected;
  final Map<(int, int), Map> activeTargets;
  final (int, int)? hovered;
  final Map? lastMove;
  final bool isMyTurn;
  final bool isGoatPlacePhase;
  final Offset origin;
  final double boardSide;
  final double step;
  final ColorScheme cs;

  _BaghChalPainter({
    required this.board,
    required this.movableSources,
    required this.selected,
    required this.activeTargets,
    required this.hovered,
    required this.lastMove,
    required this.isMyTurn,
    required this.isGoatPlacePhase,
    required this.origin,
    required this.boardSide,
    required this.step,
    required this.cs,
  });

  Offset _nodePos(int r, int c) => Offset(origin.dx + c * step, origin.dy + r * step);

  @override
  void paint(Canvas canvas, Size size) {
    final pad = step * 0.46;
    final boardRect = Rect.fromLTWH(origin.dx - pad, origin.dy - pad, boardSide + pad * 2, boardSide + pad * 2);

    // Brass/wood Nepalese board background
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(step * 0.22)),
      Paint()..color = const Color(0xFF3E2723),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.deflate(step * 0.08), Radius.circular(step * 0.16)),
      Paint()..color = const Color(0xFF4E342E),
    );

    final linePaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.55)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Orthogonal grid lines
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(_nodePos(i, 0), _nodePos(i, 4), linePaint);
      canvas.drawLine(_nodePos(0, i), _nodePos(4, i), linePaint);
    }

    // Alquerque diagonal lines (two main diagonals + diamond connecting midpoints)
    canvas.drawLine(_nodePos(0, 0), _nodePos(4, 4), linePaint);
    canvas.drawLine(_nodePos(0, 4), _nodePos(4, 0), linePaint);
    canvas.drawLine(_nodePos(0, 2), _nodePos(2, 0), linePaint);
    canvas.drawLine(_nodePos(0, 2), _nodePos(2, 4), linePaint);
    canvas.drawLine(_nodePos(4, 2), _nodePos(2, 0), linePaint);
    canvas.drawLine(_nodePos(4, 2), _nodePos(2, 4), linePaint);

    // Draw nodes and pieces
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        final pos = _nodePos(r, c);
        final v = board[r][c];
        final tInfo = activeTargets[(r, c)];

        // Empty intersection dot
        canvas.drawCircle(
          pos,
          step * 0.10,
          Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.7),
        );

        if (isMyTurn && isGoatPlacePhase && v == 0 && hovered == (r, c)) {
          canvas.drawCircle(
            pos,
            step * 0.28,
            Paint()..color = Colors.greenAccent.withValues(alpha: 0.45),
          );
        }

        if (tInfo != null) {
          final isCap = tInfo['capture'] == true;
          final tColor = isCap ? const Color(0xFFFF5252) : const Color(0xFF00E676);
          canvas.drawCircle(
            pos,
            step * 0.24,
            Paint()..color = tColor.withValues(alpha: 0.8),
          );
          canvas.drawCircle(
            pos,
            step * 0.24,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0
              ..color = Colors.white,
          );
        }

        if (v > 0) {
          final isTiger = v == 1;
          final radius = step * (isTiger ? 0.36 : 0.31);
          canvas.drawCircle(
            pos + Offset(step * 0.03, step * 0.04),
            radius,
            Paint()..color = Colors.black54,
          );

          final fill = isTiger ? const Color(0xFFE65100) : const Color(0xFFF5F5DC);
          final isSel = selected == (r, c);
          final isMovable = isMyTurn && !isGoatPlacePhase && movableSources.contains((r, c));

          canvas.drawCircle(pos, radius, Paint()..color = fill);
          canvas.drawCircle(
            pos,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isSel ? 3.0 : (isMovable ? 2.4 : 1.8)
              ..color = isSel
                  ? Colors.cyanAccent
                  : (isMovable
                      ? Colors.greenAccent
                      : (isTiger ? const Color(0xFFFFD740) : const Color(0xFF2E7D32))),
          );

          final tp = TextPainter(
            text: TextSpan(
              text: isTiger ? '🐅' : '🐐',
              style: TextStyle(
                fontSize: step * (isTiger ? 0.34 : 0.28),
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BaghChalPainter oldDelegate) => true;
}
