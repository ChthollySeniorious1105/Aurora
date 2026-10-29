import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro16/trekking_history.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TrekkingHistoryBoard extends StatefulWidget {
  final GameContext g;
  const TrekkingHistoryBoard(this.g, {super.key});

  @override
  State<TrekkingHistoryBoard> createState() => _TrekkingHistoryBoardState();
}

class _TrekkingHistoryBoardState extends State<TrekkingHistoryBoard> {
  int _useCrystals = 0;
  int? _inspectSeat;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final day = asInt(v['day'], 1);
    final maxDays = asInt(v['maxDays'], 3);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final market = (v['market'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat = (_inspectSeat != null && _inspectSeat! < pList.length)
        ? _inspectSeat!
        : mySeat;
    final isMyTurn = !over && g.seat == turn;

    final myData = (pList.isNotEmpty && mySeat < pList.length)
        ? (pList[mySeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final viewData = (pList.isNotEmpty && viewSeat < pList.length)
        ? (pList[viewSeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final myCrystals = asInt(myData['crystals'], 0);
    if (_useCrystals > myCrystals) _useCrystals = myCrystals;

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: StatusBar(
                            over
                                ? '游戏结束 · $lastAction'
                                : (isMyTurn
                                    ? '轮到你！你处于怀表最末位，请探访历史事件顺延年代旅程 · $lastAction'
                                    : '等待 ${g.name(turn)} 行动 · $lastAction'),
                            highlight: isMyTurn,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '⏱️第 $day/$maxDays 日',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, s) {
                        final pd = (pList[s] as Map).cast<String, dynamic>();
                        final sc = asInt(pd['score'], 0);
                        final hr = asInt(pd['hourPos'], 0);
                        final tLen = asInt(pd['trekLen'], 0);
                        final cry = asInt(pd['crystals'], 0);
                        final selected = s == viewSeat;
                        return GestureDetector(
                          onTap: () => setState(() => _inspectSeat = s),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: selected
                                  ? Border.all(
                                      color: Colors.amberAccent, width: 2)
                                  : null,
                            ),
                            child: g.tag(
                              s,
                              active: s == turn,
                              sub: '⭐$sc分 · ⏱️$hr/12时 · 🧭连$tLen · 💎$cry',
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildTimeRiverPanel(
                                  market,
                                  myData,
                                  myCrystals,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: _buildPocketWatchAndTrekPanel(
                                  viewSeat,
                                  viewData,
                                  pList,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildTimeRiverPanel(
                                  market,
                                  myData,
                                  myCrystals,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 5,
                                child: _buildPocketWatchAndTrekPanel(
                                  viewSeat,
                                  viewData,
                                  pList,
                                  cs,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
          if (over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '穿越历史终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeRiverPanel(
    List<dynamic> market,
    Map<String, dynamic> myData,
    int myCrystals,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final lastYear = myData['currentTrekLastYear'] as int?;
    final lastYearLabel = lastYear == null
        ? '无 (新旅程起点)'
        : (lastYear < 0 ? '公元前 ${-lastYear} 年' : '公元 $lastYear 年');

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '🌊 历史长河 (当前旅程末站: $lastYearLabel)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              if (myCrystals > 0)
                GestureDetector(
                  onTap: () => setState(() {
                    _useCrystals = (_useCrystals + 1) % (myCrystals + 1);
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _useCrystals > 0
                          ? Colors.cyan.withValues(alpha: 0.25)
                          : cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyan),
                    ),
                    child: Text(
                      '💎本次消耗水晶: $_useCrystals/$myCrystals',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 175,
                mainAxisExtent: 74,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: market.length + 1,
              itemBuilder: (context, idx) {
                if (idx == market.length) {
                  // Ancestor slot (-1)
                  return GestureDetector(
                    onTap: !isMyTurn
                        ? null
                        : () {
                            final useC = _useCrystals.clamp(0, 2);
                            setState(() => _useCrystals = 0);
                            widget.g.act({
                              'type': 'visit',
                              'slot': -1,
                              'useCrystals': useC,
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: cs.tertiary, width: isMyTurn ? 1.5 : 1),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🧭 远古先祖足迹 (百搭年代)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            Text(
                              '⏱️耗时 3 小时 · 奖励 🌟百搭',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              '✓ 永不打断当前连续旅程',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final c = (market[idx] as Map).cast<String, dynamic>();
                final yr = asInt(c['year'], 0);
                final continues = lastYear == null || yr >= lastYear;

                return GestureDetector(
                  onTap: !isMyTurn
                      ? null
                      : () {
                          final hrs = asInt(c['hours'], 1);
                          final useC = _useCrystals.clamp(0, hrs - 1);
                          setState(() => _useCrystals = 0);
                          widget.g.act({
                            'type': 'visit',
                            'slot': idx,
                            'useCrystals': useC,
                          });
                        },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: continues
                          ? cs.primaryContainer.withValues(alpha: 0.75)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: continues
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.35),
                        width: continues && isMyTurn ? 1.8 : 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${c['emoji']} ${c['title']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          Text(
                            '📅 ${c['yearLabel']} · ⏱️${c['hours']}小时',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '标记: ${c['tokensLabel']} · ${continues ? "✓顺延旅程" : "↻结算重开"}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: continues
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPocketWatchAndTrekPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    List<dynamic> pList,
    ColorScheme cs,
  ) {
    final trekLen = asInt(viewData['trekLen'], 0);
    final activeTrekVp = asInt(viewData['activeTrekVp'], 0);
    final completedTrekVp = asInt(viewData['completedTrekVp'], 0);
    final itineraryVp = asInt(viewData['itineraryVp'], 0);
    final punctualityVp = asInt(viewData['punctualityVp'], 0);
    final itinerary = (viewData['itinerary'] as List?) ?? const [0, 0, 0, 0, 0];
    final lastYr = viewData['currentTrekLastYear'] as int?;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '⌚ 12小时怀表时间轴 (精准抵达12时得 +3分!):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                for (var h = 0; h <= 12; h++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: h == 12
                            ? Colors.amber.withValues(alpha: 0.35)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: h == 12
                              ? Colors.amber
                              : cs.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$h',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              [
                                for (var s = 0; s < pList.length; s++)
                                  if (asInt((pList[s] as Map)['hourPos'], 0) ==
                                      h)
                                    'P${s + 1}'
                              ].join(','),
                              style: TextStyle(
                                fontSize: 9,
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🧭 ${widget.g.name(viewSeat)} 的时空档案:',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• 当前连续旅程: $trekLen 张 ($activeTrekVp分) · 末站年代: ${lastYr == null ? "无" : (lastYr < 0 ? "前${-lastYr}年" : "$lastYr年")}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• 旅程计分表: 1~8张 = 0 / 1 / 3 / 6 / 10 / 15 / 21 / 28 分',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• 已完成旅程分: $completedTrekVp 分 | 行程表分: $itineraryVp 分 | 守时奖: $punctualityVp 分',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('• 行程表体验标记: ',
                          style: TextStyle(fontSize: 12)),
                      for (var i = 0;
                          i < trekkingTokenEmojis.length &&
                              i < itinerary.length;
                          i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${trekkingTokenEmojis[i]}${trekkingTokenNames[i]}×${itinerary[i]}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
