import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class PentagoBoard extends StatelessWidget {
  final GameContext g;
  const PentagoBoard(this.g, {super.key});

  static const List<String> _quadNames = ['左上象限', '右上象限', '左下象限', '右下象限'];

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final board = (v['board'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(36, -1);
    final blackSeat = (v['blackSeat'] as num?)?.toInt() ?? 0;
    final whiteSeat = (v['whiteSeat'] as num?)?.toInt() ?? 1;
    final turnSeat = (v['turnSeat'] as num?)?.toInt() ?? 0;
    final turnColor = (v['turnColor'] as num?)?.toInt() ?? 0;
    final step = '${v['step'] ?? 'place'}';
    final lastPlaced = (v['lastPlaced'] as num?)?.toInt() ?? -1;
    final lastQuadrant = (v['lastQuadrant'] as num?)?.toInt() ?? -1;
    final lastDir = '${v['lastDir'] ?? ''}';
    final winLine = ((v['winLine'] as List?)?.map((e) => (e as num).toInt()) ?? const <int>[]).toSet();

    final isMyTurn = !g.spectator && !g.over && g.seat == turnSeat;
    final canPlace = isMyTurn && step == 'place';
    final canRotate = isMyTurn && step == 'rotate';

    final colorLabel = turnColor == 0 ? '黑子' : '白子';
    final statusMsg = g.over
        ? '${v['result'] ?? '对局结束'}'
        : (isMyTurn
            ? (step == 'place'
                ? '轮到你（执$colorLabel）— 第 1 步：请点击棋盘空位落子'
                : '轮到你（执$colorLabel）— 第 2 步：请选择一个 3×3 象限旋转 90°')
            : '等待 ${g.name(turnSeat)}（执$colorLabel）${step == 'place' ? '落子' : '旋转象限'}...');

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: StatusBar(statusMsg, highlight: isMyTurn),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 640;
                    if (wide) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Center(
                              child: _buildBoardGrid(
                                cs,
                                board,
                                canPlace: canPlace,
                                lastPlaced: lastPlaced,
                                lastQuadrant: lastQuadrant,
                                winLine: winLine,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 310,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildPlayersRow(cs, blackSeat, whiteSeat, turnSeat),
                                    const SizedBox(height: 10),
                                    _buildRotationPanel(cs, canRotate, lastQuadrant, lastDir),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildPlayersRow(cs, blackSeat, whiteSeat, turnSeat),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Center(
                              child: _buildBoardGrid(
                                cs,
                                board,
                                canPlace: canPlace,
                                lastPlaced: lastPlaced,
                                lastQuadrant: lastQuadrant,
                                winLine: winLine,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 360,
                              child: _buildRotationPanel(cs, canRotate, lastQuadrant, lastDir),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          if (g.over)
            ResultBanner(
              '${v['result'] ?? '对局结束'}',
            ),
        ],
      ),
    );
  }

  Widget _buildPlayersRow(ColorScheme cs, int blackSeat, int whiteSeat, int turnSeat) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        g.tag(
          blackSeat,
          active: !g.over && turnSeat == blackSeat,
          sub: '● 执黑先行',
          size: 32,
        ),
        const SizedBox(width: 10),
        g.tag(
          whiteSeat,
          active: !g.over && turnSeat == whiteSeat,
          sub: '○ 执白后手',
          size: 32,
        ),
      ],
    );
  }

  Widget _buildBoardGrid(
    ColorScheme cs,
    List<int> board, {
    required bool canPlace,
    required int lastPlaced,
    required int lastQuadrant,
    required Set<int> winLine,
  }) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))],
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuadrantTile(cs, board, 0, canPlace, lastPlaced, lastQuadrant == 0, winLine),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuadrantTile(cs, board, 1, canPlace, lastPlaced, lastQuadrant == 1, winLine),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuadrantTile(cs, board, 2, canPlace, lastPlaced, lastQuadrant == 2, winLine),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuadrantTile(cs, board, 3, canPlace, lastPlaced, lastQuadrant == 3, winLine),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadrantTile(
    ColorScheme cs,
    List<int> board,
    int q,
    bool canPlace,
    int lastPlaced,
    bool isLastRot,
    Set<int> winLine,
  ) {
    final r0 = (q ~/ 2) * 3;
    final c0 = (q % 2) * 3;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD97706), Color(0xFF92400E)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLastRot ? Colors.amberAccent : Colors.white24,
          width: isLastRot ? 2.2 : 1.2,
        ),
      ),
      child: Column(
        children: [
          for (var lr = 0; lr < 3; lr++)
            Expanded(
              child: Row(
                children: [
                  for (var lc = 0; lc < 3; lc++)
                    Expanded(
                      child: _buildCell(
                        board,
                        (r0 + lr) * 6 + (c0 + lc),
                        isCenter: lr == 1 && lc == 1,
                        canPlace: canPlace,
                        isLastPlaced: (r0 + lr) * 6 + (c0 + lc) == lastPlaced,
                        isWinCell: winLine.contains((r0 + lr) * 6 + (c0 + lc)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(
    List<int> board,
    int idx, {
    required bool isCenter,
    required bool canPlace,
    required bool isLastPlaced,
    required bool isWinCell,
  }) {
    final val = board[idx];
    final tappable = canPlace && val == -1;
    return GestureDetector(
      onTap: tappable ? () => g.act({'type': 'place', 'cell': idx}) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: val == -1
                ? Colors.black.withValues(alpha: isCenter ? 0.36 : 0.25)
                : (val == 0 ? const Color(0xFF111827) : const Color(0xFFF8FAFC)),
            border: Border.all(
              color: isWinCell
                  ? Colors.greenAccent
                  : (isLastPlaced
                      ? Colors.cyanAccent
                      : (isCenter && val == -1 ? Colors.amber.withValues(alpha: 0.45) : Colors.black26)),
              width: (isWinCell || isLastPlaced) ? 2.5 : 1.0,
            ),
            boxShadow: val != -1
                ? const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2))]
                : null,
          ),
          child: val != -1
              ? Align(
                  alignment: const Alignment(-0.3, -0.3),
                  child: FractionallySizedBox(
                    widthFactor: 0.3,
                    heightFactor: 0.3,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: val == 0 ? 0.35 : 0.8),
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildRotationPanel(ColorScheme cs, bool canRotate, int lastQuadrant, String lastDir) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: canRotate ? cs.primary : cs.outline.withValues(alpha: 0.3), width: canRotate ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                canRotate ? '请选择旋转象限 (90°)' : '四象限旋转控制台',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: canRotate ? cs.primary : cs.onSurface),
              ),
              if (canRotate)
                TextButton.icon(
                  onPressed: () => g.act({'type': 'unplace'}),
                  icon: const Icon(Icons.undo, size: 15),
                  label: const Text('重选落子', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _quadControlCard(cs, 0, canRotate)),
              const SizedBox(width: 6),
              Expanded(child: _quadControlCard(cs, 1, canRotate)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _quadControlCard(cs, 2, canRotate)),
              const SizedBox(width: 6),
              Expanded(child: _quadControlCard(cs, 3, canRotate)),
            ],
          ),
          if (lastQuadrant >= 0 && lastQuadrant < 4) ...[
            const SizedBox(height: 4),
            Text(
              '上一步旋转：${_quadNames[lastQuadrant]} ${lastDir == 'cw' ? '顺时针 ↻' : '逆时针 ↺'}',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.75)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quadControlCard(ColorScheme cs, int q, bool canRotate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_quadNames[q], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: canRotate ? () => g.act({'type': 'rotate', 'quadrant': q, 'dir': 'ccw'}) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(54, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('↺ 逆旋', style: TextStyle(fontSize: 11)),
              ),
              FilledButton.tonal(
                onPressed: canRotate ? () => g.act({'type': 'rotate', 'quadrant': q, 'dir': 'cw'}) : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(54, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('↻ 顺旋', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
