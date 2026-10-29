import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CelestiaBoard extends StatefulWidget {
  final GameContext g;
  const CelestiaBoard(this.g, {super.key});

  @override
  State<CelestiaBoard> createState() => _CelestiaBoardState();
}

class _CelestiaBoardState extends State<CelestiaBoard> {
  static const List<String> _hazardNames = [
    '指南针',
    '避雷针',
    '雾笛',
    '火炮',
    '涡轮增压器',
  ];

  static const List<IconData> _hazardIcons = [
    Icons.explore,
    Icons.flash_on,
    Icons.campaign,
    Icons.gps_fixed,
    Icons.bolt,
  ];

  static const List<Color> _hazardColors = [
    Color(0xFF1976D2),
    Color(0xFFFBC02D),
    Color(0xFF7B1FA2),
    Color(0xFFD32F2F),
    Color(0xFF00897B),
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final voyage = (v['voyage'] as num?)?.toInt() ?? 1;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 50;
    final cityIndex = (v['cityIndex'] as num?)?.toInt() ?? 0;
    final captain = (v['captain'] as num?)?.toInt() ?? 0;
    final aboard = (v['aboard'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final hazards = (v['hazards'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final phase = v['phase'] as String? ?? 'passengers';
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final handSizes = (v['handSizes'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final waiting = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final cities = (v['cities'] as List?)?.cast<Map>() ?? const <Map>[];
    final handCounts = (v['handCounts'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final canNavigate = v['canNavigate'] == true;
    final minWild = (v['minWild'] as num?)?.toInt() ?? 0;
    final lastEvent = v['lastEvent'] as String? ?? '';

    final myTurn = g.seat >= 0 && waiting.contains(g.seat);
    final curCityPts = cityIndex < cities.length ? (cities[cityIndex]['points'] as num?)?.toInt() ?? 1 : 1;
    final curCityName = cityIndex < cities.length ? '${cities[cityIndex]['name']}' : '浮空城';

    String statusText;
    if (g.over) {
      statusText = '游戏结束！';
    } else if (myTurn) {
      statusText = phase == 'passengers'
          ? '轮到你决策：留在飞艇继续前进，或跳船领取 $curCityPts 分！'
          : '你是船长！请打出装备克服危机或宣告坠毁';
    } else if (waiting.isNotEmpty) {
      final wSeat = waiting.first;
      statusText = phase == 'passengers'
          ? '等待乘客 ${g.name(wSeat)} 决定留船或跳船…'
          : '等待船长 ${g.name(wSeat)} 应对危机…';
    } else {
      statusText = lastEvent;
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
                  Center(child: StatusBar(statusText, highlight: myTurn)),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Players bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        g.tag(
                          s,
                          active: waiting.contains(s),
                          size: 32,
                          sub: '${scores[s]}/$targetScore分 · 手牌${handSizes[s]} · '
                              '${s == captain ? "👑船长" : (aboard.contains(s) ? "⛵在船" : "🪂已下船")}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 9 Floating Cities Track
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text(
                              '第 $voyage 次航程 · 云海航线（目标 $targetScore 分）',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '当前：$curCityName（$curCityPts 分）',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < cities.length; i++)
                              _buildCityTile(
                                cs,
                                index: i,
                                name: '${cities[i]['name']}',
                                points: (cities[i]['points'] as num?)?.toInt() ?? 0,
                                dice: (cities[i]['dice'] as num?)?.toInt() ?? 2,
                                isCurrent: i == cityIndex,
                                isPassed: i < cityIndex,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Hazards panel
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '前方航道危机骰（船长：${g.name(captain)}）',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final h in hazards) _buildHazardDie(h),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // My hand + Action buttons
                  if (g.seat >= 0)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: myTurn ? cs.primary : cs.outline.withValues(alpha: 0.3), width: myTurn ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('我的装备手牌', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var h = 0; h < 5; h++)
                                _buildEquipBadge(
                                  label: _hazardNames[h],
                                  icon: _hazardIcons[h],
                                  color: _hazardColors[h],
                                  count: (handCounts['$h'] as num?)?.toInt() ?? 0,
                                ),
                              _buildEquipBadge(
                                label: '喷气背包',
                                icon: Icons.rocket_launch,
                                color: Colors.deepOrange,
                                count: (handCounts['jetpack'] as num?)?.toInt() ?? 0,
                              ),
                              _buildEquipBadge(
                                label: '弹射卡',
                                icon: Icons.eject,
                                color: Colors.pink,
                                count: (handCounts['eject'] as num?)?.toInt() ?? 0,
                              ),
                            ],
                          ),
                          if (myTurn && !g.over) ...[
                            const SizedBox(height: 12),
                            _buildActions(
                              g,
                              phase: phase,
                              curCityPts: curCityPts,
                              canNavigate: canNavigate,
                              minWild: minWild,
                              captain: captain,
                              aboard: aboard,
                              hasEject: ((handCounts['eject'] as num?)?.toInt() ?? 0) > 0,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (g.over)
            Center(
              child: ResultBanner(
                _winnerText(g, scores),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${g.name(s)}：${scores[s]} 分'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _winnerText(GameContext g, List<int> scores) {
    var best = -1;
    for (final s in scores) {
      if (s > best) best = s;
    }
    final winners = [
      for (var i = 0; i < g.players; i++)
        if (scores[i] == best) g.name(i),
    ];
    return '${winners.join("、")} 获胜！（$best 分）';
  }

  Widget _buildCityTile(
    ColorScheme cs, {
    required int index,
    required String name,
    required int points,
    required int dice,
    required bool isCurrent,
    required bool isPassed,
  }) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent
            ? cs.primaryContainer
            : isPassed
                ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                : cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? cs.primary : cs.outline.withValues(alpha: 0.35),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${index + 1}. $name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isCurrent ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '💎 $points分 · 🎲×$dice',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
            ),
          ),
          if (isCurrent)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('⛵ 飞艇在此', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildHazardDie(int h) {
    final safeH = h.clamp(0, 3);
    final color = _hazardColors[safeH];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_hazardIcons[safeH], size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            _hazardNames[safeH],
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipBadge({
    required String label,
    required IconData icon,
    required Color color,
    required int count,
  }) {
    return Opacity(
      opacity: count > 0 ? 1.0 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: count > 0 ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text('$label ×$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    GameContext g, {
    required String phase,
    required int curCityPts,
    required bool canNavigate,
    required int minWild,
    required int captain,
    required List<int> aboard,
    required bool hasEject,
  }) {
    final ejectTargets = [
      for (final s in aboard)
        if (s != g.seat && s != captain) s,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (phase == 'passengers') ...[
          FilledButton.icon(
            onPressed: () => g.act({'type': 'stay'}),
            icon: const Icon(Icons.sailing, size: 18),
            label: const Text('留船继续前进'),
          ),
          OutlinedButton.icon(
            onPressed: () => g.act({'type': 'bail'}),
            icon: const Icon(Icons.paragliding, size: 18),
            label: Text('跳船领宝藏 (+$curCityPts 分)'),
          ),
        ],
        if (phase == 'captain') ...[
          if (canNavigate)
            FilledButton.icon(
              onPressed: () => g.act({'type': 'navigate', 'useWild': minWild}),
              icon: const Icon(Icons.check_circle, size: 18),
              label: Text(minWild > 0 ? '克服危机 (用 $minWild 张涡轮)' : '打出装备克服危机'),
            ),
          if (aboard.length == 1 && aboard.first == g.seat)
            OutlinedButton.icon(
              onPressed: () => g.act({'type': 'bail'}),
              icon: const Icon(Icons.paragliding, size: 18),
              label: Text('独自跳船 (+$curCityPts 分)'),
            ),
          FilledButton.tonalIcon(
            onPressed: () => g.act({'type': 'crash'}),
            icon: const Icon(Icons.warning_amber, size: 18),
            label: const Text('宣告飞艇坠毁'),
          ),
        ],
        if (hasEject)
          for (final t in ejectTargets)
            ActionChip(
              avatar: const Icon(Icons.eject, size: 16),
              label: Text('弹射 ${g.name(t)}'),
              onPressed: () => g.act({'type': 'eject', 'target': t}),
            ),
      ],
    );
  }
}
