import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<(String, String, Color)> _peMarbles = [
  ('🔴', '龙烟', Color(0xFFE53935)),
  ('🔵', '仙泪', Color(0xFF1E88E5)),
  ('🟡', '星尘', Color(0xFFFDD835)),
  ('⚫', '魔液', Color(0xFF546E7A)),
];

class PotionExplosionBoard extends StatelessWidget {
  final GameContext g;
  const PotionExplosionBoard(this.g, {super.key});

  bool _willExplode(List lane, int idx) {
    if (idx <= 0 || idx >= lane.length - 1) return false;
    final above = (lane[idx - 1] as num).toInt();
    final below = (lane[idx + 1] as num).toInt();
    return above == below;
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final skillTokensLeft = (v['skillTokensLeft'] as num?)?.toInt() ?? 6;
    final lanes = (v['lanes'] as List?) ?? const [];
    final potions = (v['potions'] as List?) ?? const [];
    final pool = (v['pool'] as List?) ?? const [];
    final completedPotions = (v['completedPotions'] as List?) ?? const [];
    final skillTokens = (v['skillTokens'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final lastExplosions = (v['lastExplosions'] as num?)?.toInt() ?? 0;
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    final myCompleted = (g.seat >= 0 && g.seat < completedPotions.length)
        ? (completedPotions[g.seat] as List)
        : const [];

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '魔法药水大爆炸 — 考核结束'
                          : '第 $round 轮 · 🎓剩余奖章:$skillTokensLeft · ${canAct ? "轮到你拿取弹珠/饮用魔药" : "等待 ${g.name(turn)} 炼药"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: lastExplosions > 0 ? FontWeight.bold : FontWeight.normal,
                        color: cs.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Drinkable Completed Potions Bar for current player
                  if (!g.over && g.seat >= 0 && myCompleted.any((cp) => (cp as Map)['drunk'] != true))
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('🥂 可饮用魔药:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          for (var i = 0; i < myCompleted.length; i++)
                            if ((myCompleted[i] as Map)['drunk'] != true)
                              FilledButton.tonal(
                                onPressed: () => g.act({'type': 'drink', 'potionIdx': i}),
                                child: Text(
                                  '饮用 ${(myCompleted[i] as Map)['emoji'] ?? '🧪'}${(myCompleted[i] as Map)['name'] ?? '魔药'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                        ],
                      ),
                    ),
                  // 5-Lane Marble Dispenser
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🔮 5 轨魔法弹珠分配器（点击弹珠拿取，带 💥 标记将直接触发同色碰撞连环爆炸！）',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var l = 0; l < lanes.length; l++)
                              _buildLaneColumn(
                                cs: cs,
                                laneIdx: l,
                                lane: lanes[l] as List,
                                canAct: canAct,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Workbenches (2 Active Potion Flasks + Retort Pool)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in g.seatsFromMe())
                        _buildPlayerWorkbench(
                          cs: cs,
                          seat: s,
                          isTurn: turn == s && !g.over,
                          seatPotions: s < potions.length ? (potions[s] as List) : const [],
                          seatPool: s < pool.length ? (pool[s] as List) : const [],
                          seatCompleted: s < completedPotions.length ? (completedPotions[s] as List) : const [],
                          seatSkills: s < skillTokens.length ? skillTokens[s] : 0,
                          seatScore: s < scores.length ? scores[s] : 0,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          sub: '⭐${s < scores.length ? scores[s] : 0}分 · 🧪${s < completedPotions.length ? (completedPotions[s] as List).length : 0}瓶 · 🎓${s < skillTokens.length ? skillTokens[s] : 0}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '魔法药水大爆炸结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildLaneColumn({
    required ColorScheme cs,
    required int laneIdx,
    required List lane,
    required bool canAct,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('第${laneIdx + 1}轨', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (var i = 0; i < lane.length; i++)
            _buildMarbleButton(
              cs: cs,
              laneIdx: laneIdx,
              idx: i,
              colorId: (lane[i] as num).toInt().clamp(0, 3),
              explodes: _willExplode(lane, i),
              canAct: canAct,
            ),
        ],
      ),
    );
  }

  Widget _buildMarbleButton({
    required ColorScheme cs,
    required int laneIdx,
    required int idx,
    required int colorId,
    required bool explodes,
    required bool canAct,
  }) {
    final m = _peMarbles[colorId];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: canAct ? () => g.act({'type': 'pick', 'lane': laneIdx, 'idx': idx}) : null,
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: m.$3.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: explodes ? Colors.orangeAccent : m.$3,
              width: explodes ? 2.0 : 1.2,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${m.$1}${m.$2}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                if (explodes) ...[
                  const SizedBox(width: 2),
                  const Text('💥', style: TextStyle(fontSize: 11)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerWorkbench({
    required ColorScheme cs,
    required int seat,
    required bool isTurn,
    required List seatPotions,
    required List seatPool,
    required List seatCompleted,
    required int seatSkills,
    required int seatScore,
  }) {
    final poolStr = seatPool.isEmpty
        ? '空'
        : seatPool.map((c) => _peMarbles[(c as num).toInt().clamp(0, 3)].$1).join(' ');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTurn ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: isTurn ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '🧙 ${g.name(seat)}${seat == g.seat ? " (你)" : ""}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '⭐$seatScore分 · 🎓×$seatSkills · 烧瓶:$poolStr',
                  style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var pIdx = 0; pIdx < seatPotions.length; pIdx++)
              _buildFlaskCard(cs, seatPotions[pIdx] as Map),
          ],
        ),
      ),
    );
  }

  Widget _buildFlaskCard(ColorScheme cs, Map flask) {
    final emoji = flask['emoji'] ?? '🧪';
    final name = flask['name'] ?? '魔药';
    final vp = flask['vp'] ?? 5;
    final need = (flask['need'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 1, 1, 0];
    final filled = (flask['filled'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0, 0, 0];

    final reqParts = <String>[];
    for (var c = 0; c < 4; c++) {
      if (c < need.length && need[c] > 0) {
        final f = c < filled.length ? filled[c] : 0;
        reqParts.add('${_peMarbles[c].$1}$f/${need[c]}');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '$emoji $name (+$vp分)',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            reqParts.join('  '),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
