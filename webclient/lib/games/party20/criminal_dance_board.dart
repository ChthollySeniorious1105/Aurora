import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CriminalDanceBoard extends StatefulWidget {
  final GameContext g;
  const CriminalDanceBoard(this.g, {super.key});

  @override
  State<CriminalDanceBoard> createState() => _CriminalDanceBoardState();
}

class _CriminalDanceBoardState extends State<CriminalDanceBoard> {
  String _selectedCard = '';
  int _selectedTarget = -1;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final firstTurn = v['firstTurn'] == true;
    final cardInfo = (v['cardInfo'] as Map?) ?? const {};
    final myHand = (v['myHand'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final playable = (v['playable'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final validTargets = (v['validTargets'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final intel = (v['intel'] as Map?) ?? const {};
    final accomplices = (v['accomplices'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final playedPile = (v['playedPile'] as List?) ?? const [];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    final activeCard = playable.contains(_selectedCard)
        ? _selectedCard
        : (playable.isNotEmpty ? playable.first : (myHand.isNotEmpty ? myHand.first : ''));
    final activeTarget = validTargets.contains(_selectedTarget)
        ? _selectedTarget
        : (validTargets.isNotEmpty ? validTargets.first : -1);

    final needsTarget = (activeCard == 'detective' ||
            activeCard == 'dog' ||
            activeCard == 'witness' ||
            activeCard == 'trade') &&
        validTargets.isNotEmpty;

    String cardTitle(String k) {
      final info = cardInfo[k] as Map?;
      if (info == null) return k;
      return '${info['emoji']}${info['name']}';
    }

    String cardDesc(String k) {
      final info = cardInfo[k] as Map?;
      if (info == null) return '';
      return '${info['desc']}';
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
                          ? '犯人在跳舞 — 案件水落石出'
                          : '第 $round/$totalRounds 局 · ${firstTurn ? "🥇首回合发现现场" : "🔍案件调查中"} · ${canAct ? "轮到你出牌" : "等待 ${g.name(turn)}"}',
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
                  // Private Witness / Dog Intel Banner
                  if (intel.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.secondary.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '👁️ 你的私人侦查情报（仅你可见）:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              for (final e in intel.entries)
                                Builder(builder: (context) {
                                  final tSeat = int.tryParse('${e.key}') ?? 0;
                                  final cards = (e.value as List?)
                                          ?.map((c) => cardTitle('$c'))
                                          .join('、') ??
                                      '';
                                  return Text(
                                    '• ${g.name(tSeat)} 曾持有: [$cards]',
                                    style: const TextStyle(fontSize: 11),
                                  );
                                }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // My Hand & Action Panel
                  if (myHand.isNotEmpty)
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '🃏 你的手牌 (${myHand.length} 张):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                              if (canAct && activeCard.isNotEmpty && playable.contains(activeCard))
                                FilledButton(
                                  onPressed: () {
                                    g.act({
                                      'type': 'play',
                                      'card': activeCard,
                                      if (needsTarget && activeTarget >= 0) 'target': activeTarget,
                                    });
                                  },
                                  child: Text(
                                    needsTarget && activeTarget >= 0
                                        ? '⚡ 对 ${g.name(activeTarget)} 打出 ${cardTitle(activeCard)}'
                                        : '⚡ 打出 ${cardTitle(activeCard)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < myHand.length; i++)
                                Builder(builder: (context) {
                                  final ck = myHand[i];
                                  final isLegal = !canAct || playable.contains(ck);
                                  return ChoiceChip(
                                    label: Text(
                                      '${cardTitle(ck)}${isLegal ? "" : " (暂不可出)"}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: activeCard == ck,
                                    onSelected: isLegal
                                        ? (_) => setState(() => _selectedCard = ck)
                                        : null,
                                  );
                                }),
                            ],
                          ),
                          if (activeCard.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '📖 ${cardTitle(activeCard)}：${cardDesc(activeCard)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                          if (canAct && needsTarget) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('🎯 选择目标玩家:', style: TextStyle(fontSize: 11)),
                                for (final t in validTargets)
                                  ChoiceChip(
                                    label: Text(
                                      '${g.name(t)} (${t < handCounts.length ? handCounts[t] : 0}张)',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    selected: activeTarget == t,
                                    onSelected: (_) => setState(() => _selectedTarget = t),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Central Played Card Pile
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
                          '🗂️ 案发现场已出卡牌记录 (${playedPile.length} 张)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        if (playedPile.isEmpty)
                          const Text('尚无出牌记录，等待【🥇第一发现人】开启调查', style: TextStyle(fontSize: 11))
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final p in playedPile.reversed.take(10))
                                Builder(builder: (context) {
                                  final m = p as Map;
                                  final s = (m['seat'] as num).toInt();
                                  final c = '${m['card']}';
                                  final t = (m['target'] as num?)?.toInt();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${g.name(s)}: ${cardTitle(c)}${t != null ? " → ${g.name(t)}" : ""}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
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
                          active: turn == s && !g.over,
                          sub: '🃏${s < handCounts.length ? handCounts[s] : 0}张${accomplices.contains(s) ? "·🎭共犯" : ""} · ⭐${s < scores.length ? scores[s] : 0}分',
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
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '犯人在跳舞结束'),
            ),
        ],
      ),
    );
  }
}
