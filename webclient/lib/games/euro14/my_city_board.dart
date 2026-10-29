import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro14/my_city.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class MyCityBoard extends StatefulWidget {
  final GameContext g;
  const MyCityBoard(this.g, {super.key});

  @override
  State<MyCityBoard> createState() => _MyCityBoardState();
}

class _MyCityBoardState extends State<MyCityBoard> {
  int? _inspectSeat;
  final List<(int, int)> _pickedCells = [];

  Color _buildingColor(int b) {
    return switch (b) {
      1 => const Color(0xFFFBC02D), // Yellow
      2 => const Color(0xFFE53935), // Red
      3 => const Color(0xFF1E88E5), // Blue
      _ => Colors.blueGrey,
    };
  }

  Color _terrainBg(int t, ColorScheme cs) {
    return switch (t) {
      0 => const Color(0xFF66BB6A).withValues(alpha: 0.35), // Meadow
      1 => const Color(0xFF2E7D32).withValues(alpha: 0.55), // Tree
      2 => const Color(0xFF78909C).withValues(alpha: 0.55), // Rock
      3 => const Color(0xFFFFB300).withValues(alpha: 0.55), // Gold
      4 => const Color(0xFF455A64).withValues(alpha: 0.8), // Mountain
      _ => cs.surfaceContainerHighest,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final gridSize = asInt(v['gridSize'], 8);
    final cardIndex = asInt(v['cardIndex'], 1);
    final maxCards = asInt(v['maxCards'], 18);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final curCard = (v['currentCard'] as Map?)?.cast<String, dynamic>();
    final validPlacements = (v['validPlacements'] as List?) ?? const [];
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
                                    ? '轮到你！在 8×8 版图放置建筑卡、跳过(-1分)或封顶休整 · $lastAction'
                                    : '等待 ${g.name(turn)} 规划城市 · $lastAction'),
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
                          '🏙️卡牌 $cardIndex/$maxCards',
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
                        final ret = asBool(pd['retired']);
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
                              sub: '⭐$sc分${ret ? ' · 已封顶' : ''}',
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
                                child: _buildCardPanel(
                                  curCard,
                                  validPlacements,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildCityGridPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
                                  curCard,
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
                                child: _buildCardPanel(
                                  curCard,
                                  validPlacements,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildCityGridPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
                                  curCard,
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
                '我的城市终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardPanel(
    Map<String, dynamic>? curCard,
    List<dynamic> validPlacements,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final cCol = curCard != null ? asInt(curCard['color'], 1) : 1;
    final cName = curCard != null ? asStr(curCard['name']) : '无';
    final shape = (curCard?['shape'] as List?) ?? const [];

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
                  '📐 当前揭示建筑卡与决策',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (isMyTurn && validPlacements.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () {
                      widget.g.act({
                        'type': 'build',
                        'cells': validPlacements.first,
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
                        '⚡快捷建造',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isMyTurn) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => widget.g.act({'type': 'pass'}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⏭️跳过(-1)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => widget.g.act({'type': 'retire'}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🏁封顶(0罚)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (curCard != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _buildingColor(cCol),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${myCityBuildingEmojis[cCol]} $cName (${shape.length} 格骨牌 · 首栋须紧邻第3/4行中央河流，单栋不可跨河)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              children: [
                const Text(
                  '📍 推荐合法建造位置（点击直接建造）：',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < validPlacements.length; i++)
                      Builder(builder: (context) {
                        final pl = validPlacements[i] as List;
                        final coordStr = [
                          for (final c in pl) '(${c[0]},${c[1]})'
                        ].join('');
                        return InkWell(
                          onTap: isMyTurn
                              ? () => widget.g.act({
                                    'type': 'build',
                                    'cells': pl,
                                  })
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '方案#${i + 1}: $coordStr',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityGridPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int gridSize,
    Map<String, dynamic>? curCard,
    bool canAct,
    ColorScheme cs,
  ) {
    final boardMat = (viewData['board'] as List?) ?? const [];
    final buildingMat = (viewData['building'] as List?) ?? const [];
    final trees = asInt(viewData['trees'], 0);
    final rocks = asInt(viewData['rocks'], 0);
    final emptyMeadows = asInt(viewData['emptyMeadows'], 0);
    final coveredGold = asInt(viewData['coveredGold'], 0);
    final squareBlocks = asInt(viewData['squareBlocks'], 0);

    final targetLen =
        curCard != null ? ((curCard['shape'] as List?)?.length ?? 3) : 3;

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
                  '🏞️ ${widget.g.name(viewSeat)} 的河畔城市 ($gridSize×$gridSize)',
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
                '🌳树+$trees · 🪨石-$rocks · 🟩空草-$emptyMeadows · 🪙金+${coveredGold * 2} · 2×2街区+${squareBlocks * 4}',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Column(
                  children: [
                    for (var r = 0; r < gridSize; r++) ...[
                      if (r == 4)
                        Container(
                          height: 3,
                          color: Colors.lightBlueAccent,
                        ),
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < gridSize; c++)
                              Expanded(
                                child: _buildCell(
                                  r,
                                  c,
                                  _matInt(boardMat, r, c, 0),
                                  _matInt(buildingMat, r, c, 0),
                                  targetLen,
                                  canAct,
                                  cs,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
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

  Widget _buildCell(
    int r,
    int c,
    int terrain,
    int bldg,
    int targetLen,
    bool canAct,
    ColorScheme cs,
  ) {
    final pickedIdx = _pickedCells.indexOf((r, c));
    final isPicked = pickedIdx >= 0;

    return GestureDetector(
      onTap: canAct && bldg == 0 && terrain != 4
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
                      'type': 'build',
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
          color: bldg > 0
              ? _buildingColor(bldg)
              : _terrainBg(terrain, cs),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isPicked
                ? Colors.amberAccent
                : (r == 3 || r == 4
                    ? Colors.lightBlueAccent.withValues(alpha: 0.7)
                    : cs.outline.withValues(alpha: 0.25)),
            width: isPicked ? 2.0 : 0.8,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: Text(
                bldg > 0
                    ? myCityBuildingEmojis[bldg]
                    : (isPicked
                        ? '#${pickedIdx + 1}'
                        : myCityTerrainEmojis[terrain]),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: bldg > 0 ? Colors.white : cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
