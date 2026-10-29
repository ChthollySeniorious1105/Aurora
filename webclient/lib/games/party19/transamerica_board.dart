import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TransAmericaBoard extends StatelessWidget {
  final GameContext g;
  const TransAmericaBoard(this.g, {super.key});

  static const List<Color> _regionColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.green,
    Colors.amber,
    Colors.deepOrangeAccent,
  ];

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = v['phase'] as String? ?? 'hub';
    final rows = (v['rows'] as num?)?.toInt() ?? 8;
    final cols = (v['cols'] as num?)?.toInt() ?? 10;
    final regionNames = (v['regionNames'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final cities = (v['cities'] as List?) ?? const [];
    final terrain = (v['terrain'] as List?) ?? const [];
    final rails = (v['rails'] as List?) ?? const [];
    final hub = (v['hub'] as List?) ?? const [];
    final myTargets = (v['myTargets'] as List?)?.map((e) => (e as num).toInt()).toList();
    final connectedCounts = (v['connectedCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final myConnectedCells = (v['myConnectedCells'] as List?)?.map((e) => (e as num).toInt()).toSet() ??
        const <int>{};
    final myConnectedCities = (v['myConnectedCities'] as List?)?.map((e) => (e as num).toInt()).toSet() ??
        const <int>{};
    final buildableCells = (v['buildableCells'] as List?) ?? const [];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    final buildableSet = <int>{};
    for (final c in buildableCells) {
      if (c is List && c.length >= 2) {
        final r = (c[0] as num).toInt();
        final col = (c[1] as num).toInt();
        buildableSet.add(r * cols + col);
      }
    }

    final cityByCoord = <int, Map>{};
    for (final c in cities) {
      if (c is Map) {
        final r = (c['r'] as num).toInt();
        final col = (c['c'] as num).toInt();
        cityByCoord[r * cols + col] = c;
      }
    }

    final hubByCoord = <int, List<int>>{};
    for (var s = 0; s < hub.length; s++) {
      final h = hub[s];
      if (h is List && h.length >= 2) {
        final code = (h[0] as num).toInt() * cols + (h[1] as num).toInt();
        hubByCoord.putIfAbsent(code, () => <int>[]).add(s);
      }
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '横贯美利坚 — 北美铁路竣工结算'
                          : '第 $round/$totalRounds 局 · ${phase == "hub" ? "🚉放置起始枢纽" : "🛤️铺设相连铁轨"} · ${canAct ? "轮到你行动" : "等待 ${g.name(turn)}"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.9)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Secret 5 Target Cities Banner
                  if (myTargets != null && myTargets.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '🔒 你的 5 座秘密目标城市 (${myConnectedCities.length}/5 已连通):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          for (final cid in myTargets)
                            if (cid >= 0 && cid < cities.length)
                              Builder(builder: (context) {
                                final city = cities[cid] as Map;
                                final reg = (city['region'] as num).toInt();
                                final reached = myConnectedCities.contains(cid);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: reached
                                        ? Colors.green.withValues(alpha: 0.25)
                                        : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _regionColors[reg.clamp(0, 4)],
                                    ),
                                  ),
                                  child: Text(
                                    '${reached ? "✅" : "🎯"}${reg < regionNames.length ? regionNames[reg] : ""}·${city['name']}(${city['r']},${city['c']})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }),
                        ],
                      ),
                    ),
                  // 8x10 North America Railroad Grid
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🗺️ 8×10 北美铁路网（点击高亮相邻格铺设铁轨；⛰️山脉耗 2 点，平原耗 1 点；两网相接立即共享全网！）',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var r = 0; r < rows; r++)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var c = 0; c < cols; c++)
                                        _buildGridCell(
                                          cs: cs,
                                          r: r,
                                          c: c,
                                          cols: cols,
                                          cost: (r < terrain.length && c < (terrain[r] as List).length)
                                              ? ((terrain[r] as List)[c] as num).toInt()
                                              : 1,
                                          hasRail: (r < rails.length && c < (rails[r] as List).length)
                                              ? (rails[r] as List)[c] == true
                                              : false,
                                          inMyNet: myConnectedCells.contains(r * cols + c),
                                          canBuildHere: buildableSet.contains(r * cols + c),
                                          city: cityByCoord[r * cols + c],
                                          isMyTarget: cityByCoord[r * cols + c] != null &&
                                              (myTargets?.contains(
                                                      (cityByCoord[r * cols + c]!['id'] as num).toInt()) ??
                                                  false),
                                          hubSeats: hubByCoord[r * cols + c] ?? const <int>[],
                                          phase: phase,
                                          canAct: canAct,
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          sub: '⭐${s < scores.length ? scores[s] : 0}分 · 🏙️${s < connectedCounts.length ? connectedCounts[s] : 0}/5城',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '横贯美利坚结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildGridCell({
    required ColorScheme cs,
    required int r,
    required int c,
    required int cols,
    required int cost,
    required bool hasRail,
    required bool inMyNet,
    required bool canBuildHere,
    required Map? city,
    required bool isMyTarget,
    required List<int> hubSeats,
    required String phase,
    required bool canAct,
  }) {
    final tappable = canAct && (phase == 'hub' || (phase == 'build' && canBuildHere));
    final cityName = city != null ? '${city['name']}' : '';
    final cityReg = city != null ? (city['region'] as num).toInt() : -1;

    Color bg;
    if (inMyNet) {
      bg = Colors.teal.withValues(alpha: 0.38);
    } else if (hasRail) {
      bg = Colors.blueGrey.withValues(alpha: 0.35);
    } else if (canBuildHere) {
      bg = cs.primaryContainer.withValues(alpha: 0.55);
    } else if (cost >= 2) {
      bg = Colors.brown.withValues(alpha: 0.22);
    } else {
      bg = cs.surfaceContainerHighest.withValues(alpha: 0.3);
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: tappable
            ? () {
                if (phase == 'hub') {
                  g.act({'type': 'place_hub', 'r': r, 'c': c});
                } else {
                  g.act({
                    'type': 'build_rail',
                    'cells': [
                      [r, c],
                    ],
                  });
                }
              }
            : null,
        child: Container(
          width: 68,
          height: 50,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isMyTarget
                  ? Colors.amber
                  : (cityReg >= 0
                      ? _regionColors[cityReg.clamp(0, 4)]
                      : (canBuildHere ? cs.primary : cs.outline.withValues(alpha: 0.25))),
              width: isMyTarget || canBuildHere ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                cityName.isNotEmpty
                    ? '${isMyTarget ? "⭐" : "🏙️"}$cityName'
                    : '($r,$c)${cost >= 2 ? "⛰️2" : ""}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: cityName.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hubSeats.isNotEmpty
                    ? '🚉P${hubSeats.map((s) => s + 1).join("+")}'
                    : (hasRail ? '🛤️铁轨' : (canBuildHere ? '+铺轨' : '—')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: hasRail || canBuildHere ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
