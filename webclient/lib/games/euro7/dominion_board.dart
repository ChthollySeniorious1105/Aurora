import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro7/dominion.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class DominionBoard extends StatefulWidget {
  final GameContext g;
  const DominionBoard(this.g, {super.key});

  @override
  State<DominionBoard> createState() => _DominionBoardState();
}

class _DominionBoardState extends State<DominionBoard> {
  final Set<int> _chapelSelected = {};
  String _stateKey = '';

  Color _cardColor(DominionCardDef def) {
    if (def.isTreasure) return const Color(0xFFD99B26);
    if (def.isVictory) return const Color(0xFF3E8E41);
    if (def.isCurse) return const Color(0xFF7B3F9E);
    if (def.type == 'action_reaction') return const Color(0xFF2B6CB0);
    if (def.type == 'action_attack') return const Color(0xFFC53030);
    return const Color(0xFF5A6270);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = asInt(v['turn'], 0);
    final round = asInt(v['round'], 1);
    final phase = asStr(v['phase'], 'turn');
    final actions = asInt(v['actions'], 0);
    final buys = asInt(v['buys'], 0);
    final coins = asInt(v['coins'], 0);
    final lastLog = asStr(v['lastLog']);
    final supplyRaw = (v['supply'] as Map?)?.cast<String, dynamic>() ?? const {};
    final hand = [for (final c in (v['hand'] as List? ?? const [])) asStr(c)];
    final played = [for (final c in (v['played'] as List? ?? const [])) asStr(c)];
    final playersList = [
      for (final p in (v['players'] as List? ?? const [])) (p as Map).cast<String, dynamic>(),
    ];

    final isMyTurn = !g.over && !g.replay && g.seat == turn;
    final curKey = '$round-$turn-$phase-${hand.length}-${played.length}';
    if (_stateKey != curKey) {
      _stateKey = curKey;
      _chapelSelected.clear();
    }

    String statusText;
    if (g.over) {
      statusText = lastLog.isNotEmpty ? lastLog : '游戏已结束';
    } else if (isMyTurn) {
      if (phase == 'chapel') {
        statusText = '礼拜堂：点选手牌移除（已选 ${_chapelSelected.length}/4 张）';
      } else if (phase == 'workshop') {
        statusText = '工坊：请点击供应区 1 张费用 ≤ 4 的卡牌免费获得';
      } else {
        statusText = '轮到你 · 行动:$actions  购买:$buys  金币:$coins';
      }
    } else {
      statusText = '第 $round 轮 · 等待 ${g.name(turn)} 行动（行动:$actions 购买:$buys 金币:$coins）';
    }

    Widget buildSupplyCard(String id, {required bool compact}) {
      final def = kDominionCards[id];
      if (def == null) return const SizedBox.shrink();
      final count = asInt(supplyRaw[id], 0);
      final canWorkshop = isMyTurn && phase == 'workshop' && count > 0 && def.cost <= 4;
      final canBuy = isMyTurn && phase == 'turn' && buys > 0 && count > 0 && coins >= def.cost;
      final active = canWorkshop || canBuy;
      final baseCol = _cardColor(def);

      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: active
            ? () {
                if (canWorkshop) {
                  g.act({'type': 'workshop_gain', 'card': id});
                } else if (canBuy) {
                  g.act({'type': 'buy', 'card': id});
                }
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: compact ? 84 : 104,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: count <= 0
                ? cs.surface.withValues(alpha: 0.35)
                : baseCol.withValues(alpha: active ? 0.28 : 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? Colors.amberAccent : baseCol.withValues(alpha: count <= 0 ? 0.25 : 0.7),
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6A817),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${def.cost}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  Text(
                    '×$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: count <= 0 ? Colors.redAccent : cs.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  def.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: count <= 0 ? cs.onSurface.withValues(alpha: 0.4) : cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                def.desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: cs.onSurface.withValues(alpha: 0.72)),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildHandCard(int index, String id) {
      final def = kDominionCards[id];
      if (def == null) return const SizedBox.shrink();
      final baseCol = _cardColor(def);
      final isChapelMode = isMyTurn && phase == 'chapel';
      final isSelected = isChapelMode && _chapelSelected.contains(index);
      final canPlay = isMyTurn && phase == 'turn' && (def.isTreasure || (def.isAction && actions > 0));

      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (isChapelMode) {
            setState(() {
              if (_chapelSelected.contains(index)) {
                _chapelSelected.remove(index);
              } else if (_chapelSelected.length < 4) {
                _chapelSelected.add(index);
              }
            });
          } else if (canPlay) {
            g.act({'type': 'play', 'card': id});
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 92,
          transform: Matrix4.translationValues(0, isSelected ? -6 : 0, 0),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: baseCol.withValues(alpha: isSelected || canPlay ? 0.32 : 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.redAccent
                  : (canPlay ? Colors.amberAccent : baseCol.withValues(alpha: 0.65)),
              width: isSelected || canPlay ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  def.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                def.desc,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: cs.onSurface.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      );
    }

    final hasTreasureInHand = hand.any((c) => kDominionCards[c]?.isTreasure ?? false);

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
                    Text('${g.name(s)}: ${scores[s]} 胜点', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    // Players bar
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final p in playersList)
                          Builder(builder: (_) {
                            final s = asInt(p['seat'], 0);
                            final sc = asInt(p['score'], 0);
                            final hc = asInt(p['handCount'], 0);
                            final dc = asInt(p['deckCount'], 0);
                            final disc = asInt(p['discardCount'], 0);
                            return g.tag(
                              s,
                              active: !g.over && turn == s,
                              size: compact ? 28 : 32,
                              sub: '$sc分 · 手$hc/库$dc/弃$disc',
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Basic Supply
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '基础供应区（空牌堆：${asInt(v['emptyPiles'], 0)}/3 · 销毁：${asInt(v['trashCount'], 0)}）',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final id in kBasicSupplyOrder)
                                if (supplyRaw.containsKey(id)) buildSupplyCard(id, compact: compact),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '王国行动卡（10张/堆）',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final id in kKingdomSupplyOrder)
                                if (supplyRaw.containsKey(id)) buildSupplyCard(id, compact: compact),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Played & Hand section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastLog,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
                                ),
                              ),
                              if (played.isNotEmpty)
                                Text(
                                  '已打出: ${played.map((c) => kDominionCards[c]?.name ?? c).join('、')}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.secondary),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (g.seat >= 0) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (var i = 0; i < hand.length; i++) buildHandCard(i, hand[i]),
                                if (hand.isEmpty)
                                  Text('（无手牌）', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                              ],
                            ),
                            if (isMyTurn) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (phase == 'chapel') ...[
                                    FilledButton.icon(
                                      onPressed: () {
                                        final selectedCards = [
                                          for (final idx in _chapelSelected)
                                            if (idx >= 0 && idx < hand.length) hand[idx],
                                        ];
                                        g.act({'type': 'chapel_trash', 'cards': selectedCards});
                                        setState(() => _chapelSelected.clear());
                                      },
                                      icon: const Icon(Icons.delete_outline, size: 16),
                                      label: Text('确认移除 (${_chapelSelected.length})'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        g.act({'type': 'chapel_trash', 'cards': const <String>[]});
                                        setState(() => _chapelSelected.clear());
                                      },
                                      child: const Text('跳过移除'),
                                    ),
                                  ] else if (phase == 'turn') ...[
                                    if (hasTreasureInHand)
                                      FilledButton.tonalIcon(
                                        onPressed: () => g.act({'type': 'play_treasures'}),
                                        icon: const Icon(Icons.monetization_on_outlined, size: 16),
                                        label: const Text('一键打出钱币'),
                                      ),
                                    FilledButton.icon(
                                      onPressed: () => g.act({'type': 'end_turn'}),
                                      icon: const Icon(Icons.skip_next, size: 16),
                                      label: const Text('结束回合'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
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
