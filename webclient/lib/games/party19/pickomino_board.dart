import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class PickominoBoard extends StatelessWidget {
  final GameContext g;
  const PickominoBoard(this.g, {super.key});

  int _wormVal(int t) => t < 21 ? 0 : ((t - 21) ~/ 4 + 1).clamp(1, 4);

  String _dieLabel(int f) => f == 6 ? '🐛虫(5)' : '🎲$f';

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 12;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final step = v['step'] as String? ?? 'keep';
    final grillTiles = (v['grillTiles'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final topTiles = (v['topTiles'] as List?) ?? const [];
    final stackSizes = (v['stackSizes'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final diceRemaining = (v['diceRemaining'] as num?)?.toInt() ?? 8;
    final currentRoll = (v['currentRoll'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final keepableFaces = (v['keepableFaces'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final lockedDice = (v['lockedDice'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final lockedSum = (v['lockedSum'] as num?)?.toInt() ?? 0;
    final hasWorm = v['hasWorm'] == true;
    final canClaim = v['canClaim'] == true;
    final stealableSeat = (v['stealableSeat'] as num?)?.toInt() ?? -1;
    final claimableGrillTile = (v['claimableGrillTile'] as num?)?.toInt() ?? -1;
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

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
                          ? '虫虫烧烤派对 — 终局结算'
                          : '第 $round/$maxRounds 轮 · 累计点数: $lockedSum ${hasWorm ? "(含🐛)" : "(未含🐛)"} · ${canAct ? "轮到你行动" : "等待 ${g.name(turn)}"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.9)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Dice Rolling & Locking Area
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎲 已锁定骰子 (总点数 $lockedSum · 剩余 $diceRemaining 颗可掷): '
                          '${lockedDice.isEmpty ? "暂无" : lockedDice.map(_dieLabel).join(" ")}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        if (currentRoll.isNotEmpty) ...[
                          Text(
                            '当前投掷结果: ${currentRoll.map(_dieLabel).join("  ")}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (canAct)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (step == 'keep') ...[
                                for (final f in keepableFaces)
                                  FilledButton(
                                    onPressed: () => g.act({'type': 'keep', 'face': f}),
                                    child: Text(
                                      '保留全部 ${_dieLabel(f)} (×${currentRoll.where((d) => d == f).length})',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                if (keepableFaces.isEmpty)
                                  FilledButton.tonal(
                                    onPressed: () => g.act({'type': 'roll'}),
                                    child: const Text('💥 确认爆煲结算', style: TextStyle(fontSize: 12)),
                                  ),
                              ] else ...[
                                if (diceRemaining > 0)
                                  FilledButton.tonal(
                                    onPressed: () => g.act({'type': 'roll'}),
                                    child: Text(
                                      '🎲 继续重掷 ($diceRemaining 颗骰)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                if (canClaim)
                                  FilledButton(
                                    onPressed: () => g.act({'type': 'claim'}),
                                    child: Text(
                                      stealableSeat >= 0
                                          ? '🦅 抢走 ${g.name(stealableSeat)} 栈顶 #$lockedSum 砖!'
                                          : '🍖 拿取烤架 #$claimableGrillTile 号砖',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Central Grill Tiles (21..36)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔥 中央烧烤架（剩余 ${grillTiles.length} 块烤砖 · 21~24=1🐛, 25~28=2🐛, 29~32=3🐛, 33~36=4🐛）',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final t in grillTiles)
                              Container(
                                width: 62,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                decoration: BoxDecoration(
                                  color: t == claimableGrillTile && hasWorm
                                      ? Colors.amber.withValues(alpha: 0.35)
                                      : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: t == claimableGrillTile && hasWorm
                                        ? cs.primary
                                        : cs.outline.withValues(alpha: 0.3),
                                    width: t == claimableGrillTile && hasWorm ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '#$t',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '🐛×${_wormVal(t)}',
                                      style: TextStyle(fontSize: 10, color: cs.primary),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Top Tiles & Stacks
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        Builder(builder: (context) {
                          final top = s < topTiles.length && topTiles[s] != null
                              ? (topTiles[s] as num).toInt()
                              : null;
                          final cnt = s < stackSizes.length ? stackSizes[s] : 0;
                          return g.tag(
                            s,
                            active: turn == s && !g.over,
                            sub: '🐛${s < scores.length ? scores[s] : 0}分 · 栈顶:${top != null ? "#$top" : "空"}($cnt块)',
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '虫虫烧烤派对结束'),
            ),
        ],
      ),
    );
  }
}
