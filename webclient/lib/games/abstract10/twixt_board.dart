import 'dart:math' as math;

import 'package:aurora_shared/games/abstract10/twixt.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TwixtBoard extends StatefulWidget {
  final GameContext g;
  const TwixtBoard(this.g, {super.key});

  @override
  State<TwixtBoard> createState() => _TwixtBoardState();
}

class _TwixtBoardState extends State<TwixtBoard> {
  (int, int)? _hoverCell;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  bool _canPlace(
    int seat,
    int r,
    int c,
    int size,
    List<List<int>> board,
  ) {
    if (r < 0 || r >= size || c < 0 || c >= size) return false;
    if ((r == 0 || r == size - 1) && (c == 0 || c == size - 1)) return false;
    if (seat == 0 && (c == 0 || c == size - 1)) return false;
    if (seat == 1 && (r == 0 || r == size - 1)) return false;
    return board[r][c] == 0;
  }

  void _onTapCell(
    int r,
    int c,
    int size,
    List<List<int>> board,
    int turn,
    bool over,
  ) {
    if (over || g.seat != turn) return;
    if (!_canPlace(turn, r, c, size, board)) return;
    g.act({'type': 'place', 'r': r, 'c': c});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = (v['size'] as int?) ?? 12;
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = <List<int>>[
      for (var r = 0; r < size; r++)
        r < rawBoard.length
            ? (rawBoard[r] as List).map((e) => (e as num).toInt()).toList()
            : List<int>.filled(size, 0),
    ];

    final bridges = ((v['bridges'] as List?) ?? const [])
        .map((e) => (e as List).map((x) => (x as num).toInt()).toList())
        .toList();

    final pegCounts = ((v['pegCounts'] as List?) ?? const [0, 0])
        .map((e) => (e as num).toInt())
        .toList();
    final bridgeCounts = ((v['bridgeCounts'] as List?) ?? const [0, 0])
        .map((e) => (e as num).toInt())
        .toList();

    final winningPath = ((v['winningPath'] as List?) ?? const [])
        .map((e) => (e as List).map((x) => (x as num).toInt()).toList())
        .toList();

    final lastMove = v['lastMove'] as Map?;
    final resultText = v['result'] as String?;

    String statusText;
    if (over) {
      statusText = resultText ?? '对局结束';
    } else if (g.seat == turn) {
      statusText =
          '轮到你插桩（${turn == 0 ? "红方：连通上下边界" : "黑方：连通左右边界"}）';
    } else {
      statusText =
          '等待 ${g.name(turn)}（${turn == 0 ? "红方" : "黑方"}）插桩搭桥…';
    }

    final p0Pegs = pegCounts.isNotEmpty ? pegCounts[0] : 0;
    final p1Pegs = pegCounts.length > 1 ? pegCounts[1] : 0;
    final p0Br = bridgeCounts.isNotEmpty ? bridgeCounts[0] : 0;
    final p1Br = bridgeCounts.length > 1 ? bridgeCounts[1] : 0;

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 460;
          return Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      g.tag(
                        0,
                        active: !over && turn == 0,
                        sub: '🔴 上下边界 · 桩$p0Pegs 桥$p0Br',
                        size: isCompact ? 28 : 34,
                      ),
                      StatusBar(statusText, highlight: !over && g.seat == turn),
                      g.tag(
                        1,
                        active: !over && turn == 1,
                        sub: '⚫ 左右边界 · 桩$p1Pegs 桥$p1Br',
                        size: isCompact ? 28 : 34,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final side = math.min(box.maxWidth, box.maxHeight);
                            final pad = side * 0.07;
                            final step =
                                size > 1 ? (side - pad * 2) / (size - 1) : 1.0;

                            (int, int)? hitCell(Offset pos) {
                              final c = ((pos.dx - pad) / step).round();
                              final r = ((pos.dy - pad) / step).round();
                              if (r < 0 || r >= size || c < 0 || c >= size) {
                                return null;
                              }
                              final cx = pad + c * step;
                              final cy = pad + r * step;
                              if ((pos - Offset(cx, cy)).distance <=
                                  step * 0.52) {
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
                                    _onTapCell(
                                      h.$1,
                                      h.$2,
                                      size,
                                      board,
                                      turn,
                                      over,
                                    );
                                  }
                                },
                                child: CustomPaint(
                                  size: Size(side, side),
                                  painter: _TwixtPainter(
                                    size: size,
                                    board: board,
                                    bridges: bridges,
                                    winningPath: winningPath,
                                    lastMove: lastMove,
                                    hoverCell: (!over && g.seat == turn)
                                        ? _hoverCell
                                        : null,
                                    turn: turn,
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

class _TwixtPainter extends CustomPainter {
  final int size;
  final List<List<int>> board;
  final List<List<int>> bridges;
  final List<List<int>> winningPath;
  final Map? lastMove;
  final (int, int)? hoverCell;
  final int turn;
  final ColorScheme cs;

  _TwixtPainter({
    required this.size,
    required this.board,
    required this.bridges,
    required this.winningPath,
    required this.lastMove,
    required this.hoverCell,
    required this.turn,
    required this.cs,
  });

  static const Color _redColor = Color(0xFFD63031);
  static const Color _redLight = Color(0xFFFF6B6B);
  static const Color _blackColor = Color(0xFF2D3436);
  static const Color _blackLight = Color(0xFF636E72);

  bool _isCorner(int r, int c) =>
      (r == 0 || r == size - 1) && (c == 0 || c == size - 1);

  bool _canPlace(int seat, int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size || _isCorner(r, c)) {
      return false;
    }
    if (seat == 0 && (c == 0 || c == size - 1)) return false;
    if (seat == 1 && (r == 0 || r == size - 1)) return false;
    return board[r][c] == 0;
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final side = math.min(canvasSize.width, canvasSize.height);
    final rect = Rect.fromLTWH(0, 0, side, side);

    // Classic ivory/warm-parchment TwixT board surface
    final bgRRect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5EFE6), Color(0xFFE5DCCB)],
      ).createShader(rect);
    canvas.drawRRect(bgRRect, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF6D5D4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(bgRRect, borderPaint);

    if (size <= 2) return;
    final pad = side * 0.07;
    final step = (side - pad * 2) / (size - 1);

    Offset holeOffset(int r, int c) => Offset(pad + c * step, pad + r * step);

    // Draw border goal lines separating row 0 / row N-1 (Red) and col 0 / col N-1 (Black)
    final topBorderY = pad + 0.5 * step;
    final botBorderY = pad + (size - 1.5) * step;
    final leftBorderX = pad + 0.5 * step;
    final rightBorderX = pad + (size - 1.5) * step;

    final redLinePaint = Paint()
      ..color = _redColor.withValues(alpha: 0.72)
      ..strokeWidth = math.max(2.0, step * 0.08)
      ..strokeCap = StrokeCap.round;

    final blackLinePaint = Paint()
      ..color = _blackColor.withValues(alpha: 0.72)
      ..strokeWidth = math.max(2.0, step * 0.08)
      ..strokeCap = StrokeCap.round;

    // Red top & bottom border lines
    canvas.drawLine(
      Offset(leftBorderX, topBorderY),
      Offset(rightBorderX, topBorderY),
      redLinePaint,
    );
    canvas.drawLine(
      Offset(leftBorderX, botBorderY),
      Offset(rightBorderX, botBorderY),
      redLinePaint,
    );

    // Black left & right border lines
    canvas.drawLine(
      Offset(leftBorderX, topBorderY),
      Offset(leftBorderX, botBorderY),
      blackLinePaint,
    );
    canvas.drawLine(
      Offset(rightBorderX, topBorderY),
      Offset(rightBorderX, botBorderY),
      blackLinePaint,
    );

    // Draw holes
    final holeRadius = math.max(2.2, step * 0.12);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (_isCorner(r, c)) continue;
        final pos = holeOffset(r, c);
        Color holeColor = const Color(0xFF7F705D);
        if (r == 0 || r == size - 1) {
          holeColor = _redColor.withValues(alpha: 0.65);
        } else if (c == 0 || c == size - 1) {
          holeColor = _blackColor.withValues(alpha: 0.65);
        }
        canvas.drawCircle(pos, holeRadius, Paint()..color = holeColor);
      }
    }

    // Draw existing bridges
    final bridgeWidth = math.max(3.2, step * 0.16);
    for (final b in bridges) {
      if (b.length < 5) continue;
      final p1 = holeOffset(b[0], b[1]);
      final p2 = holeOffset(b[2], b[3]);
      final owner = b[4];

      // Bridge shadow
      canvas.drawLine(
        p1.translate(1.0, 1.5),
        p2.translate(1.0, 1.5),
        Paint()
          ..color = Colors.black26
          ..strokeWidth = bridgeWidth
          ..strokeCap = StrokeCap.round,
      );

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = owner == 0 ? _redColor : _blackColor
          ..strokeWidth = bridgeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Highlight winning bridge chain if game is over
    if (winningPath.length >= 2) {
      final winPaint = Paint()
        ..color = Colors.amberAccent
        ..strokeWidth = bridgeWidth * 0.65
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < winningPath.length - 1; i++) {
        final a = winningPath[i];
        final b = winningPath[i + 1];
        canvas.drawLine(
          holeOffset(a[0], a[1]),
          holeOffset(b[0], b[1]),
          winPaint,
        );
      }
    }

    // Hover preview peg & potential new bridges
    if (hoverCell != null) {
      final (hr, hc) = hoverCell!;
      if (_canPlace(turn, hr, hc)) {
        final hPos = holeOffset(hr, hc);
        final me = turn + 1;
        final previewBridgePaint = Paint()
          ..color =
              (turn == 0 ? _redColor : _blackColor).withValues(alpha: 0.45)
          ..strokeWidth = bridgeWidth * 0.85
          ..strokeCap = StrokeCap.round;

        for (final (dr, dc) in TwixtGame.knightMoves) {
          final nr = hr + dr;
          final nc = hc + dc;
          if (nr >= 0 &&
              nr < size &&
              nc >= 0 &&
              nc < size &&
              board[nr][nc] == me) {
            var crosses = false;
            for (final b in bridges) {
              if (TwixtGame.segmentsIntersect(
                hr,
                hc,
                nr,
                nc,
                b[0],
                b[1],
                b[2],
                b[3],
              )) {
                crosses = true;
                break;
              }
            }
            if (!crosses) {
              canvas.drawLine(hPos, holeOffset(nr, nc), previewBridgePaint);
            }
          }
        }

        canvas.drawCircle(
          hPos,
          step * 0.34,
          Paint()
            ..color =
                (turn == 0 ? _redColor : _blackColor).withValues(alpha: 0.42),
        );
      }
    }

    // Draw placed pegs
    final pegRadius = step * 0.34;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = board[r][c];
        if (v == 0) continue;
        final center = holeOffset(r, c);

        canvas.drawCircle(
          center.translate(1.2, 1.6),
          pegRadius,
          Paint()..color = Colors.black38,
        );

        final pegPaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.85,
            colors: v == 1
                ? const [_redLight, _redColor]
                : const [_blackLight, _blackColor],
          ).createShader(Rect.fromCircle(center: center, radius: pegRadius));
        canvas.drawCircle(center, pegRadius, pegPaint);

        // Inner peg pin-hole accent
        canvas.drawCircle(
          center,
          pegRadius * 0.28,
          Paint()..color = Colors.white.withValues(alpha: 0.65),
        );
      }
    }

    // Highlight last move
    if (lastMove != null && lastMove!['r'] is num && lastMove!['c'] is num) {
      final lr = (lastMove!['r'] as num).toInt();
      final lc = (lastMove!['c'] as num).toInt();
      if (lr >= 0 && lr < size && lc >= 0 && lc < size) {
        canvas.drawCircle(
          holeOffset(lr, lc),
          pegRadius * 1.18,
          Paint()
            ..color = Colors.amberAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TwixtPainter oldDelegate) => true;
}
