import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CephalopodBoard extends StatefulWidget {
  final GameContext g;
  const CephalopodBoard(this.g, {super.key});

  @override
  State<CephalopodBoard> createState() => _CephalopodBoardState();
}

class _CephalopodBoardState extends State<CephalopodBoard> {
  (int, int)? _selectedCell;
  final Set<(int, int)> _selectedNeighbors = {};

  static const List<(int, int)> _kOrthoDirs = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  static List<List<(int, int)>> _validSubsetsAt(
    List<List<int>> pips,
    int boardSize,
    int r,
    int c,
  ) {
    final nbrs = <(int, int)>[];
    for (final (dr, dc) in _kOrthoDirs) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize && pips[nr][nc] > 0) {
        nbrs.add((nr, nc));
      }
    }
    if (nbrs.length < 2) return const [];
    final out = <List<(int, int)>>[];
    final total = 1 << nbrs.length;
    for (var mask = 1; mask < total; mask++) {
      var cnt = 0;
      var sum = 0;
      for (var i = 0; i < nbrs.length; i++) {
        if ((mask & (1 << i)) != 0) {
          cnt++;
          sum += pips[nbrs[i].$1][nbrs[i].$2];
        }
      }
      if (cnt >= 2 && sum <= 6) {
        out.add([
          for (var i = 0; i < nbrs.length; i++)
            if ((mask & (1 << i)) != 0) nbrs[i],
        ]);
      }
    }
    // Sort by highest pip sum first, then most dice captured
    out.sort((a, b) {
      final sa = a.fold<int>(0, (s, p) => s + pips[p.$1][p.$2]);
      final sb = b.fold<int>(0, (s, p) => s + pips[p.$1][p.$2]);
      if (sb != sa) return sb.compareTo(sa);
      return b.length.compareTo(a.length);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final boardSize = (v['boardSize'] as num?)?.toInt() ?? 5;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawOwners = (v['owners'] as List?) ?? const [];
    final rawPips = (v['pips'] as List?) ?? const [];
    final diceCounts = (v['diceCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final sixCounts = (v['sixCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final lastMove = v['lastMove'] as Map?;

    final owners = List.generate(boardSize, (r) {
      if (r < rawOwners.length && rawOwners[r] is List) {
        final row = rawOwners[r] as List;
        return List.generate(boardSize, (c) => c < row.length ? (row[c] as num).toInt() : -1);
      }
      return List<int>.filled(boardSize, -1);
    });

    final pips = List.generate(boardSize, (r) {
      if (r < rawPips.length && rawPips[r] is List) {
        final row = rawPips[r] as List;
        return List.generate(boardSize, (c) => c < row.length ? (row[c] as num).toInt() : 0);
      }
      return List<int>.filled(boardSize, 0);
    });

    final isMyTurn = !over && g.seat == turn;
    if (!isMyTurn) {
      _selectedCell = null;
      _selectedNeighbors.clear();
    } else if (_selectedCell != null) {
      final (sr, sc) = _selectedCell!;
      if (sr < 0 || sr >= boardSize || sc < 0 || sc >= boardSize || pips[sr][sc] > 0) {
        _selectedCell = null;
        _selectedNeighbors.clear();
      }
    }

    final cellSubsets = <(int, int), List<List<(int, int)>>>{};
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (pips[r][c] == 0) {
          cellSubsets[(r, c)] = _validSubsetsAt(pips, boardSize, r, c);
        }
      }
    }

    int selectedSum = 0;
    for (final (nr, nc) in _selectedNeighbors) {
      if (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize) {
        selectedSum += pips[nr][nc];
      }
    }
    final isSelectionValidCapture =
        _selectedCell != null && _selectedNeighbors.length >= 2 && selectedSum >= 2 && selectedSum <= 6;

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_selectedCell == null) {
        statusText = '轮到你：点击空格放置骰子（若邻格存在点数和 ≤6 的多骰组合则自动或选定吞并）';
      } else {
        final (sr, sc) = _selectedCell!;
        statusText = isSelectionValidCapture
            ? '已选落点 (${sr + 1},${sc + 1})：再点该空格确认吞并 ${_selectedNeighbors.length} 枚邻骰合成 $selectedSum 点（或点邻骰切换）'
            : '已选落点 (${sr + 1},${sc + 1})：请点击相邻骰子使所选 ≥2 枚且点数和 ≤6（当前和 $selectedSum）';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 放置或吞并骰子…';
    }

    Widget buildPlayerPanel(int s) {
      final isP0 = s == 0;
      final cnt = s < diceCounts.length ? diceCounts[s] : 0;
      final six = s < sixCounts.length ? sixCounts[s] : 0;
      final colorLabel = isP0 ? '琥珀方' : '紫晶方';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · 骰子 $cnt (6点×$six)',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isP0 ? const Color(0xFFFF8F00) : const Color(0xFF7E57C2),
            border: Border.all(
              color: isP0 ? const Color(0xFFFFE082) : const Color(0xFFD1C4E9),
              width: 2.0,
            ),
          ),
        ),
      );
    }

    Widget? buildConfirmCaptureBar() {
      if (!isMyTurn || _selectedCell == null) return null;
      final (sr, sc) = _selectedCell!;
      final subs = cellSubsets[(sr, sc)] ?? const [];
      if (subs.isEmpty) return null;

      return Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          if (isSelectionValidCapture)
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () {
                final cap = [
                  for (final (nr, nc) in _selectedNeighbors) [nr, nc],
                ];
                setState(() {
                  _selectedCell = null;
                  _selectedNeighbors.clear();
                });
                g.act({'type': 'place', 'r': sr, 'c': sc, 'capture': cap});
              },
              icon: const Icon(Icons.bolt, size: 15),
              label: Text('确认合成 $selectedSum 点'),
            ),
          for (final sub in subs.take(3))
            Builder(builder: (context) {
              final sumP = sub.fold<int>(0, (acc, p) => acc + pips[p.$1][p.$2]);
              return ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text('吞${sub.length}骰→$sumP点', style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _selectedCell = null;
                    _selectedNeighbors.clear();
                  });
                  g.act({
                    'type': 'place',
                    'r': sr,
                    'c': sc,
                    'capture': [
                      for (final (nr, nc) in sub) [nr, nc],
                    ],
                  });
                },
              );
            }),
        ],
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
                      setState(() {
                        _selectedCell = null;
                        _selectedNeighbors.clear();
                      });
                      return;
                    }

                    final hit = (r, c);

                    // If tapping the already-selected empty cell, confirm current valid capture
                    if (_selectedCell == hit) {
                      if (isSelectionValidCapture) {
                        final cap = [
                          for (final (nr, nc) in _selectedNeighbors) [nr, nc],
                        ];
                        setState(() {
                          _selectedCell = null;
                          _selectedNeighbors.clear();
                        });
                        g.act({'type': 'place', 'r': r, 'c': c, 'capture': cap});
                      } else {
                        setState(() {
                          _selectedCell = null;
                          _selectedNeighbors.clear();
                        });
                      }
                      return;
                    }

                    // If a capture cell is selected and user taps one of its occupied orthogonal neighbors, toggle it
                    if (_selectedCell != null && pips[r][c] > 0) {
                      final (sr, sc) = _selectedCell!;
                      if ((sr - r).abs() + (sc - c).abs() == 1) {
                        setState(() {
                          if (_selectedNeighbors.contains(hit)) {
                            _selectedNeighbors.remove(hit);
                          } else {
                            _selectedNeighbors.add(hit);
                          }
                        });
                        return;
                      }
                    }

                    // Tapping an empty cell
                    if (pips[r][c] == 0) {
                      final subs = cellSubsets[hit] ?? const [];
                      if (subs.isEmpty) {
                        setState(() {
                          _selectedCell = null;
                          _selectedNeighbors.clear();
                        });
                        g.act({'type': 'place', 'r': r, 'c': c, 'capture': <List<int>>[]});
                        return;
                      }
                      if (subs.length == 1) {
                        setState(() {
                          _selectedCell = null;
                          _selectedNeighbors.clear();
                        });
                        g.act({
                          'type': 'place',
                          'r': r,
                          'c': c,
                          'capture': [
                            for (final (nr, nc) in subs.first) [nr, nc],
                          ],
                        });
                        return;
                      }
                      // Multiple valid capture subsets: select cell and pre-select the highest-pip subset
                      setState(() {
                        _selectedCell = hit;
                        _selectedNeighbors
                          ..clear()
                          ..addAll(subs.first);
                      });
                    }
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _CephalopodPainter(
                boardSize: boardSize,
                owners: owners,
                pips: pips,
                cellSubsets: cellSubsets,
                selectedCell: _selectedCell,
                selectedNeighbors: _selectedNeighbors,
                isMyTurn: isMyTurn,
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
        final capBar = buildConfirmCaptureBar();

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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: StatusBar(statusText, highlight: isMyTurn),
                                      ),
                                      if (capBar != null) ...[
                                        const SizedBox(height: 6),
                                        FittedBox(fit: BoxFit.scaleDown, child: capBar),
                                      ],
                                    ],
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
                        if (capBar != null) ...[
                          const SizedBox(height: 4),
                          FittedBox(fit: BoxFit.scaleDown, child: capBar),
                        ],
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

class _CephalopodPainter extends CustomPainter {
  final int boardSize;
  final List<List<int>> owners;
  final List<List<int>> pips;
  final Map<(int, int), List<List<(int, int)>>> cellSubsets;
  final (int, int)? selectedCell;
  final Set<(int, int)> selectedNeighbors;
  final bool isMyTurn;
  final Map? lastMove;
  final double cellSize;
  final Offset origin;
  final ColorScheme cs;

  _CephalopodPainter({
    required this.boardSize,
    required this.owners,
    required this.pips,
    required this.cellSubsets,
    required this.selectedCell,
    required this.selectedNeighbors,
    required this.isMyTurn,
    required this.lastMove,
    required this.cellSize,
    required this.origin,
    required this.cs,
  });

  static const Map<int, List<Offset>> _pipOffsets = {
    1: [Offset(0, 0)],
    2: [Offset(-0.26, -0.26), Offset(0.26, 0.26)],
    3: [Offset(-0.28, -0.28), Offset(0, 0), Offset(0.28, 0.28)],
    4: [
      Offset(-0.26, -0.26),
      Offset(0.26, -0.26),
      Offset(-0.26, 0.26),
      Offset(0.26, 0.26),
    ],
    5: [
      Offset(-0.27, -0.27),
      Offset(0.27, -0.27),
      Offset(0, 0),
      Offset(-0.27, 0.27),
      Offset(0.27, 0.27),
    ],
    6: [
      Offset(-0.26, -0.28),
      Offset(0.26, -0.28),
      Offset(-0.26, 0),
      Offset(0.26, 0),
      Offset(-0.26, 0.28),
      Offset(0.26, 0.28),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final boardPx = cellSize * boardSize;
    final pad = cellSize * 0.22;
    final outerRect = Rect.fromLTWH(
      origin.dx - pad,
      origin.dy - pad,
      boardPx + pad * 2,
      boardPx + pad * 2,
    );
    final boardRRect = RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.24));
    canvas.drawShadow(Path()..addRRect(boardRRect), Colors.black54, 8, false);
    canvas.drawRRect(
      boardRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E272C), Color(0xFF12181B)],
        ).createShader(outerRect),
    );

    final lastR = (lastMove?['r'] as num?)?.toInt();
    final lastC = (lastMove?['c'] as num?)?.toInt();
    final capturedRaw = (lastMove?['captured'] as List?)?.cast<Map>() ?? const [];
    final lastCaptured = <(int, int)>{
      for (final m in capturedRaw)
        ((m['r'] as num?)?.toInt() ?? -1, (m['c'] as num?)?.toInt() ?? -1),
    };

    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        );
        final isAlt = (r + c).isOdd;
        Color sqColor = isAlt ? const Color(0xFF263238) : const Color(0xFF2F3E46);
        if (r == lastR && c == lastC) {
          sqColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), sqColor);
        } else if (lastCaptured.contains((r, c))) {
          sqColor = Color.alphaBlend(Colors.redAccent.withValues(alpha: 0.16), sqColor);
        }
        if (selectedCell == (r, c)) {
          sqColor = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.30), sqColor);
        }
        canvas.drawRect(rect, Paint()..color = sqColor);
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = Colors.white.withValues(alpha: 0.12),
        );

        final center = rect.center;
        final p = pips[r][c];
        final o = owners[r][c];

        if (p > 0) {
          final dieSide = cellSize * 0.76;
          final dieRect = Rect.fromCenter(center: center, width: dieSide, height: dieSide);
          final dieRRect = RRect.fromRectAndRadius(dieRect, Radius.circular(cellSize * 0.16));
          final isP0 = o == 0;
          final isSelectedNbr = selectedNeighbors.contains((r, c));

          canvas.drawRRect(
            dieRRect.shift(const Offset(1.5, 2.5)),
            Paint()..color = Colors.black54,
          );
          canvas.drawRRect(
            dieRRect,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isP0
                    ? [const Color(0xFFFFB300), const Color(0xFFE65100)]
                    : [const Color(0xFF9575CD), const Color(0xFF4527A0)],
              ).createShader(dieRect),
          );
          canvas.drawRRect(
            dieRRect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isSelectedNbr ? 3.0 : (p == 6 ? 2.4 : 1.5)
              ..color = isSelectedNbr
                  ? Colors.cyanAccent
                  : (p == 6
                      ? Colors.amberAccent
                      : (isP0 ? const Color(0xFFFFE082) : const Color(0xFFD1C4E9))),
          );

          final dots = _pipOffsets[p] ?? const [Offset(0, 0)];
          final dotR = dieSide * 0.088;
          for (final d in dots) {
            final dotCenter = center + Offset(d.dx * dieSide, d.dy * dieSide);
            canvas.drawCircle(dotCenter, dotR, Paint()..color = Colors.white);
          }
        } else if (isMyTurn) {
          final subs = cellSubsets[(r, c)] ?? const [];
          if (subs.isNotEmpty) {
            final bestSum = subs.first.fold<int>(0, (acc, pos) => acc + pips[pos.$1][pos.$2]);
            final badgeR = cellSize * 0.22;
            canvas.drawCircle(
              center,
              badgeR,
              Paint()..color = Colors.amberAccent.withValues(alpha: 0.22),
            );
            canvas.drawCircle(
              center,
              badgeR,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = Colors.amberAccent,
            );
            final tp = TextPainter(
              text: TextSpan(
                text: '吞$bestSum',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: cellSize * 0.20,
                  fontFamilyFallback: kFontFallback,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
          } else {
            canvas.drawCircle(
              center,
              cellSize * 0.10,
              Paint()..color = Colors.greenAccent.withValues(alpha: 0.45),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CephalopodPainter oldDelegate) => true;
}
