import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro15/living_forest.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class LivingForestBoard extends StatefulWidget {
  final GameContext g;
  const LivingForestBoard(this.g, {super.key});

  @override
  State<LivingForestBoard> createState() => _LivingForestBoardState();
}

class _LivingForestBoardState extends State<LivingForestBoard> {
  int _selectedTreeSlot = 0;
  int? _inspectSeat;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final treeRows = asInt(v['treeRows'], 3);
    final treeCols = asInt(v['treeCols'], 5);
    final winTarget = asInt(v['winTarget'], 12);
    final round = asInt(v['round'], 1);
    final turn = asInt(v['turn'], 0);
    final phase = asStr(v['phase'], 'draw');
    final actionsLeft = asInt(v['actionsLeft'], 0);
    final usedActions =
        ((v['usedActions'] as List?) ?? const []).map((e) => '$e').toSet();
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final animalMarket = (v['animalMarket'] as List?) ?? const [];
    final treeMarket = (v['treeMarket'] as List?) ?? const [];
    final fireCircle = (v['fireCircle'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    if (_selectedTreeSlot >= treeMarket.length) _selectedTreeSlot = 0;

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat = (_inspectSeat != null && _inspectSeat! < pList.length)
        ? _inspectSeat!
        : mySeat;
    final isMyTurn = !over && g.seat == turn;

    final viewData = (pList.isNotEmpty && viewSeat < pList.length)
        ? (pList[viewSeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final myData = (pList.isNotEmpty && mySeat < pList.length)
        ? (pList[mySeat] as Map).cast<String, dynamic>()
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
                                    ? (phase == 'draw'
                                        ? '轮到你召唤守护兽！注意独行标志(🐾<3可获2行动) · $lastAction'
                                        : '轮到你执行森林行动（剩余 $actionsLeft 次） · $lastAction')
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
                          '🌲第$round轮 · 目标:$winTarget',
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
                        final tr = asInt(pd['trees'], 0);
                        final fi = asInt(pd['fires'], 0);
                        final lo = asInt(pd['lotus'], 0);
                        final fr = asInt(pd['fragments'], 0);
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
                              sub: '🌲$tr 🔥$fi 🌸$lo · 💎$fr',
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
                                child: _buildCenterMarketPanel(
                                  phase,
                                  actionsLeft,
                                  usedActions,
                                  fireCircle,
                                  animalMarket,
                                  treeMarket,
                                  myData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildSpiritPanel(
                                  viewSeat,
                                  viewData,
                                  treeRows,
                                  treeCols,
                                  winTarget,
                                  treeMarket,
                                  isMyTurn &&
                                      viewSeat == g.seat &&
                                      phase == 'action' &&
                                      !usedActions.contains('plant'),
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildCenterMarketPanel(
                                  phase,
                                  actionsLeft,
                                  usedActions,
                                  fireCircle,
                                  animalMarket,
                                  treeMarket,
                                  myData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildSpiritPanel(
                                  viewSeat,
                                  viewData,
                                  treeRows,
                                  treeCols,
                                  winTarget,
                                  treeMarket,
                                  isMyTurn &&
                                      viewSeat == g.seat &&
                                      phase == 'action' &&
                                      !usedActions.contains('plant'),
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
                '生机森林终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}圣物'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCenterMarketPanel(
    String phase,
    int actionsLeft,
    Set<String> usedActions,
    List<dynamic> fireCircle,
    List<dynamic> animalMarket,
    List<dynamic> treeMarket,
    Map<String, dynamic> myData,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final elems = (myData['elements'] as List?) ?? const [0, 0, 0, 0, 0];
    final sun = elems.isNotEmpty ? asInt(elems[0], 0) : 0;
    final water = elems.length > 1 ? asInt(elems[1], 0) : 0;
    final sprout = elems.length > 2 ? asInt(elems[2], 0) : 0;
    final wind = elems.length > 3 ? asInt(elems[3], 0) : 0;
    final frags = asInt(myData['fragments'], 0);
    final helpLine = (myData['helpLine'] as List?) ?? const [];

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
          // Action Bar
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (isMyTurn && phase == 'draw') ...[
                  _actionBtn(
                    '🃏 抽牌召唤',
                    cs.primaryContainer,
                    cs.onPrimaryContainer,
                    () => widget.g.act({'type': 'draw'}),
                  ),
                  const SizedBox(width: 6),
                  _actionBtn(
                    '🛑 见好就收(获2行动)',
                    Colors.green.withValues(alpha: 0.25),
                    Colors.green[800]!,
                    () => widget.g.act({'type': 'stop_draw'}),
                  ),
                  if (frags > 0 && helpLine.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _actionBtn(
                      '💎 碎片驱散($frags)',
                      Colors.purple.withValues(alpha: 0.25),
                      Colors.purple[800]!,
                      () => widget.g.act({'type': 'fragment'}),
                    ),
                  ],
                ] else if (isMyTurn && phase == 'action') ...[
                  if (!usedActions.contains('move') && wind > 0) ...[
                    _actionBtn(
                      '🌀 巨石阵前行(+$wind步)',
                      cs.primaryContainer,
                      cs.onPrimaryContainer,
                      () => widget.g.act({'type': 'move', 'steps': wind}),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (!usedActions.contains('extinguish') &&
                      fireCircle.isNotEmpty &&
                      water >= asInt(fireCircle.first, 2)) ...[
                    _actionBtn(
                      '🔥 一键扑灭鬼火',
                      Colors.orange.withValues(alpha: 0.25),
                      Colors.deepOrange,
                      () => widget.g
                          .act({'type': 'extinguish', 'slot': 0, 'all': true}),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _actionBtn(
                    '⏭️ 结束行动',
                    cs.secondaryContainer,
                    cs.onSecondaryContainer,
                    () => widget.g.act({'type': 'pass'}),
                  ),
                ] else
                  Center(
                    child: Text(
                      '🔥鬼火圈(${fireCircle.length}) · 🦌守护兽市场 · 🌳护林树苗',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Fire Circle strip
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: fireCircle.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final fVal = asInt(fireCircle[idx], 2);
                final canEx = isMyTurn &&
                    phase == 'action' &&
                    !usedActions.contains('extinguish') &&
                    water >= fVal;
                return GestureDetector(
                  onTap: !canEx
                      ? null
                      : () => widget.g.act(
                          {'type': 'extinguish', 'slot': idx, 'all': true}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: canEx
                          ? Colors.deepOrange.withValues(alpha: 0.25)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: canEx
                            ? Colors.deepOrange
                            : cs.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '🔥鬼火 ($fVal💧)',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // Guardian Animal Market
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: animalMarket.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final a = (animalMarket[idx] as Map).cast<String, dynamic>();
                final cost = asInt(a['cost'], 3);
                final canRecruit = isMyTurn &&
                    phase == 'action' &&
                    !usedActions.contains('recruit') &&
                    sun >= cost;
                return GestureDetector(
                  onTap: !canRecruit
                      ? null
                      : () => widget.g.act({'type': 'recruit', 'slot': idx}),
                  child: Container(
                    width: 105,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: canRecruit
                          ? Colors.amber.withValues(alpha: 0.2)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: canRecruit
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
                            '${a['emoji']} ${a['name']}${asBool(a['isSolitary']) ? '🐾' : ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          Text(
                            '${a['elemSummary']}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          Text(
                            '招募: $cost☀',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: canRecruit ? Colors.amber[800] : cs.primary,
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
          const SizedBox(height: 4),
          // Tree Market
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: treeMarket.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final t = (treeMarket[idx] as Map).cast<String, dynamic>();
                final cost = asInt(t['cost'], 3);
                final sel = idx == _selectedTreeSlot;
                final affordable = sprout >= cost;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTreeSlot = idx),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sel
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel
                            ? cs.primary
                            : (affordable
                                ? Colors.green
                                : cs.outline.withValues(alpha: 0.3)),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${t['emoji']}${t['name']} ($cost🌱 → ${t['bonusLabel']})',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
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

  Widget _actionBtn(
    String label,
    Color bg,
    Color fg,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _buildSpiritPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int treeRows,
    int treeCols,
    int winTarget,
    List<dynamic> treeMarket,
    bool canPlantNow,
    ColorScheme cs,
  ) {
    final elems = (viewData['elements'] as List?) ?? const [0, 0, 0, 0, 0];
    final helpLine = (viewData['helpLine'] as List?) ?? const [];
    final forestGrid = (viewData['forestGrid'] as List?) ?? const [];
    final legalTreeCells = (viewData['legalTreeCells'] as List?) ?? const [];
    final sol = asInt(viewData['solitary'], 0);
    final circlePos = asInt(viewData['circlePos'], 0);

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
                  '🌿 ${widget.g.name(viewSeat)} ',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                for (var i = 0; i < 5 && i < elems.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '${forestElementEmojis[i]}${elems[i]}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                Text(
                  '🐾独行:$sol/3 · 🪨石阵:#$circlePos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sol >= 3 ? Colors.redAccent : cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // Help Line strip
          SizedBox(
            height: 30,
            child: helpLine.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '当前召唤队列为空（牌库 ${viewData['drawCount'] ?? 0} 张 / 弃牌 ${viewData['discardCount'] ?? 0} 张）',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: helpLine.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, idx) {
                      final c =
                          (helpLine[idx] as Map).cast<String, dynamic>();
                      final isSol = asBool(c['isSolitary']);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSol
                              ? Colors.red.withValues(alpha: 0.18)
                              : cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSol
                                ? Colors.redAccent
                                : cs.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${c['emoji']}${c['name']}${isSol ? '🐾' : ''} (${c['elemSummary']})',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
          // 3x5 Forest Tree Grid
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: treeCols / treeRows,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: treeCols,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: treeRows * treeCols,
                  itemBuilder: (context, index) {
                    final r = index ~/ treeCols;
                    final c = index % treeCols;
                    final rawCell = (r < forestGrid.length &&
                            c < (forestGrid[r] as List).length)
                        ? (forestGrid[r] as List)[c]
                        : null;
                    final tree = rawCell is Map
                        ? rawCell.cast<String, dynamic>()
                        : null;
                    final isLegal = legalTreeCells.any((pair) {
                      final p = pair as List;
                      return asInt(p[0], -1) == r && asInt(p[1], -1) == c;
                    });

                    return GestureDetector(
                      onTap: !(canPlantNow && isLegal)
                          ? null
                          : () {
                              widget.g.act({
                                'type': 'plant',
                                'slot': _selectedTreeSlot,
                                'r': r,
                                'c': c,
                              });
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          color: tree != null
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.78)
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (canPlantNow && isLegal)
                                ? Colors.greenAccent
                                : cs.outline.withValues(alpha: 0.3),
                            width: (canPlantNow && isLegal) ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: tree != null
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${tree['emoji']}',
                                          style: const TextStyle(fontSize: 15)),
                                      Text(
                                        '${tree['bonusLabel']}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    isLegal ? '🌱可种' : '$r,$c',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isLegal
                                          ? Colors.green
                                          : cs.onSurface
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
