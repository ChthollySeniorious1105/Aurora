import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro18/all_creatures.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class AllCreaturesBoard extends StatefulWidget {
  final GameContext g;
  const AllCreaturesBoard(this.g, {super.key});

  @override
  State<AllCreaturesBoard> createState() => _AllCreaturesBoardState();
}

class _AllCreaturesBoardState extends State<AllCreaturesBoard> {
  int _selR = -1;
  int _selC = -1;
  int _selBuildingIdx = 0;
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
    final actionSpaces = (v['actionSpaces'] as List?) ?? const [];
    final specialMarket = (v['specialMarket'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    if (_selBuildingIdx >= specialMarket.length) _selBuildingIdx = 0;

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
                                    ? '轮到你！点击左侧空闲行动格派遣农夫（可先点选右侧 3×4 牧场目标地块或特殊建筑） · $lastAction'
                                    : '等待 ${g.name(turn)} 派遣农夫 · $lastAction'),
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
                          '🐄第 $round/$maxRounds 轮 (轮末成对繁育)',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, s) {
                        final pd = (pList[s] as Map).cast<String, dynamic>();
                        final sc = asInt(pd['score'], 0);
                        final res = (pd['res'] as List?) ?? const [0, 0, 0];
                        final anim =
                            (pd['animals'] as List?) ?? const [0, 0, 0, 0];
                        final totA = asInt(pd['totalAnimals'], 0);
                        final totC = asInt(pd['totalCapacity'], 3);
                        final fl = asInt(pd['farmersLeft'], 0);
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
                              sub:
                                  '⭐$sc分 · 🌲${res[0]}🪨${res[1]}🧱${res[2]} · 🐑${anim[0]}🐗${anim[1]}🐄${anim[2]}🐎${anim[3]}($totA/$totC) · 👷$fl',
                              size: 26,
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
                                child: _buildActionSpacesPanel(
                                  actionSpaces,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildFarmsteadAndMarketPanel(
                                  viewSeat,
                                  viewData,
                                  specialMarket,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildActionSpacesPanel(
                                  actionSpaces,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildFarmsteadAndMarketPanel(
                                  viewSeat,
                                  viewData,
                                  specialMarket,
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
                '农家乐：牧场物语终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionSpacesPanel(
    List<dynamic> actionSpaces,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '👷 中央牧场工放行动区 (每轮每名玩家派遣 3 名农夫 · 轮末自动成对繁育)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 185,
                mainAxisExtent: 52,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: actionSpaces.length,
              itemBuilder: (context, idx) {
                final sp = (actionSpaces[idx] as Map).cast<String, dynamic>();
                final occ = asInt(sp['occupiedBy'], -1);
                final free = occ < 0;
                return GestureDetector(
                  onTap: (!isMyTurn || !free)
                      ? null
                      : () {
                          widget.g.act({
                            'type': 'take_action',
                            'actionId': sp['id'],
                            'r': _selR,
                            'c': _selC,
                            'buildingIdx': _selBuildingIdx,
                          });
                        },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: free
                          ? (isMyTurn
                              ? cs.primaryContainer.withValues(alpha: 0.65)
                              : cs.surfaceContainerHighest)
                          : Colors.brown.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: free
                            ? cs.primary.withValues(alpha: 0.5)
                            : Colors.brown,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${sp['emoji']} ${sp['name']}${free ? "" : " (👷P${occ + 1})"}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 10.5),
                          ),
                          Text(
                            '${sp['rewardDesc']}',
                            style: const TextStyle(fontSize: 9),
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

  Widget _buildFarmsteadAndMarketPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    List<dynamic> specialMarket,
    ColorScheme cs,
  ) {
    final farm = (viewData['farm'] as List?) ?? const [];
    final totA = asInt(viewData['totalAnimals'], 0);
    final totC = asInt(viewData['totalCapacity'], 3);
    final bd =
        (viewData['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🏡 ${widget.g.name(viewSeat)} 的 3×4 牧场 (总容量: $totA/$totC只 · 牲畜分:${bd['animalBaseVp'] ?? 0} 规模奖惩:${bd['animalBonusVp'] ?? 0} 基建:${bd['infraVp'] ?? 0} 建筑:${bd['buildingVp'] ?? 0})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                for (var r = 0; r < AllCreaturesGame.rows; r++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        children: [
                          for (var c = 0; c < AllCreaturesGame.cols; c++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1.5),
                                child: _buildFarmCell(
                                  r,
                                  c,
                                  (r < farm.length &&
                                          c < (farm[r] as List).length)
                                      ? (farm[r] as List)[c]
                                          as Map<String, dynamic>?
                                      : null,
                                  cs,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🏛️ 特殊农庄建筑市场 (点选目标建筑后点击左侧「建造特殊建筑」)：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            flex: 3,
            child: specialMarket.isEmpty
                ? const Center(
                    child: Text('特殊建筑已全部建完', style: TextStyle(fontSize: 10)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: specialMarket.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, idx) {
                      final b =
                          (specialMarket[idx] as Map).cast<String, dynamic>();
                      final sel = _selBuildingIdx == idx;
                      return GestureDetector(
                        onTap: () => setState(() => _selBuildingIdx = idx),
                        child: Container(
                          width: 138,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: sel
                                ? Colors.amber.withValues(alpha: 0.25)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? Colors.amber
                                  : cs.outline.withValues(alpha: 0.35),
                              width: sel ? 2 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${b['emoji']}${b['name']} (⭐${b['baseVp']})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5),
                                ),
                                Text(
                                  '需:${b['costDesc']} · 容量+${b['capacity']}',
                                  style: const TextStyle(fontSize: 9.5),
                                ),
                                Text(
                                  '${b['bonusDesc']}',
                                  style: const TextStyle(fontSize: 8.5),
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

  Widget _buildFarmCell(
    int r,
    int c,
    Map<String, dynamic>? cell,
    ColorScheme cs,
  ) {
    final sel = _selR == r && _selC == c;
    final kind = asStr(cell?['kind'], 'empty');
    final stalls = asInt(cell?['stalls'], 0);
    final hasTrough = asBool(cell?['hasTrough']);
    final cap = asInt(cell?['capacity'], 0);
    final bld = cell?['building'] as Map<String, dynamic>?;

    Color bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.4);
    String title = '🌱空草地 ($r,$c)';
    if (kind == 'cottage') {
      bgColor = Colors.orange.withValues(alpha: 0.22);
      title = '🏡初始农舍';
    } else if (kind == 'pasture') {
      bgColor = Colors.green.withValues(alpha: 0.25);
      title = stalls > 0 ? '🏠畜棚围栏牧场' : '🌿围栏牧场';
    } else if (kind == 'building' && bld != null) {
      bgColor = Colors.purple.withValues(alpha: 0.22);
      title = '${bld['emoji']}${bld['name']}';
    }

    return GestureDetector(
      onTap: () => setState(() {
        _selR = r;
        _selC = c;
      }),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? Colors.amber : cs.outline.withValues(alpha: 0.35),
            width: sel ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              ),
              Text(
                '容量:$cap只${hasTrough ? " · 🚰水槽" : ""}',
                style: const TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
