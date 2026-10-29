import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class PenteBoard extends StatefulWidget {
  final GameContext g;
  const PenteBoard(this.g, {super.key});

  @override
  State<PenteBoard> createState() => _PenteBoardState();
}

class _PenteBoardState extends State<PenteBoard> {
  (int, int)? _hoverCell;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  void _onTapCell(int r, int c, List<List<int>> board, int turn, bool over) {
    if (over || g.seat != turn) return;
    if (r < 0 || r >= board.length || c < 0 || c >= board.length) return;
    if (board[r][c] != 0) return;
    g.act({'type': 'place', 'r': r, 'c': c});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = (v['size'] as int?) ?? 13;
    final targetPairs = (v['targetPairs'] as int?) ?? 5;
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;
    final rawBoard = (v['board'] as List?) ?? const [];
    final board = <List<int>>[
      for (var r = 0; r < size; r++)
        r < rawBoard.length
            ? (rawBoard[r] as List).map((e) => (e as num).toInt()).toList()
            : List<int>.filled(size, 0),
    ];
    final capList = ((v['capturedPairs'] as List?) ?? const [0, 0])
        .map((e) => (e as num).toInt())
        .toList();
    final cap0 = capList.isNotEmpty ? capList[0] : 0;
    final cap1 = capList.length > 1 ? capList[1] : 0;

    final lastMove = v['lastMove'] as Map?;
    final winningLine = ((v['winningLine'] as List?) ?? const [])
        .map((e) => (e as List).map((x) => (x as num).toInt()).toList())
        .toList();
    final resultText = v['result'] as String?;

    String statusText;
    if (over) {
      statusText = resultText ?? '对局结束';
    } else if (g.seat == turn) {
      statusText = '轮到你落子（${turn == 0 ? "黑子" : "白子"}）：连成五子或夹吃满 $targetPairs 对获胜';
    } else {
      statusText = '等待 ${g.name(turn)}（${turn == 0 ? "黑子" : "白子"}）落子…';
    }

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompactHeight = constraints.maxHeight < 460;
          return Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  // Top header bar: players & status
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      g.tag(
                        0,
                        active: !over && turn == 0,
                        sub: '● 黑棋 · 夹吃 $cap0/$targetPairs 对',
                        size: isCompactHeight ? 28 : 34,
                      ),
                      StatusBar(statusText, highlight: !over && g.seat == turn),
                      g.tag(
                        1,
                        active: !over && turn == 1,
                        sub: '○ 白棋 · 夹吃 $cap1/$targetPairs 对',
                        size: isCompactHeight ? 28 : 34,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, boardBox) {
                            final side = math.min(boardBox.maxWidth, boardBox.maxHeight);
                            final pad = side * 0.065;
                            final step = size > 1 ? (side - pad * 2) / (size - 1) : 1.0;

                            (int, int)? hitCell(Offset pos) {
                              final c = ((pos.dx - pad) / step).round();
                              final r = ((pos.dy - pad) / step).round();
                              if (r < 0 || r >= size || c < 0 || c >= size) return null;
                              final cx = pad + c * step;
                              final cy = pad + r * step;
                              if ((pos - Offset(cx, cy)).distance <= step * 0.55) {
                                return (r, c);
                              }
                              return null;
                            }

                            return MouseRegion(
                              onHover: (ev) {
                                final h = hitCell(ev.localPosition);
                                if (h != _hoverCell) {
                                  setState(() => _hoverCell = h);
                                }
                              },
                              onExit: (_) {
                                if (_hoverCell != null) {
                                  setState(() => _hoverCell = null);
                                }
                              },
                              child: GestureDetector(
                                onTapUp: (d) {
                                  final h = hitCell(d.localPosition);
                                  if (h != null) {
                                    _onTapCell(h.$1, h.$2, board, turn, over);
                                  }
                                },
                                child: CustomPaint(
                                  size: Size(side, side),
                                  painter: _PenteGridPainter(
                                    size: size,
                                    board: board,
                                    lastMove: lastMove,
                                    winningLine: winningLine,
                                    hoverCell: (!over && g.seat == turn) ? _hoverCell : null,
                                    myColor: turn + 1,
                                    cs: cs,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (over && resultText != null) ResultBanner(resultText),
            ],
          );
        },
      ),
    );
  }
}

class _PenteGridPainter extends CustomPainter {
  final int size;
  final List<List<int>> board;
  final Map? lastMove;
  final List<List<int>> winningLine;
  final (int, int)? hoverCell;
  final int myColor;
  final ColorScheme cs;

  _PenteGridPainter({
    required this.size,
    required this.board,
    required this.lastMove,
    required this.winningLine,
    required this.hoverCell,
    required this.myColor,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final side = math.min(canvasSize.width, canvasSize.height);
    final rect = Rect.fromLTWH(0, 0, side, side);

    // Warm wooden board background
    final bgRRect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDEB887), Color(0xFFC89D66)],
      ).createShader(rect);
    canvas.drawRRect(bgRRect, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF5D3A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(bgRRect, borderPaint);

    if (size <= 1) return;
    final pad = side * 0.065;
    final step = (side - pad * 2) / (size - 1);

    final linePaint = Paint()
      ..color = const Color(0xFF4A2E14).withValues(alpha: 0.78)
      ..strokeWidth = 1.2;

    for (var i = 0; i < size; i++) {
      final pos = pad + i * step;
      canvas.drawLine(Offset(pad, pos), Offset(side - pad, pos), linePaint);
      canvas.drawLine(Offset(pos, pad), Offset(pos, side - pad), linePaint);
    }

    // Center & star points
    final center = size ~/ 2;
    final stars = <(int, int)>{
      (center, center),
      if (size >= 11) ...{
        (3, 3),
        (3, size - 4),
        (size - 4, 3),
        (size - 4, size - 4),
      },
    };
    final starPaint = Paint()..color = const Color(0xFF3E240D);
    for (final (sr, sc) in stars) {
      canvas.drawCircle(
        Offset(pad + sc * step, pad + sr * step),
        math.max(2.5, step * 0.11),
        starPaint,
      );
    }

    // Highlight recently captured intersections with red x/ring markers
    final captured = (lastMove?['captured'] as List?) ?? const [];
    for (final item in captured) {
      if (item is List && item.length >= 2) {
        final cr = (item[0] as num).toInt();
        final cc = (item[1] as num).toInt();
        final cx = pad + cc * step;
        final cy = pad + cr * step;
        final capPaint = Paint()
          ..color = Colors.redAccent.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(cx, cy), step * 0.28, capPaint);
      }
    }

    // Hover preview stone
    if (hoverCell != null) {
      final (hr, hc) = hoverCell!;
      if (hr >= 0 && hr < size && hc >= 0 && hc < size && board[hr][hc] == 0) {
        final cx = pad + hc * step;
        final cy = pad + hr * step;
        final ghostPaint = Paint()
          ..color = (myColor == 1 ? Colors.black : Colors.white).withValues(alpha: 0.38);
        canvas.drawCircle(Offset(cx, cy), step * 0.41, ghostPaint);
      }
    }

    // Draw stones
    final stoneRadius = step * 0.42;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = board[r][c];
        if (v == 0) continue;
        final cx = pad + c * step;
        final cy = pad + r * step;
        final centerOffset = Offset(cx, cy);

        canvas.drawCircle(
          centerOffset.translate(1.5, 2.0),
          stoneRadius,
          Paint()..color = Colors.black38,
        );

        final stonePaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.85,
            colors: v == 1
                ? const [Color(0xFF555555), Color(0xFF141414)]
                : const [Color(0xFFFFFFFF), Color(0xFFD6D6D6)],
          ).createShader(Rect.fromCircle(center: centerOffset, radius: stoneRadius));
        canvas.drawCircle(centerOffset, stoneRadius, stonePaint);

        if (v == 2) {
          canvas.drawCircle(
            centerOffset,
            stoneRadius,
            Paint()
              ..color = Colors.black26
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        }
      }
    }

    // Highlight last move
    if (lastMove != null && lastMove!['r'] is num && lastMove!['c'] is num) {
      final lr = (lastMove!['r'] as num).toInt();
      final lc = (lastMove!['c'] as num).toInt();
      if (lr >= 0 && lr < size && lc >= 0 && lc < size) {
        final cx = pad + lc * step;
        final cy = pad + lr * step;
        final markerPaint = Paint()
          ..color = Colors.amberAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawCircle(Offset(cx, cy), stoneRadius * 0.48, markerPaint);
      }
    }

    // Highlight winning 5-in-a-row line
    if (winningLine.length >= 2) {
      final first = winningLine.first;
      final last = winningLine.last;
      final p1 = Offset(pad + first[1] * step, pad + first[0] * step);
      final p2 = Offset(pad + last[1] * step, pad + last[0] * step);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: 0.9)
          ..strokeWidth = math.max(3.0, step * 0.16)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PenteGridPainter oldDelegate) => true;
}
