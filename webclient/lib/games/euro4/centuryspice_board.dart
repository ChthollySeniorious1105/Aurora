import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CenturySpiceBoard extends StatefulWidget {
  final GameContext g;
  const CenturySpiceBoard(this.g, {super.key});

  @override
  State<CenturySpiceBoard> createState() => _CenturySpiceBoardState();
}

class _CenturySpiceBoardState extends State<CenturySpiceBoard> {
  int? _selectedHandIdx;
  final List<int> _upgradeSteps = [];
  int _tradeTimes = 1;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static const List<Color> _spiceColors = [
    Color(0xFFFBC02D), // 0: 姜黄 Yellow
    Color(0xFFE53935), // 1: 藏红花 Red
    Color(0xFF43A047), // 2: 小豆蔻 Green
    Color(0xFF6D4C41), // 3: 肉桂 Brown
  ];

  static const List<String> _spiceLabels = ['黄', '红', '绿', '褐'];

  bool _canAfford(List<int> have, List<int> cost, [int times = 1]) {
    for (var i = 0; i < 4; i++) {
      if (have[i] < cost[i] * times) return false;
    }
    return true;
  }

  List<int> _intList4(Object? raw) {
    if (raw is List && raw.length >= 4) {
      return [for (var i = 0; i < 4; i++) (raw[i] as num).toInt()];
    }
    return const [0, 0, 0, 0];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final lastRound = v['lastRound'] == true;
    final targetOrders = (v['targetOrders'] as num?)?.toInt() ?? 5;
    final goldRem = (v['goldRemaining'] as num?)?.toInt() ?? 0;
    final silverRem = (v['silverRemaining'] as num?)?.toInt() ?? 0;
    final lastAction = '${v['lastAction'] ?? ''}';

    final orders = (v['orders'] as List?) ?? const [];
    final market = (v['market'] as List?) ?? const [];
    final myHand = (v['myHand'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final isMyTurn = !g.over && g.seat >= 0 && g.seat == turn;

    List<int> mySpices = const [0, 0, 0, 0];
    int myTotalSpices = 0;
    List myPlayed = const [];
    if (g.seat >= 0 && g.seat < pList.length) {
      final mp = pList[g.seat] as Map;
      mySpices = _intList4(mp['spices']);
      myTotalSpices = (mp['totalSpices'] as num?)?.toInt() ?? 0;
      myPlayed = (mp['played'] as List?) ?? const [];
    }

    if (_selectedHandIdx != null && _selectedHandIdx! >= myHand.length) {
      _selectedHandIdx = null;
      _upgradeSteps.clear();
    }

    final statusText = g.over
        ? '游戏结束'
        : (isMyTurn
            ? '第 $round 轮${lastRound ? "（终局轮）" : ""}：轮到你行动（出牌 / 招募 / 休整 / 完成订单）'
            : '第 $round 轮${lastRound ? "（终局轮）" : ""}：等待 ${g.name(turn)} 行动');

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBar(statusText, highlight: isMyTurn),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _badge(cs, '目标 $targetOrders 订单', Colors.teal),
                      _badge(cs, '🥇金牌(+3) ×$goldRem', Colors.amber.shade700),
                      _badge(cs, '🥈银牌(+1) ×$silverRem', Colors.blueGrey),
                    ],
                  ),
                ],
              ),
              if (lastAction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    lastAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              const SizedBox(height: 6),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Order Row
                      _sectionTitle(cs, '分数订单区（点击满足条件的订单完成）'),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < orders.length; i++)
                              _buildOrderCard(
                                cs,
                                orders[i] as Map,
                                index: i,
                                goldRem: goldRem,
                                silverRem: silverRem,
                                canClaim: isMyTurn &&
                                    _canAfford(mySpices, _intList4((orders[i] as Map)['cost'])),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Merchant Market Row
                      _sectionTitle(cs, '商人卡市场（拿取第 N 张需在左侧每张卡放 1 颗香料）'),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < market.length; i++)
                              _buildMarketCard(
                                cs,
                                market[i] as Map,
                                index: i,
                                canAcquire: isMyTurn && myTotalSpices >= i,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Players area
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in g.seatsFromMe())
                            if (s < pList.length)
                              _buildPlayerPanel(cs, pList[s] as Map, active: !g.over && s == turn),
                        ],
                      ),

                      if (g.seat >= 0) ...[
                        const SizedBox(height: 8),
                        _buildMyHandArea(
                          cs,
                          myHand,
                          myPlayed: myPlayed,
                          mySpices: mySpices,
                          isMyTurn: isMyTurn,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (g.over && v['result'] != null)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(v['result'] as Map),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: cs.onSurface.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _badge(ColorScheme cs, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSpiceRow(List<int> counts, {double size = 14}) {
    final chips = <Widget>[];
    for (var t = 0; t < 4; t++) {
      if (counts[t] <= 0) continue;
      chips.add(
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: _spiceColors[t],
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '${counts[t]}${_spiceLabels[t]}',
            style: TextStyle(
              fontSize: size * 0.75,
              color: t == 0 ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    if (chips.isEmpty) {
      return const Text('无香料', style: TextStyle(fontSize: 10));
    }
    return Wrap(spacing: 2, runSpacing: 2, children: chips);
  }

  Widget _buildOrderCard(
    ColorScheme cs,
    Map o, {
    required int index,
    required int goldRem,
    required int silverRem,
    required bool canClaim,
  }) {
    final pts = (o['points'] as num?)?.toInt() ?? 0;
    final cost = _intList4(o['cost']);
    final hasGold = index == 0 && goldRem > 0;
    final hasSilver = index == 1 && silverRem > 0;

    final card = Container(
      width: 120,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canClaim ? Colors.amber : cs.outline.withValues(alpha: 0.4),
          width: canClaim ? 2.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pts 分',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.primary),
              ),
              if (hasGold)
                const Text('🥇+3', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
              else if (hasSilver)
                const Text('🥈+1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          _buildSpiceRow(cost, size: 13),
          if (canClaim) ...[
            const SizedBox(height: 6),
            Text(
              '点击完成订单',
              style: TextStyle(fontSize: 10, color: Colors.amber.shade800, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
    if (!canClaim) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => g.act({'type': 'claim', 'index': index}),
      child: card,
    );
  }

  Widget _buildMarketCard(
    ColorScheme cs,
    Map m, {
    required int index,
    required bool canAcquire,
  }) {
    final name = '${m['name']}';
    final onCardSpices = _intList4(m['spices']);
    final hasSpicesOnCard = onCardSpices.any((x) => x > 0);

    final card = Container(
      width: 126,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canAcquire ? cs.primary : cs.outline.withValues(alpha: 0.35),
          width: canAcquire ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    index == 0 ? '免费招募' : '需放 $index 香料',
                    style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('#${index + 1}', style: const TextStyle(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _buildMerchantFormula(m),
          if (hasSpicesOnCard) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('附带:', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
                Expanded(child: _buildSpiceRow(onCardSpices, size: 12)),
              ],
            ),
          ],
        ],
      ),
    );
    if (!canAcquire) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => g.act({'type': 'acquire', 'index': index}),
      child: card,
    );
  }

  Widget _buildMerchantFormula(Map m) {
    final kind = '${m['kind']}';
    if (kind == 'produce') {
      final gain = _intList4(m['gain']);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('收获 ', style: TextStyle(fontSize: 10)),
          Flexible(child: _buildSpiceRow(gain, size: 12)),
        ],
      );
    }
    if (kind == 'upgrade') {
      final up = (m['upgrades'] as num?)?.toInt() ?? 2;
      return Text('升级香料 ×$up 次', style: const TextStyle(fontSize: 11, color: Colors.teal));
    }
    final give = _intList4(m['give']);
    final get = _intList4(m['get']);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        _buildSpiceRow(give, size: 11),
        const Icon(Icons.arrow_forward, size: 12),
        _buildSpiceRow(get, size: 11),
      ],
    );
  }

  Widget _buildPlayerPanel(ColorScheme cs, Map p, {required bool active}) {
    final s = (p['seat'] as num).toInt();
    final sp = _intList4(p['spices']);
    final totalSp = (p['totalSpices'] as num?)?.toInt() ?? 0;
    final handCount = (p['handCount'] as num?)?.toInt() ?? 0;
    final played = (p['played'] as List?) ?? const [];
    final claimedCount = (p['claimedCount'] as num?)?.toInt() ?? 0;
    final gold = (p['goldCoins'] as num?)?.toInt() ?? 0;
    final silver = (p['silverCoins'] as num?)?.toInt() ?? 0;
    final score = (p['score'] as num?)?.toInt() ?? 0;

    return Container(
      width: 245,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? cs.primary : cs.outline.withValues(alpha: 0.35),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            s,
            active: active,
            size: 30,
            sub: '订单 $claimedCount · 🃏$handCount/已出${played.length} · ⭐$score',
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text('商队($totalSp/10): ', style: const TextStyle(fontSize: 11)),
              Expanded(child: _buildSpiceRow(sp, size: 13)),
              if (gold > 0) Text('🥇$gold ', style: const TextStyle(fontSize: 11)),
              if (silver > 0) Text('🥈$silver', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyHandArea(
    ColorScheme cs,
    List myHand, {
    required List myPlayed,
    required List<int> mySpices,
    required bool isMyTurn,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '我的手牌 (${myHand.length}) · 已打出 (${myPlayed.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              if (isMyTurn && myPlayed.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () {
                    setState(() {
                      _selectedHandIdx = null;
                      _upgradeSteps.clear();
                    });
                    g.act({'type': 'rest'});
                  },
                  icon: const Icon(Icons.replay, size: 15),
                  label: Text('休整（收回 ${myPlayed.length} 张卡）'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (myHand.isEmpty)
            const Text('手牌为空，请点击【休整】收回已打出的商人卡', style: TextStyle(fontSize: 12))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < myHand.length; i++)
                  _buildHandCardTile(
                    cs,
                    myHand[i] as Map,
                    index: i,
                    mySpices: mySpices,
                    isMyTurn: isMyTurn,
                  ),
              ],
            ),
          if (isMyTurn && _selectedHandIdx != null && _selectedHandIdx! < myHand.length)
            _buildSelectedCardControls(
              cs,
              myHand[_selectedHandIdx!] as Map,
              cardIndex: _selectedHandIdx!,
              mySpices: mySpices,
            ),
        ],
      ),
    );
  }

  Widget _buildHandCardTile(
    ColorScheme cs,
    Map c, {
    required int index,
    required List<int> mySpices,
    required bool isMyTurn,
  }) {
    final name = '${c['name']}';
    final kind = '${c['kind']}';
    final give = _intList4(c['give']);
    final playable = isMyTurn && (kind != 'trade' || _canAfford(mySpices, give));
    final selected = _selectedHandIdx == index;

    final tile = Container(
      width: 125,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? Colors.amber : (playable ? cs.primary : cs.outline.withValues(alpha: 0.35)),
          width: selected || playable ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          _buildMerchantFormula(c),
        ],
      ),
    );

    if (!playable) return Opacity(opacity: 0.55, child: tile);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (kind == 'produce') {
          g.act({'type': 'play', 'index': index});
        } else {
          setState(() {
            if (_selectedHandIdx == index) {
              _selectedHandIdx = null;
              _upgradeSteps.clear();
            } else {
              _selectedHandIdx = index;
              _upgradeSteps.clear();
              _tradeTimes = 1;
            }
          });
        }
      },
      child: tile,
    );
  }

  Widget _buildSelectedCardControls(
    ColorScheme cs,
    Map c, {
    required int cardIndex,
    required List<int> mySpices,
  }) {
    final kind = '${c['kind']}';
    if (kind == 'upgrade') {
      final maxUp = (c['upgrades'] as num?)?.toInt() ?? 2;
      final simSpices = List<int>.of(mySpices);
      for (final st in _upgradeSteps) {
        if (st >= 0 && st < 3 && simSpices[st] > 0) {
          simSpices[st]--;
          simSpices[st + 1]++;
        }
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('选择要升级的香料 (${_upgradeSteps.length}/$maxUp)：', style: const TextStyle(fontSize: 12)),
            for (var lv = 0; lv < 3; lv++)
              if (simSpices[lv] > 0 && _upgradeSteps.length < maxUp)
                ActionChip(
                  label: Text('${_spiceLabels[lv]}→${_spiceLabels[lv + 1]}', style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _upgradeSteps.add(lv)),
                ),
            if (_upgradeSteps.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _upgradeSteps.clear()),
                child: const Text('重置'),
              ),
            FilledButton(
              onPressed: () {
                final steps = List<int>.of(_upgradeSteps);
                setState(() {
                  _selectedHandIdx = null;
                  _upgradeSteps.clear();
                });
                g.act({
                  'type': 'play',
                  'index': cardIndex,
                  if (steps.isNotEmpty) 'steps': steps,
                });
              },
              child: Text(_upgradeSteps.isEmpty ? '自动升级并打出' : '确认升级并打出'),
            ),
          ],
        ),
      );
    }

    if (kind == 'trade') {
      final give = _intList4(c['give']);
      var maxTimes = 10;
      for (var t = 0; t < 4; t++) {
        if (give[t] > 0) {
          final m = mySpices[t] ~/ give[t];
          if (m < maxTimes) maxTimes = m;
        }
      }
      if (_tradeTimes > maxTimes) _tradeTimes = maxTimes.clamp(1, 10);
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('交易次数：', style: TextStyle(fontSize: 12)),
            for (var k = 1; k <= maxTimes; k++)
              ChoiceChip(
                label: Text('×$k'),
                selected: _tradeTimes == k,
                onSelected: (_) => setState(() => _tradeTimes = k),
              ),
            FilledButton(
              onPressed: () {
                final t = _tradeTimes;
                setState(() => _selectedHandIdx = null);
                g.act({'type': 'play', 'index': cardIndex, 'times': t});
              },
              child: Text('执行 ×$_tradeTimes 交易'),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildResultBanner(Map res) {
    final winners = ((res['winners'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final scores = ((res['scores'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final title = winners.isEmpty ? '游戏结束' : '🏆 ${winners.map(g.name).join("、")} 获胜！';
    return ResultBanner(
      title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var s = 0; s < g.players && s < scores.length; s++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('${g.name(s)}：${scores[s]} 分', style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
