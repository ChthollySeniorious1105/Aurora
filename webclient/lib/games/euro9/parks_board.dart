import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const _resIcons = ['🌲', '⛰️', '☀️', '💧', '🦌'];
const _resNames = ['树木', '山脉', '阳光', '水滴', '野生'];

class ParksBoard extends StatefulWidget {
  final GameContext g;
  const ParksBoard(this.g, {super.key});

  @override
  State<ParksBoard> createState() => _ParksBoardState();
}

class _ParksBoardState extends State<ParksBoard> {
  int _selectedHiker = 0;

  String _resString(List<dynamic> r) {
    final parts = <String>[];
    for (var i = 0; i < r.length && i < 5; i++) {
      parts.add('${_resIcons[i]}${r[i]}');
    }
    return parts.join(' ');
  }

  String _costString(List<dynamic> cost) {
    final parts = <String>[];
    for (var i = 0; i < cost.length && i < 4; i++) {
      final c = (cost[i] as num).toInt();
      if (c > 0) parts.add('${_resIcons[i]}×$c');
    }
    return parts.isEmpty ? '免费' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final season = (v['season'] as num?)?.toInt() ?? 1;
    final totalSeasons = (v['totalSeasons'] as num?)?.toInt() ?? 3;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'move'}';
    final lastAction = '${v['lastAction'] ?? ''}';
    final trail = (v['trail'] as List?) ?? const [];
    final hikers = (v['hikers'] as List?) ?? const [];
    final campfireLit = (v['campfireLit'] as List?) ?? const [];
    final resources = (v['resources'] as List?) ?? const [];
    final scores = (v['score'] as List?) ?? const [];
    final parksDisplay = (v['parksDisplay'] as List?) ?? const [];
    final gearDisplay = (v['gearDisplay'] as List?) ?? const [];
    final reservedParks = (v['reservedParks'] as List?) ?? const [];
    final visitedParks = (v['visitedParks'] as List?) ?? const [];
    final canMove = (v['canMove'] as List?) ?? const [[], []];

    final isMyTurn = !g.over && g.seat == turn;
    final activeHiker = _selectedHiker.clamp(0, 1);
    final myLegalSites = (activeHiker < canMove.length && canMove[activeHiker] is List)
        ? (canMove[activeHiker] as List).map((e) => (e as num).toInt()).toSet()
        : <int>{};

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '游戏已结束 — $lastAction'
                          : '第 $season/$totalSeasons 季 · 轮到 ${g.name(turn)}${phase == 'end_action' ? '（山径终点行动）' : ''} · $lastAction',
                      highlight: isMyTurn,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Players bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in g.seatsFromMe())
                        if (s < resources.length)
                          g.tag(
                            s,
                            active: s == turn && !g.over,
                            sub:
                                '⭐${scores[s]}分 | ${(campfireLit[s] == true) ? '🔥篝火亮' : '🌑篝火灭'} | ${_resString(resources[s] as List)} | 🏞️${(visitedParks[s] as List).length}',
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Hiker selector when it's my turn to move
                  if (isMyTurn && phase == 'move' && g.seat >= 0 && g.seat < hikers.length)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('选择要移动的徒步者：', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
                          for (var h = 0; h < 2; h++)
                            ChoiceChip(
                              label: Text(
                                '🥾 徒步者 ${h + 1} (位置: ${(hikers[g.seat][h] as num).toInt() < 0 ? '起点' : '${hikers[g.seat][h]}'})',
                              ),
                              selected: activeHiker == h,
                              onSelected: (_) => setState(() => _selectedHiker = h),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Trail section
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🌲 本季山径 (Trail Sites)', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Trailhead (-1)
                            _buildTrailTile(
                              cs,
                              index: -1,
                              title: '🚩 山径起点',
                              subtitle: '全员出发点',
                              occupants: _occupantsAt(hikers, -1, g),
                              clickable: false,
                              onTap: null,
                            ),
                            for (var i = 0; i < trail.length; i++)
                              _buildTrailTile(
                                cs,
                                index: i,
                                title: '${i + 1}. ${(trail[i] as Map)['name']}',
                                subtitle: '${(trail[i] as Map)['desc']}',
                                occupants: _occupantsAt(hikers, i, g),
                                clickable: isMyTurn && phase == 'move' && myLegalSites.contains(i),
                                onTap: () => g.act({'type': 'move', 'hiker': activeHiker, 'to': i}),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // National Parks display & Gear display
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // National Parks Display
                      Container(
                        width: 560,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🏞️ 国家公园展示区 (National Parks)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < parksDisplay.length; i++)
                                  _buildParkCard(
                                    cs,
                                    park: parksDisplay[i] as Map<String, dynamic>,
                                    canAct: isMyTurn && phase == 'end_action',
                                    onVisit: () => g.act({'type': 'visit_park', 'park': i, 'reserved': false}),
                                    onReserve: () => g.act({'type': 'reserve_park', 'park': i}),
                                  ),
                              ],
                            ),
                            if (g.seat >= 0 &&
                                g.seat < reservedParks.length &&
                                (reservedParks[g.seat] as List).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('📌 我的已预约公园：',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.secondary)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (var i = 0; i < (reservedParks[g.seat] as List).length; i++)
                                    _buildParkCard(
                                      cs,
                                      park: (reservedParks[g.seat] as List)[i] as Map<String, dynamic>,
                                      canAct: isMyTurn && phase == 'end_action',
                                      onVisit: () => g.act({'type': 'visit_park', 'park': i, 'reserved': true}),
                                      onReserve: null,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Gear Display
                      Container(
                        width: 420,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🎒 户外装备展示区 (Gear Cards)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < gearDisplay.length; i++)
                                  _buildGearCard(
                                    cs,
                                    gear: gearDisplay[i] as Map<String, dynamic>,
                                    canBuy: isMyTurn && phase == 'end_action',
                                    onBuy: () => g.act({'type': 'buy_gear', 'gear': i}),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over && v['result'] is Map)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '🏆 获胜者：${((v['result'] as Map)['winners'] as List?)?.join('、') ?? ''}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players && s < scores.length; s++)
                      Text('${g.name(s)}：${scores[s]} 分（访问 ${(visitedParks[s] as List).length} 座公园）'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _occupantsAt(List<dynamic> hikers, int siteIdx, GameContext g) {
    final out = <String>[];
    for (var s = 0; s < hikers.length; s++) {
      final list = hikers[s] as List;
      for (var h = 0; h < list.length; h++) {
        if ((list[h] as num).toInt() == siteIdx) {
          out.add('${g.name(s)}#${h + 1}');
        }
      }
    }
    return out;
  }

  Widget _buildTrailTile(
    ColorScheme cs, {
    required int index,
    required String title,
    required String subtitle,
    required List<String> occupants,
    required bool clickable,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: clickable
          ? cs.primaryContainer.withValues(alpha: 0.92)
          : cs.surfaceContainerHighest.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: clickable ? onTap : null,
        child: Container(
          width: 145,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: clickable ? cs.primary : cs.outline.withValues(alpha: 0.35),
              width: clickable ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8))),
              if (occupants.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final occ in occupants)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('🥾$occ', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParkCard(
    ColorScheme cs, {
    required Map<String, dynamic> park,
    required bool canAct,
    required VoidCallback onVisit,
    required VoidCallback? onReserve,
  }) {
    final name = '${park['name']}';
    final vp = (park['vp'] as num?)?.toInt() ?? 0;
    final cost = (park['cost'] as List?) ?? const [];
    return Container(
      width: 168,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Text('⭐$vp分', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text('费用: ${_costString(cost)}', style: const TextStyle(fontSize: 11)),
          if (canAct) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  onPressed: onVisit,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  child: const Text('访问', style: TextStyle(fontSize: 11)),
                ),
                if (onReserve != null)
                  OutlinedButton(
                    onPressed: onReserve,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                    child: const Text('预约', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGearCard(
    ColorScheme cs, {
    required Map<String, dynamic> gear,
    required bool canBuy,
    required VoidCallback onBuy,
  }) {
    final name = '${gear['name']}';
    final sunCost = (gear['sunCost'] as num?)?.toInt() ?? 1;
    final desc = '${gear['desc'] ?? ''}';
    final discRes = (gear['discountRes'] as num?)?.toInt() ?? 0;
    return Container(
      width: 185,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Text('☀️×$sunCost', style: TextStyle(fontWeight: FontWeight.bold, color: cs.tertiary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 3),
          Text('减免: ${_resNames[discRes.clamp(0, 4)]} | $desc', style: const TextStyle(fontSize: 11)),
          if (canBuy) ...[
            const SizedBox(height: 6),
            FilledButton.tonal(
              onPressed: onBuy,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              ),
              child: const Text('购买装备', style: TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}
