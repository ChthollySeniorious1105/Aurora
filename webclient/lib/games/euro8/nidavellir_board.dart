import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _classNames = ['铁匠', '猎人', '战士', '矿工', '探险家'];
const List<String> _classIcons = ['🔨', '🏹', '⚔️', '⛏️', '🧭'];
const List<Color> _classColors = [
  Color(0xFF7B1FA2), // 铁匠 purple
  Color(0xFF2E7D32), // 猎人 green
  Color(0xFFC62828), // 战士 red
  Color(0xFFEF6C00), // 矿工 orange
  Color(0xFF1565C0), // 探险家 blue
];

const List<String> _tavernNames = ['欢笑酒馆', '跃马酒馆', '闪耀酒馆'];
const List<String> _tavernIcons = ['🍺', '🐎', '✨'];

class NidavellirBoard extends StatefulWidget {
  final GameContext g;
  const NidavellirBoard(this.g, {super.key});

  @override
  State<NidavellirBoard> createState() => _NidavellirBoardState();
}

class _NidavellirBoardState extends State<NidavellirBoard> {
  // Indices (0..4) into my 5 coins selected for tavern 0, 1, 2
  List<int> _selectedCoinIndices = [0, 1, 2];
  int? _viewSeat;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 6;
    final phase = (v['phase'] as String?) ?? 'bid';
    final currentTavern = (v['currentTavern'] as num?)?.toInt() ?? 0;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final lastAction = (v['lastAction'] as String?) ?? '';

    final taverns = (v['taverns'] as List?)?.cast<Map>() ?? const [];
    final availableHeroes = (v['availableHeroes'] as List?)?.cast<Map>() ?? const [];
    final playersData = (v['playersData'] as List?)?.cast<Map>() ?? const [];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List<int>.filled(g.players, 0);

    final activeSeat = g.seat >= 0 ? g.seat : 0;
    final inspectedSeat = (_viewSeat != null && _viewSeat! < g.players) ? _viewSeat! : activeSeat;
    final myData = g.seat >= 0 && g.seat < playersData.length ? playersData[g.seat] : null;
    final myHasBid = myData?['hasBid'] == true;
    final myCoins = (myData?['coins'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 2, 3, 4, 5];

    final isMyBidTurn = !over && phase == 'bid' && g.seat >= 0 && !myHasBid;
    final isMyDraftTurn = !over && phase == 'draft' && g.seat >= 0 && g.seat == turn;
    final isMyHeroTurn = !over && phase == 'recruit_hero' && g.seat >= 0 && g.seat == turn;

    String statusText() {
      if (over) return '尼达维利亚 已结束';
      if (phase == 'bid') {
        return isMyBidTurn ? '请为三座酒馆各部署 1 枚硬币' : '等待其他特使部署酒馆硬币…';
      }
      if (phase == 'recruit_hero') {
        return isMyHeroTurn ? '集齐五兵种！请招募 1 位传奇英雄' : '等待 ${g.name(turn)} 招募传奇英雄…';
      }
      return isMyDraftTurn
          ? '轮到你在【${_tavernNames[currentTavern]}】招募矮人'
          : '【${_tavernNames[currentTavern]}】等待 ${g.name(turn)} 招募矮人…';
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(statusText(), highlight: isMyBidTurn || isMyDraftTurn || isMyHeroTurn),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('第 $round / $maxRounds 轮 · 纪元 ${round <= maxRounds ~/ 2 ? "I" : "II"}'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      Builder(builder: (context) {
                        final pd = s < playersData.length ? playersData[s] : const {};
                        final gem = (pd['gem'] as num?)?.toInt() ?? 1;
                        final sc = (pd['score'] as num?)?.toInt() ?? 0;
                        final pCoins = (pd['coins'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
                        return GestureDetector(
                          onTap: () => setState(() => _viewSeat = s),
                          child: g.tag(
                            s,
                            active: !over &&
                                ((phase == 'bid' && pd['hasBid'] != true) || (phase != 'bid' && s == turn)),
                            sub: '$sc分 · 💎$gem · 🪙[${pCoins.join(",")}]',
                            size: 30,
                          ),
                        );
                      }),
                  ],
                ),
              ),
              if (lastAction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Text(
                    lastAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isMyBidTurn) _buildBidPanel(cs, g, myCoins),
                      if (isMyHeroTurn) _buildHeroRecruitPanel(cs, g, availableHeroes),
                      const SizedBox(height: 8),
                      _buildTavernsPanel(cs, g, taverns, phase, currentTavern, isMyDraftTurn, playersData),
                      const SizedBox(height: 8),
                      if (inspectedSeat < playersData.length)
                        _buildArmyPanel(cs, g, inspectedSeat, playersData[inspectedSeat]),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (over && v['result'] != null)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(g, scores),
            ),
        ],
      ),
    );
  }

  Widget _buildBidPanel(ColorScheme cs, GameContext g, List<int> myCoins) {
    if (_selectedCoinIndices.length != 3 ||
        _selectedCoinIndices.toSet().length != 3 ||
        _selectedCoinIndices.any((i) => i < 0 || i >= myCoins.length)) {
      _selectedCoinIndices = [0, 1, 2];
    }
    final pouchIndices = [
      for (var i = 0; i < myCoins.length; i++)
        if (!_selectedCoinIndices.contains(i)) i,
    ];
    final pouchVals = [for (final i in pouchIndices) myCoins[i]]..sort();
    final hasZeroInTavern = _selectedCoinIndices.any((i) => myCoins[i] == 0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🪙 硬币部署阶段 — 为三座酒馆各分配 1 枚硬币（其余 2 枚留在皇家钱袋）：',
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
          ),
          const SizedBox(height: 8),
          for (var t = 0; t < 3; t++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    child: Text('${_tavernIcons[t]} ${_tavernNames[t]}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  for (var cIdx = 0; cIdx < myCoins.length; cIdx++)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${myCoins[cIdx]}币'),
                      selected: _selectedCoinIndices[t] == cIdx,
                      onSelected: (_) {
                        setState(() {
                          final existingTavern = _selectedCoinIndices.indexOf(cIdx);
                          if (existingTavern >= 0 && existingTavern != t) {
                            // Swap between the two taverns
                            final prev = _selectedCoinIndices[t];
                            _selectedCoinIndices[t] = cIdx;
                            _selectedCoinIndices[existingTavern] = prev;
                          } else {
                            _selectedCoinIndices[t] = cIdx;
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '💰 皇家钱袋硬币: [${pouchVals.join(", ")}]${hasZeroInTavern && pouchVals.length == 2 ? " → 0币锻造将把 ${pouchVals[1]} 升级为 ${min(25, pouchVals[0] + pouchVals[1])}！" : ""}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.gavel, size: 16),
                label: const Text('确认出价'),
                onPressed: () {
                  final chosen = [for (final idx in _selectedCoinIndices) myCoins[idx]];
                  g.act({'type': 'bid', 'coins': chosen});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroRecruitPanel(ColorScheme cs, GameContext g, List<Map> availableHeroes) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👑 集齐五兵种横排！请立即招募 1 位传奇英雄：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in availableHeroes)
                InkWell(
                  onTap: () => g.act({'type': 'recruit_hero', 'heroId': (h['id'] as num).toInt()}),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 175,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${h['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('${h['desc']}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTavernsPanel(
    ColorScheme cs,
    GameContext g,
    List<Map> taverns,
    String phase,
    int currentTavern,
    bool isMyDraftTurn,
    List<Map> playersData,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🍺 尼达维利亚三大酒馆', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
          const SizedBox(height: 6),
          for (var t = 0; t < taverns.length; t++)
            Builder(builder: (context) {
              final tav = taverns[t];
              final cards = (tav['cards'] as List?)?.cast<Map>() ?? const [];
              final isActiveTavern = phase == 'draft' && currentTavern == t;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActiveTavern
                      ? cs.primaryContainer.withValues(alpha: 0.35)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActiveTavern ? cs.primary : cs.outline.withValues(alpha: 0.3),
                    width: isActiveTavern ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${_tavernIcons[t]} ${_tavernNames[t]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (phase != 'bid')
                          for (var s = 0; s < playersData.length; s++)
                            Builder(builder: (context) {
                              final bids = (playersData[s]['bids'] as List?)?.map((e) => (e as num).toInt()).toList();
                              if (bids == null || t >= bids.length) return const SizedBox.shrink();
                              return Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('${g.name(s)}: ${bids[t]}币', style: const TextStyle(fontSize: 11)),
                              );
                            }),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (cards.isEmpty)
                      Text('本酒馆矮人已全部招募完毕', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (var idx = 0; idx < cards.length; idx++)
                            _buildDwarfCard(
                              cs,
                              cards[idx],
                              canPick: isMyDraftTurn && isActiveTavern,
                              onTap: () => g.act({'type': 'draft', 'index': idx}),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDwarfCard(ColorScheme cs, Map card, {required bool canPick, required VoidCallback onTap}) {
    final classId = (card['classId'] as num?)?.toInt() ?? 0;
    final name = (card['name'] as String?) ?? '';
    final badges = (card['badges'] as num?)?.toInt() ?? 1;
    final rankSum = (card['rankSum'] as num?)?.toInt() ?? 0;
    final coinUp = (card['coinUpgrade'] as num?)?.toInt() ?? 0;
    final color = _classColors[classId % 5];

    return InkWell(
      onTap: canPick ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: canPick ? Colors.amberAccent : Colors.white.withValues(alpha: 0.5),
            width: canPick ? 2.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_classIcons[classId % 5]} $name',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              '徽章×$badges${rankSum > 0 ? " · 点数$rankSum" : ""}${coinUp > 0 ? " · 🪙+$coinUp" : ""}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArmyPanel(ColorScheme cs, GameContext g, int seat, Map pData) {
    final badges = (pData['badges'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List<int>.filled(5, 0);
    final classScores = (pData['classScores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List<int>.filled(5, 0);
    final heroes = (pData['heroes'] as List?)?.cast<Map>() ?? const [];
    final coins = (pData['coins'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${g.name(seat)} 的矮人军团 (🪙硬币: ${coins.join(", ")})',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
              ),
              Wrap(
                spacing: 4,
                children: [
                  for (var s = 0; s < g.players; s++)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(g.name(s), style: const TextStyle(fontSize: 11)),
                      selected: seat == s,
                      onSelected: (_) => setState(() => _viewSeat = s),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var c = 0; c < 5; c++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _classColors[c].withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _classColors[c]),
                  ),
                  child: Text(
                    '${_classIcons[c]} ${_classNames[c]}: ${badges[c]}徽章 (${classScores[c]}分)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (heroes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '👑 已招募英雄: ${heroes.map((h) => h["name"]).join("、")}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultBanner(GameContext g, List<int> scores) {
    final maxScore = scores.reduce(max);
    final winners = [for (var s = 0; s < g.players; s++) if (scores[s] == maxScore) g.name(s)];
    return ResultBanner(
      '${winners.join("、")} 击败法夫纳获胜！($maxScore 分)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var s = 0; s < g.players; s++)
            Text('${g.name(s)}: ${scores[s]} 分'),
        ],
      ),
    );
  }
}
