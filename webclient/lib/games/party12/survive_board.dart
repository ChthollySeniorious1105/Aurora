import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class SurviveBoard extends StatefulWidget {
  final GameContext g;
  const SurviveBoard(this.g, {super.key});

  @override
  State<SurviveBoard> createState() => _SurviveBoardState();
}

class _SurviveBoardState extends State<SurviveBoard> {
  int? _selectedExplorerId;
  int? _selectedBoatId;
  int? _selectedCreatureId;

  static const List<Color> _seatColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
  ];

  static bool _isSafeIsland(int r, int c) => (r == 0 || r == 6) && (c == 0 || c == 6);

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'move';
    final turnSeat = (v['turnSeat'] as int?) ?? 0;
    final movesLeft = (v['movesLeft'] as int?) ?? 3;
    final minIslandTerrain = (v['minIslandTerrain'] as int?) ?? 1;
    final waiting = (v['waitingFor'] as List?)?.cast<int>() ?? const <int>[];
    final isMyTurn = g.seat >= 0 && waiting.contains(g.seat);

    final terrain = [
      for (final row in (v['terrain'] as List? ?? const []))
        (row as List).cast<int>(),
    ];
    final explorers = (v['explorers'] as List? ?? const []).cast<Map<String, dynamic>>();
    final boats = (v['boats'] as List? ?? const []).cast<Map<String, dynamic>>();
    final creatures = (v['creatures'] as List? ?? const []).cast<Map<String, dynamic>>();
    final score = (v['score'] as List? ?? const []).cast<int>();
    final rescuedCount = (v['rescuedCount'] as List? ?? const []).cast<int>();
    final volcanoErupted = v['volcanoErupted'] == true;

    const terrainNames = ['', '沙滩', '森林', '山峰'];
    String statusText;
    if (g.over) {
      statusText = volcanoErupted ? '火山爆发！亚特兰蒂斯彻底沉没！' : '游戏结束！所有探险家已结算！';
    } else if (phase == 'move') {
      statusText = isMyTurn
          ? '你的回合 · 移动阶段（剩余 $movesLeft 步）：点选你的探险家或小船后再点击相邻格'
          : '等待 ${g.name(turnSeat)} 移动探险家/小船（剩余 $movesLeft 步）…';
    } else if (phase == 'sink') {
      final tLabel = minIslandTerrain >= 1 && minIslandTerrain <= 3 ? terrainNames[minIslandTerrain] : '岛屿';
      statusText = isMyTurn
          ? '你的回合 · 沉岛阶段：请点击一块【$tLabel】板块使其沉没'
          : '等待 ${g.name(turnSeat)} 沉没一块【$tLabel】板块…';
    } else {
      statusText = isMyTurn
          ? '你的回合 · 海怪阶段：点选一只海洋生物再点击目标海域格移动'
          : '等待 ${g.name(turnSeat)} 移动海洋生物…';
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(statusText, highlight: isMyTurn),
                    if (isMyTurn && phase == 'move')
                      FilledButton.tonal(
                        onPressed: () => g.act({'type': 'end_move'}),
                        child: const Text('结束移动'),
                      ),
                    if (isMyTurn && phase == 'creature')
                      OutlinedButton(
                        onPressed: () => g.act({'type': 'pass'}),
                        child: const Text('跳过海怪移动'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      g.tag(
                        s,
                        active: s == turnSeat && !g.over,
                        size: 28,
                        sub: '🏆 ${s < score.length ? score[s] : 0}分 · 获救 ${s < rescuedCount.length ? rescuedCount[s] : 0}人',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = min(constraints.maxWidth, constraints.maxHeight) - 12;
                    final gridSide = max(180.0, side);
                    return Center(
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: gridSide,
                          height: gridSide,
                          child: _buildGrid(
                            cs: cs,
                            terrain: terrain,
                            explorers: explorers,
                            boats: boats,
                            creatures: creatures,
                            phase: phase,
                            minIslandTerrain: minIslandTerrain,
                            isMyTurn: isMyTurn,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                volcanoErupted ? '火山爆发 · 逃离亚特兰蒂斯结束！' : '逃离亚特兰蒂斯结束！',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Text(
                        '${g.name(s)}: ${s < score.length ? score[s] : 0} 分 (获救 ${s < rescuedCount.length ? rescuedCount[s] : 0} 人)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid({
    required ColorScheme cs,
    required List<List<int>> terrain,
    required List<Map<String, dynamic>> explorers,
    required List<Map<String, dynamic>> boats,
    required List<Map<String, dynamic>> creatures,
    required String phase,
    required int minIslandTerrain,
    required bool isMyTurn,
  }) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: 49,
      itemBuilder: (context, index) {
        final r = index ~/ 7;
        final c = index % 7;
        final t = (r < terrain.length && c < terrain[r].length) ? terrain[r][c] : 0;
        final safe = _isSafeIsland(r, c);
        final cellBoats = boats.where((b) => b['r'] == r && b['c'] == c).toList();
        final cellCreatures = creatures.where((cr) => cr['r'] == r && cr['c'] == c).toList();
        final cellExps = explorers
            .where((e) => e['status'] == 'alive' && e['r'] == r && e['c'] == c)
            .toList();

        Color bgColor;
        String label = '';
        if (safe) {
          bgColor = const Color(0xFF00695C);
          label = '🏝️安全岛';
        } else if (t == 1) {
          bgColor = const Color(0xFFD4A359);
          label = '沙滩';
        } else if (t == 2) {
          bgColor = const Color(0xFF2E7D32);
          label = '森林';
        } else if (t == 3) {
          bgColor = const Color(0xFF5D4037);
          label = '⛰️山峰';
        } else {
          bgColor = const Color(0xFF0D47A1);
        }

        final canSinkHere = isMyTurn && phase == 'sink' && t == minIslandTerrain && t > 0;

        return InkWell(
          onTap: isMyTurn
              ? () => _onTapCell(
                    r: r,
                    c: c,
                    t: t,
                    phase: phase,
                    minIslandTerrain: minIslandTerrain,
                    cellExps: cellExps,
                    cellBoats: cellBoats,
                    cellCreatures: cellCreatures,
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: canSinkHere ? Colors.amberAccent : Colors.white24,
                width: canSinkHere ? 2 : 1,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label.isNotEmpty)
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  if (cellBoats.isNotEmpty)
                    for (final b in cellBoats)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedBoatId == b['id'] ? Colors.amber : Colors.brown.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('⛵小船', style: TextStyle(fontSize: 9, color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                  if (cellCreatures.isNotEmpty)
                    for (final cr in cellCreatures)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedCreatureId == cr['id'] ? Colors.amber : Colors.red.shade900,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${cr['type'] == 'serpent' ? '🐉' : (cr['type'] == 'shark' ? '🦈' : '🐋')}${cr['label']}',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                  if (cellExps.isNotEmpty)
                    Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        for (final e in cellExps)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _seatColors[((e['owner'] as int?) ?? 0) % _seatColors.length],
                              borderRadius: BorderRadius.circular(8),
                              border: _selectedExplorerId == e['id']
                                  ? Border.all(color: Colors.yellowAccent, width: 2)
                                  : null,
                            ),
                            child: Text(
                              '${e['value'] ?? '?'}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onTapCell({
    required int r,
    required int c,
    required int t,
    required String phase,
    required int minIslandTerrain,
    required List<Map<String, dynamic>> cellExps,
    required List<Map<String, dynamic>> cellBoats,
    required List<Map<String, dynamic>> cellCreatures,
  }) {
    final g = widget.g;

    if (phase == 'sink') {
      if (t == minIslandTerrain && t > 0) {
        g.act({'type': 'sink', 'r': r, 'c': c});
      }
      return;
    }

    if (phase == 'creature') {
      if (cellCreatures.isNotEmpty && _selectedCreatureId == null) {
        setState(() => _selectedCreatureId = cellCreatures.first['id'] as int?);
        return;
      }
      if (_selectedCreatureId != null) {
        final id = _selectedCreatureId!;
        setState(() => _selectedCreatureId = null);
        g.act({'type': 'creature', 'creatureId': id, 'r': r, 'c': c});
      }
      return;
    }

    if (phase == 'move') {
      final myCellExps = cellExps.where((e) => e['owner'] == g.seat).toList();
      if (_selectedExplorerId != null) {
        final id = _selectedExplorerId!;
        setState(() => _selectedExplorerId = null);
        g.act({'type': 'move', 'explorerId': id, 'r': r, 'c': c});
        return;
      }
      if (_selectedBoatId != null) {
        final id = _selectedBoatId!;
        setState(() => _selectedBoatId = null);
        g.act({'type': 'move_boat', 'boatId': id, 'r': r, 'c': c});
        return;
      }
      if (myCellExps.isNotEmpty) {
        setState(() {
          _selectedExplorerId = myCellExps.first['id'] as int?;
          _selectedBoatId = null;
        });
      } else if (cellBoats.isNotEmpty) {
        setState(() {
          _selectedBoatId = cellBoats.first['id'] as int?;
          _selectedExplorerId = null;
        });
      }
    }
  }
}
