import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const _mIcons = ['🔴', '🟡', '🔵', '⚫'];
const _mNames = ['红热能', '黄电能', '蓝水能', '黑原子'];

class GizmosBoard extends StatelessWidget {
  final GameContext g;
  const GizmosBoard(this.g, {super.key});

  String _marblesText(List<dynamic> m) {
    final parts = <String>[];
    for (var i = 0; i < m.length && i < 4; i++) {
      parts.add('${_mIcons[i]}${m[i]}');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final targetGizmos = (v['targetGizmos'] as num?)?.toInt() ?? 12;
    final endTriggered = v['endTriggered'] == true;
    final lastAction = '${v['lastAction'] ?? ''}';
    final energyRow = (v['energyRow'] as List?) ?? const [];
    final deckCounts = (v['deckCounts'] as List?) ?? const [0, 0, 0];
    final display = (v['display'] as List?) ?? const [[], [], []];
    final marbles = (v['marbles'] as List?) ?? const [];
    final storageLimit = (v['storageLimit'] as List?) ?? const [];
    final archiveLimit = (v['archiveLimit'] as List?) ?? const [];
    final researchLimit = (v['researchLimit'] as List?) ?? const [];
    final archive = (v['archive'] as List?) ?? const [];
    final built = (v['built'] as List?) ?? const [];
    final scores = (v['scores'] as List?) ?? const [];

    final isMyTurn = !g.over && g.seat == turn;

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '游戏已结束 — $lastAction'
                          : '第 $round 轮${endTriggered ? '（终局轮！）' : ''} · 目标 $targetGizmos 装置/4座3级 · 轮到 ${g.name(turn)} · $lastAction',
                      highlight: isMyTurn,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Player tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in g.seatsFromMe())
                        if (s < scores.length)
                          g.tag(
                            s,
                            active: s == turn && !g.over,
                            sub:
                                '⭐${scores[s]}分 | ⚙️${(built[s] as List).length}/$targetGizmos | ${_marblesText(marbles[s] as List)} (限${storageLimit[s]}) | 📁${(archive[s] as List).length}/${archiveLimit[s]} | 🔍${researchLimit[s]}',
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Energy Dispenser Row
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('🔮 能量球轨道 (Energy Row)：',
                            style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                        for (var i = 0; i < energyRow.length; i++)
                          ActionChip(
                            label: Text(
                              '${_mIcons[(energyRow[i] as num).toInt()]} ${_mNames[(energyRow[i] as num).toInt()]}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: isMyTurn ? () => g.act({'type': 'pick', 'index': i}) : null,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3 Tiers of Gizmo Cards
                  for (var t = 2; t >= 0; t--) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '⚙️ ${t + 1} 级装置展示区 (牌库剩余 ${t < deckCounts.length ? deckCounts[t] : 0} 张)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                              ),
                              if (isMyTurn && t < deckCounts.length && (deckCounts[t] as num).toInt() > 0)
                                OutlinedButton.icon(
                                  onPressed: () => g.act({'type': 'research', 'tier': t + 1}),
                                  icon: const Icon(Icons.search, size: 15),
                                  label: Text('研究 ${t + 1} 级牌库', style: const TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (t < display.length)
                                for (var i = 0; i < (display[t] as List).length; i++)
                                  _buildGizmoCard(
                                    cs,
                                    card: (display[t] as List)[i] as Map<String, dynamic>,
                                    canAct: isMyTurn,
                                    onBuild: () => g.act({'type': 'build', 'tier': t + 1, 'index': i}),
                                    onFile: () => g.act({'type': 'file', 'tier': t + 1, 'index': i}),
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // My Archive & Built Engine
                  if (g.seat >= 0 && g.seat < archive.length)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📁 我的个人归档区 (${(archive[g.seat] as List).length}/${archiveLimit[g.seat]}) 与已建引擎 (${(built[g.seat] as List).length}座)',
                            style: TextStyle(fontWeight: FontWeight.bold, color: cs.secondary),
                          ),
                          if ((archive[g.seat] as List).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < (archive[g.seat] as List).length; i++)
                                  _buildGizmoCard(
                                    cs,
                                    card: (archive[g.seat] as List)[i] as Map<String, dynamic>,
                                    canAct: isMyTurn,
                                    onBuild: () => g.act({'type': 'build', 'fromArchive': true, 'archive': i}),
                                    onFile: null,
                                  ),
                              ],
                            ),
                          ],
                          if ((built[g.seat] as List).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final raw in (built[g.seat] as List))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_mIcons[((raw as Map)['color'] as num).toInt()]} ${raw['name']} (⭐${raw['vp']})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (g.over && v['result'] is Map)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '🏆 获胜者：${((v['result'] as Map)['winners'] as List?)?.join('、') ?? ''}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players && s < scores.length; s++)
                      Text('${g.name(s)}：${scores[s]} 分（已建 ${(built[s] as List).length} 座装置）'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGizmoCard(
    ColorScheme cs, {
    required Map<String, dynamic> card,
    required bool canAct,
    required VoidCallback onBuild,
    required VoidCallback? onFile,
  }) {
    final name = '${card['name']}';
    final color = (card['color'] as num?)?.toInt() ?? 0;
    final cost = (card['cost'] as num?)?.toInt() ?? 1;
    final vp = (card['vp'] as num?)?.toInt() ?? 1;
    final desc = '${card['desc'] ?? ''}';

    return Container(
      width: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${_mIcons[color]} $name',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
              Text('⭐$vp', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          Text('费用: ${_mIcons[color]}×$cost', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(fontSize: 10.5, color: cs.onSurface.withValues(alpha: 0.82))),
          if (canAct) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  onPressed: onBuild,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  child: const Text('建造', style: TextStyle(fontSize: 11)),
                ),
                if (onFile != null)
                  OutlinedButton(
                    onPressed: onFile,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                    child: const Text('归档', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
