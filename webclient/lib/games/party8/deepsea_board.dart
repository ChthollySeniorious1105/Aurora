import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class DeepSeaBoard extends StatelessWidget {
  final GameContext g;
  const DeepSeaBoard(this.g, {super.key});

  static const List<Color> _levelColors = [
    Color(0xFF78909C),
    Color(0xFF29B6F6), // Level 1
    Color(0xFF26A69A), // Level 2
    Color(0xFF5C6BC0), // Level 3
    Color(0xFF8E24AA), // Level 4
  ];

  static const List<Color> _diverColors = [
    Color(0xFFE53935),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
  ];

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 3;
    final oxygen = (v['oxygen'] as num?)?.toInt() ?? 25;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'dir'}';
    final dice =
        (v['dice'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const [1, 1];
    final lastEvent = '${v['lastEvent'] ?? ''}';
    final path = (v['path'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        const <Map<String, dynamic>>[];
    final pos =
        (v['pos'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, -1);
    final turningBack =
        (v['turningBack'] as List?)?.map((e) => e == true).toList() ??
            List.filled(g.players, false);
    final returned =
        (v['returned'] as List?)?.map((e) => e == true).toList() ??
            List.filled(g.players, false);
    final carriedCount =
        (v['carriedCount'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);

    final myTurn = !g.over && g.seat == turn;
    final statusText = g.over
        ? '深海探险结束！'
        : phase == 'dir'
            ? '第 $round/$maxRounds 潜 · 轮到 ${g.name(turn)} 选择方向'
            : '第 $round/$maxRounds 潜 · 轮到 ${g.name(turn)} 探索海底';

    return Stack(
      children: [
        Container(
          color: g.table,
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              // Top bar: Status + Oxygen gauge
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBar(statusText, highlight: myTurn),
                  _buildOxygenPill(cs, oxygen),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '骰子(1~3): ${dice[0]} + ${dice[1]} = ${dice[0] + dice[1]}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (lastEvent.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  lastEvent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              // Player tags
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in g.seatsFromMe())
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: g.tag(
                          s,
                          active: !g.over && s == turn,
                          sub:
                              '入库:${scores[s]}分 · 背负:${carriedCount[s]} · ${_diverStateText(pos[s], turningBack[s], returned[s])}',
                          size: 30,
                          trailing: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _diverColors[s % _diverColors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Action controls if it's my turn
              if (myTurn) ...[
                const SizedBox(height: 6),
                _buildActionButtons(
                  phase: phase,
                  myPos: pos[g.seat],
                  myCarried: carriedCount[g.seat],
                  path: path,
                ),
              ],
              const SizedBox(height: 6),
              // Main Sea Path
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildSubmarineCard(cs, pos, returned, scores),
                        for (var i = 0; i < path.length; i++)
                          _buildPathTile(
                            index: i,
                            tile: path[i],
                            pos: pos,
                            turningBack: turningBack,
                            returned: returned,
                            turn: turn,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (g.over)
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: ResultBanner(
                _winnerText(scores),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${g.name(s)}: ${scores[s]} 分',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _winnerText(List<int> scores) {
    if (scores.isEmpty) return '游戏结束';
    var best = scores.first;
    for (final s in scores) {
      if (s > best) best = s;
    }
    final winners = <String>[
      for (var i = 0; i < g.players; i++)
        if (scores[i] == best) g.name(i),
    ];
    return '${winners.join("、")} 获胜！（$best 分）';
  }

  String _diverStateText(int p, bool back, bool ret) {
    if (ret) return '已返航✓';
    if (p < 0) return '潜艇待命';
    return back ? '返航⬆(#${p + 1})' : '下潜⬇(#${p + 1})';
  }

  Widget _buildOxygenPill(ColorScheme cs, int oxygen) {
    final color = oxygen > 12
        ? Colors.cyan.shade700
        : oxygen > 5
            ? Colors.orange.shade800
            : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bubble_chart, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '共享氧气: $oxygen / 25',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required String phase,
    required int myPos,
    required int myCarried,
    required List<Map<String, dynamic>> path,
  }) {
    if (phase == 'dir') {
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => g.act({'type': 'dir', 'dir': 'down'}),
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: const Text('继续下潜'),
          ),
          if (myPos >= 0)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.black87,
              ),
              onPressed: () => g.act({'type': 'dir', 'dir': 'back'}),
              icon: const Icon(Icons.u_turn_left, size: 16),
              label: const Text('掉头返航'),
            ),
        ],
      );
    } else if (phase == 'tile') {
      final onTile = myPos >= 0 && myPos < path.length ? path[myPos] : null;
      final isBlank = onTile == null || onTile['blank'] == true;
      final lvl = (onTile?['level'] as num?)?.toInt() ?? 1;
      return Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          OutlinedButton(
            onPressed: () => g.act({'type': 'tile', 'act': 'stay'}),
            child: const Text('停留不动'),
          ),
          if (!isBlank)
            ElevatedButton.icon(
              onPressed: () => g.act({'type': 'tile', 'act': 'pickup'}),
              icon: const Icon(Icons.pan_tool_alt, size: 16),
              label: Text('拾取遗迹 (等级$lvl)'),
            ),
          if (isBlank && myCarried > 0)
            ElevatedButton.icon(
              onPressed: () => g.act({'type': 'tile', 'act': 'drop', 'idx': 0}),
              icon: const Icon(Icons.file_download, size: 16),
              label: const Text('放回 1 个遗迹'),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSubmarineCard(
    ColorScheme cs,
    List<int> pos,
    List<bool> returned,
    List<int> scores,
  ) {
    final inSub = <int>[
      for (var s = 0; s < g.players; s++)
        if (pos[s] < 0 || returned[s]) s,
    ];
    return Container(
      width: 96,
      height: 62,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.amber.shade600,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade900, width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_boat, size: 16, color: Colors.black87),
                SizedBox(width: 4),
                Text(
                  '深海潜艇',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              inSub.isEmpty
                  ? '全员下潜中'
                  : '舱内: ${inSub.map((s) => g.name(s)).join(",")}',
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathTile({
    required int index,
    required Map<String, dynamic> tile,
    required List<int> pos,
    required List<bool> turningBack,
    required List<bool> returned,
    required int turn,
  }) {
    final isBlank = tile['blank'] == true;
    final level = (tile['level'] as num?)?.toInt() ?? 0;
    int? occupant;
    for (var s = 0; s < g.players; s++) {
      if (!returned[s] && pos[s] == index) {
        occupant = s;
        break;
      }
    }

    final bgColor = isBlank
        ? Colors.grey.withValues(alpha: 0.25)
        : _levelColors[level.clamp(0, 4)];
    final isActiveDiver = occupant != null && occupant == turn && !g.over;

    return Container(
      width: 56,
      height: 62,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActiveDiver
              ? Colors.amber
              : occupant != null
                  ? Colors.white
                  : Colors.black26,
          width: isActiveDiver ? 2.5 : 1,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#${index + 1}',
              style: TextStyle(
                fontSize: 10,
                color: isBlank ? Colors.black54 : Colors.white70,
              ),
            ),
            Text(
              isBlank ? '空位' : '•' * level,
              style: TextStyle(
                fontSize: isBlank ? 11 : 15,
                fontWeight: FontWeight.bold,
                color: isBlank ? Colors.black54 : Colors.white,
              ),
            ),
            if (occupant != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: _diverColors[occupant % _diverColors.length],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${g.name(occupant)}${turningBack[occupant] ? "⬆" : "⬇"}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
