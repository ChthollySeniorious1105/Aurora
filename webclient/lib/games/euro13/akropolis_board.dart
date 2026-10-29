import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro13/akropolis.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class AkropolisBoard extends StatefulWidget {
  final GameContext g;
  const AkropolisBoard(this.g, {super.key});

  @override
  State<AkropolisBoard> createState() => _AkropolisBoardState();
}

class _AkropolisBoardState extends State<AkropolisBoard> {
  int _selectedSlot = 0;
  int? _inspectSeat;
  final List<(int, int)> _pickedCells = [];

  Color _typeColor(int type) {
    return switch (type) {
      0 => const Color(0xFF78909C), // Quarry Grey
      1 => const Color(0xFF1E88E5), // Housing Blue
      2 => const Color(0xFFFBC02D), // Market Yellow
      3 => const Color(0xFFE53935), // Barracks Red
      4 => const Color(0xFF8E24AA), // Temple Purple
      5 => const Color(0xFF43A047), // Garden Green
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final gridSize = asInt(v['gridSize'], 7);
    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 9);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final market = (v['market'] as List?) ?? const [];
    final validTriples = (v['validTriples'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    if (_selectedSlot >= market.length) {
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
    final myStones = asInt(myData['stones'], 0);

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
                                    ? '轮到你！选工地板块并点 3 个同高度相邻六角格筑城 · $lastAction'
                                    : '等待 ${g.name(turn)} 筑城 · $lastAction'),
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
                          '🏛️第 $round/$maxRounds 轮',
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
                        final st = asInt(pd['stones'], 0);
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
                              sub: '⭐$sc分 · ⬜$st石',
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
                                child: _buildMarketPanel(
                                  market,
                                  validTriples,
                                  myStones,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildCityPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
                                  isMyTurn && viewSeat == g.seat,
                                  myStones,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildMarketPanel(
                                  market,
                                  validTriples,
                                  myStones,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildCityPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
                                  isMyTurn && viewSeat == g.seat,
                                  myStones,
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
                '雅典卫城终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketPanel(
    List<dynamic> market,
    List<dynamic> validTriples,
    int myStones,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final canAffordSlot = _selectedSlot <= myStones;
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
              const Flexible(
                child: Text(
                  '🏗️ 卫城施工工地（拿取第 k 块需支付 k 枚石材）',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (isMyTurn &&
                  canAffordSlot &&
                  validTriples.isNotEmpty &&
                  _selectedSlot < market.length)
                InkWell(
                  onTap: () {
                    final firstTriple = validTriples.first as List;
                    widget.g.act({
                      'type': 'build',
                      'slot': _selectedSlot,
                      'cells': firstTriple,
                    });
                    setState(() => _pickedCells.clear());
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚡快捷筑城',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              itemCount: market.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, slot) {
                final tm = (market[slot] as Map).cast<String, dynamic>();
                final cells = (tm['cells'] as List?) ?? const [];
                final affordable = slot <= myStones;
                final selected = _selectedSlot == slot;

                return GestureDetector(
                  onTap: () => setState(() => _selectedSlot = slot),
                  child: Opacity(
                    opacity: affordable ? 1.0 : 0.55,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primaryContainer.withValues(alpha: 0.7)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
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
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              slot == 0 ? '免费' : '⬜×$slot',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                for (var i = 0; i < cells.length; i++)
                                  Expanded(
                                    child: _buildMiniCellChip(
                                      (cells[i] as Map).cast<String, dynamic>(),
                                    ),
                                  ),
                              ],
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

  Widget _buildMiniCellChip(Map<String, dynamic> cell) {
    final t = asInt(cell['type'], 0);
    final isPlaza = asBool(cell['isPlaza']);
    final stars = asInt(cell['stars'], 0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: _typeColor(t),
        borderRadius: BorderRadius.circular(6),
        border: isPlaza
            ? Border.all(color: Colors.amberAccent, width: 1.5)
            : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          isPlaza
              ? '${'★' * stars}${akropolisTypeNames[t]}广场'
              : '${akropolisTypeEmojis[t]}${akropolisTypeNames[t]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCityPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int gridSize,
    bool canAct,
    int myStones,
    ColorScheme cs,
  ) {
    final heightMat = (viewData['height'] as List?) ?? const [];
    final typeMat = (viewData['topType'] as List?) ?? const [];
    final plazaMat = (viewData['topIsPlaza'] as List?) ?? const [];
    final starsMat = (viewData['topStars'] as List?) ?? const [];
    final breakdown = (viewData['colorBreakdown'] as List?) ?? const [];

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
                  '${widget.g.name(viewSeat)} 的卫城 ($gridSize×$gridSize)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (_pickedCells.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _pickedCells.clear()),
                  child: Text(
                    '已选 ${_pickedCells.length}/3 格 (重选)',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  for (final b in breakdown)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Builder(builder: (context) {
                        final bm = (b as Map).cast<String, dynamic>();
                        final col = asInt(bm['color'], 1);
                        final st = asInt(bm['stars'], 0);
                        final ht = asInt(bm['heights'], 0);
                        final vp = asInt(bm['vp'], 0);
                        return Text(
                          '${akropolisTypeEmojis[col]}★$st×高$ht=$vp',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        );
                      }),
                    ),
                ],
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
                    for (var r = 0; r < gridSize; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < gridSize; c++)
                              Expanded(
                                child: _buildCityCell(
                                  r,
                                  c,
                                  _matInt(heightMat, r, c, 0),
                                  _matInt(typeMat, r, c, -1),
                                  _matBool(plazaMat, r, c),
                                  _matInt(starsMat, r, c, 0),
                                  canAct && _selectedSlot <= myStones,
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

  Widget _buildCityCell(
    int r,
    int c,
    int h,
    int t,
    bool isPlaza,
    int stars,
    bool canAct,
    ColorScheme cs,
  ) {
    final pickedIdx = _pickedCells.indexOf((r, c));
    final isPicked = pickedIdx >= 0;

    return GestureDetector(
      onTap: canAct
          ? () {
              setState(() {
                if (isPicked) {
                  _pickedCells.removeAt(pickedIdx);
                } else {
                  _pickedCells.add((r, c));
                  if (_pickedCells.length == 3) {
                    final cells = [
                      for (final (pr, pc) in _pickedCells) [pr, pc],
                    ];
                    _pickedCells.clear();
                    widget.g.act({
                      'type': 'build',
                      'slot': _selectedSlot,
                      'cells': cells,
                    });
                  }
                }
              });
            }
          : null,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: h > 0
              ? _typeColor(t)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPicked
                ? Colors.amberAccent
                : (isPlaza
                    ? Colors.white
                    : cs.outline.withValues(alpha: 0.25)),
            width: isPicked ? 2.2 : (isPlaza ? 1.5 : 0.7),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: h > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPlaza ? '★' * stars : akropolisTypeEmojis[t],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${h}F',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      isPicked ? '#${pickedIdx + 1}' : '·',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPicked
                            ? Colors.amberAccent
                            : cs.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
