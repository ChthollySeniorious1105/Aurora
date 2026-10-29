import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _carNames = [
  '🟥 红车',
  '🟦 蓝车',
  '🟩 绿车',
  '🟨 黄车',
  '🟪 紫车',
  '⬛ 黑车',
];

class DownforceBoard extends StatefulWidget {
  final GameContext g;
  const DownforceBoard(this.g, {super.key});

  @override
  State<DownforceBoard> createState() => _DownforceBoardState();
}

class _DownforceBoardState extends State<DownforceBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final trackLen = (v['trackLen'] as num?)?.toInt() ?? 36;
    final chicanes = (v['chicanes'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [7, 15, 23, 31];
    final betLines = (v['betLines'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [9, 18, 27];
    final phase = v['phase'] as String? ?? 'auction';
    final auctionCar = (v['auctionCar'] as num?)?.toInt() ?? 0;
    final carOwner = (v['carOwner'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ??
        List<int?>.filled(6, null);
    final auctionCost = (v['auctionCost'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final carPos = (v['carPos'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [0, 0, 0, 0, 0, 0];
    final carLane = (v['carLane'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [0, 1, 0, 1, 0, 1];
    final standings = (v['standings'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [0, 1, 2, 3, 4, 5];
    final hand = (v['hand'] as List?) ?? const [];
    final betStage = (v['betStage'] as num?)?.toInt() ?? 0;
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final waitingFor = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final lastEvent = v['lastEvent'] as String? ?? '';

    final isMyTurn = waitingFor.contains(g.seat) && !g.over;
    final phaseTitle = phase == 'auction'
        ? '阶段一：百万美元赛车竞拍'
        : phase == 'bet'
            ? '阶段二：第 ${betStage + 1} 线秘密押注'
            : '阶段二：方程式多车推进竞速';

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
                          ? '极速方程式 — 大奖赛结束'
                          : '$phaseTitle · ${isMyTurn ? "轮到你行动" : "等待行动中"}',
                      highlight: isMyTurn,
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
                  // Phase 1: Auction Controls
                  if (phase == 'auction' && isMyTurn)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔨 当前竞拍赛车：${_carNames[auctionCar % 6]}（选择百万美元出价）：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (var m = 1; m <= 6; m++)
                                FilledButton.tonal(
                                  onPressed: () => g.act({'type': 'bid', 'amount': m}),
                                  child: Text('出价 \$${m}M'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // Phase 2: Betting Line Controls
                  if (phase == 'bet' && isMyTurn)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🏁 第 ${betStage + 1} 条押注线：请秘密押注最终跑进前三名的赛车：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (var c = 0; c < 6; c++)
                                FilledButton.tonal(
                                  onPressed: () => g.act({'type': 'bet', 'car': c}),
                                  child: Text('押注 ${_carNames[c]}'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // Phase 2: Speed Card Hand
                  if (phase == 'race' && hand.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMyTurn ? cs.primary : cs.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🃏 我的速度卡手牌（打出后卡上所有颜色赛车按速度从高到低依次推进）：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < hand.length; i++)
                                _buildSpeedCard(
                                  g,
                                  cs,
                                  i,
                                  hand[i] as Map,
                                  isMyTurn,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // 6 Race Cars Standings & Track Progress
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
                          '🏎️ 赛道实时排名（全长 $trackLen 格 · ⚠️单车道弯道瓶颈: $chicanes · 🏁押注线: $betLines）：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        for (var rank = 0; rank < standings.length; rank++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: _buildCarRow(
                              g: g,
                              cs: cs,
                              rank: rank + 1,
                              car: standings[rank],
                              pos: standings[rank] < carPos.length ? carPos[standings[rank]] : 0,
                              lane: standings[rank] < carLane.length ? carLane[standings[rank]] : 0,
                              owner: standings[rank] < carOwner.length ? carOwner[standings[rank]] : null,
                              trackLen: trackLen,
                              isChicane: chicanes.contains(
                                standings[rank] < carPos.length ? carPos[standings[rank]] : -1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Players & Winnings
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: waitingFor.contains(s) && !g.over
                                  ? cs.primary
                                  : cs.outline.withValues(alpha: 0.25),
                            ),
                          ),
                          child: g.tag(
                            s,
                            active: waitingFor.contains(s) && !g.over,
                            sub: '购车成本 \$${auctionCost[s]}M · 预估净收益 \$${scores[s]}M',
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

  Widget _buildSpeedCard(
    GameContext g,
    ColorScheme cs,
    int idx,
    Map cardMap,
    bool canPlay,
  ) {
    final entries = <MapEntry<int, int>>[];
    cardMap.forEach((k, v) {
      final c = int.tryParse('$k') ?? 0;
      final spd = (v as num).toInt();
      entries.add(MapEntry(c, spd));
    });
    entries.sort((a, b) => b.value.compareTo(a.value));

    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: canPlay ? cs.primary : cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '速度卡 #${idx + 1}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
          ),
          const SizedBox(height: 4),
          for (final e in entries)
            Text(
              '${_carNames[e.key % 6]} +${e.value}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
    if (!canPlay) return box;
    return InkWell(
      onTap: () => g.act({'type': 'play', 'cardIdx': idx}),
      borderRadius: BorderRadius.circular(10),
      child: box,
    );
  }

  Widget _buildCarRow({
    required GameContext g,
    required ColorScheme cs,
    required int rank,
    required int car,
    required int pos,
    required int lane,
    required int? owner,
    required int trackLen,
    required bool isChicane,
  }) {
    final ownerText = owner != null ? '车主: ${g.name(owner)}' : '待竞拍';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '第$rank名 ${_carNames[car % 6]}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            '位置: $pos/$trackLen (车道${lane + 1}${isChicane ? "·⚠️弯道瓶颈" : ""})',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.85)),
          ),
          Text(
            '[$ownerText]',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary),
          ),
        ],
      ),
    );
  }
}
