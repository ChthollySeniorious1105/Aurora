import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro13/flamecraft.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class FlamecraftBoard extends StatefulWidget {
  final GameContext g;
  const FlamecraftBoard(this.g, {super.key});

  @override
  State<FlamecraftBoard> createState() => _FlamecraftBoardState();
}

class _FlamecraftBoardState extends State<FlamecraftBoard> {
  int _selectedHandIdx = -1;
  int? _inspectSeat;

  Color _goodColor(int t) {
    return switch (t) {
      0 => const Color(0xFFD4882A), // Bread
      1 => const Color(0xFFD32F2F), // Meat
      2 => const Color(0xFF546E7A), // Iron
      3 => const Color(0xFF00897B), // Potion
      4 => const Color(0xFF43A047), // Plant
      5 => const Color(0xFF8E24AA), // Crystal
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 8);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final shops = (v['shops'] as List?) ?? const [];
    final spells = (v['spells'] as List?) ?? const [];
    final park = (v['park'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat = (_inspectSeat != null && _inspectSeat! < pList.length)
        ? _inspectSeat!
        : mySeat;
    final isMyTurn = !over && g.seat == turn;

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
                                    ? '轮到你！造访街区店铺采集点火，或消耗货物施展附魔 · $lastAction'
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
                          '🐉第 $round/$maxRounds 轮',
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
                        final h = asInt(pd['hearts'], 0);
                        final c = asInt(pd['coins'], 0);
                        final sc = asInt(pd['score'], 0);
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
                              sub: '❤️$h · 🪙$c · ⭐$sc',
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
                                child: _buildShopsPanel(
                                  shops,
                                  pList,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: _buildSpellsAndHandPanel(
                                  spells,
                                  park,
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
                                flex: 6,
                                child: _buildShopsPanel(
                                  shops,
                                  pList,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 5,
                                child: _buildSpellsAndHandPanel(
                                  spells,
                                  park,
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
                '魔法龙镇终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShopsPanel(
    List<dynamic> shops,
    List<dynamic> pList,
    bool isMyTurn,
    ColorScheme cs,
  ) {
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
            '🏪 魔法街区 6 大工坊（点击店铺采集物资、入驻幼龙并唤醒烈焰）',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.25,
              ),
              itemCount: shops.length,
              itemBuilder: (context, idx) {
                final sm = (shops[idx] as Map).cast<String, dynamic>();
                final sName = asStr(sm['name']);
                final baseGood = asInt(sm['baseGood'], idx);
                final ench = asInt(sm['enchantCount'], 0);
                final dragons = (sm['dragons'] as List?) ?? const [];

                final visitors = <String>[];
                for (var s = 0; s < pList.length; s++) {
                  final loc = asInt((pList[s] as Map)['location'], -1);
                  if (loc == idx) visitors.add(widget.g.name(s));
                }

                return GestureDetector(
                  onTap: isMyTurn
                      ? () {
                          final slotIdx =
                              (dragons.length < 3 && _selectedHandIdx >= 0)
                                  ? _selectedHandIdx
                                  : -1;
                          widget.g.act({
                            'type': 'gather',
                            'shop': idx,
                            'handIdx': slotIdx,
                            'fireSlot': dragons.isEmpty ? 0 : dragons.length - 1,
                          });
                          setState(() => _selectedHandIdx = -1);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _goodColor(baseGood).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMyTurn ? Colors.amberAccent : Colors.white38,
                        width: isMyTurn ? 1.5 : 0.8,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${flameGoodEmojis[baseGood]} $sName ${ench > 0 ? '✨+$ench' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '龙位 ${dragons.length}/3: ${[
                              for (final d in dragons)
                                flameGoodEmojis[asInt((d as Map)['type'], 0)]
                            ].join(' ')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                          if (visitors.isNotEmpty)
                            Text(
                              '在场: ${visitors.join(',')}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 9,
                              ),
                            ),
                          if (isMyTurn)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                '🔥点击采集/点火',
                                style: TextStyle(
                                  color: Colors.yellowAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
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

  Widget _buildSpellsAndHandPanel(
    List<dynamic> spells,
    List<dynamic> park,
    int viewSeat,
    Map<String, dynamic> viewData,
    bool canAct,
    ColorScheme cs,
  ) {
    final goods = asIntList(viewData['goods']);
    final coins = asInt(viewData['coins'], 0);
    final hand = (viewData['hand'] as List?) ?? const [];

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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  '${widget.g.name(viewSeat)} 物资: ',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
                for (var g = 0; g < 6; g++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      '${flameGoodEmojis[g]}${g < goods.length ? goods[g] : 0}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                Text(
                  ' · 🪙$coins',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hand.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, idx) {
                final dm = (hand[idx] as Map).cast<String, dynamic>();
                final dName = asStr(dm['name']);
                final selected = _selectedHandIdx == idx;
                return GestureDetector(
                  onTap: canAct
                      ? () => setState(
                          () => _selectedHandIdx = selected ? -1 : idx)
                      : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.amber.shade700
                          : cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: selected
                          ? Border.all(color: Colors.white, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        selected ? '✓入驻:$dName' : dName,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '🪄 5 张附魔咒语（点击施展附魔获得 5～8❤️ 并唤醒全店群龙）',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: ListView.separated(
              itemCount: spells.length,
              separatorBuilder: (_, _) => const SizedBox(height: 3),
              itemBuilder: (context, idx) {
                final sp = (spells[idx] as Map).cast<String, dynamic>();
                final spName = asStr(sp['name']);
                final targetShop = asInt(sp['targetShop'], 0);
                final cost = asIntList(sp['cost']);
                final hearts = asInt(sp['hearts'], 5);

                final costParts = <String>[];
                for (var g = 0; g < cost.length; g++) {
                  if (cost[g] > 0) {
                    costParts.add('${flameGoodEmojis[g]}×${cost[g]}');
                  }
                }

                return GestureDetector(
                  onTap: canAct
                      ? () => widget.g.act({
                            'type': 'enchant',
                            'shop': targetShop,
                            'spellSlot': idx,
                          })
                      : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _goodColor(targetShop).withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${flameGoodEmojis[targetShop]}《$spName》 需:${costParts.join(' ')}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+$hearts❤️',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
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
}
