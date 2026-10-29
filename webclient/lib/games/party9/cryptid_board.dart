import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CryptidBoard extends StatefulWidget {
  final GameContext g;
  const CryptidBoard(this.g, {super.key});

  @override
  State<CryptidBoard> createState() => _CryptidBoardState();
}

class _CryptidBoardState extends State<CryptidBoard> {
  int _selectedHex = 0;
  int _selectedTargetSeat = 1;

  static const List<String> _terrainNames = ['森林', '沙漠', '水域', '沼泽', '山脉'];
  static const List<Color> _terrainColors = [
    Color(0xFF2E7D32), // 森林
    Color(0xFFF9A825), // 沙漠
    Color(0xFF0277BD), // 水域
    Color(0xFF4A148C), // 沼泽
    Color(0xFF616161), // 山脉
  ];

  static const List<Color> _seatColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
  ];

  static const List<Color> _structColors = [
    Color(0xFF29B6F6), // 蓝
    Color(0xFFFAFAFA), // 白
    Color(0xFF66BB6A), // 绿
  ];

  static const List<String> _structColorNames = ['蓝', '白', '绿'];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final cells = (v['cells'] as List?)?.cast<Map>() ?? const <Map>[];
    final cubes = (v['cubes'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ?? List<int?>.filled(54, null);
    final discs = (v['discs'] as List?)
            ?.map((r) => (r as List).map((e) => (e as num).toInt()).toList())
            .toList() ??
        List.generate(54, (_) => <int>[]);
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = v['phase'] as String? ?? 'turn';
    final winner = (v['winner'] as num?)?.toInt() ?? -1;
    final myClue = v['myClue'] as String?;
    final myMatching = (v['myMatchingHexes'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? const <int>{};
    final targetHex = (v['targetHex'] as num?)?.toInt();
    final allClues = (v['allClues'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastEvent = v['lastEvent'] as String? ?? '';

    final myTurn = g.seat >= 0 && turn == g.seat && !g.over;
    if (_selectedTargetSeat == g.seat || _selectedTargetSeat >= g.players) {
      _selectedTargetSeat = ((g.seat < 0 ? 0 : g.seat) + 1) % g.players;
    }

    String statusText;
    if (g.over) {
      statusText = winner >= 0 ? '${g.name(winner)} 发现了诡影栖息地（格 #$targetHex），获得胜利！' : '游戏结束！';
    } else if (myTurn) {
      statusText = phase == 'penalty_cube'
          ? '请点击一个【不符合你线索】的无方块格，放置惩罚排除方块（■）'
          : '轮到你行动：选择地图格 #$_selectedHex 后向其他玩家提问或发起搜索！';
    } else {
      statusText = phase == 'penalty_cube'
          ? '等待 ${g.name(turn)} 放置惩罚方块（■）…'
          : '等待 ${g.name(turn)} 进行推理行动…';
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
                  // Players bar with color badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          size: 30,
                          trailing: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _seatColors[s % _seatColors.length],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Secret clue banner
                  if (myClue != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.key, size: 18, color: cs.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '我的秘密线索：$myClue（共 ${myMatching.length} 格符合，带 ★ 标记）',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // 54-Hex Map (9 cols x 6 rows)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var r = 0; r < 6; r++)
                              Padding(
                                padding: EdgeInsets.only(left: r.isOdd ? 28.0 : 0.0, bottom: 4.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var c = 0; c < 9; c++)
                                      if (r * 9 + c < cells.length)
                                        _buildHexTile(
                                          cs,
                                          g,
                                          cell: cells[r * 9 + c],
                                          cubeOwner: cubes[r * 9 + c],
                                          discOwners: discs[r * 9 + c],
                                          matchesMine: myMatching.contains(r * 9 + c),
                                          isTarget: targetHex == (r * 9 + c),
                                          selected: _selectedHex == (r * 9 + c),
                                          myTurn: myTurn,
                                          phase: phase,
                                        ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Action Controls
                  if (myTurn)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.primary, width: 1.5),
                      ),
                      child: _buildActionControls(
                        cs,
                        g,
                        phase: phase,
                        cubes: cubes,
                        myMatching: myMatching,
                      ),
                    ),
                  if (g.over && allClues.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '真相揭晓（唯一栖息地：格 #$targetHex）',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          for (var s = 0; s < allClues.length && s < g.players; s++)
                            Text(
                              '• ${g.name(s)}：${allClues[s]['text']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (g.over)
            Center(
              child: ResultBanner(
                winner >= 0 ? '${g.name(winner)} 发现神秘生物获胜！' : '游戏结束！',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (targetHex != null) Text('唯一栖息地：地图格 #$targetHex'),
                    for (var s = 0; s < allClues.length && s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${g.name(s)} 线索：${allClues[s]['text']}'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHexTile(
    ColorScheme cs,
    GameContext g, {
    required Map cell,
    required int? cubeOwner,
    required List<int> discOwners,
    required bool matchesMine,
    required bool isTarget,
    required bool selected,
    required bool myTurn,
    required String phase,
  }) {
    final idx = (cell['index'] as num?)?.toInt() ?? 0;
    final terrain = ((cell['terrain'] as num?)?.toInt() ?? 0).clamp(0, 4);
    final animal = (cell['animal'] as num?)?.toInt() ?? 0;
    final structType = (cell['structType'] as num?)?.toInt() ?? 0;
    final structColor = (cell['structColor'] as num?)?.toInt() ?? -1;

    final tColor = _terrainColors[terrain];

    String structLabel = '';
    if (structType == 1 && structColor >= 0 && structColor < 3) {
      structLabel = '${_structColorNames[structColor]}屋';
    } else if (structType == 2 && structColor >= 0 && structColor < 3) {
      structLabel = '${_structColorNames[structColor]}石';
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedHex = idx);
        if (myTurn && phase == 'penalty_cube' && cubeOwner == null && !matchesMine) {
          g.act({'type': 'place_cube', 'hex': idx});
        }
      },
      child: Container(
        width: 58,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: tColor.withValues(alpha: cubeOwner != null ? 0.35 : 0.78),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isTarget
                ? Colors.amberAccent
                : selected
                    ? Colors.white
                    : animal == 1
                        ? Colors.brown.shade900
                        : animal == 2
                            ? Colors.redAccent
                            : Colors.black38,
            width: isTarget || selected ? 2.5 : (animal > 0 ? 2.0 : 1.0),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#$idx${matchesMine ? "★" : ""}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (animal > 0)
                    Text(
                      animal == 1 ? '🐻' : '🐆',
                      style: const TextStyle(fontSize: 10),
                    ),
                ],
              ),
              Text(
                _terrainNames[terrain],
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (structLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    structLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: structColor >= 0 && structColor < 3 ? _structColors[structColor] : Colors.white,
                    ),
                  ),
                ),
              if (cubeOwner != null)
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _seatColors[cubeOwner % _seatColors.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '■P${cubeOwner + 1}',
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              else if (discOwners.isNotEmpty)
                Wrap(
                  spacing: 2,
                  children: [
                    for (final d in discOwners)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _seatColors[d % _seatColors.length],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionControls(
    ColorScheme cs,
    GameContext g, {
    required String phase,
    required List<int?> cubes,
    required Set<int> myMatching,
  }) {
    final hexCubed = _selectedHex >= 0 && _selectedHex < 54 && cubes[_selectedHex] != null;
    final hexMatchesMe = myMatching.contains(_selectedHex);

    if (phase == 'penalty_cube') {
      final canPlace = !hexCubed && !hexMatchesMe;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('已选格 #$_selectedHex：', style: const TextStyle(fontWeight: FontWeight.bold)),
          FilledButton.icon(
            onPressed: canPlace ? () => g.act({'type': 'place_cube', 'hex': _selectedHex}) : null,
            icon: const Icon(Icons.stop, size: 18),
            label: Text(canPlace ? '在格 #$_selectedHex 放置惩罚方块 (■)' : '请选择不符合你线索的无方块格'),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('选中格 #$_selectedHex · 提问对象：', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        for (var s = 0; s < g.players; s++)
          if (s != g.seat)
            ChoiceChip(
              label: Text(g.name(s)),
              selected: _selectedTargetSeat == s,
              onSelected: (_) => setState(() => _selectedTargetSeat = s),
            ),
        FilledButton.tonalIcon(
          onPressed: !hexCubed
              ? () => g.act({
                    'type': 'question',
                    'target': _selectedTargetSeat,
                    'hex': _selectedHex,
                  })
              : null,
          icon: const Icon(Icons.help_outline, size: 18),
          label: Text('询问 ${g.name(_selectedTargetSeat)} 格 #$_selectedHex'),
        ),
        FilledButton.icon(
          onPressed: (!hexCubed && hexMatchesMe)
              ? () => g.act({
                    'type': 'search',
                    'hex': _selectedHex,
                  })
              : null,
          icon: const Icon(Icons.travel_explore, size: 18),
          label: Text('搜索格 #$_selectedHex（需符合己方线索）'),
        ),
      ],
    );
  }
}
