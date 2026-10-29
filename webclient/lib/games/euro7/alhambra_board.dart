import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro7/alhambra.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _currencyColors = [
  Color(0xFF2B6CB0), // 0: 蓝弗罗林
  Color(0xFF2F855A), // 1: 绿迪拉姆
  Color(0xFFDD6B20), // 2: 橙第纳尔
  Color(0xFFD69E2E), // 3: 黄杜卡特
];

const List<Color> _buildingColors = [
  Color(0xFF3182CE), // 0: 亭阁
  Color(0xFFC53030), // 1: 后宫
  Color(0xFF8B5A2B), // 2: 拱廊
  Color(0xFF718096), // 3: 寝宫
  Color(0xFF38A169), // 4: 花园
  Color(0xFF805AD5), // 5: 塔楼
];

class AlhambraBoard extends StatefulWidget {
  final GameContext g;
  const AlhambraBoard(this.g, {super.key});

  @override
  State<AlhambraBoard> createState() => _AlhambraBoardState();
}

class _AlhambraBoardState extends State<AlhambraBoard> {
  final Set<int> _selectedMarketMoney = {};
  final Set<int> _selectedHandCards = {};
  int? _selectedTileSlot;
  String _stateKey = '';

  String _wallsText(int mask) {
    final dirs = <String>[];
    if ((mask & 1) != 0) dirs.add('北');
    if ((mask & 2) != 0) dirs.add('东');
    if ((mask & 4) != 0) dirs.add('南');
    if ((mask & 8) != 0) dirs.add('西');
    return dirs.isEmpty ? '无墙' : '${dirs.join('')}墙';
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = asInt(v['turn'], 0);
    final round = asInt(v['round'], 1);
    final bonusAction = v['bonusAction'] == true;
    final scoringDone = asInt(v['scoringRoundsDone'], 0);
    final totalScoring = asInt(v['totalScoringRounds'], 3);
    final tileDeckCount = asInt(v['tileDeckCount'], 0);
    final lastLog = asStr(v['lastLog']);

    final moneyMarket = [
      for (final m in (v['moneyMarket'] as List? ?? const [])) (m as Map).cast<String, dynamic>(),
    ];
    final tileMarket = [
      for (final t in (v['tileMarket'] as List? ?? const []))
        t is Map ? t.cast<String, dynamic>() : null,
    ];
    final hand = [
      for (final m in (v['hand'] as List? ?? const [])) (m as Map).cast<String, dynamic>(),
    ];
    final playersList = [
      for (final p in (v['players'] as List? ?? const [])) (p as Map).cast<String, dynamic>(),
    ];

    final isMyTurn = !g.over && !g.replay && g.seat == turn;
    final curKey = '$round-$turn-$bonusAction-${moneyMarket.length}-${hand.length}-$tileDeckCount';
    if (_stateKey != curKey) {
      _stateKey = curKey;
      _selectedMarketMoney.clear();
      _selectedHandCards.clear();
      _selectedTileSlot = null;
    }

    String statusText;
    if (g.over) {
      statusText = lastLog.isNotEmpty ? lastLog : '游戏结束';
    } else if (isMyTurn) {
      statusText = bonusAction
          ? '精准支付奖励！你可以再执行 1 次行动（拿取货币或购买建筑）'
          : '轮到你行动：拿取货币（1张任意，或多张总和≤5）或用同色货币购买建筑';
    } else {
      statusText = '第 $round 轮 · 等待 ${g.name(turn)} 行动（计分轮 $scoringDone/$totalScoring · 剩余建筑 $tileDeckCount）';
    }

    final selectedMarketSum = _selectedMarketMoney.fold<int>(
      0,
      (s, i) => s + (i >= 0 && i < moneyMarket.length ? asInt(moneyMarket[i]['value'], 0) : 0),
    );
    final canTakeMoney = isMyTurn &&
        _selectedMarketMoney.isNotEmpty &&
        (_selectedMarketMoney.length == 1 || selectedMarketSum <= 5);

    int? selectedHandCurrency;
    var selectedHandSum = 0;
    var handCurrencyUniform = true;
    for (final idx in _selectedHandCards) {
      if (idx >= 0 && idx < hand.length) {
        final c = asInt(hand[idx]['currency'], 0);
        final val = asInt(hand[idx]['value'], 0);
        if (selectedHandCurrency == null) {
          selectedHandCurrency = c;
        } else if (selectedHandCurrency != c) {
          handCurrencyUniform = false;
        }
        selectedHandSum += val;
      }
    }

    final slotForBuy = _selectedTileSlot ?? selectedHandCurrency;
    final targetTile = (slotForBuy != null && slotForBuy >= 0 && slotForBuy < tileMarket.length)
        ? tileMarket[slotForBuy]
        : null;
    final targetCost = targetTile != null ? asInt(targetTile['cost'], 99) : 99;
    final canBuyTile = isMyTurn &&
        slotForBuy != null &&
        targetTile != null &&
        _selectedHandCards.isNotEmpty &&
        handCurrencyUniform &&
        selectedHandCurrency == slotForBuy &&
        selectedHandSum >= targetCost;
    final isExactBuy = canBuyTile && selectedHandSum == targetCost;

    Widget? banner;
    if (g.over) {
      final res = (v['result'] as Map?)?.cast<String, dynamic>();
      final scores = res != null ? asIntList(res['scores']) : <int>[];
      final pl = res != null ? asIntList(res['placings']) : <int>[];
      final winners = [
        for (var s = 0; s < pl.length; s++)
          if (pl[s] == 1) g.name(s),
      ];
      banner = ResultBanner(
        winners.isEmpty ? '游戏结束' : '${winners.join('、')} 获胜！',
        child: scores.isEmpty
            ? null
            : Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (var s = 0; s < scores.length; s++)
                    Text('${g.name(s)}: ${scores[s]} 分', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600 || constraints.maxHeight < 480;
        return Stack(
          children: [
            Container(
              color: g.table,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: StatusBar(statusText, highlight: isMyTurn)),
                    const SizedBox(height: 6),
                    // Players & Palace summary
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final p in playersList)
                          Builder(builder: (_) {
                            final s = asInt(p['seat'], 0);
                            final sc = asInt(p['score'], 0);
                            final w = asInt(p['walls'], 0);
                            final hc = asInt(p['handCount'], 0);
                            final blds = asIntList(p['buildings']);
                            final bldSummary = [
                              for (var t = 0; t < blds.length && t < kAlhambraBuildings.length; t++)
                                if (blds[t] > 0) '${kAlhambraBuildings[t].substring(0, 1)}${blds[t]}',
                            ].join(' ');
                            return g.tag(
                              s,
                              active: !g.over && turn == s,
                              size: compact ? 28 : 32,
                              sub: '$sc分 · 墙$w · 手$hc${bldSummary.isNotEmpty ? ' · $bldSummary' : ''}',
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Money Market & Building Tile Market
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '中央货币市场（点选1张任意面值，或多张面值总和≤5）',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                              ),
                              if (canTakeMoney)
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    g.act({
                                      'type': 'take_money',
                                      'indices': _selectedMarketMoney.toList(),
                                    });
                                    setState(() => _selectedMarketMoney.clear());
                                  },
                                  icon: const Icon(Icons.payments_outlined, size: 15),
                                  label: Text('拿取货币 (总和$selectedMarketSum)'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < moneyMarket.length; i++)
                                Builder(builder: (_) {
                                  final c = asInt(moneyMarket[i]['currency'], 0).clamp(0, 3);
                                  final val = asInt(moneyMarket[i]['value'], 1);
                                  final sel = _selectedMarketMoney.contains(i);
                                  final col = _currencyColors[c];
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: isMyTurn
                                        ? () {
                                            setState(() {
                                              if (sel) {
                                                _selectedMarketMoney.remove(i);
                                              } else {
                                                _selectedMarketMoney.add(i);
                                              }
                                            });
                                          }
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 140),
                                      width: compact ? 80 : 96,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: col.withValues(alpha: sel ? 0.38 : 0.18),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: sel ? Colors.amberAccent : col,
                                          width: sel ? 2.2 : 1.2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              kAlhambraCurrencies[c],
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Text(
                                            '$val',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: col,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '宫殿建筑市场（按槽位对应货币购买，精准支付可额外行动！）',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var slot = 0; slot < 4; slot++)
                                Builder(builder: (_) {
                                  final tile = slot < tileMarket.length ? tileMarket[slot] : null;
                                  final currCol = _currencyColors[slot];
                                  final isSelSlot = _selectedTileSlot == slot;
                                  if (tile == null) {
                                    return Container(
                                      width: compact ? 105 : 130,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: cs.surface.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: currCol.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '${kAlhambraCurrencies[slot]}\n（已售出）',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                                      ),
                                    );
                                  }
                                  final bType = asInt(tile['type'], 0).clamp(0, 5);
                                  final cost = asInt(tile['cost'], 0);
                                  final wallsMask = asInt(tile['walls'], 0);
                                  final wallCnt = asInt(tile['wallCount'], 0);
                                  final bCol = _buildingColors[bType];

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: isMyTurn
                                        ? () {
                                            setState(() {
                                              _selectedTileSlot = isSelSlot ? null : slot;
                                            });
                                          }
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: compact ? 105 : 130,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: bCol.withValues(alpha: isSelSlot ? 0.32 : 0.16),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelSlot ? Colors.amberAccent : currCol,
                                          width: isSelSlot ? 2.4 : 1.4,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    kAlhambraCurrencies[slot],
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: currCol,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: currCol,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '费用 $cost',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${kAlhambraBuildings[bType]} (+${bType + 1}系)',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_wallsText(wallsMask)} (+$wallCnt墙)',
                                            style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.78)),
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
                    // Hand & Buy controls
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '我的货币手牌（点选同色手牌支付建筑费用）',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                                ),
                              ),
                              if (canBuyTile)
                                FilledButton.icon(
                                  onPressed: () {
                                    g.act({
                                      'type': 'buy_tile',
                                      'slot': slotForBuy,
                                      'cards': _selectedHandCards.toList(),
                                    });
                                    setState(() {
                                      _selectedHandCards.clear();
                                      _selectedTileSlot = null;
                                    });
                                  },
                                  icon: Icon(isExactBuy ? Icons.auto_awesome : Icons.shopping_bag_outlined, size: 16),
                                  label: Text(
                                    isExactBuy
                                        ? '精准购买 ($selectedHandSum/$targetCost · 获额外行动!)'
                                        : '购买建筑 ($selectedHandSum/$targetCost)',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < hand.length; i++)
                                Builder(builder: (_) {
                                  final c = asInt(hand[i]['currency'], 0).clamp(0, 3);
                                  final val = asInt(hand[i]['value'], 1);
                                  final col = _currencyColors[c];
                                  final sel = _selectedHandCards.contains(i);
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: isMyTurn
                                        ? () {
                                            setState(() {
                                              if (sel) {
                                                _selectedHandCards.remove(i);
                                              } else {
                                                _selectedHandCards.add(i);
                                                _selectedTileSlot ??= c;
                                              }
                                            });
                                          }
                                        : null,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 140),
                                      width: 74,
                                      transform: Matrix4.translationValues(0, sel ? -5 : 0, 0),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: col.withValues(alpha: sel ? 0.36 : 0.16),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: sel ? Colors.amberAccent : col,
                                          width: sel ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              kAlhambraCurrencies[c],
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Text(
                                            '$val',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: col,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              if (hand.isEmpty)
                                Text('（无货币手牌）', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (banner != null) Align(alignment: Alignment.topCenter, child: banner),
          ],
        );
      },
    );
  }
}
