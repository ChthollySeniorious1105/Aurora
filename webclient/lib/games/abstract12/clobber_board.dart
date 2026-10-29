import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ClobberBoard extends StatefulWidget {
  final GameContext g;
  const ClobberBoard(this.g, {super.key});

  @override
  State<ClobberBoard> createState() => _ClobberBoardState();
}

class _ClobberBoardState extends State<ClobberBoard> {
  (int, int)? _selectedFrom;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true;
    final myTurn = !over && g.seat == turn;

    final rows = (v['rows'] as num?)?.toInt() ?? 5;
    final cols = (v['cols'] as num?)?.toInt() ?? 6;
    final rawBoard = (v['board'] as List?) ?? const [];
    final board = <List<int>>[
      for (var r = 0; r < rows; r++)
        if (r < rawBoard.length && rawBoard[r] is List)
          [for (final x in rawBoard[r] as List) (x as num).toInt()]
        else
          List.filled(cols, 0),
    ];

    final stoneCounts = <int>[
      for (final x in (v['stoneCounts'] as List? ?? const [0, 0])) (x as num).toInt(),
    ];

    final legalMoves = <(int, int), List<(int, int)>>{};
    for (final m in (v['legalMoves'] as List? ?? const [])) {
      if (m is Map) {
        final r1 = (m['fromR'] as num?)?.toInt() ?? -1;
        final c1 = (m['fromC'] as num?)?.toInt() ?? -1;
        final r2 = (m['toR'] as num?)?.toInt() ?? -1;
        final c2 = (m['toC'] as num?)?.toInt() ?? -1;
        (legalMoves[(r1, c1)] ??= <(int, int)>[]).add((r2, c2));
      }
    }

    if (!myTurn || (_selectedFrom != null && !legalMoves.containsKey(_selectedFrom))) {
      _selectedFrom = null;
    }

    final lastMove = v['lastMove'] as Map?;
    final result = v['result'] as String?;

    String statusText;
    if (over) {
      statusText = result ?? '游戏结束';
    } else if (myTurn) {
      statusText = _selectedFrom == null
          ? '轮到你：点击己方棋子，正交压吃相邻敌子'
          : '点击高亮的相邻敌方棋子完成压吃';
    } else {
      statusText = '等待 ${g.name(turn)} 行棋…';
    }

    final targets = _selectedFrom != null ? (legalMoves[_selectedFrom] ?? const <(int, int)>[]) : const <(int, int)>[];

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(6),
      child: Stack(
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
                    active: turn == 0 && !over,
                    sub: '执黑 · 剩余 ${stoneCounts.isNotEmpty ? stoneCounts[0] : 0} 子',
                    size: 32,
                  ),
                  StatusBar(statusText, highlight: myTurn),
                  g.tag(
                    1,
                    active: turn == 1 && !over,
                    sub: '执白 · 剩余 ${stoneCounts.length > 1 ? stoneCounts[1] : 0} 子',
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final maxH = constraints.maxHeight;
                    if (maxW <= 0 || maxH <= 0) return const SizedBox();
                    final cellSize = min(maxW / cols, maxH / rows);
                    final boardW = cellSize * cols;
                    final boardH = cellSize * rows;

                    return Center(
                      child: Container(
                        width: boardW,
                        height: boardH,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.brown.shade900, width: 2.5),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            children: [
                              for (var r = 0; r < rows; r++)
                                Expanded(
                                  child: Row(
                                    children: [
                                      for (var c = 0; c < cols; c++)
                                        Expanded(
                                          child: _buildCell(
                                            r,
                                            c,
                                            board[r][c],
                                            myTurn,
                                            legalMoves,
                                            targets,
                                            lastMove,
                                            g,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (over && result != null) ResultBanner(result),
        ],
      ),
    );
  }

  Widget _buildCell(
    int r,
    int c,
    int stone,
    bool myTurn,
    Map<(int, int), List<(int, int)>> legalMoves,
    List<(int, int)> targets,
    Map? lastMove,
    GameContext g,
  ) {
    final isDarkSquare = (r + c) % 2 == 0;
    final baseBg = isDarkSquare ? const Color(0xFF8D6E63) : const Color(0xFFD7CCC8);
    final isSelected = _selectedFrom == (r, c);
    final isTarget = targets.contains((r, c));
    final isMovable = myTurn && legalMoves.containsKey((r, c));
    final isLastFrom = lastMove?['fromR'] == r && lastMove?['fromC'] == c;
    final isLastTo = lastMove?['toR'] == r && lastMove?['toC'] == c;

    Color bg = baseBg;
    if (isSelected) {
      bg = Color.alphaBlend(Colors.cyanAccent.withValues(alpha: 0.45), baseBg);
    } else if (isTarget) {
      bg = Color.alphaBlend(Colors.redAccent.withValues(alpha: 0.42), baseBg);
    } else if (isLastFrom || isLastTo) {
      bg = Color.alphaBlend(Colors.amber.withValues(alpha: 0.35), baseBg);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: myTurn ? () => _onTapCell(r, c, legalMoves, targets, g) : null,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: Colors.black26, width: 0.5),
        ),
        child: Center(
          child: stone == 0
              ? (isLastFrom
                  ? FractionallySizedBox(
                      widthFactor: 0.25,
                      heightFactor: 0.25,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : const SizedBox())
              : FractionallySizedBox(
                  widthFactor: 0.78,
                  heightFactor: 0.78,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.3),
                        colors: stone == 1
                            ? [const Color(0xFF455A64), const Color(0xFF151C20)]
                            : [const Color(0xFFFFFFFF), const Color(0xFFCFD8DC)],
                      ),
                      border: Border.all(
                        color: isSelected
                            ? Colors.cyanAccent
                            : isTarget
                                ? Colors.redAccent
                                : isMovable
                                    ? Colors.amberAccent
                                    : (stone == 1 ? Colors.black87 : Colors.grey.shade500),
                        width: (isSelected || isTarget || isMovable) ? 2.4 : 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 1.5)),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _onTapCell(
    int r,
    int c,
    Map<(int, int), List<(int, int)>> legalMoves,
    List<(int, int)> targets,
    GameContext g,
  ) {
    if (_selectedFrom != null && targets.contains((r, c))) {
      final (r1, c1) = _selectedFrom!;
      setState(() => _selectedFrom = null);
      g.act({
        'type': 'move',
        'fromR': r1,
        'fromC': c1,
        'toR': r,
        'toC': c,
      });
      return;
    }

    if (legalMoves.containsKey((r, c))) {
      setState(() {
        _selectedFrom = (_selectedFrom == (r, c)) ? null : (r, c);
      });
    } else {
      setState(() => _selectedFrom = null);
    }
  }
}
