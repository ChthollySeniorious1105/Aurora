import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro12/tiny_towns.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TinyTownsBoard extends StatefulWidget {
  final GameContext g;
  const TinyTownsBoard(this.g, {super.key});

  @override
  State<TinyTownsBoard> createState() => _TinyTownsBoardState();
}

class _TinyTownsBoardState extends State<TinyTownsBoard> {
  int? _inspectSeat;

  Color _resColor(int v, ColorScheme cs) {
    return switch (v) {
      0 => const Color(0xFF795548), // Wood
      1 => const Color(0xFFFBC02D), // Wheat
      2 => const Color(0xFFE53935), // Brick
      3 => const Color(0xFF1E88E5), // Glass
      4 => const Color(0xFF90A4AE), // Stone
      _ => cs.primaryContainer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final gridSize = asInt(v['gridSize'], 4);
    final builderSeat = asInt(v['builderSeat'], 0);
    final calledRes = v['calledRes'] is int ? v['calledRes'] as int : null;
    final phase = asStr(v['phase'], 'call');
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final buildings = (v['buildings'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : builderSeat;
    final viewSeat =
        (_inspectSeat != null && _inspectSeat! < pList.length)
            ? _inspectSeat!
            : mySeat;

    final myData = (pList.isNotEmpty && mySeat < pList.length)
        ? (pList[mySeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final viewData = (pList.isNotEmpty && viewSeat < pList.length)
        ? (pList[viewSeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final myFinished = asBool(myData['finished']);
    final myPlacedRes = asBool(myData['placedRes']);
    final myValidBuilds = (myData['validBuilds'] as List?) ?? const [];

    final isMyCall = !over && phase == 'call' && g.seat == builderSeat;
    final isMyPlace =
        !over && phase == 'place' && g.seat >= 0 && !myFinished && !myPlacedRes;
    final isMyBuildStep =
        !over && phase == 'place' && g.seat >= 0 && !myFinished && myPlacedRes;

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
                                : (isMyCall
                                    ? '你是本轮总建筑师！请指定 1 种资源 · $lastAction'
                                    : (isMyPlace
                                        ? '请将 ${calledRes != null ? "${ttResourceEmojis[calledRes]}${ttResourceNames[calledRes]}" : "资源"} 放置到 4×4 城镇空位 · $lastAction'
                                        : '当前阶段: ${phase == "call" ? "宣布资源" : "放置与建造"} · $lastAction')),
                            highlight: isMyCall || isMyPlace || isMyBuildStep,
                          ),
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
                        final fin = asBool(pd['finished']);
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
                              active: s == builderSeat,
                              sub:
                                  '${s == builderSeat ? "🔨建筑师 · " : ""}$sc分${fin ? "(竣工)" : ""}',
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
                                child: _buildTownGridPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
                                  calledRes,
                                  isMyPlace && viewSeat == g.seat,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildRightPanel(
                                  buildings,
                                  myValidBuilds,
                                  isMyCall,
                                  isMyBuildStep,
                                  calledRes,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildTownGridPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
                                  calledRes,
                                  isMyPlace && viewSeat == g.seat,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildRightPanel(
                                  buildings,
                                  myValidBuilds,
                                  isMyCall,
                                  isMyBuildStep,
                                  calledRes,
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
                '小小城镇终局结算 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTownGridPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int gridSize,
    int? calledRes,
    bool canPlaceHere,
    ColorScheme cs,
  ) {
    final grid = (viewData['grid'] as List?) ?? const [];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
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
                  '${widget.g.name(viewSeat)} 的城镇 ($gridSize×$gridSize)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Text(
                '当前得分: ${viewData['score'] ?? 0} 分',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
                                child: _buildTownCell(
                                  r,
                                  c,
                                  (r < grid.length &&
                                          c < (grid[r] as List).length)
                                      ? asInt((grid[r] as List)[c], -1)
                                      : -1,
                                  canPlaceHere,
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

  Widget _buildTownCell(
    int r,
    int c,
    int cellVal,
    bool canPlaceHere,
    ColorScheme cs,
  ) {
    final isEmpty = cellVal == -1;
    final isRes = cellVal >= 0 && cellVal <= 4;
    final bDef = cellVal >= 10 ? tinyBuildingById[cellVal] : null;

    String label = '';
    Color bg;
    if (isEmpty) {
      bg = canPlaceHere
          ? cs.primary.withValues(alpha: 0.18)
          : cs.surfaceContainerHighest.withValues(alpha: 0.45);
      label = canPlaceHere ? '+' : '';
    } else if (isRes) {
      bg = _resColor(cellVal, cs);
      label = '${ttResourceEmojis[cellVal]}\n${ttResourceNames[cellVal]}';
    } else {
      bg = cs.primaryContainer;
      label = bDef != null ? '${bDef.emoji}\n${bDef.name}' : '🏛️';
    }

    return GestureDetector(
      onTap: canPlaceHere && isEmpty
          ? () => widget.g.act({'type': 'place_res', 'r': r, 'c': c})
          : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (canPlaceHere && isEmpty)
                ? cs.primary
                : cs.outline.withValues(alpha: 0.3),
            width: (canPlaceHere && isEmpty) ? 1.5 : 0.8,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isRes ? Colors.white : cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(
    List<dynamic> buildings,
    List<dynamic> myValidBuilds,
    bool isMyCall,
    bool isMyBuildStep,
    int? calledRes,
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
          if (isMyCall) ...[
            const Text(
              '🔨 请选择本轮所有玩家必须放置的资源：',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var res = 0; res < 5; res++)
                  InkWell(
                    onTap: () =>
                        widget.g.act({'type': 'call_resource', 'res': res}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _resColor(res, cs),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${ttResourceEmojis[res]}${ttResourceNames[res]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 10),
          ],
          if (myValidBuilds.isNotEmpty || isMyBuildStep) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '✨ 可合成建筑：',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                for (var i = 0; i < myValidBuilds.length && i < 6; i++)
                  Builder(
                    builder: (context) {
                      final bm =
                          (myValidBuilds[i] as Map).cast<String, dynamic>();
                      final bId = asInt(bm['building']);
                      final def = tinyBuildingById[bId];
                      final at = bm['at'] as List;
                      return InkWell(
                        onTap: () => widget.g.act(bm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cs.primary),
                          ),
                          child: Text(
                            '建造 ${def?.emoji ?? ""}${def?.name ?? ""}(${at[0]},${at[1]})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (isMyBuildStep)
                  InkWell(
                    onTap: () => widget.g.act({'type': 'end_step'}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '✅结束建造步骤',
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
            const Divider(height: 8),
          ],
          const Text(
            '📜 建筑配方与计分图鉴（正交连通资源即可合成）',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              itemCount: buildings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, idx) {
                final bm = (buildings[idx] as Map).cast<String, dynamic>();
                final recipe = asIntList(bm['recipe']);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${bm['emoji']}${bm['name']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        [for (final r in recipe) ttResourceEmojis[r]].join('+'),
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          asStr(bm['desc']),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.8),
                          ),
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
}
