import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class _CandidateDest {
  final int tailR;
  final int tailC;
  final int dr;
  final int dc;
  final int len;
  final int steps;
  final int targetR;
  final int targetC;
  final bool isCapture;

  const _CandidateDest({
    required this.tailR,
    required this.tailC,
    required this.dr,
    required this.dc,
    required this.len,
    required this.steps,
    required this.targetR,
    required this.targetC,
    required this.isCapture,
  });
}

class EpaminondasBoard extends StatefulWidget {
  final GameContext g;
  const EpaminondasBoard(this.g, {super.key});

  @override
  State<EpaminondasBoard> createState() => _EpaminondasBoardState();
}

class _EpaminondasBoardState extends State<EpaminondasBoard> {
  (int, int)? _anchor;
  (int, int)? _endStone;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static const List<(int, int)> _dirs8 = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  bool _inBounds(int r, int c, int rows, int cols) =>
      r >= 0 && r < rows && c >= 0 && c < cols;

  List<(int, int)> _selectedStones(List<List<int>> board, int rows, int cols) {
    if (_anchor == null) return const [];
    final (r1, c1) = _anchor!;
    if (!_inBounds(r1, c1, rows, cols)) return const [];
    if (_endStone == null || _endStone == _anchor) return [(r1, c1)];
    final (r2, c2) = _endStone!;
    final dr = (r2 - r1).sign;
    final dc = (c2 - c1).sign;
    final len = math.max((r2 - r1).abs(), (c2 - c1).abs()) + 1;
    return [
      for (var i = 0; i < len; i++) (r1 + i * dr, c1 + i * dc),
    ];
  }

  List<_CandidateDest> _computeCandidates(
    List<List<int>> board,
    int rows,
    int cols,
    int seat,
  ) {
    if (_anchor == null) return const [];
    final me = seat + 1;
    final opp = 2 - seat;
    final (r1, c1) = _anchor!;
    if (!_inBounds(r1, c1, rows, cols) || board[r1][c1] != me) return const [];

    final out = <_CandidateDest>[];

    void addPhalanxRay(int tailR, int tailC, int dr, int dc, int len) {
      final headR = tailR + (len - 1) * dr;
      final headC = tailC + (len - 1) * dc;
      for (var s = 1; s <= len; s++) {
        final tr = headR + s * dr;
        final tc = headC + s * dc;
        if (!_inBounds(tr, tc, rows, cols)) break;
        final cell = board[tr][tc];
        if (cell == me) break;
        if (cell == 0) {
          out.add(
            _CandidateDest(
              tailR: tailR,
              tailC: tailC,
              dr: dr,
              dc: dc,
              len: len,
              steps: s,
              targetR: tr,
              targetC: tc,
              isCapture: false,
            ),
          );
        } else if (cell == opp) {
          if (len >= 2) {
            var enemyCount = 0;
            while (_inBounds(
                  tr + enemyCount * dr,
                  tc + enemyCount * dc,
                  rows,
                  cols,
                ) &&
                board[tr + enemyCount * dr][tc + enemyCount * dc] == opp) {
              enemyCount++;
            }
            if (len > enemyCount) {
              out.add(
                _CandidateDest(
                  tailR: tailR,
                  tailC: tailC,
                  dr: dr,
                  dc: dc,
                  len: len,
                  steps: s,
                  targetR: tr,
                  targetC: tc,
                  isCapture: true,
                ),
              );
            }
          }
          break;
        }
      }
    }

    if (_endStone == null || _endStone == _anchor) {
      // Single stone moves in all 8 directions + auto-detected maximal phalanx moves from _anchor as tail
      for (final (dr, dc) in _dirs8) {
        final nr = r1 + dr;
        final nc = c1 + dc;
        if (_inBounds(nr, nc, rows, cols) && board[nr][nc] == 0) {
          out.add(
            _CandidateDest(
              tailR: r1,
              tailC: c1,
              dr: dr,
              dc: dc,
              len: 1,
              steps: 1,
              targetR: nr,
              targetC: nc,
              isCapture: false,
            ),
          );
        }

        // Also check if (r1, c1) is the tail of a contiguous line of friendly stones
        var maxL = 1;
        while (_inBounds(r1 + maxL * dr, c1 + maxL * dc, rows, cols) &&
            board[r1 + maxL * dr][c1 + maxL * dc] == me) {
          maxL++;
        }
        if (maxL >= 2) {
          addPhalanxRay(r1, c1, dr, dc, maxL);
        }
      }
    } else {
      // Explicit phalanx between _anchor and _endStone
      final (r2, c2) = _endStone!;
      final dr = (r2 - r1).sign;
      final dc = (c2 - c1).sign;
      final len = math.max((r2 - r1).abs(), (c2 - c1).abs()) + 1;
      // Forward from r1 -> r2
      addPhalanxRay(r1, c1, dr, dc, len);
      // Or backward from r2 -> r1
      addPhalanxRay(r2, c2, -dr, -dc, len);
    }

    return out;
  }

  void _onTapCell(
    int r,
    int c,
    List<List<int>> board,
    int rows,
    int cols,
    int turn,
    bool over,
  ) {
    if (over || g.seat != turn) return;
    if (!_inBounds(r, c, rows, cols)) return;

    final me = turn + 1;
    final candidates = _computeCandidates(board, rows, cols, turn);

    // 1. Check if (r, c) is a legal destination for the current selection
    for (final cand in candidates) {
      if (cand.targetR == r && cand.targetC == c) {
        setState(() {
          _anchor = null;
          _endStone = null;
        });
        g.act({
          'type': 'move',
          'r': cand.tailR,
          'c': cand.tailC,
          'dr': cand.dr,
          'dc': cand.dc,
          'len': cand.len,
          'steps': cand.steps,
          'from': [cand.tailR, cand.tailC],
          'to': [cand.targetR, cand.targetC],
        });
        return;
      }
    }

    // 2. If tapping a friendly stone: either start a new selection or extend phalanx
    if (board[r][c] == me) {
      if (_anchor == null) {
        setState(() {
          _anchor = (r, c);
          _endStone = null;
        });
        return;
      }
      final (ar, ac) = _anchor!;
      if (ar == r && ac == c) {
        setState(() {
          _anchor = null;
          _endStone = null;
        });
        return;
      }

      // Check if (r, c) forms a contiguous friendly line with _anchor
      final diffR = r - ar;
      final diffC = c - ac;
      if (diffR == 0 || diffC == 0 || diffR.abs() == diffC.abs()) {
        final dr = diffR.sign;
        final dc = diffC.sign;
        final len = math.max(diffR.abs(), diffC.abs()) + 1;
        var allMe = true;
        for (var i = 0; i < len; i++) {
          if (board[ar + i * dr][ac + i * dc] != me) {
            allMe = false;
            break;
          }
        }
        if (allMe) {
          setState(() {
            _endStone = (r, c);
          });
          return;
        }
      }

      // Otherwise switch anchor to the newly tapped stone
      setState(() {
        _anchor = (r, c);
        _endStone = null;
      });
      return;
    }

    // 3. Tapped an empty or non-reachable enemy cell: clear selection
    setState(() {
      _anchor = null;
      _endStone = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = (v['rows'] as int?) ?? 8;
    final cols = (v['cols'] as int?) ?? 10;
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = <List<int>>[
      for (var r = 0; r < rows; r++)
        r < rawBoard.length
            ? (rawBoard[r] as List).map((e) => (e as num).toInt()).toList()
            : List<int>.filled(cols, 0),
    ];

    final stoneCounts = ((v['stoneCounts'] as List?) ?? const [20, 20])
        .map((e) => (e as num).toInt())
        .toList();
    final backRankCounts = ((v['backRankCounts'] as List?) ?? const [0, 0])
        .map((e) => (e as num).toInt())
        .toList();

    final lastMove = v['lastMove'] as Map?;
    final resultText = v['result'] as String?;

    final candidates = (!over && g.seat == turn)
        ? _computeCandidates(board, rows, cols, turn)
        : const <_CandidateDest>[];
    final selectedStones = (!over && g.seat == turn)
        ? _selectedStones(board, rows, cols)
        : const <(int, int)>[];

    String statusText;
    if (over) {
      statusText = resultText ?? '对局结束';
    } else if (g.seat == turn) {
      if (_anchor == null) {
        statusText =
            '轮到你行动（${turn == 0 ? "白棋▲冲顶行" : "黑棋▼冲底行"}）：点击棋子（可再点同线棋子选方阵）后移动';
      } else {
        statusText =
            '已选 ${selectedStones.length} 子${selectedStones.length >= 2 ? "方阵" : ""}：点击高亮目标格推进，或点击同线己子调整方阵长度';
      }
    } else {
      statusText = '等待 ${g.name(turn)}（${turn == 0 ? "白棋" : "黑棋"}）调遣方阵…';
    }

    final s0 = stoneCounts.isNotEmpty ? stoneCounts[0] : 0;
    final s1 = stoneCounts.length > 1 ? stoneCounts[1] : 0;
    final b0 = backRankCounts.isNotEmpty ? backRankCounts[0] : 0;
    final b1 = backRankCounts.length > 1 ? backRankCounts[1] : 0;

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
                        sub: '⚪ 白棋 $s0 · 敌底线 $b0',
                        size: isCompact ? 28 : 34,
                      ),
                      StatusBar(statusText, highlight: !over && g.seat == turn),
                      g.tag(
                        1,
                        active: !over && turn == 1,
                        sub: '⚫ 黑棋 $s1 · 敌底线 $b1',
                        size: isCompact ? 28 : 34,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: cols / rows,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final cellW = box.maxWidth / cols;
                            final cellH = box.maxHeight / rows;
                            final cell = math.min(cellW, cellH);
                            final boardW = cell * cols;
                            final boardH = cell * rows;

                            return GestureDetector(
                              onTapUp: (d) {
                                final c = (d.localPosition.dx / cell).floor();
                                final r = (d.localPosition.dy / cell).floor();
                                _onTapCell(
                                  r,
                                  c,
                                  board,
                                  rows,
                                  cols,
                                  turn,
                                  over,
                                );
                              },
                              child: CustomPaint(
                                size: Size(boardW, boardH),
                                painter: _EpaminondasPainter(
                                  rows: rows,
                                  cols: cols,
                                  board: board,
                                  selectedStones: selectedStones,
                                  candidates: candidates,
                                  lastMove: lastMove,
                                  cs: cs,
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

class _EpaminondasPainter extends CustomPainter {
  final int rows;
  final int cols;
  final List<List<int>> board;
  final List<(int, int)> selectedStones;
  final List<_CandidateDest> candidates;
  final Map? lastMove;
  final ColorScheme cs;

  _EpaminondasPainter({
    required this.rows,
    required this.cols,
    required this.board,
    required this.selectedStones,
    required this.candidates,
    required this.lastMove,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / cols, size.height / rows);
    final boardW = cell * cols;
    final boardH = cell * rows;
    final fullRect = Rect.fromLTWH(0, 0, boardW, boardH);

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(fullRect, const Radius.circular(10)),
    );

    // Draw checkerboard cells with subtle back-rank tinting on row 0 and row rows-1
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final isLight = (r + c).isEven;
        Color cellColor = isLight
            ? const Color(0xFFEAD2AC)
            : const Color(0xFFC59B6D);
        if (r == 0) {
          cellColor = Color.lerp(cellColor, const Color(0xFF4A90E2), 0.16)!;
        } else if (r == rows - 1) {
          cellColor = Color.lerp(cellColor, const Color(0xFFD0021B), 0.14)!;
        }
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          Paint()..color = cellColor,
        );
      }
    }

    // Highlight last move cells
    final newCells = (lastMove?['newCells'] as List?) ?? const [];
    for (final item in newCells) {
      if (item is List && item.length >= 2) {
        final lr = (item[0] as num).toInt();
        final lc = (item[1] as num).toInt();
        canvas.drawRect(
          Rect.fromLTWH(lc * cell, lr * cell, cell, cell),
          Paint()..color = Colors.amber.withValues(alpha: 0.35),
        );
      }
    }

    // Highlight selected phalanx stones
    for (final (sr, sc) in selectedStones) {
      canvas.drawRect(
        Rect.fromLTWH(sc * cell, sr * cell, cell, cell),
        Paint()..color = Colors.cyanAccent.withValues(alpha: 0.42),
      );
    }

    // Draw stones
    final radius = cell * 0.39;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = board[r][c];
        if (v == 0) continue;
        final center = Offset((c + 0.5) * cell, (r + 0.5) * cell);

        canvas.drawCircle(
          center.translate(1.2, 1.8),
          radius,
          Paint()..color = Colors.black38,
        );

        final stonePaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.85,
            colors: v == 1
                ? const [Color(0xFFFFFFFF), Color(0xFFD5D5D5)]
                : const [Color(0xFF555555), Color(0xFF161616)],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawCircle(center, radius, stonePaint);

        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = v == 1 ? Colors.black26 : Colors.white24
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1,
        );
      }
    }

    // Draw candidate destination markers
    final seenTargets = <(int, int), bool>{};
    for (final cand in candidates) {
      final key = (cand.targetR, cand.targetC);
      final prevCap = seenTargets[key] ?? false;
      seenTargets[key] = prevCap || cand.isCapture;
    }

    for (final entry in seenTargets.entries) {
      final (tr, tc) = entry.key;
      final isCap = entry.value;
      final center = Offset((tc + 0.5) * cell, (tr + 0.5) * cell);
      if (isCap) {
        canvas.drawCircle(
          center,
          cell * 0.43,
          Paint()
            ..color = Colors.redAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8,
        );
      } else {
        canvas.drawCircle(
          center,
          cell * 0.18,
          Paint()..color = const Color(0xFF00C853).withValues(alpha: 0.85),
        );
      }
    }

    canvas.restore();

    // Outer frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(fullRect, const Radius.circular(10)),
      Paint()
        ..color = const Color(0xFF5D3A1A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _EpaminondasPainter oldDelegate) => true;
}
