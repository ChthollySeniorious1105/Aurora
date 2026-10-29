import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ForSaleBoard extends StatefulWidget {
  final GameContext g;
  const ForSaleBoard(this.g, {super.key});

  @override
  State<ForSaleBoard> createState() => _ForSaleBoardState();
}

class _ForSaleBoardState extends State<ForSaleBoard> {
  int _customBid = 1;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final phase = '${v['phase'] ?? 'bid'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final roundNum = (v['roundNum'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 1;
    final highBid = (v['highBid'] as num?)?.toInt() ?? 0;
    final tableProperties = (v['tableProperties'] as List?)?.cast<Map>() ?? const <Map>[];
    final tableChecks = (v['tableChecks'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final myProperties = (v['myProperties'] as List?)?.cast<Map>() ?? const <Map>[];
    final mySelectedProperty = (v['mySelectedProperty'] as num?)?.toInt();
    final lastSellReveal = (v['lastSellReveal'] as List?)?.cast<Map>() ?? const <Map>[];
    final pList = (v['players'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastAction = '${v['lastAction'] ?? ''}';

    final isMyBidTurn = !g.over && phase == 'bid' && g.seat == turn;
    final needMySell = !g.over && phase == 'sell' && g.seat >= 0 && mySelectedProperty == null;

    final myCoins = (g.seat >= 0 && g.seat < pList.length)
        ? ((pList[g.seat]['coins'] as num?)?.toInt() ?? 0)
        : 0;
    final myCurrentBid = (g.seat >= 0 && g.seat < pList.length)
        ? ((pList[g.seat]['bid'] as num?)?.toInt() ?? 0)
        : 0;

    final minBid = highBid + 1;
    if (_customBid < minBid || _customBid > max(minBid, myCoins)) {
      _customBid = minBid.clamp(1, max(1, myCoins));
    }

    String statusText = lastAction;
    if (!g.over) {
      if (isMyBidTurn) {
        statusText = '🏠 第 $roundNum/$totalRounds 轮买房竞拍：轮到你出价（当前最高 \$${highBid}k）或放弃';
      } else if (needMySell) {
        statusText = '💵 第 $roundNum/$totalRounds 轮卖房变现：请点击下方 1 张房产暗牌出售';
      }
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      statusText,
                      highlight: isMyBidTurn || needMySell,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildPlayersWrap(cs, pList, phase, turn),
                  const SizedBox(height: 8),
                  if (phase == 'bid')
                    _buildBidPhaseCenter(
                      cs,
                      tableProperties: tableProperties,
                      highBid: highBid,
                      myCoins: myCoins,
                      myCurrentBid: myCurrentBid,
                      isMyBidTurn: isMyBidTurn,
                    )
                  else
                    _buildSellPhaseCenter(
                      cs,
                      tableChecks: tableChecks,
                      lastSellReveal: lastSellReveal,
                    ),
                  const SizedBox(height: 8),
                  _buildMyPropertiesSection(
                    cs,
                    myProperties: myProperties,
                    phase: phase,
                    needMySell: needMySell,
                    mySelectedProperty: mySelectedProperty,
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: _buildFinalBanner(cs),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayersWrap(ColorScheme cs, List<Map> pList, String phase, int turn) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final p in pList)
          Builder(builder: (context) {
            final s = (p['seat'] as num?)?.toInt() ?? 0;
            final coins = (p['coins'] as num?)?.toInt() ?? 0;
            final bid = (p['bid'] as num?)?.toInt() ?? 0;
            final inAuction = p['inAuction'] == true;
            final propCount = (p['propertyCount'] as num?)?.toInt() ?? 0;
            final checkMoney = (p['checkMoney'] as num?)?.toInt();
            final chosenSell = p['chosenSell'] == true;
            final active = phase == 'bid' ? (s == turn && !g.over) : (!chosenSell && !g.over);

            final subParts = <String>[
              '💰\$${coins}k',
              if (phase == 'bid') (inAuction ? '出价\$${bid}k' : '已拿房') else (chosenSell ? '✅已出牌' : '⏳选牌中'),
              '🏠$propCount',
              if (checkMoney != null) '💵\$${checkMoney}k',
            ];

            return g.tag(
              s,
              active: active,
              sub: subParts.join(' · '),
              size: 32,
            );
          }),
      ],
    );
  }

  Widget _buildBidPhaseCenter(
    ColorScheme cs, {
    required List<Map> tableProperties,
    required int highBid,
    required int myCoins,
    required int myCurrentBid,
    required bool isMyBidTurn,
  }) {
    final minBid = highBid + 1;
    final canBid = isMyBidTurn && minBid <= myCoins;
    final passCost = myCurrentBid ~/ 2;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text(
            '🏘️ 本轮待拍房产（从小到大排列：放弃拿最小，坚持到最后拿最大）',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < tableProperties.length; i++)
                _buildPropertyCard(
                  cs,
                  value: (tableProperties[i]['value'] as num).toInt(),
                  name: '${tableProperties[i]['name']}',
                  badge: i == 0
                      ? '放弃拿此房'
                      : (i == tableProperties.length - 1 ? '最高出价得' : null),
                  highlight: i == tableProperties.length - 1,
                ),
            ],
          ),
          if (isMyBidTurn) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (canBid) ...[
                  for (final b in {
                    minBid,
                    min(myCoins, minBid + 1),
                    min(myCoins, minBid + 2),
                    myCoins,
                  })
                    FilledButton.tonal(
                      onPressed: () => g.act({'type': 'bid', 'amount': b}),
                      child: Text('出价 \$${b}k'),
                    ),
                ],
                FilledButton.icon(
                  onPressed: () => g.act({'type': 'pass'}),
                  icon: const Icon(Icons.pan_tool_alt, size: 16),
                  label: Text('放弃（付 \$${passCost}k 拿最小房）'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSellPhaseCenter(
    ColorScheme cs, {
    required List<int> tableChecks,
    required List<Map> lastSellReveal,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text(
            '💵 本轮待变现支票（从小到大排列：打出房产点数最高者赢得最大支票）',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < tableChecks.length; i++)
                _buildCheckCard(
                  cs,
                  amount: tableChecks[i],
                  isTop: i == tableChecks.length - 1,
                ),
            ],
          ),
          if (lastSellReveal.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                const Text('上轮成交：', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                for (final r in lastSellReveal)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${r['name']}: ${r['property']}号${r['propertyName']} → \$${r['check']}k',
                      style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyPropertiesSection(
    ColorScheme cs, {
    required List<Map> myProperties,
    required String phase,
    required bool needMySell,
    required int? mySelectedProperty,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            phase == 'sell'
                ? '🏠 我的房产手牌（点击 1 张房产暗牌出售）：'
                : '🏠 我已购入的房产：',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          if (myProperties.isEmpty)
            const Text('暂无房产牌', style: TextStyle(fontSize: 11))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in myProperties)
                  Builder(builder: (context) {
                    final val = (p['value'] as num).toInt();
                    final name = '${p['name']}';
                    final selected = mySelectedProperty == val;
                    return _buildPropertyCard(
                      cs,
                      value: val,
                      name: name,
                      highlight: selected,
                      badge: selected ? '已选出售' : (needMySell ? '点击出售' : null),
                      onTap: needMySell ? () => g.act({'type': 'sell', 'card': val}) : null,
                    );
                  }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(
    ColorScheme cs, {
    required int value,
    required String name,
    String? badge,
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    final Color tierColor = value >= 24
        ? Colors.deepPurple.shade700
        : (value >= 16
            ? Colors.blue.shade700
            : (value >= 8 ? Colors.teal.shade700 : Colors.brown.shade600));

    final card = Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tierColor, tierColor.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? Colors.amberAccent : Colors.white38,
          width: highlight ? 2 : 1,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#$value',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.yellowAccent, fontSize: 9),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }

  Widget _buildCheckCard(ColorScheme cs, {required int amount, required bool isTop}) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: amount == 0 ? Colors.grey.shade700 : Colors.green.shade800,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTop ? Colors.amberAccent : Colors.white38,
          width: isTop ? 2 : 1,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏦 支票', style: TextStyle(color: Colors.white70, fontSize: 10)),
            Text(
              '\$${amount}k',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalBanner(ColorScheme cs) {
    final fin = (v['final'] as List?)?.cast<Map>() ?? const <Map>[];
    final winners = fin.where((m) => m['win'] == true).map((m) => '${m['name']}').join('、');
    return ResultBanner(
      winners.isEmpty ? '游戏结束' : '🏆 $winners 赢得房产大亨！',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in fin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${m['win'] == true ? "👑 " : ""}${m['name']}：总资产 \$${m['score']}k（支票 \$${m['checkMoney']}k + 金币 \$${m['coins']}k）',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: m['win'] == true ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
