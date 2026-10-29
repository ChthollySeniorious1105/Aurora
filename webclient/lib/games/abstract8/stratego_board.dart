import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class StrategoBoard extends StatefulWidget {
  final GameContext g;
  const StrategoBoard(this.g, {super.key});

  @override
  State<StrategoBoard> createState() => _StrategoBoardState();
}

class _StrategoBoardState extends State<StrategoBoard> {
  (int, int)? _selected;
  bool _swapMode = false;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  void _onCellTap(int r, int c) {
    final over = v['over'] == true || g.over;
    if (over || g.seat < 0) return;

    final phase = (v['phase'] as String?) ?? 'play';
    final turn = (v['turn'] as int?) ?? 0;
    final canSwap = v['canSwap'] == true;
    final board = (v['board'] as List?) ?? const [];
    if (r < 0 || r >= board.length) return;
    final row = board[r] as List;
    if (c < 0 || c >= row.length) return;
    final cell = row[c] as Map<String, dynamic>?;

    // Setup or Swap mode
    if (phase == 'setup' || (_swapMode && canSwap)) {
      if (cell != null && cell['lake'] != true && cell['owner'] == g.seat) {
        if (_selected == null) {
          setState(() => _selected = (r, c));
        } else if (_selected == (r, c)) {
          setState(() => _selected = null);
        } else {
          final prev = _selected!;
          setState(() => _selected = null);
          g.act({
            'type': 'swap',
            'from': [prev.$1, prev.$2],
            'to': [r, c],
          });
        }
      } else {
        setState(() => _selected = null);
      }
      return;
    }

    if (g.seat != turn) return;

    final legal = ((v['legalMoves'] as List?) ?? const []).cast<Map>();
    if (_selected != null) {
      final (sr, sc) = _selected!;
      if (sr == r && sc == c) {
        setState(() => _selected = null);
        return;
      }
      final match = legal.where((m) {
        final from = (m['from'] as List).cast<int>();
        final to = (m['to'] as List).cast<int>();
        return from[0] == sr && from[1] == sc && to[0] == r && to[1] == c;
      }).toList();

      if (match.isNotEmpty) {
        setState(() => _selected = null);
        g.act({
          'type': 'move',
          'from': [sr, sc],
          'to': [r, c],
        });
        return;
      }
    }

    if (cell != null && cell['lake'] != true && cell['owner'] == g.seat) {
      final rk = cell['rank'] as int?;
      if (rk != 0 && rk != 11) {
        setState(() => _selected = (r, c));
        return;
      }
    }
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final phase = (v['phase'] as String?) ?? 'play';
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;
    final canSwap = v['canSwap'] == true;
    if (!canSwap && _swapMode) _swapMode = false;

    final seats = g.seatsFromMe();
    final me = seats.first;
    final opp = seats.length > 1 ? seats[1] : 1 - me;
    final myTurn = !over && (phase == 'setup' ? !((v['ready'] as List?)?[me] == true) : g.seat == turn);

    String statusText;
    if (over) {
      statusText = (v['winReason'] as String?) ?? '对局结束';
    } else if (phase == 'setup') {
      statusText = myTurn ? '布阵阶段：点击两枚己方棋子可互换位置，就绪后点击开战' : '等待对手完成军阵部署…';
    } else if (_swapMode && canSwap) {
      statusText = '调整军阵：点击两枚己方棋子交换位置';
    } else if (myTurn) {
      statusText = '你的回合：调动部队或向敌军发起试探与进攻';
    } else {
      statusText = '等待 ${g.name(turn)} 调动军团…';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, c) {
        final isWide = c.maxWidth > c.maxHeight * 1.25;
        final boardWidget = _buildBattlefieldGrid(cs, phase, canSwap);
        final sidePanel = _buildSidePanel(cs, statusText, myTurn, phase, canSwap, me, opp);

        return Stack(
          children: [
            if (isWide)
              Row(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.all(8), child: boardWidget)),
                  SizedBox(
                    width: math.min(280, c.maxWidth * 0.38),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: sidePanel,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: _buildCompactHeader(cs, statusText, myTurn, opp),
                  ),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: boardWidget)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    child: _buildCompactFooter(cs, phase, canSwap, me),
                  ),
                ],
              ),
            if (over)
              Center(
                child: ResultBanner((v['winReason'] as String?) ?? '对局结束'),
              ),
          ],
        );
      }),
    );
  }

  String _armySub(int seat) {
    final team = seat == 0 ? '红军' : '蓝军';
    final caps = (v['capturedBy'] as List?) ?? const [[], []];
    if (seat < 0 || seat >= caps.length) return team;
    final list = (caps[seat] as List).cast<int>();
    return '$team · 歼敌 ${list.length} 枚';
  }

  Widget _buildCompactHeader(ColorScheme cs, String statusText, bool myTurn, int opp) {
    final turn = (v['turn'] as int?) ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: myTurn)),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(child: g.tag(opp, active: turn == opp, sub: _armySub(opp), size: 32)),
            const SizedBox(width: 6),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _buildCombatBanner(cs))),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactFooter(ColorScheme cs, String phase, bool canSwap, int me) {
    final turn = (v['turn'] as int?) ?? 0;
    return Row(
      children: [
        Flexible(child: g.tag(me, active: turn == me, sub: _armySub(me), size: 32)),
        const SizedBox(width: 6),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _buildActionButtons(cs, phase, canSwap, me))),
      ],
    );
  }

  Widget _buildSidePanel(
    ColorScheme cs,
    String statusText,
    bool myTurn,
    String phase,
    bool canSwap,
    int me,
    int opp,
  ) {
    final turn = (v['turn'] as int?) ?? 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: LayoutBuilder(builder: (context, pc) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: pc.maxHeight > 20 ? pc.maxHeight - 20 : 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatusBar(statusText, highlight: myTurn),
                    const SizedBox(height: 8),
                    g.tag(opp, active: turn == opp, sub: _armySub(opp), size: 32),
                    const SizedBox(height: 8),
                    Center(child: FittedBox(fit: BoxFit.scaleDown, child: _buildCombatBanner(cs))),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _buildActionButtons(cs, phase, canSwap, me))),
                ),
                g.tag(me, active: turn == me, sub: _armySub(me), size: 32),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCombatBanner(ColorScheme cs) {
    final combat = v['lastCombat'] as Map?;
    if (combat == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '规则: 间谍(1)刺元帅(10) · 工兵(3)排雷 · 侦察兵(2)远袭',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer),
        ),
      );
    }

    final aName = combat['attackerName'] ?? '?';
    final aRank = combat['attackerRank'] ?? '?';
    final dName = combat['defenderName'] ?? '?';
    final dRank = combat['defenderRank'] ?? '?';
    final outcome = combat['outcome'] as String? ?? '';
    final resText = switch (outcome) {
      'attacker' => '攻方胜',
      'defender' => '守方胜',
      'flag' => '夺取军旗!',
      _ => '同归于尽',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
      ),
      child: Text(
        '交战: $aName($aRank) vs $dName($dRank) → $resText',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface),
      ),
    );
  }

  Widget _buildActionButtons(ColorScheme cs, String phase, bool canSwap, int me) {
    if (g.seat < 0 || v['over'] == true || g.over) {
      return const SizedBox();
    }
    final readyList = ((v['ready'] as List?) ?? const [false, false]).cast<bool>();
    final isReady = me < readyList.length && readyList[me];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canSwap) ...[
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _selected = null);
              g.act({'type': 'shuffle'});
            },
            icon: const Icon(Icons.shuffle, size: 15),
            label: const Text('随机布阵', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          if (phase != 'setup')
            FilterChip(
              label: const Text('换位微调', style: TextStyle(fontSize: 12)),
              selected: _swapMode,
              onSelected: (val) => setState(() {
                _swapMode = val;
                _selected = null;
              }),
            ),
        ],
        if (phase == 'setup' && !isReady) ...[
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: () => g.act({'type': 'ready'}),
            icon: const Icon(Icons.check, size: 15),
            label: const Text('完成布阵', style: TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }

  Widget _buildBattlefieldGrid(ColorScheme cs, String phase, bool canSwap) {
    final gridSize = (v['gridSize'] as int?) ?? 8;
    final board = (v['board'] as List?) ?? const [];
    if (board.length < gridSize) return const SizedBox();

    final legal = ((v['legalMoves'] as List?) ?? const []).cast<Map>();
    final targetSquares = <(int, int)>{};
    if (_selected != null && phase == 'play' && !_swapMode) {
      for (final m in legal) {
        final from = (m['from'] as List).cast<int>();
        final to = (m['to'] as List).cast<int>();
        if (from[0] == _selected!.$1 && from[1] == _selected!.$2) {
          targetSquares.add((to[0], to[1]));
        }
      }
    }

    final lastMove = v['lastMove'] as Map?;
    final lastFrom = (lastMove?['from'] as List?)?.cast<int>();
    final lastTo = (lastMove?['to'] as List?)?.cast<int>();
    final flip = g.seat == 1;

    return LayoutBuilder(builder: (context, bc) {
      final side = math.min(bc.maxWidth, bc.maxHeight);
      if (side <= 20) return const SizedBox();
      final cellSize = side / gridSize;

      return Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outline.withValues(alpha: 0.5), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var dr = 0; dr < gridSize; dr++)
                Expanded(
                  child: Row(
                    children: [
                      for (var dc = 0; dc < gridSize; dc++)
                        Expanded(
                          child: Builder(builder: (context) {
                            final r = flip ? (gridSize - 1 - dr) : dr;
                            final c = flip ? (gridSize - 1 - dc) : dc;
                            final cell = (board[r] as List)[c] as Map<String, dynamic>?;
                            final isLake = cell != null && cell['lake'] == true;
                            final isSel = _selected == (r, c);
                            final isTarget = targetSquares.contains((r, c));
                            final isLast = (lastFrom != null && lastFrom[0] == r && lastFrom[1] == c) ||
                                (lastTo != null && lastTo[0] == r && lastTo[1] == c);

                            Color bg;
                            if (isLake) {
                              bg = const Color(0xFF1E5F8A);
                            } else {
                              bg = (r + c).isEven ? const Color(0xFFDCE3C8) : const Color(0xFFC5CFA9);
                            }
                            if (isSel) {
                              bg = Color.lerp(bg, Colors.amber, 0.6)!;
                            } else if (isLast) {
                              bg = Color.lerp(bg, Colors.yellowAccent, 0.35)!;
                            }

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onCellTap(r, c),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: bg,
                                  border: Border.all(
                                    color: isTarget
                                        ? Colors.greenAccent
                                        : Colors.black.withValues(alpha: 0.14),
                                    width: isTarget ? 2.0 : 0.5,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isLake)
                                      Icon(
                                        Icons.waves,
                                        size: cellSize * 0.45,
                                        color: Colors.lightBlueAccent.withValues(alpha: 0.45),
                                      ),
                                    if (!isLake && cell != null)
                                      _buildStrategoPiece(cell, cellSize),
                                    if (isTarget)
                                      Container(
                                        width: cell != null ? cellSize * 0.85 : cellSize * 0.30,
                                        height: cell != null ? cellSize * 0.85 : cellSize * 0.30,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: cell != null ? Colors.transparent : const Color(0xAA00E676),
                                          border: cell != null
                                              ? Border.all(color: Colors.redAccent, width: 2.4)
                                              : null,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStrategoPiece(Map<String, dynamic> cell, double cellSize) {
    final owner = (cell['owner'] as int?) ?? 0;
    final rank = cell['rank'] as int?;
    final revealed = cell['revealed'] == true;
    final shortLabel = (cell['short'] as String?) ?? '?';

    final baseCol = owner == 0 ? const Color(0xFFB7282E) : const Color(0xFF1E4D8C);
    final borderCol = revealed ? Colors.amberAccent : const Color(0xFFE8D8B0);

    String display;
    if (rank == null) {
      display = '暗';
    } else if (rank == 0) {
      display = '🚩旗';
    } else if (rank == 11) {
      display = '💣雷';
    } else {
      display = shortLabel;
    }

    return Container(
      width: cellSize * 0.84,
      height: cellSize * 0.84,
      decoration: BoxDecoration(
        color: baseCol,
        borderRadius: BorderRadius.circular(cellSize * 0.16),
        border: Border.all(color: borderCol, width: revealed ? 2.0 : 1.3),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2.5, offset: Offset(0, 1.5))],
      ),
      padding: const EdgeInsets.all(2),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            display,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamilyFallback: kFontFallback,
            ),
          ),
        ),
      ),
    );
  }
}
