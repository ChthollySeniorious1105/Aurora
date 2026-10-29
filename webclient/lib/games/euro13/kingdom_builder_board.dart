import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro13/kingdom_builder.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class KingdomBuilderBoard extends StatefulWidget {
  final GameContext g;
  const KingdomBuilderBoard(this.g, {super.key});

  @override
  State<KingdomBuilderBoard> createState() => _KingdomBuilderBoardState();
}

class _KingdomBuilderBoardState extends State<KingdomBuilderBoard> {
  int? _inspectSeat;

  Color _terrainColor(int t) {
    return switch (t) {
      0 => const Color(0xFF66BB6A), // Grass
      1 => const Color(0xFF8D6E63), // Canyon
      2 => const Color(0xFFE6B800), // Desert
      3 => const Color(0xFFEC407A), // Flower
      4 => const Color(0xFF2E7D32), // Forest
      5 => const Color(0xFF5C6BC0), // Castle
      _ => Colors.blueGrey,
    };
  }

  Color _seatColor(int seat) {
    return switch (seat) {
      0 => const Color(0xFFE53935),
      1 => const Color(0xFF1E88E5),
      2 => const Color(0xFFFFB300),
      3 => const Color(0xFF8E24AA),
      _ => Colors.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final mapSize = asInt(v['mapSize'], 8);
    final map = (v['map'] as List?) ?? const [];
    final owner = (v['owner'] as List?) ?? const [];
    final activeCards = asIntList(v['activeCards']);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final validList = (v['validCells'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final validSet = <(int, int)>{
      for (final item in validList)
        if (item is List && item.length >= 2) (asInt(item[0]), asInt(item[1])),
    };

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
                                ? '王国建造终局 · $lastAction'
                                : (isMyTurn
                                    ? '轮到你！必须在手牌地形的高亮格建造聚落（优先相邻） · $lastAction'
                                    : '等待 ${g.name(turn)} 建造聚落 · $lastAction'),
                            highlight: isMyTurn,
                          ),
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
                        final ht = asInt(pd['handTerrain'], 0);
                        final left = asInt(pd['settlementsLeft'], 0);
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
                              sub: '${kbTerrainEmojis[ht]}${kbTerrainNames[ht]} · 🏠余$left · ⭐$sc',
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
                                flex: 4,
                                child: _buildCardsPanel(
                                  activeCards,
                                  viewSeat,
                                  viewData,
                                  validSet,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildMapPanel(
                                  mapSize,
                                  map,
                                  owner,
                                  validSet,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildCardsPanel(
                                  activeCards,
                                  viewSeat,
                                  viewData,
                                  validSet,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildMapPanel(
                                  mapSize,
                                  map,
                                  owner,
                                  validSet,
                                  isMyTurn,
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
                '王国建造者终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardsPanel(
    List<int> activeCards,
    int viewSeat,
    Map<String, dynamic> viewData,
    Set<(int, int)> validSet,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final ht = asInt(viewData['handTerrain'], 0);
    final castleVp = asInt(viewData['castleVp'], 0);
    final cardVp = asIntList(viewData['cardVp']);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '🃏 ${widget.g.name(viewSeat)} 手牌地形: ${kbTerrainEmojis[ht]}${kbTerrainNames[ht]}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Text(
                '🏰城堡得分: +$castleVp',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              itemCount: activeCards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 3),
              itemBuilder: (context, idx) {
                final cid = activeCards[idx];
                final vp = idx < cardVp.length ? cardVp[idx] : 0;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '👑【${kbCardNames[cid]}】${kbCardDescs[cid]}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+$vp分',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPanel(
    int mapSize,
    List<dynamic> map,
    List<dynamic> owner,
    Set<(int, int)> validSet,
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
        children: [
          const Text(
            '🗺️ 8×8 王国六角版图（遵循相邻强制规则，点击高亮地形格放置聚落）',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Column(
                  children: [
                    for (var r = 0; r < mapSize; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < mapSize; c++)
                              Expanded(
                                child: _buildHexCell(
                                  r,
                                  c,
                                  _matInt(map, r, c, 0),
                                  _matInt(owner, r, c, -1),
                                  isMyTurn && validSet.contains((r, c)),
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

  Widget _buildHexCell(
    int r,
    int c,
    int terrain,
    int cellOwner,
    bool clickable,
  ) {
    return GestureDetector(
      onTap: clickable
          ? () => widget.g.act({
                'type': 'build',
                'cells': [
                  [r, c],
                ],
              })
          : null,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: _terrainColor(terrain),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: clickable
                ? Colors.yellowAccent
                : (cellOwner >= 0 ? Colors.white : Colors.black26),
            width: clickable ? 2.0 : (cellOwner >= 0 ? 1.4 : 0.6),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: cellOwner >= 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: _seatColor(cellOwner),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '🏠P${cellOwner + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    )
                  : Text(
                      kbTerrainEmojis[terrain],
                      style: const TextStyle(fontSize: 10),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
