import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class BombBustersBoard extends StatefulWidget {
  final GameContext g;
  const BombBustersBoard(this.g, {super.key});

  @override
  State<BombBustersBoard> createState() => _BombBustersBoardState();
}

class _BombBustersBoardState extends State<BombBustersBoard> {
  int _selectedMyIdx = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final detonator = (v['detonator'] as num?)?.toInt() ?? 4;
    final maxDetonator = (v['maxDetonator'] as num?)?.toInt() ?? 4;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final defused = v['defused'] == true;
    final exploded = v['exploded'] == true;
    final wires = (v['wires'] as List?) ?? const [];
    final soloCuttable = (v['soloCuttable'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final teamScore = (v['teamScore'] as num?)?.toInt() ?? 0;
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    final myRack = (g.seat >= 0 && g.seat < wires.length)
        ? (wires[g.seat] as List)
        : const [];
    final myUncutNonRed = <int>[
      for (var i = 0; i < myRack.length; i++)
        if ((myRack[i] as Map)['cut'] != true &&
            ((myRack[i] as Map)['value'] as num).toInt() != 100)
          i,
    ];
    final activeMyIdx = myUncutNonRed.contains(_selectedMyIdx)
        ? _selectedMyIdx
        : (myUncutNonRed.isNotEmpty ? myUncutNonRed.first : -1);
    final activeMyVal = activeMyIdx >= 0
        ? ((myRack[activeMyIdx] as Map)['value'] as num).toInt()
        : -1;

    String wireBadge(int val) {
      if (val == 100) return '🔴红线(炸弹)';
      if (val == 99) return '🟡黄线';
      if (val <= 0) return '❓暗线';
      return '🔵$val号';
    }

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
                          ? (defused
                              ? '🏆 拆弹专家 — 炸弹成功解除！（团队 $teamScore 分）'
                              : '💥 拆弹专家 — 炸弹引爆！任务失败')
                          : '💣 引信剩余 $detonator/$maxDetonator 格 · 团队 $teamScore 分 · ${canAct ? "轮到你拆弹" : "等待 ${g.name(turn)}"}',
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
                  // Solo Cut & Active Selection Controls
                  if (canAct)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            activeMyIdx >= 0
                                ? '✂️ 已选己方第 ${activeMyIdx + 1} 根【${wireBadge(activeMyVal)}】— 点击下方任意队友未剪槽位执行【双人配对剪线】'
                                : '✂️ 请选择导线行动',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          for (final sv in soloCuttable)
                            FilledButton(
                              onPressed: () => g.act({'type': 'solo_cut', 'value': sv}),
                              child: Text(
                                '✂️ 单人独剪全部【${wireBadge(sv)}】(+2分)',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // All Players' Sorted Wire Racks
                  for (final s in g.seatsFromMe())
                    if (s >= 0 && s < wires.length)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: s == g.seat
                                ? cs.primary.withValues(alpha: 0.5)
                                : cs.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🔌 ${g.name(s)}${s == g.seat ? " (你)" : ""} 的升序导线架（左→右从小到大）:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: s == g.seat ? cs.primary : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (var idx = 0; idx < (wires[s] as List).length; idx++)
                                  Builder(builder: (context) {
                                    final w = (wires[s] as List)[idx] as Map;
                                    final cut = w['cut'] == true;
                                    final token = (w['token'] as num?)?.toInt();
                                    final val = (w['value'] as num).toInt();
                                    final isMe = s == g.seat;
                                    final isMySelected = isMe && activeMyIdx == idx;
                                    final canDualCutHere =
                                        canAct && !isMe && !cut && activeMyIdx >= 0;

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: isMe && !cut && val != 100
                                          ? () => setState(() => _selectedMyIdx = idx)
                                          : (canDualCutHere
                                              ? () => g.act({
                                                    'type': 'dual_cut',
                                                    'myIdx': activeMyIdx,
                                                    'targetSeat': s,
                                                    'targetIdx': idx,
                                                  })
                                              : null),
                                      child: Container(
                                        width: 92,
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: cut
                                              ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
                                              : (isMySelected
                                                  ? cs.primaryContainer
                                                  : cs.surfaceContainerHighest.withValues(alpha: 0.65)),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isMySelected || canDualCutHere
                                                ? cs.primary
                                                : cs.outline.withValues(alpha: 0.3),
                                            width: isMySelected ? 2.0 : 1.0,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '槽位 #${idx + 1}',
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                            const SizedBox(height: 2),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                wireBadge(val),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: cut ? TextDecoration.lineThrough : null,
                                                  color: val == 100 ? cs.error : cs.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              cut
                                                  ? '✂️已剪断'
                                                  : (token != null ? '🏷️标记:$token' : '🔒未剪'),
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ],
                        ),
                      ),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          sub: '⭐${s < scores.length ? scores[s] : 0}分',
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
              child: ResultBanner(
                lastEvent.isNotEmpty
                    ? lastEvent
                    : (exploded ? '炸弹爆炸！拆弹失败' : '拆弹成功！'),
              ),
            ),
        ],
      ),
    );
  }
}
