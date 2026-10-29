import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ShobuBoard extends StatefulWidget {
  final GameContext g;
  const ShobuBoard(this.g, {super.key});

  @override
  State<ShobuBoard> createState() => _ShobuBoardState();
}

class _ShobuBoardState extends State<ShobuBoard> {
  int? _selPBoard;
  int? _selPFrom;
  int? _selPTo;
  int? _selABoard;
  int? _selAFrom;

  void _clearSelection() {
    _selPBoard = null;
    _selPFrom = null;
    _selPTo = null;
    _selABoard = null;
    _selAFrom = null;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true;
    final myTurn = !over && g.seat == turn;

    final rawBoards = (v['boards'] as List?) ?? const [];
    final boards = <List<int>>[
      for (var i = 0; i < 4; i++)
        if (i < rawBoards.length && rawBoards[i] is List)
          [for (final x in rawBoards[i] as List) (x as num).toInt()]
        else
          List.filled(16, 0),
    ];

    final legalMoves = <Map<String, int>>[];
    for (final m in (v['legalMoves'] as List? ?? const [])) {
      if (m is Map) {
        legalMoves.add({
          'pBoard': (m['pBoard'] as num?)?.toInt() ?? -1,
          'pFrom': (m['pFrom'] as num?)?.toInt() ?? -1,
          'pTo': (m['pTo'] as num?)?.toInt() ?? -1,
          'aBoard': (m['aBoard'] as num?)?.toInt() ?? -1,
          'aFrom': (m['aFrom'] as num?)?.toInt() ?? -1,
          'aTo': (m['aTo'] as num?)?.toInt() ?? -1,
          'dir': (m['dir'] as num?)?.toInt() ?? -1,
          'steps': (m['steps'] as num?)?.toInt() ?? -1,
        });
      }
    }

    if (!myTurn || legalMoves.isEmpty) {
      _clearSelection();
    } else if (_selPBoard != null && _selPFrom != null) {
      final stillValid = legalMoves.any((m) => m['pBoard'] == _selPBoard && m['pFrom'] == _selPFrom);
      if (!stillValid) _clearSelection();
    }

    final lastMove = v['lastMove'] as Map?;
    final result = v['result'] as String?;

    String statusText;
    if (over) {
      statusText = result ?? '游戏结束';
    } else if (myTurn) {
      if (_selPFrom == null) {
        final homeDesc = turn == 0 ? '#1 或 #2' : '#3 或 #4';
        statusText = '第一步（消极步）：点击己方主场 ($homeDesc) 的石子';
      } else if (_selPTo == null) {
        statusText = '第一步（消极步）：点击棋盘 #${_selPBoard! + 1} 上的高亮落点';
      } else if (_selAFrom == null) {
        final shadeDesc = (_selPBoard! % 2 == 0) ? '浅色盘 (#2/#4)' : '深色盘 (#1/#3)';
        statusText = '第二步（积极步）：在$shadeDesc上点击一枚己方石子同步移动';
      } else {
        statusText = '第二步（积极步）：点击高亮目标格完成同步推石';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 行棋…';
    }

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
                  g.tag(0, active: turn == 0 && !over, sub: '执黑 · 主场 #1/#2', size: 32),
                  StatusBar(statusText, highlight: myTurn),
                  if (myTurn && _selPFrom != null)
                    ActionChip(
                      label: const Text('重选', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(_clearSelection),
                    ),
                  g.tag(1, active: turn == 1 && !over, sub: '执白 · 主场 #3/#4', size: 32),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = min(constraints.maxWidth, constraints.maxHeight);
                    if (side <= 0) return const SizedBox();
                    return Center(
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: Column(
                          children: [
                            // Top row: Player 1 (White) Home Boards (#3 Dark = index 2, #4 Light = index 3)
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _buildSingleBoard(context, 2, boards[2], myTurn, legalMoves, lastMove, g)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildSingleBoard(context, 3, boards[3], myTurn, legalMoves, lastMove, g)),
                                ],
                              ),
                            ),
                            // Traditional hemp rope divider
                            Container(
                              height: 6,
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD7CCC8),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                              ),
                            ),
                            // Bottom row: Player 0 (Black) Home Boards (#1 Dark = index 0, #2 Light = index 1)
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: _buildSingleBoard(context, 0, boards[0], myTurn, legalMoves, lastMove, g)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildSingleBoard(context, 1, boards[1], myTurn, legalMoves, lastMove, g)),
                                ],
                              ),
                            ),
                          ],
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

  Widget _buildSingleBoard(
    BuildContext context,
    int boardIdx,
    List<int> cells,
    bool myTurn,
    List<Map<String, int>> legalMoves,
    Map? lastMove,
    GameContext g,
  ) {
    final isDark = boardIdx % 2 == 0;
    final boardColor = isDark ? const Color(0xFF5D4037) : const Color(0xFFD7B899);
    final gridColor = isDark ? const Color(0xFF8D6E63) : const Color(0xFF8D6E63);
    final label = '#${boardIdx + 1} ${isDark ? "深色" : "浅色"} (${boardIdx < 2 ? "黑主场" : "白主场"})';

    // Compute highlighted cells for this board
    final selectableStarts = <int>{};
    final selectableTargets = <int>{};

    if (myTurn) {
      if (_selPTo == null) {
        // Step 1: selecting passive stone and passive target
        for (final m in legalMoves) {
          if (m['pBoard'] == boardIdx) {
            selectableStarts.add(m['pFrom']!);
            if (_selPBoard == boardIdx && _selPFrom == m['pFrom']) {
              selectableTargets.add(m['pTo']!);
            }
          }
        }
      } else {
        // Step 2: passive move locked in; selecting aggressive stone on opposite-shade board
        for (final m in legalMoves) {
          if (m['pBoard'] == _selPBoard &&
              m['pFrom'] == _selPFrom &&
              m['pTo'] == _selPTo &&
              m['aBoard'] == boardIdx) {
            selectableStarts.add(m['aFrom']!);
            if (_selABoard == boardIdx && _selAFrom == m['aFrom']) {
              selectableTargets.add(m['aTo']!);
            }
          }
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: boardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (_selPBoard == boardIdx || _selABoard == boardIdx)
              ? Colors.cyanAccent
              : Colors.black45,
          width: (_selPBoard == boardIdx || _selABoard == boardIdx) ? 2.2 : 1.5,
        ),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.amber.shade100 : Colors.brown.shade900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                itemCount: 16,
                itemBuilder: (context, cellIdx) {
                  final stone = cells[cellIdx];
                  final isSelStart = (_selPBoard == boardIdx && _selPFrom == cellIdx) ||
                      (_selABoard == boardIdx && _selAFrom == cellIdx);
                  final isSelPTo = _selPBoard == boardIdx && _selPTo == cellIdx;
                  final isCanStart = selectableStarts.contains(cellIdx);
                  final isCanTarget = selectableTargets.contains(cellIdx);

                  final isLast = (lastMove?['pBoard'] == boardIdx &&
                          (lastMove?['pFrom'] == cellIdx || lastMove?['pTo'] == cellIdx)) ||
                      (lastMove?['aBoard'] == boardIdx &&
                          (lastMove?['aFrom'] == cellIdx || lastMove?['aTo'] == cellIdx));

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: myTurn ? () => _onCellTap(boardIdx, cellIdx, legalMoves, g) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelStart || isSelPTo
                            ? Colors.cyanAccent.withValues(alpha: 0.35)
                            : isCanTarget
                                ? Colors.lightGreenAccent.withValues(alpha: 0.38)
                                : isLast
                                    ? Colors.amber.withValues(alpha: 0.25)
                                    : Colors.transparent,
                        border: Border.all(color: gridColor.withValues(alpha: 0.55), width: 0.6),
                      ),
                      child: Center(
                        child: _buildCellContent(stone, isCanStart, isCanTarget),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(int stone, bool isCanStart, bool isCanTarget) {
    if (stone == 0) {
      if (isCanTarget) {
        return FractionallySizedBox(
          widthFactor: 0.42,
          heightFactor: 0.42,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.lightGreenAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      }
      return const SizedBox();
    }

    final isBlack = stone == 1;
    return FractionallySizedBox(
      widthFactor: 0.78,
      heightFactor: 0.78,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: isBlack
                ? [const Color(0xFF546E7A), const Color(0xFF1C262B)]
                : [const Color(0xFFFFFFFF), const Color(0xFFCFD8DC)],
          ),
          border: Border.all(
            color: isCanTarget
                ? Colors.lightGreenAccent
                : isCanStart
                    ? Colors.amberAccent
                    : (isBlack ? Colors.black87 : Colors.grey.shade500),
            width: (isCanStart || isCanTarget) ? 2.2 : 1.0,
          ),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1))],
        ),
      ),
    );
  }

  void _onCellTap(
    int boardIdx,
    int cellIdx,
    List<Map<String, int>> legalMoves,
    GameContext g,
  ) {
    if (_selPTo == null) {
      // Step 1: Choosing passive stone and passive target
      if (_selPBoard == boardIdx && _selPFrom != null) {
        final match = legalMoves.where(
          (m) => m['pBoard'] == boardIdx && m['pFrom'] == _selPFrom && m['pTo'] == cellIdx,
        );
        if (match.isNotEmpty) {
          setState(() {
            _selPTo = cellIdx;
          });
          return;
        }
      }

      final hasPassiveStart = legalMoves.any((m) => m['pBoard'] == boardIdx && m['pFrom'] == cellIdx);
      if (hasPassiveStart) {
        setState(() {
          _selPBoard = boardIdx;
          _selPFrom = cellIdx;
          _selPTo = null;
          _selABoard = null;
          _selAFrom = null;
        });
      }
      return;
    }

    // Step 2: Passive move is locked in; choosing aggressive move
    if (_selABoard == boardIdx && _selAFrom != null) {
      final match = legalMoves.where(
        (m) =>
            m['pBoard'] == _selPBoard &&
            m['pFrom'] == _selPFrom &&
            m['pTo'] == _selPTo &&
            m['aBoard'] == boardIdx &&
            m['aFrom'] == _selAFrom &&
            m['aTo'] == cellIdx,
      );
      if (match.isNotEmpty) {
        final m = match.first;
        setState(_clearSelection);
        g.act({
          'type': 'move',
          'pBoard': m['pBoard'],
          'pFrom': m['pFrom'],
          'aBoard': m['aBoard'],
          'aFrom': m['aFrom'],
          'dir': m['dir'],
          'steps': m['steps'],
        });
        return;
      }
    }

    // Tapping a valid aggressive start stone: since dir and steps are already fixed by the passive move,
    // each aggressive start stone has a unique destination! We can select it, or if tapped again / directly,
    // highlight its destination (or if only 1 destination, selecting it shows the target, and tapping target or stone again confirms).
    final aggMatches = legalMoves
        .where(
          (m) =>
              m['pBoard'] == _selPBoard &&
              m['pFrom'] == _selPFrom &&
              m['pTo'] == _selPTo &&
              m['aBoard'] == boardIdx &&
              m['aFrom'] == cellIdx,
        )
        .toList();

    if (aggMatches.isNotEmpty) {
      if (_selABoard == boardIdx && _selAFrom == cellIdx && aggMatches.length == 1) {
        final m = aggMatches.first;
        setState(_clearSelection);
        g.act({
          'type': 'move',
          'pBoard': m['pBoard'],
          'pFrom': m['pFrom'],
          'aBoard': m['aBoard'],
          'aFrom': m['aFrom'],
          'dir': m['dir'],
          'steps': m['steps'],
        });
        return;
      }
      setState(() {
        _selABoard = boardIdx;
        _selAFrom = cellIdx;
      });
    }
  }
}
