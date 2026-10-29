import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro14/isle_of_cats.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class IsleOfCatsBoard extends StatefulWidget {
  final GameContext g;
  const IsleOfCatsBoard(this.g, {super.key});

  @override
  State<IsleOfCatsBoard> createState() => _IsleOfCatsBoardState();
}

class _IsleOfCatsBoardState extends State<IsleOfCatsBoard> {
  int _selectedSlot = 0;
  int _oshaxColor = 1;
  int? _inspectSeat;
  final List<(int, int)> _pickedCells = [];

  Color _catColor(int c) {
    return switch (c) {
      1 => const Color(0xFF1E88E5), // Blue
      2 => const Color(0xFFFBC02D), // Yellow
      3 => const Color(0xFFE53935), // Red
      4 => const Color(0xFF8E24AA), // Purple
      5 => const Color(0xFF43A047), // Green
      6 => const Color(0xFF90A4AE), // Oshax
      7 => const Color(0xFFFF8F00), // Treasure
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final rows = asInt(v['rows'], 5);
    final cols = asInt(v['cols'], 9);
    final day = asInt(v['day'], 1);
    final maxDays = asInt(v['maxDays'], 5);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final roomMap = (v['roomMap'] as List?) ?? const [];
    final rats = (v['rats'] as List?) ?? const [];
    final mapColor = (v['mapColor'] as List?) ?? const [];
    final islandCats = (v['islandCats'] as List?) ?? const [];
    final lessonMarket = (v['lessonMarket'] as List?) ?? const [];
    final validBySlot = (v['validBySlot'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    if (_selectedSlot >= islandCats.length) {
      _selectedSlot = 0;
    }

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
    final myFish = asInt(myData['fish'], 0);
    final myBaskets = asInt(myData['baskets'], 0);

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
                                    ? '轮到你！选猫咪上船、研习任务或结束今日 · $lastAction'
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
                          '🐱第 $day/$maxDays 天',
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
                        final f = asInt(pd['fish'], 0);
                        final b = asInt(pd['baskets'], 0);
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
                              sub: '⭐$sc分 · 🐟$f · 🧺$b',
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
                                child: _buildIslandPanel(
                                  islandCats,
                                  lessonMarket,
                                  validBySlot,
                                  myFish,
                                  myBaskets,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildBoatPanel(
                                  viewSeat,
                                  viewData,
                                  rows,
                                  cols,
                                  roomMap,
                                  rats,
                                  mapColor,
                                  islandCats,
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
                                child: _buildIslandPanel(
                                  islandCats,
                                  lessonMarket,
                                  validBySlot,
                                  myFish,
                                  myBaskets,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildBoatPanel(
                                  viewSeat,
                                  viewData,
                                  rows,
                                  cols,
                                  roomMap,
                                  rats,
                                  mapColor,
                                  islandCats,
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
                '猫岛奇缘终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIslandPanel(
    List<dynamic> islandCats,
    List<dynamic> lessonMarket,
    List<dynamic> validBySlot,
    int myFish,
    int myBaskets,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final slotValid = (_selectedSlot < validBySlot.length)
        ? (validBySlot[_selectedSlot] as List)
        : const [];
    final selCat = (_selectedSlot < islandCats.length)
        ? (islandCats[_selectedSlot] as Map).cast<String, dynamic>()
        : null;
    final canRescueSel = isMyTurn &&
        selCat != null &&
        myBaskets > 0 &&
        myFish >= asInt(selCat['fishCost'], 3) &&
        slotValid.isNotEmpty;

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
                  '🏝️ 猫岛草场与研习卡',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (canRescueSel)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () {
                      widget.g.act({
                        'type': 'rescue',
                        'slot': _selectedSlot,
                        'oshaxColor': _oshaxColor,
                        'cells': slotValid.first,
                      });
                      setState(() => _pickedCells.clear());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚡快捷营救',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isMyTurn)
                InkWell(
                  onTap: () => widget.g.act({'type': 'pass'}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🌙结束今日',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              children: [
                for (var s = 0; s < islandCats.length; s++)
                  Builder(builder: (context) {
                    final cm = (islandCats[s] as Map).cast<String, dynamic>();
                    final col = asInt(cm['color'], 1);
                    final cost = asInt(cm['fishCost'], 3);
                    final shape = (cm['shape'] as List?) ?? const [];
                    final selected = _selectedSlot == s;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedSlot = s;
                        _pickedCells.clear();
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? cs.primaryContainer.withValues(alpha: 0.7)
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? cs.primary
                                : cs.outline.withValues(alpha: 0.3),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: _catColor(col),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${isleCatTypeEmojis[col]}${isleCatTypeNames[col]}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '🐟$cost + 🧺1 · ${shape.length}格骨牌',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (col == 6 && selected)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var oc = 1; oc <= 5; oc++)
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _oshaxColor = oc),
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 2),
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          border: _oshaxColor == oc
                                              ? Border.all(
                                                  color: Colors.amberAccent,
                                                  width: 1.5)
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isleCatTypeEmojis[oc],
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                if (lessonMarket.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  const Text(
                    '📜 研习卡市场（点击直接研习）',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  for (var l = 0; l < lessonMarket.length; l++)
                    Builder(builder: (context) {
                      final lm =
                          (lessonMarket[l] as Map).cast<String, dynamic>();
                      final title = asStr(lm['title']);
                      final desc = asStr(lm['desc']);
                      final cost = asInt(lm['cost'], 2);
                      final canBuy = isMyTurn && myFish >= cost;
                      return GestureDetector(
                        onTap: canBuy
                            ? () => widget.g.act({'type': 'lesson', 'slot': l})
                            : null,
                        child: Opacity(
                          opacity: canBuy ? 1.0 : 0.6,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '🐟$cost ',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                                Expanded(
                                  child: Text(
                                    '《$title》$desc',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoatPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int rows,
    int cols,
    List<dynamic> roomMap,
    List<dynamic> rats,
    List<dynamic> mapColor,
    List<dynamic> islandCats,
    bool canAct,
    ColorScheme cs,
  ) {
    final boatMat = (viewData['boat'] as List?) ?? const [];
    final familyVp = asInt(viewData['familyVp'], 0);
    final treasureVp = asInt(viewData['treasureVp'], 0);
    final lessonVp = asInt(viewData['lessonVp'], 0);
    final uncoveredRats = asInt(viewData['uncoveredRats'], 0);
    final unfilledRooms = asInt(viewData['unfilledRooms'], 6);

    final selCat = (_selectedSlot < islandCats.length)
        ? (islandCats[_selectedSlot] as Map).cast<String, dynamic>()
        : null;
    final targetLen =
        selCat != null ? ((selCat['shape'] as List?)?.length ?? 3) : 3;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '⛵ ${widget.g.name(viewSeat)} 的救援船 ($rows×$cols · 6舱室)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (_pickedCells.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _pickedCells.clear()),
                  child: Text(
                    '已选 ${_pickedCells.length}/$targetLen 格 (清除)',
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 20,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '猫族+$familyVp · 宝藏+$treasureVp · 研习+$lessonVp · 🐀露鼠-$uncoveredRats · 空舱-${unfilledRooms * 5}',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: cols / rows,
                child: Column(
                  children: [
                    for (var r = 0; r < rows; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < cols; c++)
                              Expanded(
                                child: _buildBoatCell(
                                  r,
                                  c,
                                  _matInt(boatMat, r, c, 0),
                                  _matInt(roomMap, r, c, 0),
                                  _matBool(rats, r, c),
                                  _matInt(mapColor, r, c, 0),
                                  targetLen,
                                  canAct,
                                  cs,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _matInt(List<dynamic> mat, int r, int c, int fallback) {
    if (r >= mat.length) return fallback;
    final row = mat[r] as List;
    if (c >= row.length) return fallback;
    return asInt(row[c], fallback);
  }

  bool _matBool(List<dynamic> mat, int r, int c) {
    if (r >= mat.length) return false;
    final row = mat[r] as List;
    if (c >= row.length) return false;
    return asBool(row[c]);
  }

  Widget _buildBoatCell(
    int r,
    int c,
    int val,
    int room,
    bool hasRat,
    int mapCol,
    int targetLen,
    bool canAct,
    ColorScheme cs,
  ) {
    final pickedIdx = _pickedCells.indexOf((r, c));
    final isPicked = pickedIdx >= 0;

    return GestureDetector(
      onTap: canAct && val == 0
          ? () {
              setState(() {
                if (isPicked) {
                  _pickedCells.removeAt(pickedIdx);
                } else {
                  _pickedCells.add((r, c));
                  if (_pickedCells.length == targetLen) {
                    final cells = [
                      for (final (pr, pc) in _pickedCells) [pr, pc],
                    ];
                    _pickedCells.clear();
                    widget.g.act({
                      'type': 'rescue',
                      'slot': _selectedSlot,
                      'oshaxColor': _oshaxColor,
                      'cells': cells,
                    });
                  }
                }
              });
            }
          : null,
      child: Container(
        margin: const EdgeInsets.all(0.8),
        decoration: BoxDecoration(
          color: val > 0
              ? _catColor(val)
              : cs.surfaceContainerHighest
                  .withValues(alpha: room.isEven ? 0.45 : 0.28),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isPicked
                ? Colors.amberAccent
                : (mapCol > 0 && val == 0
                    ? _catColor(mapCol)
                    : cs.outline.withValues(alpha: 0.25)),
            width: isPicked ? 2.0 : (mapCol > 0 && val == 0 ? 1.5 : 0.6),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: Text(
                val > 0
                    ? isleCatTypeEmojis[val]
                    : (isPicked
                        ? '#${pickedIdx + 1}'
                        : (hasRat
                            ? '🐀'
                            : (mapCol > 0
                                ? '🗺️${isleCatTypeEmojis[mapCol]}'
                                : 'R${room + 1}'))),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: val > 0
                      ? Colors.white
                      : cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
