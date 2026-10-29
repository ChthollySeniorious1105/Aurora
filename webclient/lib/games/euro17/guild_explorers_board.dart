import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro17/guild_explorers.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class GuildExplorersBoard extends StatefulWidget {
  final GameContext g;
  const GuildExplorersBoard(this.g, {super.key});

  @override
  State<GuildExplorersBoard> createState() => _GuildExplorersBoardState();
}

class _GuildExplorersBoardState extends State<GuildExplorersBoard> {
  final List<(int, int)> _selectedCells = [];
  int? _inspectSeat;

  static const List<Color> _terrainColors = [
    Color(0xFF0277BD), // 0: 🌊 海洋
    Color(0xFF558B2F), // 1: 🌾 平原
    Color(0xFF5D4037), // 2: ⛰️ 山脉
    Color(0xFFF9A825), // 3: 🏜️ 沙漠
    Color(0xFF6A1B9A), // 4: 🗼 发现塔
    Color(0xFFBF360C), // 5: 🏚️ 宝藏遗迹
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final era = asInt(v['era'], 1);
    final maxEras = asInt(v['maxEras'], 4);
    final cardStep = asInt(v['cardStep'], 1);
    final cardsPerEra = asInt(v['cardsPerEra'], 5);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final currentCard =
        (v['currentCard'] as Map?)?.cast<String, dynamic>() ?? const {};
    final terrain = (v['terrain'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat = (_inspectSeat != null && _inspectSeat! < pList.length)
        ? _inspectSeat!
        : mySeat;
    final isMyTurn = !over && g.seat == turn;
    final maxCells = asInt(currentCard['maxCells'], 2);

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
                                    ? '轮到你！点选7×7王国地图相连地形格放置探索方块，再点确认探索 · $lastAction'
                                    : '等待 ${g.name(turn)} 勘探 · $lastAction'),
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
                          '🧭第 $era/$maxEras 时代 · 卡 $cardStep/$cardsPerEra',
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
                        final vvp = asInt(pd['villageVp'], 0);
                        final tcn = asInt(pd['towerCoins'], 0);
                        final rcn = asInt(pd['treasureCoins'], 0);
                        final vCnt = asInt(pd['villageCount'], 0);
                        final tCnt = asInt(pd['towerCount'], 0);
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
                                  '⭐$sc分 (🏠$vCnt座/$vvp分 🗼$tCnt座/$tcn🪙 🏚️$rcn🪙)',
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
                                flex: 4,
                                child: _buildCardAndActionPanel(
                                  currentCard,
                                  maxCells,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildMapPanel(
                                  viewSeat,
                                  terrain,
                                  viewData,
                                  isMyTurn && viewSeat == mySeat,
                                  maxCells,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildCardAndActionPanel(
                                  currentCard,
                                  maxCells,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildMapPanel(
                                  viewSeat,
                                  terrain,
                                  viewData,
                                  isMyTurn && viewSeat == mySeat,
                                  maxCells,
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
                '探索者公会终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardAndActionPanel(
    Map<String, dynamic> currentCard,
    int maxCells,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: const Text(
              '📜 当前探索指令卡 & 时代规则',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary, width: 1.5),
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${currentCard['emoji'] ?? '🧭'} ${currentCard['name'] ?? '探索令'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '可探索地形: ${currentCard['terrainEmoji'] ?? ''} ${currentCard['terrainName'] ?? ''} (含🗼发现塔/🏚️遗迹)',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '本回合最多放置: $maxCells 枚探索方块 (已选 ${_selectedCells.length}/$maxCells)',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '💡 从🏰(3,3)或🏠永久村落出发；完整探索同色相连区立建🏠村落(跨时代保留)',
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (!isMyTurn || _selectedCells.isEmpty)
                      ? null
                      : () {
                          final cells = [
                            for (final (r, c) in _selectedCells) [r, c],
                          ];
                          setState(() => _selectedCells.clear());
                          widget.g.act({
                            'type': 'explore',
                            'cells': cells,
                          });
                        },
                  icon: const Icon(Icons.explore, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('确认探索 (${_selectedCells.length}/$maxCells)'),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _selectedCells.isEmpty
                    ? null
                    : () => setState(() => _selectedCells.clear()),
                child: const Text('重选', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapPanel(
    int viewSeat,
    List<dynamic> terrain,
    Map<String, dynamic> viewData,
    bool canActHere,
    int maxCells,
    ColorScheme cs,
  ) {
    final explored = (viewData['explored'] as List?) ?? const [];
    final villages = (viewData['villages'] as List?) ?? const [];
    final towers = (viewData['towers'] as List?) ?? const [];
    final ruins = (viewData['ruins'] as List?) ?? const [];

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
              '🗺️ ${widget.g.name(viewSeat)} 的 7×7 王国地图 (🏰王都(3,3) · 🏠永久村落 · 🧭已探索 · 点选格子加入探索队列)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < GuildExplorersGame.mapSize; r++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          for (var c = 0; c < GuildExplorersGame.mapSize; c++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                child: _buildMapCell(
                                  r,
                                  c,
                                  (r < terrain.length &&
                                          c < (terrain[r] as List).length)
                                      ? asInt((terrain[r] as List)[c], 0)
                                      : 0,
                                  (r < explored.length &&
                                          c < (explored[r] as List).length)
                                      ? asBool((explored[r] as List)[c])
                                      : false,
                                  (r < villages.length &&
                                          c < (villages[r] as List).length)
                                      ? asBool((villages[r] as List)[c])
                                      : false,
                                  (r < towers.length &&
                                          c < (towers[r] as List).length)
                                      ? asBool((towers[r] as List)[c])
                                      : false,
                                  (r < ruins.length &&
                                          c < (ruins[r] as List).length)
                                      ? asBool((ruins[r] as List)[c])
                                      : false,
                                  canActHere,
                                  maxCells,
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
        ],
      ),
    );
  }

  Widget _buildMapCell(
    int r,
    int c,
    int t,
    bool isExplored,
    bool hasVillage,
    bool hasTower,
    bool hasRuin,
    bool canActHere,
    int maxCells,
    ColorScheme cs,
  ) {
    final isCapital =
        r == GuildExplorersGame.capR && c == GuildExplorersGame.capC;
    final sel = _selectedCells.contains((r, c));
    final tColor = _terrainColors[t.clamp(0, _terrainColors.length - 1)];

    String badge = '';
    if (isCapital) {
      badge = '🏰王都';
    } else if (hasVillage) {
      badge = isExplored ? '🏠+🧭' : '🏠村落';
    } else if (isExplored) {
      badge = '🧭已探';
    } else if (hasTower) {
      badge = '🗼已登';
    } else if (hasRuin) {
      badge = '🏚️已掘';
    }

    return GestureDetector(
      onTap: (!canActHere || isExplored)
          ? null
          : () => setState(() {
                if (sel) {
                  _selectedCells.remove((r, c));
                } else if (_selectedCells.length < maxCells) {
                  _selectedCells.add((r, c));
                }
              }),
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: sel
              ? Colors.amber.withValues(alpha: 0.45)
              : tColor.withValues(alpha: isExplored ? 0.36 : 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel
                ? Colors.amber
                : (hasVillage
                    ? Colors.greenAccent
                    : (isExplored ? tColor : tColor.withValues(alpha: 0.45))),
            width: (sel || hasVillage || isCapital) ? 1.8 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCapital
                    ? '🏰(3,3)'
                    : '${guildTerrainEmojis[t.clamp(0, 5)]}($r,$c)',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              ),
              if (badge.isNotEmpty)
                Text(
                  badge,
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
