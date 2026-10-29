import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class MaheBoard extends StatelessWidget {
  final GameContext g;
  const MaheBoard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final controller = (v['controller'] as num?)?.toInt() ?? turn;
    final pos = (v['pos'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final stacks = (v['stacks'] as List?) ?? const [];
    final movingGroup = (v['movingGroup'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [turn];
    final dice = (v['dice'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1];
    final diceSum = (v['diceSum'] as num?)?.toInt() ?? 1;
    final moveSteps = (v['moveSteps'] as num?)?.toInt() ?? 1;
    final eggDeckCount = (v['eggDeckCount'] as num?)?.toInt() ?? 15;
    final eggs = (v['eggs'] as List?) ?? const [];
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
                          ? '马埃岛海龟竞速 — 比赛结束'
                          : '${g.name(turn)} 的海龟行动 (栈顶控制者: ${g.name(controller)}) · ${canAct ? "请决定见好就收或继续加骰" : "等待 ${g.name(controller)} 决策"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.88)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Dice & Push-Your-Luck Control Bar
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: canAct ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🎲 当前骰子: ${dice.join(" + ")} = $diceSum 点 (×${dice.length}倍 = 前进 $moveSteps 格)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            Text(
                              '🐢 同行海龟栈: [${movingGroup.map((s) => "P${s + 1}(${g.name(s)})").join(" → ")}] · 🥚剩余海龟蛋牌堆: $eggDeckCount 张',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        if (canAct)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              FilledButton(
                                onPressed: () => g.act({'type': 'stop'}),
                                child: Text('🛑 见好就收 (前进 $moveSteps 格)'),
                              ),
                              if (dice.length < 3)
                                FilledButton.tonal(
                                  onPressed: () => g.act({'type': 'roll'}),
                                  child: Text('🎲 加掷第 ${dice.length + 1} 颗骰子 (×${dice.length + 1}倍 / >7爆点)'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 21-Space Island Loop
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🏝️ 马埃岛 21 格环形赛道（越过 20 格即产卵拿分并环岛）：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var p = 0; p < 21; p++)
                              _buildTrackSpace(
                                g: g,
                                cs: cs,
                                space: p,
                                pos: pos,
                                stack: p < stacks.length && stacks[p] is List
                                    ? (stacks[p] as List).map((e) => (e as num).toInt()).toList()
                                    : const <int>[],
                              ),
                          ],
                        ),
                      ],
                    ),
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
                          active: controller == s && !g.over,
                          sub: '📍第${s < pos.length ? pos[s] : 0}格 · 🥚蛋:${s < eggs.length && eggs[s] is List ? (eggs[s] as List).length : 0}枚 · ⭐${s < scores.length ? scores[s] : 0}分',
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
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '游戏结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackSpace({
    required GameContext g,
    required ColorScheme cs,
    required int space,
    required List<int> pos,
    required List<int> stack,
  }) {
    final turtlesAtZero = space == 0
        ? [
            for (var s = 0; s < pos.length; s++)
              if (pos[s] == 0) s,
          ]
        : const <int>[];
    final list = space == 0 ? turtlesAtZero : stack;
    final hasTurtles = list.isNotEmpty;

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: hasTurtles
            ? cs.primaryContainer
            : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasTurtles ? cs.primary : cs.outline.withValues(alpha: 0.25),
          width: hasTurtles ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            space == 0
                ? '🏖️ #0 起点'
                : (space == 20 ? '🥚 #20 产卵滩' : '🌊 #$space 航道'),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            hasTurtles
                ? (space == 0
                    ? list.map((s) => '🐢P${s + 1}').join(' ')
                    : '底[${list.map((s) => "P${s + 1}").join("→")}]顶')
                : '空',
            style: TextStyle(
              fontSize: 10,
              fontWeight: hasTurtles ? FontWeight.bold : FontWeight.normal,
              color: hasTurtles ? cs.onPrimaryContainer : cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
