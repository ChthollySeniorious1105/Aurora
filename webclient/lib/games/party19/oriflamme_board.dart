import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class OriflammeBoard extends StatefulWidget {
  final GameContext g;
  const OriflammeBoard(this.g, {super.key});

  @override
  State<OriflammeBoard> createState() => _OriflammeBoardState();
}

class _OriflammeBoardState extends State<OriflammeBoard> {
  int _selectedCard = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 6;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = v['phase'] as String? ?? 'place';
    final resolveIdx = (v['resolveIdx'] as num?)?.toInt() ?? 0;
    final cardDefs = (v['cardDefs'] as List?) ?? const [];
    final myHand = (v['myHand'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final queue = (v['queue'] as List?) ?? const [];
    final validTargets = (v['validTargets'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 1);
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    final activeHandCard = myHand.contains(_selectedCard)
        ? _selectedCard
        : (myHand.isNotEmpty ? myHand.first : -1);

    String cardTitle(int cid) {
      if (cid >= 0 && cid < cardDefs.length) {
        final m = cardDefs[cid] as Map;
        return '${m['emoji']}${m['name']}';
      }
      return '❓暗置权谋卡';
    }

    String cardDesc(int cid) {
      if (cid >= 0 && cid < cardDefs.length) {
        final m = cardDefs[cid] as Map;
        return '${m['desc']}';
      }
      return '对手暗置的权谋卡牌';
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
                          ? '王权烈焰 — 王座加冕结算'
                          : '第 $round/$totalRounds 轮 · ${phase == "place" ? "🎴暗置入列阶段" : "⚡从左至右结算 (第 ${resolveIdx + 1}/${queue.length} 张)"} · ${canAct ? "轮到你行动" : "等待 ${g.name(turn)}"}',
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
                  // Resolve Phase Decision Panel
                  if (canAct && phase == 'resolve' && resolveIdx >= 0 && resolveIdx < queue.length)
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
                            '⚡ 结算队列第 ${resolveIdx + 1} 张牌:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          FilledButton.tonal(
                            onPressed: () => g.act({'type': 'keep_hidden'}),
                            child: const Text('🤫 保持暗置 (+1 VP 叠于牌上)', style: TextStyle(fontSize: 12)),
                          ),
                          if (validTargets.isEmpty)
                            FilledButton(
                              onPressed: () => g.act({'type': 'reveal'}),
                              child: const Text('🔥 翻开收分并发动技能', style: TextStyle(fontSize: 12)),
                            )
                          else
                            for (final tIdx in validTargets)
                              FilledButton(
                                onPressed: () => g.act({'type': 'reveal', 'targetIdx': tIdx}),
                                child: Text(
                                  '🔥 翻开并对第 ${tIdx + 1} 位发动',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                        ],
                      ),
                    ),
                  // Central Intrigue Queue (Left to Right)
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
                          '📜 中央权谋队列（⬅️ 从左向右依次结算 ➡️）',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        if (queue.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text('当前队列为空，请将手牌暗置放入左端或右端', style: TextStyle(fontSize: 12)),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < queue.length; i++)
                                Builder(builder: (context) {
                                  final item = queue[i] as Map;
                                  final owner = (item['owner'] as num).toInt();
                                  final revealed = item['revealed'] == true;
                                  final tokens = (item['tokens'] as num).toInt();
                                  final cid = (item['card'] as num).toInt();
                                  final isResolving = phase == 'resolve' && i == resolveIdx;
                                  final isTargetable =
                                      canAct && phase == 'resolve' && validTargets.contains(i);

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: isTargetable
                                        ? () => g.act({'type': 'reveal', 'targetIdx': i})
                                        : null,
                                    child: Container(
                                      width: 118,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isResolving
                                            ? cs.primaryContainer.withValues(alpha: 0.75)
                                            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isResolving || isTargetable
                                              ? cs.primary
                                              : cs.outline.withValues(alpha: 0.3),
                                          width: isResolving || isTargetable ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '#${i + 1} · ${g.name(owner)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            cardTitle(cid),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: cs.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${revealed ? "🔓已翻开" : "🔒暗置"} · 🪙×$tokens',
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
                  const SizedBox(height: 8),
                  // Player Hand & Left/Right Placement Controls
                  if (myHand.isNotEmpty)
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '🃏 你的家族权谋手牌 (${myHand.length} 张):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                              ),
                              if (canAct && phase == 'place' && activeHandCard >= 0) ...[
                                FilledButton.tonal(
                                  onPressed: () =>
                                      g.act({'type': 'place', 'card': activeHandCard, 'pos': 'left'}),
                                  child: Text(
                                    '⬅️ 暗置入左端 (${cardTitle(activeHandCard)})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      g.act({'type': 'place', 'card': activeHandCard, 'pos': 'right'}),
                                  child: Text(
                                    '➡️ 暗置入右端 (${cardTitle(activeHandCard)})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final cid in myHand)
                                ChoiceChip(
                                  label: Text(
                                    '${cardTitle(cid)} (${cardDesc(cid)})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: activeHandCard == cid,
                                  onSelected: (_) => setState(() => _selectedCard = cid),
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
                          active: turn == s && !g.over,
                          sub: '👑${s < scores.length ? scores[s] : 0} VP',
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
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '王权烈焰结束'),
            ),
        ],
      ),
    );
  }
}
