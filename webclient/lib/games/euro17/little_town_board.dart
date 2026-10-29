import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro17/little_town.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class LittleTownBoard extends StatefulWidget {
  final GameContext g;
  const LittleTownBoard(this.g, {super.key});

  @override
  State<LittleTownBoard> createState() => _LittleTownBoardState();
}

class _LittleTownBoardState extends State<LittleTownBoard> {
  int _selectedMarketIdx = -1; // -1 = Gather mode, >= 0 = Build mode

  static const List<Color> _ownerColors = [
    Color(0xFF1E88E5),
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 4);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final map = (v['map'] as List?) ?? const [];
    final buildings = (v['buildings'] as List?) ?? const [];
    final workersOnMap = (v['workersOnMap'] as List?) ?? const [];
    final market = (v['market'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    if (_selectedMarketIdx >= market.length) _selectedMarketIdx = -1;
    final isMyTurn = !over && g.seat == turn;

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
                                    ? (_selectedMarketIdx < 0
                                        ? '轮到你！点击6×8山谷空草地派遣工匠八邻采集/激活，或点选右侧建筑卡后建造 · $lastAction'
                                        : '建造模式：请点击6×8山谷上的任意空草地建造所选建筑 · $lastAction')
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
                          '🏰第 $round/$maxRounds 轮',
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
                        final cn = asInt(pd['coins'], 0);
                        final wl = asInt(pd['workersLeft'], 0);
                        final res = (pd['res'] as List?) ?? const [0, 0, 0, 0];
                        return g.tag(
                          s,
                          active: s == turn,
                          sub:
                              '⭐$sc分 🪙$cn · 🌲${res[0]} 🪨${res[1]} 🐟${res[2]} 🌾${res[3]} · 👷$wl',
                          size: 26,
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
                                flex: 7,
                                child: _buildMapPanel(
                                  map,
                                  buildings,
                                  workersOnMap,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: _buildMarketPanel(
                                  market,
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
                                child: _buildMapPanel(
                                  map,
                                  buildings,
                                  workersOnMap,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 5,
                                child: _buildMarketPanel(
                                  market,
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
                '小小建筑师终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapPanel(
    List<dynamic> map,
    List<dynamic> buildings,
    List<dynamic> workersOnMap,
    bool isMyTurn,
    ColorScheme cs,
  ) {
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
              _selectedMarketIdx < 0
                  ? '🏞️ 6×8 共享山谷地图 (当前: 👷八邻采集模式 · 点击任意🌿草地激活周围全部 8 格资源与建筑)'
                  : '🏗️ 6×8 共享山谷地图 (当前: 建造模式 · 点击任意🌿草地建造所选市场建筑)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < LittleTownGame.rows; r++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          for (var c = 0; c < LittleTownGame.cols; c++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                child: _buildValleyCell(
                                  r,
                                  c,
                                  (r < map.length &&
                                          c < (map[r] as List).length)
                                      ? asInt((map[r] as List)[c], 0)
                                      : 0,
                                  (r < buildings.length &&
                                          c < (buildings[r] as List).length)
                                      ? (buildings[r] as List)[c]
                                          as Map<String, dynamic>?
                                      : null,
                                  (r < workersOnMap.length &&
                                          c < (workersOnMap[r] as List).length)
                                      ? asInt((workersOnMap[r] as List)[c], -1)
                                      : -1,
                                  isMyTurn,
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

  Widget _buildValleyCell(
    int r,
    int c,
    int terrain,
    Map<String, dynamic>? placedBld,
    int workerSeat,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    if (placedBld != null) {
      final owner = asInt(placedBld['owner'], 0);
      final card =
          (placedBld['card'] as Map?)?.cast<String, dynamic>() ?? const {};
      final oColor = _ownerColors[owner % _ownerColors.length];
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: oColor.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: oColor, width: 1.5),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${card['emoji']}${card['name']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              ),
              Text(
                '🏰P${owner + 1} · ${card['effectDesc']}',
                style: const TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      );
    }

    if (workerSeat >= 0) {
      final wColor = _ownerColors[workerSeat % _ownerColors.length];
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: wColor.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: wColor, width: 1.5),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '👷P${workerSeat + 1}工匠',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              ),
              Text('($r,$c)', style: const TextStyle(fontSize: 9)),
            ],
          ),
        ),
      );
    }

    if (terrain > 0) {
      final tIdx = terrain.clamp(0, 4);
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.brown.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.brown.withValues(alpha: 0.5)),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${littleTownTerrainEmojis[tIdx]}${littleTownTerrainNames[tIdx]}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              ),
              const Text('+1产出', style: TextStyle(fontSize: 8)),
            ],
          ),
        ),
      );
    }

    // Open grass square (terrain == 0)
    return GestureDetector(
      onTap: !isMyTurn
          ? null
          : () {
              if (_selectedMarketIdx >= 0) {
                final mIdx = _selectedMarketIdx;
                setState(() => _selectedMarketIdx = -1);
                widget.g.act({
                  'type': 'build',
                  'marketIdx': mIdx,
                  'r': r,
                  'c': c,
                });
              } else {
                widget.g.act({
                  'type': 'gather',
                  'r': r,
                  'c': c,
                });
              }
            },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isMyTurn
              ? (_selectedMarketIdx >= 0
                  ? Colors.amber.withValues(alpha: 0.22)
                  : Colors.lightGreen.withValues(alpha: 0.22))
              : cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isMyTurn
                ? (_selectedMarketIdx >= 0 ? Colors.amber : Colors.green)
                : cs.outline.withValues(alpha: 0.25),
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedMarketIdx >= 0 ? '🏗️建此' : '🌿草地',
                style:
                    const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
              ),
              Text(
                '($r,$c)',
                style: TextStyle(
                  fontSize: 8,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketPanel(
    List<dynamic> market,
    bool isMyTurn,
    ColorScheme cs,
  ) {
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
              const Expanded(
                child: Text(
                  '🏛️ 建筑蓝图市场 (点选蓝图切换建造模式)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              if (_selectedMarketIdx >= 0)
                InkWell(
                  onTap: () => setState(() => _selectedMarketIdx = -1),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '切回采集模式',
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: market.isEmpty
                ? const Center(
                    child: Text('市场建筑已全部建完', style: TextStyle(fontSize: 11)))
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 155,
                      mainAxisExtent: 56,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: market.length,
                    itemBuilder: (context, idx) {
                      final c = (market[idx] as Map).cast<String, dynamic>();
                      final sel = _selectedMarketIdx == idx;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedMarketIdx = sel ? -1 : idx;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: sel
                                ? Colors.amber.withValues(alpha: 0.28)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? Colors.amber
                                  : cs.outline.withValues(alpha: 0.3),
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
                                  '${c['emoji']} ${c['name']} (+${c['buildVp']}⭐)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                                Text(
                                  '造价:${c['costDesc']} · 效:${c['effectDesc']}',
                                  style: const TextStyle(fontSize: 10),
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
