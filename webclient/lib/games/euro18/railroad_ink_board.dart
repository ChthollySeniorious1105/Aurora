import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro18/railroad_ink.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class RailroadInkBoard extends StatefulWidget {
  final GameContext g;
  const RailroadInkBoard(this.g, {super.key});

  @override
  State<RailroadInkBoard> createState() => _RailroadInkBoardState();
}

class _RailroadInkBoardState extends State<RailroadInkBoard> {
  int _selectedDieIdx = 0;
  int _selectedSpecialIdx = 0;
  bool _useSpecial = false;
  int _rot = 0;
  int? _inspectSeat;

  static const List<String> _edgeShort = ['空', '🛣️公', '🛤️铁'];

  List<int> _rotateEdges(List<dynamic> rawEdges, int rot) {
    final base = [for (final e in rawEdges) asInt(e, 0)];
    if (base.length < 4) return const [0, 0, 0, 0];
    final r = ((rot % 4) + 4) % 4;
    return [for (var d = 0; d < 4; d++) base[(d - r + 4) % 4]];
  }

  String _exitBadgeForCell(int r, int c) {
    final parts = <String>[];
    const dirArrows = ['⬆️', '➡️', '⬇️', '⬅️'];
    for (var d = 0; d < 4; d++) {
      final ex = RailroadInkGame.exitEdgeType(r, c, d);
      if (ex == 1) parts.add('${dirArrows[d]}🛣️');
      if (ex == 2) parts.add('${dirArrows[d]}🛤️');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 7);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final currentDice = (v['currentDice'] as List?) ?? const [];
    final specialTemplates = (v['specialTemplates'] as List?) ?? const [];
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

    final myDiceUsed = (myData['diceUsed'] as List?) ?? const [false, false, false, false];
    if (!_useSpecial &&
        _selectedDieIdx < myDiceUsed.length &&
        asBool(myDiceUsed[_selectedDieIdx])) {
      for (var i = 0; i < myDiceUsed.length; i++) {
        if (!asBool(myDiceUsed[i])) {
          _selectedDieIdx = i;
          break;
        }
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
                                    ? '轮到你！选择路线骰与旋转角度，点击 7×7 网格空位绘制路线 · $lastAction'
                                    : '等待 ${g.name(turn)} 规划路线 · $lastAction'),
                            highlight: isMyTurn,
                          ),
                        ),
                      ),
                      if (isMyTurn) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => g.act({'type': 'end_turn'}),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '⏭️ 结束本轮绘制',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🚉第 $round/$maxRounds 轮',
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
                        final bd = (pd['breakdown'] as Map?)
                                ?.cast<String, dynamic>() ??
                            const {};
                        final spCnt = asInt(pd['specialsCount'], 0);
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
                                  '⭐$sc分 (🔗${bd['exitVp'] ?? 0} 🛣️${bd['longestHighwayVp'] ?? 0} 🛤️${bd['longestRailwayVp'] ?? 0} 🏙️${bd['centerVp'] ?? 0} ⚠️-${bd['errors'] ?? 0}) · 特$spCnt/3',
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
                                flex: 5,
                                child: _buildDiceAndSpecialsPanel(
                                  currentDice,
                                  specialTemplates,
                                  myData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 7,
                                child: _buildBoardGridPanel(
                                  viewSeat,
                                  viewData,
                                  isMyTurn && viewSeat == mySeat,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildDiceAndSpecialsPanel(
                                  currentDice,
                                  specialTemplates,
                                  myData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 7,
                                child: _buildBoardGridPanel(
                                  viewSeat,
                                  viewData,
                                  isMyTurn && viewSeat == mySeat,
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
                '铁道涂鸦终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiceAndSpecialsPanel(
    List<dynamic> currentDice,
    List<dynamic> specialTemplates,
    Map<String, dynamic> myData,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final diceUsed =
        (myData['diceUsed'] as List?) ?? const [false, false, false, false];
    final specialsUsed = (myData['specialsUsed'] as List?) ??
        const [false, false, false, false, false, false];
    final specialUsedThisRound = asBool(myData['specialUsedThisRound']);
    final specialsCount = asInt(myData['specialsCount'], 0);

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
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '🎲 本轮 4 枚路线骰 (当前旋转: ${_rot * 90}°)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _rot = (_rot + 1) % 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.primary),
                  ),
                  child: Text(
                    '🔄 旋转 (${_rot * 90}°)',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                for (var i = 0; i < currentDice.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildDieCard(
                        i,
                        (currentDice[i] as Map).cast<String, dynamic>(),
                        i < diceUsed.length && asBool(diceUsed[i]),
                        cs,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🚉 6 大特殊交叉枢纽 (已用 $specialsCount/3 · 本轮${specialUsedThisRound ? "已用" : "可用1块"})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                for (var i = 0; i < specialTemplates.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: _buildSpecialCard(
                        i,
                        (specialTemplates[i] as Map).cast<String, dynamic>(),
                        i < specialsUsed.length && asBool(specialsUsed[i]),
                        specialUsedThisRound || specialsCount >= 3,
                        cs,
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

  Widget _buildDieCard(
    int idx,
    Map<String, dynamic> tpl,
    bool used,
    ColorScheme cs,
  ) {
    final sel = !_useSpecial && _selectedDieIdx == idx && !used;
    final rotEdges =
        _rotateEdges((tpl['baseEdges'] as List?) ?? const [0, 0, 0, 0], _rot);

    return GestureDetector(
      onTap: used
          ? null
          : () => setState(() {
                _useSpecial = false;
                _selectedDieIdx = idx;
              }),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: used
              ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
              : (sel
                  ? Colors.amber.withValues(alpha: 0.25)
                  : cs.surfaceContainerHighest),
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
                '${tpl['emoji']} ${tpl['name']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  decoration: used ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                used
                    ? '✅本轮已绘'
                    : '北:${_edgeShort[rotEdges[0]]} 东:${_edgeShort[rotEdges[1]]}',
                style: const TextStyle(fontSize: 9),
              ),
              if (!used)
                Text(
                  '南:${_edgeShort[rotEdges[2]]} 西:${_edgeShort[rotEdges[3]]}',
                  style: const TextStyle(fontSize: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialCard(
    int idx,
    Map<String, dynamic> tpl,
    bool used,
    bool lockedThisRound,
    ColorScheme cs,
  ) {
    final sel = _useSpecial && _selectedSpecialIdx == idx && !used;
    final rotEdges =
        _rotateEdges((tpl['baseEdges'] as List?) ?? const [0, 0, 0, 0], _rot);

    return GestureDetector(
      onTap: (used || lockedThisRound)
          ? null
          : () => setState(() {
                _useSpecial = true;
                _selectedSpecialIdx = idx;
              }),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: used
              ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
              : (sel
                  ? Colors.purple.withValues(alpha: 0.25)
                  : cs.secondaryContainer.withValues(alpha: 0.65)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? Colors.amber : cs.outline.withValues(alpha: 0.3),
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
                '${tpl['emoji']}${tpl['name']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 9.5,
                  decoration: used ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                used
                    ? '已用'
                    : '[${_edgeShort[rotEdges[0]]},${_edgeShort[rotEdges[1]]},${_edgeShort[rotEdges[2]]},${_edgeShort[rotEdges[3]]}]',
                style: const TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardGridPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    bool canActHere,
    ColorScheme cs,
  ) {
    final grid = (viewData['grid'] as List?) ?? const [];

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
              '🗺️ ${widget.g.name(viewSeat)} 的 7×7 铁道涂鸦图 (四周含 12 个公/铁出口 · 金框为中央 3×3 加分格)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < RailroadInkGame.size; r++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          for (var c = 0; c < RailroadInkGame.size; c++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                child: _buildGridCell(
                                  r,
                                  c,
                                  (r < grid.length &&
                                          c < (grid[r] as List).length)
                                      ? (grid[r] as List)[c]
                                          as Map<String, dynamic>?
                                      : null,
                                  canActHere,
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

  Widget _buildGridCell(
    int r,
    int c,
    Map<String, dynamic>? tile,
    bool canActHere,
    ColorScheme cs,
  ) {
    final isCenter = RailroadInkGame.isCenterCell(r, c);
    final exitBadge = _exitBadgeForCell(r, c);

    if (tile == null) {
      return GestureDetector(
        onTap: !canActHere
            ? null
            : () {
                if (_useSpecial) {
                  setState(() => _useSpecial = false);
                  widget.g.act({
                    'type': 'place_special',
                    'specialIdx': _selectedSpecialIdx,
                    'r': r,
                    'c': c,
                    'rot': _rot,
                  });
                } else {
                  widget.g.act({
                    'type': 'place_route',
                    'dieIdx': _selectedDieIdx,
                    'r': r,
                    'c': c,
                    'rot': _rot,
                  });
                }
              },
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isCenter
                ? Colors.amber.withValues(alpha: 0.14)
                : cs.surfaceContainerHighest.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isCenter
                  ? Colors.amber.withValues(alpha: 0.7)
                  : cs.outline.withValues(alpha: 0.25),
              width: isCenter ? 1.4 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (exitBadge.isNotEmpty)
                  Text(
                    exitBadge,
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold),
                  )
                else
                  Text(
                    isCenter ? '🏙️中心' : '($r,$c)',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final edges = (tile['edges'] as List?) ?? const [0, 0, 0, 0];
    final isSpecial = asBool(tile['isSpecial']);
    final isStation = asBool(tile['isStation']);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSpecial
            ? Colors.purple.withValues(alpha: 0.22)
            : (isStation
                ? Colors.teal.withValues(alpha: 0.22)
                : cs.primaryContainer.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCenter ? Colors.amber : cs.primary,
          width: isCenter ? 1.6 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${tile['emoji']}${tile['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9),
            ),
            Text(
              '↑${_edgeShort[asInt(edges[0], 0)]} →${_edgeShort[asInt(edges[1], 0)]}',
              style: const TextStyle(fontSize: 8),
            ),
            Text(
              '↓${_edgeShort[asInt(edges[2], 0)]} ←${_edgeShort[asInt(edges[3], 0)]}',
              style: const TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }
}
