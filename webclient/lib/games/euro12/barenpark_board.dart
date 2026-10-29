import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro12/barenpark.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class BarenparkBoard extends StatefulWidget {
  final GameContext g;
  const BarenparkBoard(this.g, {super.key});

  @override
  State<BarenparkBoard> createState() => _BarenparkBoardState();
}

class _BarenparkBoardState extends State<BarenparkBoard> {
  int _selectedInvIdx = 0;
  int _rot = 0;
  bool _flip = false;
  int? _inspectSeat;
  String? _preferredSupplyKey;

  Color _tileColor(String bearType, ColorScheme cs) {
    return switch (bearType) {
      'green' => const Color(0xFF43A047),
      'koala' => const Color(0xFF8D6E63),
      'panda' => const Color(0xFF546E7A),
      'polar' => const Color(0xFF0288D1),
      'gobi' => const Color(0xFFD84315),
      _ => cs.primary,
    };
  }

  String _iconEmoji(int ic) {
    return switch (ic) {
      1 => '🚧',
      2 => '🚚',
      3 => '🏗️',
      4 => '🗽',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final rows = asInt(v['rows'], 6);
    final cols = asInt(v['cols'], 8);
    final zoneCols = asInt(v['zoneCols'], 4);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final statues = asIntList(v['statues']);
    final supplyMap =
        (v['supply'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat =
        (_inspectSeat != null && _inspectSeat! < pList.length)
            ? _inspectSeat!
            : mySeat;
    final isMyTurn = !over && g.seat == turn;

    final myData = (pList.isNotEmpty && mySeat < pList.length)
        ? (pList[mySeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final viewData = (pList.isNotEmpty && viewSeat < pList.length)
        ? (pList[viewSeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final myInv = (myData['inventory'] as List?) ?? const [];
    if (_selectedInvIdx >= myInv.length) {
      _selectedInvIdx = 0;
    }

    Map<String, dynamic>? selectedTileMap;
    List<(int, int)> selectedShape = const [];
    if (myInv.isNotEmpty && _selectedInvIdx < myInv.length) {
      selectedTileMap = (myInv[_selectedInvIdx] as Map).cast<String, dynamic>();
      final key = asStr(selectedTileMap['key']);
      final def = barenTileByKey[key];
      if (def != null) {
        selectedShape = transformCells(def.cells, _rot, _flip);
      }
    }

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
                  // Top Bar: Status + Player Switcher
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
                                    ? '轮到你放置板块！点击空地拼放或跳过 · $lastAction'
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
                          color: cs.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🗽雕像余 ${statues.length} (最高${statues.isEmpty ? 0 : statues.first}分)',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Player tags
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, s) {
                        final pd = (pList[s] as Map).cast<String, dynamic>();
                        final sc = asInt(pd['score'], 0);
                        final invLen = ((pd['inventory'] as List?) ?? const []).length;
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
                              sub: '$sc分 · 库存$invLen',
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Main Body
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildParkArea(
                                  context,
                                  viewSeat,
                                  viewData,
                                  rows,
                                  cols,
                                  zoneCols,
                                  isMyTurn && viewSeat == g.seat,
                                  selectedShape,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: _buildSidePanel(
                                  context,
                                  myInv,
                                  selectedShape,
                                  supplyMap,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildParkArea(
                                  context,
                                  viewSeat,
                                  viewData,
                                  rows,
                                  cols,
                                  zoneCols,
                                  isMyTurn && viewSeat == g.seat,
                                  selectedShape,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 5,
                                child: _buildSidePanel(
                                  context,
                                  myInv,
                                  selectedShape,
                                  supplyMap,
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
                '熊熊公园终局结算 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParkArea(
    BuildContext context,
    int viewSeat,
    Map<String, dynamic> viewData,
    int rows,
    int cols,
    int zoneCols,
    bool canActOnGrid,
    List<(int, int)> selectedShape,
    ColorScheme cs,
  ) {
    final iconsGrid = (viewData['icons'] as List?) ?? const [];
    final grid = (viewData['grid'] as List?) ?? const [];
    final zoneStatues = (viewData['zoneStatues'] as List?) ?? const [];
    final placedList = (viewData['placedTiles'] as List?) ?? const [];

    // Map each (r,c) to its placed tile info for rich display
    final cellTileInfo = <(int, int), Map<String, dynamic>>{};
    for (final p in placedList) {
      final pm = (p as Map).cast<String, dynamic>();
      final tMap = (pm['tile'] as Map).cast<String, dynamic>();
      final abs = (pm['absCells'] as List?) ?? const [];
      for (var i = 0; i < abs.length; i++) {
        final pair = abs[i] as List;
        final ar = asInt(pair[0]);
        final ac = asInt(pair[1]);
        cellTileInfo[(ar, ac)] = {
          ...tMap,
          'isAnchor': i == 0,
        };
      }
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.82),
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
                  '${widget.g.name(viewSeat)} 的公园 ($cols×$rows)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (var z = 0; z < 4; z++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (z < zoneStatues.length &&
                                zoneStatues[z] != null)
                            ? Colors.amber.withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '园${z + 1}:${(z < zoneStatues.length && zoneStatues[z] != null) ? "🗽+${zoneStatues[z]}" : "未满"}',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: cols / rows,
                child: LayoutBuilder(
                  builder: (context, box) {
                    return Column(
                      children: [
                        for (var r = 0; r < rows; r++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var c = 0; c < cols; c++)
                                  Expanded(
                                    child: _buildParkCell(
                                      r,
                                      c,
                                      zoneCols,
                                      iconsGrid,
                                      grid,
                                      zoneStatues,
                                      cellTileInfo[(r, c)],
                                      canActOnGrid,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkCell(
    int r,
    int c,
    int zoneCols,
    List<dynamic> iconsGrid,
    List<dynamic> grid,
    List<dynamic> zoneStatues,
    Map<String, dynamic>? tileInfo,
    bool canActOnGrid,
    ColorScheme cs,
  ) {
    final ic = (r < iconsGrid.length && c < (iconsGrid[r] as List).length)
        ? asInt((iconsGrid[r] as List)[c], 0)
        : 0;
    final cellKey = (r < grid.length && c < (grid[r] as List).length)
        ? (grid[r] as List)[c] as String?
        : null;
    final zoneIdx = (r ~/ 3) * 2 + (c ~/ zoneCols);
    final zoneStatueVp =
        zoneIdx < zoneStatues.length ? zoneStatues[zoneIdx] as int? : null;

    final isZoneRightEdge = c == zoneCols - 1;
    final isZoneBottomEdge = r == 2;

    Color bgColor;
    String label = '';
    if (tileInfo != null) {
      bgColor = _tileColor(asStr(tileInfo['bearType']), cs);
      final isAnchor = asBool(tileInfo['isAnchor']);
      final vp = asInt(tileInfo['vp'], 0);
      label = isAnchor
          ? '${tileInfo['emoji']}${vp > 0 ? "$vp" : ""}'
          : '${tileInfo['emoji']}';
    } else if (ic == 4) {
      bgColor = zoneStatueVp != null
          ? Colors.amber.shade700
          : Colors.brown.shade300.withValues(alpha: 0.55);
      label = zoneStatueVp != null ? '🗽+$zoneStatueVp' : '🗽';
    } else {
      bgColor = (zoneIdx == 0)
          ? Colors.green.withValues(alpha: 0.18)
          : cs.surfaceContainerHighest.withValues(alpha: 0.55);
      label = _iconEmoji(ic);
    }

    return GestureDetector(
      onTap: canActOnGrid && cellKey == null && ic != 4
          ? () {
              widget.g.act({
                'type': 'place',
                'invIdx': _selectedInvIdx,
                'r': r,
                'c': c,
                'rot': _rot,
                'flip': _flip,
                if (_preferredSupplyKey != null)
                  'gains': [
                    _preferredSupplyKey!,
                    _preferredSupplyKey!,
                    _preferredSupplyKey!
                  ],
              });
            }
          : null,
      child: Container(
        margin: EdgeInsets.only(
          right: isZoneRightEdge ? 2.5 : 0.8,
          bottom: isZoneBottomEdge ? 2.5 : 0.8,
          left: 0.8,
          top: 0.8,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: ic == 4
                ? Colors.amber.shade600
                : cs.outline.withValues(alpha: 0.35),
            width: ic == 4 ? 1.5 : 0.8,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: tileInfo != null ? Colors.white : cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    List<dynamic> myInv,
    List<(int, int)> selectedShape,
    Map<String, dynamic> supplyMap,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Controls row: Rotate, Flip, Pass
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '个人板块库存',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   InkWell(
                    onTap: () => setState(() => _rot = (_rot + 1) & 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🔄旋转(${_rot * 90}°)',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _flip = !_flip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _flip
                            ? cs.tertiaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '↔️翻转${_flip ? "(开)" : ""}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (isMyTurn) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => widget.g.act({'type': 'pass'}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⏭️跳过(+1×1)',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cs.onErrorContainer),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Inventory list
          SizedBox(
            height: 54,
            child: myInv.isEmpty
                ? const Center(
                    child: Text('库存为空，请点击跳过领取 1×1 绿地',
                        style: TextStyle(fontSize: 11)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: myInv.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final tm =
                          (myInv[idx] as Map).cast<String, dynamic>();
                      final sel = idx == _selectedInvIdx;
                      final key = asStr(tm['key']);
                      final def = barenTileByKey[key];
                      final cells = def != null
                          ? transformCells(
                              def.cells, sel ? _rot : 0, sel ? _flip : false)
                          : const <(int, int)>[];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedInvIdx = idx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel
                                ? cs.primaryContainer
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? cs.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _miniPolyomino(
                                cells,
                                _tileColor(asStr(tm['bearType']), cs),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${tm['emoji']}${tm['name']}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${tm['vp']}分 · ${cells.length}格',
                                    style: const TextStyle(fontSize: 10),
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
          const Divider(height: 8),
          const Text(
            '公共供应区（点击可设为覆盖施工图标时的优先拿取项）',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final d in barenTileDefs)
                    _buildSupplyChip(d, supplyMap[d.key], cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplyChip(
      BarenTileDef def, Object? rawInfo, ColorScheme cs) {
    final info = rawInfo is Map
        ? rawInfo.cast<String, dynamic>()
        : const <String, dynamic>{};
    final count = asInt(info['count'], 0);
    final topVp = asInt(info['topVp'], 0);
    final selected = _preferredSupplyKey == def.key;
    final tierIcon = _iconEmoji(def.tier);

    return GestureDetector(
      onTap: () => setState(() {
        _preferredSupplyKey = selected ? null : def.key;
      }),
      child: Opacity(
        opacity: count > 0 ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer
                : cs.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? cs.primary : cs.outline.withValues(alpha: 0.25),
              width: selected ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$tierIcon${def.emoji}${def.name}',
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                count > 0 ? '$topVp分(×$count)' : '售罄',
                style: TextStyle(
                  fontSize: 10,
                  color: count > 0 ? cs.primary : cs.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniPolyomino(List<(int, int)> cells, Color color) {
    if (cells.isEmpty) return const SizedBox(width: 24, height: 24);
    var maxR = 0;
    var maxC = 0;
    final set = cells.toSet();
    for (final (r, c) in cells) {
      if (r > maxR) maxR = r;
      if (c > maxC) maxC = c;
    }
    return SizedBox(
      width: 28,
      height: 28,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r <= maxR; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c <= maxC; c++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.all(0.6),
                      decoration: BoxDecoration(
                        color: set.contains((r, c))
                            ? color
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
