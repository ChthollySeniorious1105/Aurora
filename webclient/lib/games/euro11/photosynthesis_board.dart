import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _seatCols = [
  Color(0xFFE05246),
  Color(0xFF3276D6),
  Color(0xFFE8B028),
  Color(0xFF42A85A),
];
const List<String> _treeIcons = ['🌱', '🌿', '🌲', '🌳'];
const List<String> _treeNames = ['种子', '小树', '中树', '大树'];
const List<String> _sunDirNames = ['→ 东', '↗ 东北', '↖ 西北', '← 西', '↙ 西南', '↘ 东南'];

int _asInt(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
List<T> _asList<T>(Object? v) => v is List ? v.cast<T>() : <T>[];
Map<String, dynamic> _asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

class PhotosynthesisBoard extends StatelessWidget {
  final GameContext g;
  const PhotosynthesisBoard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final over = v['phase'] == 'over';
    final turn = _asInt(v['turn']);
    final round = _asInt(v['round'], 1);
    final maxRounds = _asInt(v['maxRounds'], 12);
    final sunDir = _asInt(v['sunDir']) % 6;
    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final hexes = _asList<dynamic>(v['hexes']).map(_asMap).toList();
    final validPlants = _asList<dynamic>(v['validPlants'])
        .map(_asMap)
        .map((m) => (_asInt(m['q']), _asInt(m['r'])))
        .toSet();
    final ps = _asList<dynamic>(v['players']).map(_asMap).toList();
    final myLight = me >= 0 && me < ps.length ? _asInt(ps[me]['light']) : 0;

    final status = over
        ? '光合作用 · 森林终局结算'
        : myTurn
            ? '第 $round/$maxRounds 回合 (☀️${_sunDirNames[sunDir]}) · 轮到你（☀️ $myLight 光点）：点空地播种(1)/点树生长(1-3)/点大树采伐(3)'
            : '第 $round/$maxRounds 回合 (☀️${_sunDirNames[sunDir]}) · 等待 ${g.name(turn)} 行动';

    Widget forestHexMap(double maxW, double maxH) {
      return Container(
        width: maxW,
        height: maxH,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            colors: [Color(0xFF28593A), Color(0xFF143020)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.45), width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 440,
            height: 390,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 12,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amberAccent),
                    ),
                    child: Text(
                      '☀️ 阳光方向: ${_sunDirNames[sunDir]}',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                for (final h in hexes)
                  Builder(builder: (_) {
                    final q = _asInt(h['q']);
                    final r = _asInt(h['r']);
                    final soil = _asInt(h['soil'], 1);
                    final tree = h['tree'] is Map ? _asMap(h['tree']) : null;
                    final shadowed = h['shadowed'] == true;
                    final activated = h['activated'] == true;
                    final cx = 220.0 + (q + r * 0.5) * 76.0;
                    final cy = 200.0 + r * 66.0;

                    final canPlantHere = myTurn && tree == null && validPlants.contains((q, r));
                    final isMyTree = tree != null && _asInt(tree['owner'], -1) == me;
                    final treeSize = tree != null ? _asInt(tree['size']) : -1;
                    final canGrowHere = myTurn && isMyTree && treeSize < 3 && !activated && myLight >= treeSize + 1;
                    final canHarvestHere = myTurn && isMyTree && treeSize == 3 && !activated && myLight >= 3;
                    final interactive = canPlantHere || canGrowHere || canHarvestHere;

                    final soilColor = switch (soil) {
                      3 => const Color(0xFF598B2C),
                      2 => const Color(0xFF3E6F26),
                      _ => const Color(0xFF2C551E),
                    };

                    return Positioned(
                      left: cx - 34,
                      top: cy - 34,
                      child: GestureDetector(
                        onTap: !interactive
                            ? null
                            : () {
                                if (canPlantHere) {
                                  g.act({'type': 'plant', 'q': q, 'r': r});
                                } else if (canGrowHere) {
                                  g.act({'type': 'grow', 'q': q, 'r': r});
                                } else if (canHarvestHere) {
                                  g.act({'type': 'harvest', 'q': q, 'r': r});
                                }
                              },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tree != null
                                ? _seatCols[_asInt(tree['owner']) % _seatCols.length].withValues(alpha: shadowed ? 0.5 : 0.85)
                                : soilColor,
                            border: Border.all(
                              color: interactive
                                  ? Colors.amberAccent
                                  : (shadowed ? Colors.blueGrey.shade200 : Colors.white38),
                              width: interactive ? 2.5 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: interactive ? 6 : 3,
                                color: interactive ? Colors.amberAccent.withValues(alpha: 0.6) : Colors.black45,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: tree == null
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('🍃' * soil, style: const TextStyle(fontSize: 11)),
                                        Text(
                                          canPlantHere ? '+播种(1☀️)' : '($q,$r)',
                                          style: TextStyle(
                                            color: canPlantHere ? Colors.amberAccent : Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${_treeIcons[treeSize.clamp(0, 3)]}${shadowed ? '🌑' : '☀️'}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        Text(
                                          'P${_asInt(tree['owner']) + 1}·${_treeNames[treeSize.clamp(0, 3)]}',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        if (canGrowHere)
                                          Text('↑生长(${treeSize + 1}☀️)', style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                        if (canHarvestHere)
                                          const Text('🪓采伐(3☀️)', style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    }

    Widget playersAndControls() {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final p in ps)
              Builder(builder: (_) {
                final s = _asInt(p['seat']);
                return g.tag(
                  s,
                  active: !over && turn == s,
                  size: 28,
                  sub: '${_asInt(p['score'])}分 · ☀️${_asInt(p['light'])} · 🌲${_asInt(p['trees'])} · 采伐${_asInt(p['harvested'])}${p['passed'] == true ? ' (已跳过)' : ''}',
                );
              }),
            if (myTurn)
              FilledButton.icon(
                onPressed: () => g.act({'type': 'pass'}),
                icon: const Icon(Icons.skip_next, size: 16),
                label: const Text('结束本轮行动 (Pass)'),
              ),
          ],
        ),
      );
    }

    Widget? banner;
    if (over) {
      final pl = _asList<dynamic>(v['placings']).map(_asInt).toList();
      final winners = [for (var s = 0; s < pl.length; s++) if (pl[s] == 1) g.name(s)];
      banner = ResultBanner(
        '${winners.join('、')} 赢得森林之冠！',
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DataTable(
            headingRowHeight: 28,
            dataRowMinHeight: 24,
            dataRowMaxHeight: 28,
            columns: const [
              DataColumn(label: Text('玩家')),
              DataColumn(label: Text('采伐大树')),
              DataColumn(label: Text('余光')),
              DataColumn(label: Text('总分')),
            ],
            rows: [
              for (final p in ps)
                DataRow(cells: [
                  DataCell(Text(g.name(_asInt(p['seat'])), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('${_asInt(p['harvested'])} 棵')),
                  DataCell(Text('${_asInt(p['light'])} ☀️')),
                  DataCell(Text('${_asInt(p['score'])}', style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final mapH = max(220.0, min(370.0, c.maxHeight * 0.58));
      return Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBar(status, highlight: myTurn),
                  const SizedBox(height: 6),
                  forestHexMap(c.maxWidth - 12, mapH),
                  const SizedBox(height: 6),
                  playersAndControls(),
                ],
              ),
            ),
          ),
          if (banner != null) Align(alignment: Alignment.topCenter, child: banner),
        ],
      );
    });
  }
}
