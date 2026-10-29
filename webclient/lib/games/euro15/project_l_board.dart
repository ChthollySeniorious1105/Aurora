import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro15/project_l.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ProjectLBoard extends StatefulWidget {
  final GameContext g;
  const ProjectLBoard(this.g, {super.key});

  @override
  State<ProjectLBoard> createState() => _ProjectLBoardState();
}

class _ProjectLBoardState extends State<ProjectLBoard> {
  int _selectedShape = 0;
  int? _inspectSeat;

  Color _shapeColor(int sh) {
    return switch (sh) {
      0 => const Color(0xFFFBC02D), // Yellow L1
      1 => const Color(0xFF43A047), // Green L2
      2 => const Color(0xFF1E88E5), // Blue L3_I
      3 => const Color(0xFFFB8C00), // Orange L3_L
      4 => const Color(0xFFE53935), // Red L4_O
      5 => const Color(0xFF00ACC1), // Cyan L4_I
      6 => const Color(0xFF8E24AA), // Purple L4_L
      7 => const Color(0xFFD81B60), // Pink L4_T
      8 => const Color(0xFF3949AB), // Indigo L4_Z
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final turn = asInt(v['turn'], 0);
    final actionsLeft = asInt(v['actionsLeft'], 3);
    final usedMaster = asBool(v['usedMaster']);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final whiteMarket = (v['whiteMarket'] as List?) ?? const [];
    final blackMarket = (v['blackMarket'] as List?) ?? const [];
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
                                    ? '轮到你（剩余 $actionsLeft/3 行动）！拿谜题/升方块/嵌块/大师行动 · $lastAction'
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
                          '🧩第$round轮 · 行动:$actionsLeft/3',
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
                        final done = asInt(pd['completedCount'], 0);
                        final res = (pd['reserve'] as List?) ?? const [];
                        final totalPieces = res.fold<int>(
                            0, (sum, e) => sum + asInt(e, 0));
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
                              sub: '⭐$sc分 · 完成$done题 · 库存$totalPieces块',
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
                                  whiteMarket,
                                  blackMarket,
                                  myData,
                                  usedMaster,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildPlayerEnginePanel(
                                  viewSeat,
                                  viewData,
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
                                child: _buildMarketPanel(
                                  whiteMarket,
                                  blackMarket,
                                  myData,
                                  usedMaster,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildPlayerEnginePanel(
                                  viewSeat,
                                  viewData,
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
                '几何方阵终局 · ${[
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
    List<dynamic> whiteMarket,
    List<dynamic> blackMarket,
    Map<String, dynamic> myData,
    bool usedMaster,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final res = (myData['reserve'] as List?) ?? const [];
    final active = (myData['activePuzzles'] as List?) ?? const [];
    final selCount =
        _selectedShape < res.length ? asInt(res[_selectedShape], 0) : 0;
    final nextShape = (_selectedShape + 1).clamp(0, 8);

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
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (isMyTurn) ...[
                  _btn(
                    '➕ 获1级黄点',
                    cs.primaryContainer,
                    cs.onPrimaryContainer,
                    () => widget.g.act({'type': 'gain_l1'}),
                  ),
                  const SizedBox(width: 6),
                  if (selCount > 0 && _selectedShape < 8) ...[
                    _btn(
                      '⬆️ 升级${projectLShapeEmojis[_selectedShape]}→${projectLShapeEmojis[nextShape]}',
                      Colors.teal.withValues(alpha: 0.22),
                      Colors.teal[800]!,
                      () => widget.g.act({
                        'type': 'upgrade',
                        'from': _selectedShape,
                        'to': nextShape,
                      }),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (!usedMaster && active.isNotEmpty)
                    _btn(
                      '✨ 大师行动(全谜题嵌块)',
                      Colors.amber.withValues(alpha: 0.28),
                      Colors.amber[900]!,
                      () => widget.g.act({'type': 'master'}),
                    ),
                ] else
                  const Center(
                    child: Text(
                      '⬜ 白色基础谜题 (1~2分)  &  ⬛ 黑色高阶谜题 (3~5分)',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < whiteMarket.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildMarketPuzzleCard(
                      (whiteMarket[i] as Map).cast<String, dynamic>(),
                      0,
                      i,
                      isMyTurn && active.length < 4,
                      cs,
                    ),
                  ),
                for (var i = 0; i < blackMarket.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildMarketPuzzleCard(
                      (blackMarket[i] as Map).cast<String, dynamic>(),
                      1,
                      i,
                      isMyTurn && active.length < 4,
                      cs,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: fg),
        ),
      ),
    );
  }

  Widget _buildMarketPuzzleCard(
    Map<String, dynamic> p,
    int tier,
    int slot,
    bool canDraft,
    ColorScheme cs,
  ) {
    final vp = asInt(p['vp'], 1);
    final rew = asInt(p['rewardShape'], 0);
    final recessed = (p['recessed'] as List?) ?? const [];
    final isBlack = tier == 1;

    return GestureDetector(
      onTap: !canDraft
          ? null
          : () => widget.g.act({'type': 'draft', 'tier': tier, 'slot': slot}),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isBlack ? const Color(0xFF263238) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: canDraft
                ? cs.primary
                : cs.outline.withValues(alpha: 0.35),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isBlack ? '⬛' : '⬜'} +$vp分 奖${projectLShapeEmojis[rew.clamp(0, 8)]}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isBlack ? Colors.white : cs.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              _buildMiniGrid(recessed, const [], 13),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniGrid(
    List<dynamic> recessed,
    List<dynamic> grid,
    double cellSz,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 4; r++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < 4; c++)
                Builder(
                  builder: (context) {
                    final isRec = r < recessed.length &&
                        c < (recessed[r] as List).length &&
                        asBool((recessed[r] as List)[c]);
                    final fillVal = r < grid.length &&
                            c < (grid[r] as List).length
                        ? asInt((grid[r] as List)[c], 0)
                        : 0;
                    return Container(
                      width: cellSz,
                      height: cellSz,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: !isRec
                            ? Colors.grey.withValues(alpha: 0.25)
                            : (fillVal > 0
                                ? _shapeColor(fillVal - 1)
                                : Colors.white.withValues(alpha: 0.9)),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: isRec ? Colors.black45 : Colors.transparent,
                          width: 0.8,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildPlayerEnginePanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    bool canInteract,
    ColorScheme cs,
  ) {
    final reserve = (viewData['reserve'] as List?) ?? const [];
    final activePuzzles = (viewData['activePuzzles'] as List?) ?? const [];

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
          Text(
            '🔧 ${widget.g.name(viewSeat)} 的几何块库存（点选形状后可嵌入或升级）',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: projectLShapeNames.length,
              separatorBuilder: (_, _) => const SizedBox(width: 5),
              itemBuilder: (context, sh) {
                final cnt = sh < reserve.length ? asInt(reserve[sh], 0) : 0;
                final sel = sh == _selectedShape;
                return GestureDetector(
                  onTap: () => setState(() => _selectedShape = sh),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: sel
                          ? _shapeColor(sh).withValues(alpha: 0.28)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel
                            ? _shapeColor(sh)
                            : cs.outline.withValues(alpha: 0.3),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${projectLShapeEmojis[sh]}${projectLShapeNames[sh]} ×$cnt',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            cnt > 0 ? FontWeight.bold : FontWeight.normal,
                        color: cnt > 0
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: activePuzzles.isEmpty
                ? Center(
                    child: Text(
                      '面前暂无活跃谜题，请从上方市场拿取谜题',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activePuzzles.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, slot) {
                      final p = (activePuzzles[slot] as Map)
                          .cast<String, dynamic>();
                      final vp = asInt(p['vp'], 1);
                      final rew = asInt(p['rewardShape'], 0);
                      final recessed = (p['recessed'] as List?) ?? const [];
                      final grid = (p['grid'] as List?) ?? const [];
                      final emptyCnt = asInt(p['emptyRecessed'], 0);

                      return GestureDetector(
                        onTap: !canInteract
                            ? null
                            : () {
                                widget.g.act({
                                  'type': 'place',
                                  'slot': slot,
                                  'shape': _selectedShape,
                                });
                              },
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: cs.primary.withValues(alpha: 0.6)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '谜题#${p['id']} (+$vp分 奖${projectLShapeEmojis[rew.clamp(0, 8)]})',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 3),
                                _buildMiniGrid(recessed, grid, 16),
                                const SizedBox(height: 3),
                                Text(
                                  canInteract
                                      ? '⚡点击嵌入${projectLShapeEmojis[_selectedShape]} (差$emptyCnt格)'
                                      : '剩余 $emptyCnt 格凹槽',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
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
}
