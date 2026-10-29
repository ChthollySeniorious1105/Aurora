import 'package:aurora_shared/games/cards11/bohnanza.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class BohnanzaBoard extends StatelessWidget {
  final GameContext g;
  const BohnanzaBoard(this.g, {super.key});

  Map<String, dynamic> get v => g.view;

  List<int> _intList(Object? raw) =>
      raw is List ? [for (final x in raw) (x as num).toInt()] : const [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final step = (v['step'] as String?) ?? 'plant';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final plantedThisTurn = (v['plantedThisTurn'] as num?)?.toInt() ?? 0;
    final currentCycle = (v['currentCycle'] as num?)?.toInt() ?? 1;
    final maxCycles = (v['maxCycles'] as num?)?.toInt() ?? 1;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;

    final gold = _intList(v['gold']);
    final handCounts = _intList(v['handCounts']);
    final myHand = _intList(v['myHand']);
    final market = _intList(v['market']);

    final rawFields = v['fields'] as List? ?? const [];
    final allFields = [
      for (final pFields in rawFields)
        if (pFields is List)
          [for (final fld in pFields) _intList(fld)]
        else
          const <List<int>>[],
    ];

    final seats = g.seatsFromMe();
    final mySeat = seats.first;
    final oppSeats = seats.sublist(1);
    final isMyTurn = !g.spectator && !g.over && turn == g.seat;

    final myFields = mySeat < allFields.length
        ? allFields[mySeat]
        : const <List<int>>[[], []];
    final myGold = mySeat < gold.length ? gold[mySeat] : 0;

    String statusText;
    if (g.over) {
      statusText = '牌库耗尽，种豆结算完成！';
    } else if (!isMyTurn) {
      statusText =
          '等待 ${g.name(turn)} ${step == 'plant' ? '种植手牌第1张豆子' : '处理集市豆子'}…';
    } else if (step == 'plant') {
      statusText = plantedThisTurn == 0
          ? '阶段1：必须将手牌第1张 (hand[0]) 种入豆田（若无空位请先按护豆规则收割）'
          : '阶段1：已种 1 张，可继续种新的第1张手牌或点击「结束种豆进入集市」';
    } else {
      statusText = '阶段2（集市）：请将集市翻开的豆子种入自己豆田，或赠予其他玩家';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 450 || w < 440;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(compact ? 4 : 8),
                child: Column(
                  children: [
                    // Top header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '牌库轮次 $currentCycle/$maxCycles · 余牌 $deckCount 张',
                            style: TextStyle(
                              fontSize: compact ? 10 : 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // Opponents row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in oppSeats)
                          _buildOpponentCard(
                            s: s,
                            active: !g.over && turn == s,
                            gold: s < gold.length ? gold[s] : 0,
                            cards: s < handCounts.length ? handCounts[s] : 0,
                            fields: s < allFields.length
                                ? allFields[s]
                                : const [],
                            compact: compact,
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // Center area: Market + My Bean Fields
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 6 : 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (step == 'market' && market.isNotEmpty) ...[
                                  _buildMarketSection(
                                    market: market,
                                    myFields: myFields,
                                    oppSeats: oppSeats,
                                    isMyTurn: isMyTurn,
                                    compact: compact,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                _buildMyFieldsSection(
                                  mySeat: mySeat,
                                  myGold: myGold,
                                  myFields: myFields,
                                  myHand: myHand,
                                  step: step,
                                  plantedThisTurn: plantedThisTurn,
                                  isMyTurn: isMyTurn,
                                  compact: compact,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // Locked Hand Row
                    if (!g.spectator && myHand.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 6 : 10,
                          vertical: compact ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.lock,
                                  size: 13,
                                  color: Colors.amberAccent,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '锁定顺序手牌（共 ${myHand.length} 张）：只能打出最左侧第 1 张 (hand[0])，新摸牌排在最右侧',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: compact ? 10 : 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < myHand.length; i++)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _buildBeanCard(
                                        beanId: myHand[i],
                                        isFirst: i == 0,
                                        indexLabel:
                                            i == 0 ? '首张 hand[0]' : '#${i + 1}',
                                        compact: compact,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (g.over)
                Center(
                  child: ResultBanner(
                    _buildWinnerTitle(gold),
                    child: Text(
                      [
                        for (var s = 0; s < g.players; s++)
                          '${g.name(s)}: ${s < gold.length ? gold[s] : 0}金币',
                      ].join('  |  '),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _buildWinnerTitle(List<int> gold) {
    if (gold.isEmpty) return '对局结束';
    var best = 0;
    for (var s = 1; s < gold.length; s++) {
      if (gold[s] > gold[best]) best = s;
    }
    return '${g.name(best)} 荣获最富豆农 (${gold[best]} 金币)！';
  }

  Widget _buildOpponentCard({
    required int s,
    required bool active,
    required int gold,
    required int cards,
    required List<List<int>> fields,
    required bool compact,
  }) {
    final fieldSummary = [
      for (var f = 0; f < fields.length; f++)
        fields[f].isEmpty
            ? '田${f + 1}:空'
            : '田${f + 1}:${kBeanVarieties[fields[f].first].emoji}×${fields[f].length}',
    ].join(' ');
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: g.tag(
        s,
        active: active,
        size: compact ? 25 : 30,
        sub: '🪙$gold 金 · 手牌 $cards · $fieldSummary',
      ),
    );
  }

  Widget _buildMarketSection({
    required List<int> market,
    required List<List<int>> myFields,
    required List<int> oppSeats,
    required bool isMyTurn,
    required bool compact,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🏪 集市翻牌（Market）：可种入自己豆田或赠换给其他玩家',
            style: TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var idx = 0; idx < market.length; idx++)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBeanCard(
                      beanId: market[idx],
                      isFirst: true,
                      indexLabel: '集市 #${idx + 1}',
                      compact: compact,
                    ),
                    if (isMyTurn) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (var f = 0; f < myFields.length; f++)
                            if (myFields[f].isEmpty ||
                                myFields[f].first == market[idx])
                              FilledButton.tonal(
                                onPressed: () => g.act({
                                  'type': 'plant_market',
                                  'index': idx,
                                  'field': f,
                                }),
                                child: Text('种入田${f + 1}'),
                              ),
                          for (final opp in oppSeats)
                            OutlinedButton(
                              onPressed: () => g.act({
                                'type': 'gift_market',
                                'index': idx,
                                'target': opp,
                              }),
                              child: Text('赠 ${g.name(opp)}'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyFieldsSection({
    required int mySeat,
    required int myGold,
    required List<List<int>> myFields,
    required List<int> myHand,
    required String step,
    required int plantedThisTurn,
    required bool isMyTurn,
    required bool compact,
  }) {
    final hasMultiBeanField = myFields.any((fld) => fld.length >= 2);
    final firstHandBean = myHand.isNotEmpty ? myHand.first : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            g.tag(
              mySeat,
              active: isMyTurn,
              size: compact ? 26 : 30,
              sub: '我的金库：🪙 $myGold 枚金币 · 拥有 ${myFields.length} 块豆田',
            ),
            if (isMyTurn && step == 'plant' && plantedThisTurn >= 1)
              FilledButton.icon(
                onPressed: () => g.act({'type': 'done_plant'}),
                icon: const Icon(Icons.storefront, size: 16),
                label: const Text('结束种豆 → 翻开集市'),
              ),
            if (isMyTurn && myFields.length < 3 && myGold >= 3)
              OutlinedButton.icon(
                onPressed: () => g.act({'type': 'buy_field'}),
                icon: const Icon(Icons.add_business, size: 16),
                label: const Text('买第3块豆田 (-3金)'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var f = 0; f < myFields.length; f++)
              _buildSingleFieldBox(
                fieldIndex: f,
                beans: myFields[f],
                hasMultiBeanField: hasMultiBeanField,
                firstHandBean: firstHandBean,
                canPlantHand: isMyTurn &&
                    step == 'plant' &&
                    plantedThisTurn < 2 &&
                    firstHandBean != null &&
                    (myFields[f].isEmpty || myFields[f].first == firstHandBean),
                isMyTurn: isMyTurn,
                compact: compact,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleFieldBox({
    required int fieldIndex,
    required List<int> beans,
    required bool hasMultiBeanField,
    required int? firstHandBean,
    required bool canPlantHand,
    required bool isMyTurn,
    required bool compact,
  }) {
    final isEmpty = beans.isEmpty;
    final variety = isEmpty ? null : kBeanVarieties[beans.first];
    final count = beans.length;
    final harvestGold = isEmpty ? 0 : bohnanzaHarvestGold(beans.first, count);
    final canHarvest =
        isMyTurn && !isEmpty && !(count == 1 && hasMultiBeanField);

    return Container(
      width: compact ? 150 : 185,
      padding: EdgeInsets.all(compact ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.brown.shade900.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canPlantHand ? Colors.greenAccent : Colors.amber.shade700,
          width: canPlantHand ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🌱 豆田 #${fieldIndex + 1}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          if (isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '空豆田（可种任意品种）',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            )
          else ...[
            Text(
              '${variety!.emoji} ${variety.nameZh} × $count 颗',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              '当前收割可得：🪙 +$harvestGold 金',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              if (canPlantHand && firstHandBean != null)
                FilledButton.tonal(
                  onPressed: () =>
                      g.act({'type': 'plant', 'field': fieldIndex}),
                  child: Text(
                    '种 ${kBeanVarieties[firstHandBean].nameZh}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              if (!isEmpty)
                OutlinedButton(
                  onPressed: canHarvest
                      ? () => g.act({'type': 'harvest', 'field': fieldIndex})
                      : null,
                  child: Text(
                    canHarvest ? '收割 (+$harvestGold金)' : '护豆保护中',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBeanCard({
    required int beanId,
    required bool isFirst,
    required String indexLabel,
    required bool compact,
  }) {
    final v = kBeanVarieties[beanId.clamp(0, kBeanVarieties.length - 1)];
    final scaleStr = [
      for (var i = 0; i < v.thresholds.length; i++)
        if (v.thresholds[i] != null) '${v.thresholds[i]}=${i + 1}G',
    ].join(' ');

    return Container(
      width: compact ? 86 : 102,
      padding: EdgeInsets.all(compact ? 4 : 6),
      decoration: BoxDecoration(
        color: isFirst ? const Color(0xFFFFF8E1) : const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFirst ? Colors.amber.shade800 : Colors.black38,
          width: isFirst ? 2.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isFirst ? Colors.redAccent : Colors.blueGrey,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                indexLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(v.emoji, style: const TextStyle(fontSize: 22)),
            Text(
              '${v.nameZh} (${v.totalCards})',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            Text(
              scaleStr,
              style: const TextStyle(
                color: Colors.brown,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
