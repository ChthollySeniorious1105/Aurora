import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TacoCatBoard extends StatelessWidget {
  final GameContext g;
  const TacoCatBoard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 12;
    final spokenWord = (v['spokenWord'] as num?)?.toInt() ?? 0;
    final cardType = (v['cardType'] as num?)?.toInt() ?? 0;
    final pileCount = (v['pileCount'] as num?)?.toInt() ?? 1;
    final cardDefs = (v['cardDefs'] as List?) ?? const [];
    final actionDefs = (v['actionDefs'] as List?) ?? const [];
    final personalDeck = (v['personalDeck'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 10);
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final myReaction = v['myReaction'] as String?;
    final reactedSeats = (v['reactedSeats'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canReact = v['canReact'] == true && !g.over;

    String cardTitle(int cid) {
      if (cid >= 0 && cid < cardDefs.length) {
        final m = cardDefs[cid] as Map;
        return '${m['emoji']} ${m['name']}';
      }
      return '❓未知卡';
    }

    final isMatch = cardType < 5 && cardType == spokenWord;
    final isSpecial = cardType >= 5;

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
                          ? '塔可猫羊起司披萨 — 终局手速榜'
                          : '第 $round/$totalRounds 轮 · 中央罚牌堆 $pileCount 张 · ${canReact ? "⚡ 请立即选择反应动作！" : "已反应 (${reactedSeats.length}/${g.players})"}',
                      highlight: canReact,
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
                  // Mantra Cycle Bar (🌮 -> 🐱 -> 🐐 -> 🧀 -> 🍕)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var w = 0; w < 5 && w < cardDefs.length; w++)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: w == spokenWord
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: w == spokenWord
                                        ? cs.primary
                                        : cs.outline.withValues(alpha: 0.25),
                                    width: w == spokenWord ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Text(
                                  '${w == spokenWord ? "🗣️ " : ""}${(cardDefs[w] as Map)['emoji']}${(cardDefs[w] as Map)['short']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: w == spokenWord ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Spoken Word vs Flipped Card Arena
                        Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              width: 155,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text('🗣️ 本轮念出咒语', style: TextStyle(fontSize: 11)),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      cardTitle(spokenWord),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text('⚡ VS ⚡', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Container(
                              width: 170,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (isMatch || isSpecial)
                                    ? cs.primaryContainer.withValues(alpha: 0.85)
                                    : cs.surfaceContainerHighest.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (isMatch || isSpecial) ? cs.primary : cs.outline,
                                  width: (isMatch || isSpecial) ? 2.0 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '🃏 翻开中央牌 (堆叠 $pileCount 张)',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      cardTitle(cardType),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
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
                  // 5 Reaction Buttons (Slap / Hold / Gorilla / Groundhog / Narwhal)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          myReaction != null
                              ? '✅ 你本轮已选择反应：$myReaction'
                              : '🖐️ 选择你的闪电反应动作:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final a in actionDefs)
                              Builder(builder: (context) {
                                final m = a as Map;
                                final key = '${m['key']}';
                                final label = '${m['label']}';
                                return FilledButton.tonal(
                                  onPressed: canReact
                                      ? () => g.act({'type': 'react', 'action': key})
                                      : null,
                                  child: Text(label, style: const TextStyle(fontSize: 12)),
                                );
                              }),
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
                          active: !g.over && !reactedSeats.contains(s),
                          sub: '🃏剩${s < personalDeck.length ? personalDeck[s] : 0}张 · ⭐${s < scores.length ? scores[s] : 0}分',
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
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '塔可猫羊起司披萨结束'),
            ),
        ],
      ),
    );
  }
}
