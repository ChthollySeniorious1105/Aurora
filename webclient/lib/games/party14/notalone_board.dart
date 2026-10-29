import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class NotAloneBoard extends StatefulWidget {
  final GameContext g;
  const NotAloneBoard(this.g, {super.key});

  @override
  State<NotAloneBoard> createState() => _NotAloneBoardState();
}

class _NotAloneBoardState extends State<NotAloneBoard> {
  int? _selectedPlace;
  int? _selectedUnlock;
  final Set<int> _huntTargets = {};

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final phase = (v['phase'] as String?) ?? 'explore';
    final rescueLeft = (v['rescueLeft'] as num?)?.toInt() ?? 11;
    final rescueMax = (v['rescueMax'] as num?)?.toInt() ?? 11;
    final assimLeft = (v['assimilationLeft'] as num?)?.toInt() ?? 9;
    final assimMax = (v['assimilationMax'] as num?)?.toInt() ?? 9;
    final artemiaActive = v['artemiaActive'] == true;
    final waiting = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? <int>{};
    final will = (v['will'] as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];
    final myHand = (v['myHand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];
    final discards = (v['discards'] as List?)
            ?.map((l) => (l as List).map((e) => (e as num).toInt()).toList())
            .toList() ??
        <List<int>>[];
    final places = (v['places'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final reserve = (v['reserve'] as Map?)?.map((k, val) => MapEntry(k.toString(), (val as num).toInt())) ?? <String, int>{};
    final lastTargets = (v['lastTargets'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? <int>{};
    final lastRes = v['lastResolution'] as Map<String, dynamic>?;
    final myTurn = waiting.contains(g.seat) && !g.over;

    String statusText;
    if (g.over) {
      statusText = (v['resultText'] as String?) ?? '游戏结束';
    } else if (phase == 'explore') {
      statusText = myTurn ? '第 $round 回合：请从手牌选择 1 张地点潜行，或放弃抵抗' : '第 $round 回合：等待宇航员潜行选牌…';
    } else {
      statusText = myTurn
          ? '第 $round 回合：请选择 1${artemiaActive ? "~2" : ""} 个星球地点放置异形狩猎标记！'
          : '第 $round 回合：等待异形生物 (${g.name(0)}) 布置狩猎标记…';
    }

    return Container(
      color: g.table,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header & Tracks
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBar(statusText, highlight: myTurn),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _trackChip(
                            cs,
                            icon: '🚀',
                            label: '救援倒计时',
                            current: rescueLeft,
                            maxVal: rescueMax,
                            color: Colors.cyan,
                          ),
                          _trackChip(
                            cs,
                            icon: '👾',
                            label: '同化倒计时',
                            current: assimLeft,
                            maxVal: assimMax,
                            color: Colors.purpleAccent,
                          ),
                          if (artemiaActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.deepOrangeAccent),
                              ),
                              child: const Text(
                                '⚡ 阿忒弥亚双狩猎激活',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Players Strip
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        _buildPlayerCard(
                          cs,
                          g,
                          s,
                          active: waiting.contains(s),
                          will: s < will.length ? will[s] : 0,
                          handCount: s < handCounts.length ? handCounts[s] : 0,
                          discard: s < discards.length ? discards[s] : const [],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 10 Planet Artemia Locations Grid
                  Text(
                    '🪐 阿忒弥亚星球 10 大探索地点 ${phase == "hunt" && g.seat == 0 ? "（点击选择1~2个狩猎目标）" : ""}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 680 ? 5 : 2;
                      final spacing = 6.0;
                      final itemW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final p in places)
                            SizedBox(
                              width: itemW,
                              child: _buildPlaceTile(
                                cs,
                                p,
                                reserveCount: reserve['${p['id']}'],
                                wasTargeted: lastTargets.contains((p['id'] as num).toInt()),
                                isHuntSelected: _huntTargets.contains((p['id'] as num).toInt()),
                                inMyHand: myHand.contains((p['id'] as num).toInt()),
                                isExploreSelected: _selectedPlace == (p['id'] as num).toInt(),
                                onTap: () => _onTapPlace(
                                  g,
                                  phase,
                                  myTurn,
                                  (p['id'] as num).toInt(),
                                  myHand,
                                  artemiaActive,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  // Creature Hunt Controls
                  if (myTurn && phase == 'hunt' && g.seat == 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.error),
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _huntTargets.isEmpty
                                ? '👾 请点击上方 1..10 号地点选择狩猎目标（可选 1~2 个）'
                                : '🎯 已锁定狩猎地点：${_huntTargets.map((id) => "#$id").join(" + ")}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          FilledButton.icon(
                            onPressed: _huntTargets.isEmpty
                                ? null
                                : () {
                                    final list = _huntTargets.toList();
                                    setState(() => _huntTargets.clear());
                                    g.act({'type': 'hunt', 'targets': list});
                                  },
                            icon: const Icon(Icons.radar, size: 18),
                            label: const Text('确认发动异形狩猎'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Hunted Explore Controls
                  if (g.seat > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: myTurn ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '🃏 我的手牌 (${myHand.length} 张)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (myTurn && phase == 'explore')
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: (_selectedPlace != null && myHand.contains(_selectedPlace))
                                          ? () {
                                              final pl = _selectedPlace!;
                                              final unl = _selectedUnlock;
                                              setState(() {
                                                _selectedPlace = null;
                                                _selectedUnlock = null;
                                              });
                                              g.act({
                                                'type': 'explore',
                                                'place': pl,
                                                'unlock': ?unl,
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.explore, size: 16),
                                      label: Text(_selectedPlace == null ? '点选地点牌潜行' : '潜行探索 #$_selectedPlace'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() => _selectedPlace = null);
                                        g.act({'type': 'give_up'});
                                      },
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('放弃抵抗(回3意志+拿回弃牌)'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (myHand.isEmpty)
                            const Text('当前手牌为空，请点击“放弃抵抗”拿回弃牌堆并恢复意志力！', style: TextStyle(fontSize: 12))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final id in myHand)
                                  ChoiceChip(
                                    label: Text('#$id ${_placeName(places, id)}'),
                                    selected: _selectedPlace == id,
                                    onSelected: (myTurn && phase == 'explore')
                                        ? (sel) => setState(() => _selectedPlace = sel ? id : null)
                                        : null,
                                  ),
                              ],
                            ),
                          if (myTurn && phase == 'explore' && _selectedPlace == 5) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('探测车拟解锁新地点：', style: TextStyle(fontSize: 12)),
                                for (var u = 6; u <= 10; u++)
                                  if ((reserve['$u'] ?? 0) > 0 && !myHand.contains(u))
                                    ChoiceChip(
                                      label: Text('#$u ${_placeName(places, u)}'),
                                      selected: _selectedUnlock == u,
                                      onSelected: (sel) => setState(() => _selectedUnlock = sel ? u : null),
                                    ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Last Round Resolution Log
                  if (lastRes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📋 上回合（第 ${lastRes['round']} 回合）结算记录',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          for (final ev in (lastRes['events'] as List? ?? const []))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('• $ev', style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(statusText),
              ),
          ],
        ),
      ),
    );
  }

  void _onTapPlace(
    GameContext g,
    String phase,
    bool myTurn,
    int id,
    List<int> myHand,
    bool artemiaActive,
  ) {
    if (!myTurn) return;
    if (phase == 'hunt' && g.seat == 0) {
      setState(() {
        if (_huntTargets.contains(id)) {
          _huntTargets.remove(id);
        } else {
          if (_huntTargets.length >= 2) {
            _huntTargets.remove(_huntTargets.first);
          }
          _huntTargets.add(id);
        }
      });
    } else if (phase == 'explore' && g.seat > 0 && myHand.contains(id)) {
      setState(() {
        _selectedPlace = _selectedPlace == id ? null : id;
      });
    }
  }

  String _placeName(List<Map<String, dynamic>> places, int id) {
    for (final p in places) {
      if ((p['id'] as num).toInt() == id) {
        return '${p['emoji']} ${p['name']}';
      }
    }
    return '#$id';
  }

  Widget _trackChip(
    ColorScheme cs, {
    required String icon,
    required String label,
    required int current,
    required int maxVal,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$icon $label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(
            '$current / $maxVal',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(
    ColorScheme cs,
    GameContext g,
    int s, {
    required bool active,
    required int will,
    required int handCount,
    required List<int> discard,
  }) {
    final isCreature = s == 0;
    final roleSub = isCreature
        ? '👾 异形生物'
        : '❤️×$will · 手牌$handCount · 弃牌[${discard.join(",")}]';
    return g.tag(s, active: active, sub: roleSub, size: 32);
  }

  Widget _buildPlaceTile(
    ColorScheme cs,
    Map<String, dynamic> p, {
    required int? reserveCount,
    required bool wasTargeted,
    required bool isHuntSelected,
    required bool inMyHand,
    required bool isExploreSelected,
    required VoidCallback onTap,
  }) {
    final id = (p['id'] as num).toInt();
    final highlighted = isHuntSelected || isExploreSelected;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlighted
              ? cs.primaryContainer.withValues(alpha: 0.9)
              : cs.surface.withValues(alpha: inMyHand ? 0.88 : 0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHuntSelected
                ? cs.error
                : (isExploreSelected
                    ? cs.primary
                    : (inMyHand ? cs.secondary : cs.outline.withValues(alpha: 0.3))),
            width: highlighted ? 2.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '#$id ${p['emoji']} ${p['name']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                if (wasTargeted)
                  const Tooltip(
                    message: '上回合异形曾在此狩猎',
                    child: Text('🎯', style: TextStyle(fontSize: 12)),
                  ),
                if (reserveCount != null)
                  Text(
                    '余$reserveCount',
                    style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.7)),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${p['desc']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: cs.onSurface.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
