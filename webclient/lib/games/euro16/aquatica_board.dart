import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro16/aquatica.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class AquaticaBoard extends StatefulWidget {
  final GameContext g;
  const AquaticaBoard(this.g, {super.key});

  @override
  State<AquaticaBoard> createState() => _AquaticaBoardState();
}

class _AquaticaBoardState extends State<AquaticaBoard> {
  int? _inspectSeat;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 6);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final locationMarket = (v['locationMarket'] as List?) ?? const [];
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
                                    ? '轮到你！打出手牌/翻转蝠鲼获取🪙⚔️⬆️，购买/征服海域并上浮收纳 · $lastAction'
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
                          '🌊第 $round/$maxRounds 轮',
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
                        final coins = asInt(pd['coins'], 0);
                        final str = asInt(pd['strength'], 0);
                        final rises = asInt(pd['freeRises'], 0);
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
                              sub: '⭐$sc分 · 🪙$coins ⚔️$str ⬆️$rises',
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
                                flex: 5,
                                child: _buildMarketAndHandPanel(
                                  locationMarket,
                                  myData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildDepthSlotsAndMantasPanel(
                                  viewSeat,
                                  viewData,
                                  isMyTurn && viewSeat == g.seat,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildMarketAndHandPanel(
                                  locationMarket,
                                  myData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildDepthSlotsAndMantasPanel(
                                  viewSeat,
                                  viewData,
                                  isMyTurn && viewSeat == g.seat,
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
                '深海国度终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketAndHandPanel(
    List<dynamic> locationMarket,
    Map<String, dynamic> myData,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final myCoins = asInt(myData['coins'], 0);
    final myStr = asInt(myData['strength'], 0);
    final myHand = (myData['hand'] as List?) ?? const [];
    final mySlots = (myData['depthSlots'] as List?) ?? const [];
    final hasEmptySlot = mySlots.any((s) => s == null);

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
              const Expanded(
                child: Text(
                  '🌊 深海海域市场 (可花🪙购买或花⚔️征服入空槽位)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              if (isMyTurn) ...[
                InkWell(
                  onTap: () => widget.g.act({'type': 'recall'}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '🔄召回手牌&蝠鲼',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => widget.g.act({'type': 'end_turn'}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '✓结束回合',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 6,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: locationMarket.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final loc =
                    (locationMarket[idx] as Map).cast<String, dynamic>();
                final buyCost = asInt(loc['buyCost'], 0);
                final conqCost = asInt(loc['conquerCost'], 0);
                final canBuy = isMyTurn && hasEmptySlot && myCoins >= buyCost;
                final canConq = isMyTurn && hasEmptySlot && myStr >= conqCost;

                return Container(
                  width: 132,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (canBuy || canConq)
                          ? cs.primary
                          : cs.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${loc['emoji']} ${loc['name']} (⭐${loc['vp']}分)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          '${loc['depthsDesc']}',
                          style: const TextStyle(fontSize: 9),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: !canBuy
                                  ? null
                                  : () => widget.g.act({
                                        'type': 'buy_loc',
                                        'marketIdx': idx,
                                      }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: canBuy
                                      ? Colors.amber.withValues(alpha: 0.3)
                                      : Colors.black12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '🪙买($buyCost)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: canBuy
                                        ? Colors.amber[900]
                                        : cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: !canConq
                                  ? null
                                  : () => widget.g.act({
                                        'type': 'conquer_loc',
                                        'marketIdx': idx,
                                      }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: canConq
                                      ? Colors.redAccent.withValues(alpha: 0.25)
                                      : Colors.black12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚔️征($conqCost)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: canConq
                                        ? Colors.redAccent
                                        : cs.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            flex: 5,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: myHand.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final c = (myHand[idx] as Map).cast<String, dynamic>();
                return GestureDetector(
                  onTap: !isMyTurn
                      ? null
                      : () => widget.g.act({
                            'type': 'play_card',
                            'cardIdx': idx,
                          }),
                  child: Container(
                    width: 112,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMyTurn
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${c['emoji']} ${c['name']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          Text(
                            '${c['effectDesc']}',
                            style: const TextStyle(fontSize: 10),
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

  Widget _buildDepthSlotsAndMantasPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    bool canAct,
    ColorScheme cs,
  ) {
    final mantas = (viewData['mantas'] as List?) ?? const [];
    final depthSlots = (viewData['depthSlots'] as List?) ?? const [];
    final vault = (viewData['vault'] as List?) ?? const [];
    final freeRises = asInt(viewData['freeRises'], 0);

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
                  '🦈 ${widget.g.name(viewSeat)} 的 4枚蝠鲼 & 3条深海上升槽:',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Text(
                '宝库: ${vault.length}处 (${viewData['vaultVp'] ?? 0}分)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mantas.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, m) {
                final ready = asBool(mantas[m]);
                return GestureDetector(
                  onTap: (!canAct || !ready)
                      ? null
                      : () => widget.g.act({'type': 'use_manta', 'manta': m}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ready
                          ? Colors.teal.withValues(alpha: 0.25)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ready
                            ? Colors.teal
                            : cs.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${aquaticaMantaEmojis[m]}蝠鲼:${aquaticaMantaNames[m]}${ready ? "" : "(已翻)"}',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                for (var s = 0; s < 3; s++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _buildDepthSlotCard(
                        s,
                        s < depthSlots.length
                            ? depthSlots[s] as Map<String, dynamic>?
                            : null,
                        freeRises,
                        canAct,
                        cs,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepthSlotCard(
    int slotIdx,
    Map<String, dynamic>? loc,
    int freeRises,
    bool canAct,
    ColorScheme cs,
  ) {
    if (loc == null) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: Text(
          '深海槽 #${slotIdx + 1}\n(空槽位)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final curDepth = asInt(loc['currentDepth'], 0);
    final maxDepth = asInt(loc['maxDepth'], 3);
    final atTop = curDepth >= maxDepth;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: atTop
            ? Colors.amber.withValues(alpha: 0.22)
            : cs.secondaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: atTop ? Colors.amber : cs.primary.withValues(alpha: 0.5),
          width: atTop ? 2 : 1,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${loc['emoji']} ${loc['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            Text(
              '当前深度: $curDepth/$maxDepth · 宝库⭐${loc['vp']}分',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            Text(
              '${loc['depthsDesc']}',
              style: const TextStyle(fontSize: 9),
            ),
            const SizedBox(height: 4),
            if (canAct)
              if (atTop)
                InkWell(
                  onTap: () =>
                      widget.g.act({'type': 'score_loc', 'slot': slotIdx}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '🏁计分收纳宝库',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                )
              else if (freeRises > 0)
                InkWell(
                  onTap: () => widget.g.act({'type': 'rise', 'slot': slotIdx}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⬆️海域上浮1层',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
