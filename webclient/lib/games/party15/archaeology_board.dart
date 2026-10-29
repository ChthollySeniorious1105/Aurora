import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _archNames = [
  '🏺 陶片',
  '🪙 古币',
  '🪬 护身符',
  '🏆 圣杯',
  '📜 莎草纸',
  '👑 法老面具',
  '🗺️ 藏宝图',
];

const List<int> _archTradeVals = [1, 2, 3, 4, 4, 5, 3];

const List<String> _archSetPriceTips = [
  '1/2/3/4/5 G',
  '2/5/10/18/30 G',
  '3/7/14/24/40 G',
  '4/10/20/35 G',
  '5/12/24/42 G',
  '6/16/32 G',
  '用于探索金字塔',
];

class ArchaeologyBoard extends StatefulWidget {
  final GameContext g;
  const ArchaeologyBoard(this.g, {super.key});

  @override
  State<ArchaeologyBoard> createState() => _ArchaeologyBoardState();
}

class _ArchaeologyBoardState extends State<ArchaeologyBoard> {
  final Set<int> _selHandIndices = {};
  final Set<int> _selMarketIndices = {};

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = v['phase'] as String? ?? 'action';
    final digCount = (v['digCount'] as num?)?.toInt() ?? 0;
    final market = (v['market'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final pyramidCounts = (v['pyramidCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [3, 5, 7];
    final hands = (v['hands'] as List?) ?? const [];
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final museum = (v['museum'] as List?) ?? const [];
    final gold = (v['gold'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final sandstormRemaining =
        (v['sandstormRemaining'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List<int>.filled(g.players, 0);
    final lastEvent = v['lastEvent'] as String? ?? '';

    final mySeat = g.seat >= 0 && g.seat < g.players ? g.seat : 0;
    final myHand = mySeat < hands.length
        ? (hands[mySeat] as List).map((e) => (e as num).toInt()).toList()
        : const <int>[];
    final isMyTurn = g.seat == turn && !g.over;
    final needSandstorm = g.seat >= 0 &&
        g.seat < sandstormRemaining.length &&
        phase == 'sandstorm' &&
        sandstormRemaining[g.seat] > 0;

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
                          ? '沙漠考古队 — 探险结束'
                          : needSandstorm
                              ? '🌪️ 沙尘暴！请弃置 ${sandstormRemaining[g.seat]} 张手牌到集市'
                              : (isMyTurn ? '轮到你行动（$phase）' : '等待 ${g.name(turn)} 行动'),
                      highlight: isMyTurn || needSandstorm,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Dig Site, Pyramid & Marketplace
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            _badge(cs, '⛏️ 挖掘场剩余: $digCount 张'),
                            for (var ch = 0; ch < pyramidCounts.length; ch++)
                              _pyramidButton(g, cs, ch, pyramidCounts[ch], myHand, isMyTurn && phase == 'action'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '⛺ 中央集市 (${market.length} 张) — 点击勾选可与手牌等价交换：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        if (market.isEmpty)
                          Text('集市暂无文物', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)))
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < market.length; i++)
                                _artifactChip(
                                  cs,
                                  market[i],
                                  selected: _selMarketIndices.contains(i),
                                  onTap: isMyTurn && phase == 'action'
                                      ? () => setState(() {
                                            if (_selMarketIndices.contains(i)) {
                                              _selMarketIndices.remove(i);
                                            } else {
                                              _selMarketIndices.add(i);
                                            }
                                          })
                                      : null,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // My Hand & Actions
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎒 我的手牌 (${myHand.length} 张)：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        if (myHand.isEmpty)
                          Text('暂无手牌', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)))
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < myHand.length; i++)
                                _artifactChip(
                                  cs,
                                  myHand[i],
                                  selected: _selHandIndices.contains(i),
                                  onTap: () => setState(() {
                                    if (_selHandIndices.contains(i)) {
                                      _selHandIndices.remove(i);
                                    } else {
                                      _selHandIndices.add(i);
                                    }
                                  }),
                                ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        if (needSandstorm)
                          FilledButton.icon(
                            onPressed: () {
                              final cards = [
                                for (final i in _selHandIndices)
                                  if (i < myHand.length) myHand[i],
                              ];
                              g.act({
                                'type': 'sandstorm',
                                if (cards.isNotEmpty) 'cards': cards,
                              });
                              setState(_selHandIndices.clear);
                            },
                            icon: const Icon(Icons.air, size: 16),
                            label: Text('确认向集市弃置 (${sandstormRemaining[g.seat]} 张)'),
                          ),
                        if (isMyTurn && phase == 'thief')
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              const Text('🥷 选择偷取目标：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              for (var s = 0; s < g.players; s++)
                                if (s != g.seat && handCounts[s] > 0)
                                  FilledButton.tonal(
                                    onPressed: () => g.act({'type': 'thief', 'target': s}),
                                    child: Text('偷取 ${g.name(s)} (${handCounts[s]}张)'),
                                  ),
                            ],
                          ),
                        if (isMyTurn && phase == 'action')
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _selHandIndices.isNotEmpty && _selMarketIndices.isNotEmpty
                                    ? () {
                                        final give = [
                                          for (final i in _selHandIndices)
                                            if (i < myHand.length) myHand[i],
                                        ];
                                        final take = [
                                          for (final i in _selMarketIndices)
                                            if (i < market.length) market[i],
                                        ];
                                        g.act({'type': 'trade', 'give': give, 'take': take});
                                        setState(() {
                                          _selHandIndices.clear();
                                          _selMarketIndices.clear();
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.swap_horiz, size: 16),
                                label: const Text('集市交易'),
                              ),
                              for (var art = 0; art < 6; art++)
                                if (myHand.any((c) => c == art))
                                  OutlinedButton(
                                    onPressed: () {
                                      setState(_selHandIndices.clear);
                                      g.act({'type': 'sell', 'artifact': art});
                                    },
                                    child: Text(
                                      '出售 ${_archNames[art]} ×${myHand.where((c) => c == art).length}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selHandIndices.clear();
                                    _selMarketIndices.clear();
                                  });
                                  g.act({'type': 'end_turn'});
                                },
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('结束回合'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Players & Museum Sets
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: turn == s && !g.over ? cs.primary : cs.outline.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              g.tag(
                                s,
                                active: turn == s && !g.over,
                                sub: '💰 ${gold[s]} 金币 · 手牌 ${handCounts[s]} 张',
                              ),
                              if (s < museum.length) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '已展出: ${_museumSummary(museum[s] as List)}',
                                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.75)),
                                ),
                              ],
                            ],
                          ),
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

  String _museumSummary(List counts) {
    final parts = <String>[];
    for (var i = 0; i < counts.length && i < 6; i++) {
      final c = (counts[i] as num).toInt();
      if (c > 0) parts.add('${_archNames[i]}×$c');
    }
    return parts.isEmpty ? '暂无' : parts.join(' ');
  }

  Widget _badge(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
    );
  }

  Widget _pyramidButton(GameContext g, ColorScheme cs, int ch, int count, List<int> myHand, bool canAct) {
    final mapNeed = ch + 1;
    final myMaps = myHand.where((c) => c == 6).length;
    final enabled = canAct && count > 0 && myMaps >= mapNeed;
    return OutlinedButton.icon(
      onPressed: enabled ? () => g.act({'type': 'pyramid', 'chamber': ch}) : null,
      icon: const Icon(Icons.change_history, size: 15),
      label: Text(
        '金字塔密室${ch + 1} ($mapNeed图→$count宝)',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _artifactChip(ColorScheme cs, int type, {bool selected = false, VoidCallback? onTap}) {
    final safeType = type.clamp(0, _archNames.length - 1);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? cs.primary : cs.outline.withValues(alpha: 0.35),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_archNames[safeType]} (价值${_archTradeVals[safeType]})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: selected ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
          Text(
            _archSetPriceTips[safeType],
            style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(onTap: onTap, child: chip);
  }
}
