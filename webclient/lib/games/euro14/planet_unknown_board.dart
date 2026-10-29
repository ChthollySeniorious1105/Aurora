import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro14/planet_unknown.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class PlanetUnknownBoard extends StatefulWidget {
  final GameContext g;
  const PlanetUnknownBoard(this.g, {super.key});

  @override
  State<PlanetUnknownBoard> createState() => _PlanetUnknownBoardState();
}

class _PlanetUnknownBoardState extends State<PlanetUnknownBoard> {
  int _selectedSlot = 0;
  int? _inspectSeat;
  final List<(int, int)> _pickedCells = [];

  Color _trackColor(int t) {
    return switch (t) {
      0 => const Color(0xFF43A047), // Civ Green
      1 => const Color(0xFF0288D1), // Water Blue
      2 => const Color(0xFF7CB342), // Biomass Lime
      3 => const Color(0xFFF57C00), // Rover Orange
      4 => const Color(0xFF5E35B1), // Tech Purple
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
    final maxRounds = asInt(v['maxRounds'], 10);
    final susanRot = asInt(v['susanRot'], 0);
    final phase = asStr(v['phase'], 'rotate');
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final depots = (v['depots'] as List?) ?? const [];
    final validBySlot = (v['validBySlot'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

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
    final myDepotIdx = asInt(myData['depotIdx'], (susanRot + mySeat) % 6);

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
                                ? '行星改造完成 · $lastAction'
                                : (isMyTurn
                                    ? (phase == 'rotate'
                                        ? '轮到指挥官旋转 S.U.S.A.N. 空间站 · $lastAction'
                                        : '轮到你从舱位 #${myDepotIdx + 1} 选双地形骨牌改造行星 · $lastAction')
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
                          '🪐第 $round/$maxRounds 轮 · 旋#$susanRot',
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
                        final dIdx = asInt(pd['depotIdx'], 0);
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
                              sub: '⭐$sc分 · 舱#${dIdx + 1}',
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
                                child: _buildSusanPanel(
                                  depots,
                                  validBySlot,
                                  myDepotIdx,
                                  susanRot,
                                  phase,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildPlanetPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
                                  depots,
                                  myDepotIdx,
                                  isMyTurn &&
                                      phase == 'place' &&
                                      viewSeat == g.seat,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildSusanPanel(
                                  depots,
                                  validBySlot,
                                  myDepotIdx,
                                  susanRot,
                                  phase,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildPlanetPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
                                  depots,
                                  myDepotIdx,
                                  isMyTurn &&
                                      phase == 'place' &&
                                      viewSeat == g.seat,
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
                '未知行星终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSusanPanel(
    List<dynamic> depots,
    List<dynamic> validBySlot,
    int myDepotIdx,
    int susanRot,
    String phase,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final slotValid = (_selectedSlot < validBySlot.length)
        ? (validBySlot[_selectedSlot] as List)
        : const [];

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
              Expanded(
                child: Text(
                  '🛸 S.U.S.A.N. 旋转空间站 (你的补给舱 #${myDepotIdx + 1})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (isMyTurn && phase == 'place' && slotValid.isNotEmpty)
                InkWell(
                  onTap: () {
                    widget.g.act({
                      'type': 'place',
                      'slot': _selectedSlot,
                      'cells': slotValid.first,
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
                      '⚡快捷部署',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (phase == 'rotate')
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  const Text(
                    '旋转舱位: ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  for (var r = 0; r < 6; r++)
                    Expanded(
                      child: GestureDetector(
                        onTap: isMyTurn
                            ? () => widget.g.act({'type': 'rotate', 'rot': r})
                            : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: susanRot == r
                                ? cs.primary
                                : cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '旋#$r',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: susanRot == r
                                    ? cs.onPrimary
                                    : cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (phase == 'rotate') const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              itemCount: depots.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, d) {
                final pair = (depots[d] as List?) ?? const [];
                final isMine = d == myDepotIdx;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMine
                        ? cs.primaryContainer.withValues(alpha: 0.45)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: isMine
                          ? cs.primary
                          : cs.outline.withValues(alpha: 0.25),
                      width: isMine ? 1.8 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '舱#${d + 1}${isMine ? "(你)" : ""}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isMine ? cs.primary : cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      for (var s = 0; s < pair.length; s++)
                        Expanded(
                          child: _buildDepotTileChip(
                            (pair[s] as Map).cast<String, dynamic>(),
                            s,
                            isMine,
                            cs,
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

  Widget _buildDepotTileChip(
    Map<String, dynamic> tm,
    int slot,
    bool isMine,
    ColorScheme cs,
  ) {
    final ta = asInt(tm['trackA'], 0);
    final tb = asInt(tm['trackB'], 1);
    final meteor = asBool(tm['hasMeteor']);
    final shape = (tm['shape'] as List?) ?? const [];
    final selected = isMine && _selectedSlot == slot;

    return GestureDetector(
      onTap: isMine
          ? () => setState(() {
                _selectedSlot = slot;
                _pickedCells.clear();
              })
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? _trackColor(ta)
              : cs.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Colors.amberAccent : _trackColor(ta),
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '槽${slot + 1}: ${planetTrackEmojis[ta]}+${planetTrackEmojis[tb]} (${shape.length}格${meteor ? "☄️" : ""})',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanetPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int gridSize,
    List<dynamic> depots,
    int myDepotIdx,
    bool canAct,
    ColorScheme cs,
  ) {
    final planetMat = (viewData['planet'] as List?) ?? const [];
    final podMat = (viewData['lifepods'] as List?) ?? const [];
    final meteorMat = (viewData['meteors'] as List?) ?? const [];
    final tracks = (viewData['tracks'] as List?) ?? const [];
    final rescued = asInt(viewData['rescuedLifepods'], 0);
    final civCards = asInt(viewData['civCards'], 0);
    final medalScore = asInt(viewData['medalScore'], 0);
    final trackScore = asInt(viewData['trackScore'], 0);

    var targetLen = 2;
    if (myDepotIdx < depots.length) {
      final pair = depots[myDepotIdx] as List;
      if (_selectedSlot < pair.length) {
        final tm = (pair[_selectedSlot] as Map).cast<String, dynamic>();
        targetLen = ((tm['shape'] as List?)?.length ?? 2);
      }
    }

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
                  '🪐 ${widget.g.name(viewSeat)} 的行星 ($gridSize×$gridSize · 奖章+$medalScore · 轨道+$trackScore · 🌟+$rescued · 文明+${civCards * 2})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              if (_pickedCells.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _pickedCells.clear()),
                  child: Text(
                    '已选 ${_pickedCells.length}/$targetLen 格',
                    style: TextStyle(
                      fontSize: 10,
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
                  for (var t = 0; t < tracks.length; t++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _trackColor(t),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${planetTrackEmojis[t]}${planetTrackNames[t]} Lv.${tracks[t]}/10',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                                child: _buildPlanetCell(
                                  r,
                                  c,
                                  _matInt(planetMat, r, c, 0),
                                  _matBool(podMat, r, c),
                                  _matBool(meteorMat, r, c),
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

  Widget _buildPlanetCell(
    int r,
    int c,
    int terrain,
    bool hasPod,
    bool hasMeteor,
    int targetLen,
    bool canAct,
    ColorScheme cs,
  ) {
    final pickedIdx = _pickedCells.indexOf((r, c));
    final isPicked = pickedIdx >= 0;

    return GestureDetector(
      onTap: canAct && terrain == 0
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
                      'type': 'place',
                      'slot': _selectedSlot,
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
          color: terrain > 0
              ? _trackColor(terrain - 1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isPicked
                ? Colors.amberAccent
                : (hasMeteor
                    ? Colors.redAccent
                    : cs.outline.withValues(alpha: 0.25)),
            width: isPicked ? 2.0 : (hasMeteor ? 1.5 : 0.7),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: Text(
                hasMeteor
                    ? '☄️'
                    : (terrain > 0
                        ? planetTrackEmojis[terrain - 1]
                        : (isPicked
                            ? '#${pickedIdx + 1}'
                            : (hasPod ? '🌟' : '·'))),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: terrain > 0
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
