import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _terrainNames = ['山脉', '森林', '草原', '湿地', '河流'];
const List<Color> _terrainColors = [
  Color(0xFF78909C), // 山脉
  Color(0xFF2E7D32), // 森林
  Color(0xFFF9A825), // 草原
  Color(0xFF26A69A), // 湿地
  Color(0xFF1E88E5), // 河流
];

const List<String> _animalNames = ['棕熊', '麋鹿', '大马哈鱼', '红尾鵟', '赤狐'];
const List<String> _animalIcons = ['🐻', '🦌', '🐟', '🦅', '🦊'];
const List<Color> _animalColors = [
  Color(0xFF6D4C41), // 棕熊
  Color(0xFF8D6E63), // 麋鹿
  Color(0xFFE53935), // 大马哈鱼
  Color(0xFF1565C0), // 红尾鵟
  Color(0xFFEF6C00), // 赤狐
];

class CascadiaBoard extends StatefulWidget {
  final GameContext g;
  const CascadiaBoard(this.g, {super.key});

  @override
  State<CascadiaBoard> createState() => _CascadiaBoardState();
}

class _CascadiaBoardState extends State<CascadiaBoard> {
  int _tileIdx = 0;
  int _animalIdx = 0;
  bool _splitMode = false;
  (int, int)? _selectedHex;
  (int, int)? _selectedAnimalHex;
  bool _discardAnimal = false;
  int? _viewSeat;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 20;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final tilesLeft = (v['tilesLeft'] as num?)?.toInt() ?? 0;
    final culledThisTurn = v['culledThisTurn'] == true;
    final threeOfAKind = (v['threeOfAKind'] as num?)?.toInt() ?? -1;
    final lastAction = (v['lastAction'] as String?) ?? '';

    final market = (v['market'] as List?)?.cast<Map>() ?? const [];
    final natureTokens = (v['natureTokens'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final gridsRaw = (v['grids'] as List?) ?? const [];
    final validHexesRaw = (v['validHexes'] as List?)?.cast<Map>() ?? const [];
    final breakdown = (v['breakdown'] as List?)?.cast<Map>() ?? const [];

    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;
    final activeSeat = g.seat >= 0 ? g.seat : 0;
    final inspectedSeat = (_viewSeat != null && _viewSeat! < g.players) ? _viewSeat! : activeSeat;

    if (_tileIdx >= market.length) _tileIdx = 0;
    if (_animalIdx >= market.length) _animalIdx = 0;
    if (!_splitMode) _animalIdx = _tileIdx;

    final validCoords = <(int, int)>[
      for (final m in validHexesRaw) ((m['r'] as num).toInt(), (m['c'] as num).toInt()),
    ];
    if (_selectedHex == null || !validCoords.contains(_selectedHex)) {
      _selectedHex = validCoords.isNotEmpty ? validCoords.first : null;
    }

    // Determine which hexes on my grid (plus the newly placed tile at `_selectedHex`) can accept the selected animal
    final chosenPair = market.isNotEmpty ? market[_tileIdx] : null;
    final chosenTile = chosenPair?['tile'] as Map?;
    final chosenAnimal = market.isNotEmpty ? ((market[_animalIdx]['animal'] as num?)?.toInt() ?? 0) : 0;

    final myGridList = (activeSeat < gridsRaw.length ? gridsRaw[activeSeat] as List : const []).cast<Map>();
    final candidateAnimalHexes = <(int, int)>[];
    if (_selectedHex != null && chosenTile != null) {
      final allowed = (chosenTile['allowedAnimals'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
      if (allowed.contains(chosenAnimal)) {
        candidateAnimalHexes.add(_selectedHex!);
      }
    }
    for (final h in myGridList) {
      final hasAnimal = h['hasAnimal'] == true || h['animal'] != null;
      final allowed = (h['allowedAnimals'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
      if (!hasAnimal && allowed.contains(chosenAnimal)) {
        candidateAnimalHexes.add(((h['r'] as num).toInt(), (h['c'] as num).toInt()));
      }
    }
    if (!_discardAnimal) {
      if (_selectedAnimalHex == null || !candidateAnimalHexes.contains(_selectedAnimalHex)) {
        _selectedAnimalHex = candidateAnimalHexes.isNotEmpty ? candidateAnimalHexes.first : null;
      }
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(
                      over
                          ? '卡斯卡迪亚之旅 已结束'
                          : (isMyTurn ? '轮到你放置栖息地与野生动物' : '等待 ${g.name(turn)} 行动…'),
                      highlight: isMyTurn,
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('第 $round / $maxRounds 轮 · 牌堆余 $tilesLeft'),
                    ),
                  ],
                ),
              ),
              // Player strip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      GestureDetector(
                        onTap: () => setState(() => _viewSeat = s),
                        child: g.tag(
                          s,
                          active: s == turn && !over,
                          sub: '${scores[s]}分 · 🌲${natureTokens[s]}',
                          size: 30,
                        ),
                      ),
                  ],
                ),
              ),
              if (lastAction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Text(
                    lastAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              // Main scrollable area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMarketSection(
                        cs,
                        g,
                        market,
                        isMyTurn,
                        isMyTurn ? natureTokens[g.seat] : 0,
                        threeOfAKind,
                        culledThisTurn,
                      ),
                      const SizedBox(height: 8),
                      if (isMyTurn && market.isNotEmpty && _selectedHex != null)
                        _buildPlacementControls(
                          cs,
                          g,
                          validCoords,
                          candidateAnimalHexes,
                          chosenAnimal,
                          natureTokens[g.seat],
                        ),
                      const SizedBox(height: 8),
                      _buildHexMapSection(
                        cs,
                        g,
                        inspectedSeat,
                        (inspectedSeat < gridsRaw.length ? gridsRaw[inspectedSeat] as List : const []).cast<Map>(),
                        inspectedSeat == turn && !over ? validCoords : const [],
                      ),
                      const SizedBox(height: 8),
                      if (breakdown.isNotEmpty) _buildScoreSummaryCard(cs, g, breakdown),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (over && v['result'] != null)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(g, scores),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketSection(
    ColorScheme cs,
    GameContext g,
    List<Map> market,
    bool isMyTurn,
    int myTokens,
    int threeOfAKind,
    bool culledThisTurn,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text('中央栖息地与野生动物市场', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
              if (isMyTurn)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      visualDensity: VisualDensity.compact,
                      selected: _splitMode,
                      label: Text('🌲 跨列自由搭配 (余$myTokens)'),
                      onSelected: myTokens > 0
                          ? (val) => setState(() {
                                _splitMode = val;
                                if (!val) _animalIdx = _tileIdx;
                              })
                          : null,
                    ),
                    if (myTokens > 0)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('🌲 刷新全部动物'),
                        onPressed: () => g.act({'type': 'wipe_animals'}),
                      ),
                    if (threeOfAKind >= 0 && !culledThisTurn)
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text('免费刷新3只${_animalNames[threeOfAKind]}'),
                        onPressed: () => g.act({'type': 'cull_free'}),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < market.length; i++) _buildMarketSlot(cs, i, market[i], isMyTurn),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketSlot(ColorScheme cs, int idx, Map pair, bool isMyTurn) {
    final tile = (pair['tile'] as Map?) ?? const {};
    final terrains = (tile['terrains'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0];
    final allowed = (tile['allowedAnimals'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0];
    final isKeystone = tile['isKeystone'] == true;
    final animal = (pair['animal'] as num?)?.toInt() ?? 0;

    final tileSelected = _tileIdx == idx;
    final animalSelected = _animalIdx == idx;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (tileSelected || animalSelected)
            ? cs.primaryContainer.withValues(alpha: 0.45)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (tileSelected || animalSelected) ? cs.primary : cs.outline.withValues(alpha: 0.35),
          width: (tileSelected || animalSelected) ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: isMyTurn
                ? () => setState(() {
                      _tileIdx = idx;
                      if (!_splitMode) _animalIdx = idx;
                    })
                : null,
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 3,
                  runSpacing: 2,
                  children: [
                    for (final t in terrains)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _terrainColors[t % 5],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _terrainNames[t % 5],
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isKeystone)
                      const Text('🌲+1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '可栖息: ${allowed.map((a) => _animalIcons[a % 5]).join(" ")}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 10),
          InkWell(
            onTap: isMyTurn
                ? () => setState(() {
                      if (_splitMode) {
                        _animalIdx = idx;
                      } else {
                        _tileIdx = idx;
                        _animalIdx = idx;
                      }
                    })
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _animalColors[animal % 5].withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_animalIcons[animal % 5]} ${_animalNames[animal % 5]}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementControls(
    ColorScheme cs,
    GameContext g,
    List<(int, int)> validCoords,
    List<(int, int)> candidateAnimalHexes,
    int chosenAnimal,
    int myTokens,
  ) {
    final needToken = _tileIdx != _animalIdx;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('① 选择新栖息地板块放置坐标 (点击下方网格或坐标标签):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final pos in validCoords.take(14))
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('(${pos.$1}, ${pos.$2})'),
                  selected: _selectedHex == pos,
                  onSelected: (_) => setState(() => _selectedHex = pos),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '② 安置【${_animalIcons[chosenAnimal]} ${_animalNames[chosenAnimal]}】位置:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final aPos in candidateAnimalHexes)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(aPos == _selectedHex ? '新板块(${aPos.$1},${aPos.$2})' : '(${aPos.$1},${aPos.$2})'),
                  selected: !_discardAnimal && _selectedAnimalHex == aPos,
                  onSelected: (_) => setState(() {
                    _discardAnimal = false;
                    _selectedAnimalHex = aPos;
                  }),
                ),
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: const Text('弃置该动物'),
                selected: _discardAnimal || candidateAnimalHexes.isEmpty,
                onSelected: (_) => setState(() => _discardAnimal = true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(needToken ? '确认放置 (花费1枚🌲)' : '确认放置栖息地与动物'),
              onPressed: (!needToken || myTokens > 0) && _selectedHex != null
                  ? () {
                      final placeAnimal = !_discardAnimal &&
                          _selectedAnimalHex != null &&
                          candidateAnimalHexes.contains(_selectedAnimalHex);
                      g.act({
                        'type': 'turn',
                        'tileIdx': _tileIdx,
                        'animalIdx': _animalIdx,
                        'r': _selectedHex!.$1,
                        'c': _selectedHex!.$2,
                        if (placeAnimal) 'animalR': _selectedAnimalHex!.$1,
                        if (placeAnimal) 'animalC': _selectedAnimalHex!.$2,
                        if (!placeAnimal) 'discardAnimal': true,
                      });
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexMapSection(
    ColorScheme cs,
    GameContext g,
    int seat,
    List<Map> hexes,
    List<(int, int)> validCoords,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${g.name(seat)} 的生态版图 (${hexes.length} 块栖息地)',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
              ),
              Wrap(
                spacing: 4,
                children: [
                  for (var s = 0; s < g.players; s++)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(g.name(s), style: const TextStyle(fontSize: 11)),
                      selected: seat == s,
                      onSelected: (_) => setState(() => _viewSeat = s),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) => _onHexCanvasTap(
                    details.localPosition,
                    Size(constraints.maxWidth, 220),
                    hexes,
                    validCoords,
                  ),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 220),
                    painter: _CascadiaHexPainter(
                      hexes: hexes,
                      validCoords: validCoords,
                      selectedHex: _selectedHex,
                      selectedAnimalHex: _discardAnimal ? null : _selectedAnimalHex,
                      cs: cs,
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

  void _onHexCanvasTap(
    Offset pos,
    Size size,
    List<Map> hexes,
    List<(int, int)> validCoords,
  ) {
    const radius = 22.0;
    final allCoords = <(int, int)>[
      for (final h in hexes) ((h['r'] as num).toInt(), (h['c'] as num).toInt()),
      ...validCoords,
    ];
    if (allCoords.isEmpty) return;

    Offset axialToPixel(int r, int c) {
      final x = radius * sqrt(3) * (c + r / 2.0);
      final y = radius * 1.5 * r;
      return Offset(x, y);
    }

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final rc in allCoords) {
      final p = axialToPixel(rc.$1, rc.$2);
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    final centerShift = Offset(
      size.width / 2 - (minX + maxX) / 2,
      size.height / 2 - (minY + maxY) / 2,
    );

    for (final vc in validCoords) {
      final center = axialToPixel(vc.$1, vc.$2) + centerShift;
      if ((pos - center).distance <= radius * 0.9) {
        setState(() => _selectedHex = vc);
        return;
      }
    }
    for (final h in hexes) {
      final rc = ((h['r'] as num).toInt(), (h['c'] as num).toInt());
      final center = axialToPixel(rc.$1, rc.$2) + centerShift;
      if ((pos - center).distance <= radius * 0.9) {
        setState(() {
          _discardAnimal = false;
          _selectedAnimalHex = rc;
        });
        return;
      }
    }
  }

  Widget _buildScoreSummaryCard(ColorScheme cs, GameContext g, List<Map> breakdown) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('实时生态计分榜 (🐻棕熊 / 🦌麋鹿 / 🐟大马哈鱼 / 🦅红尾鵟 / 🦊赤狐 / 地形走廊 / 🌲松果)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 28,
              dataRowMinHeight: 26,
              dataRowMaxHeight: 30,
              columnSpacing: 14,
              columns: const [
                DataColumn(label: Text('玩家')),
                DataColumn(label: Text('🐻')),
                DataColumn(label: Text('🦌')),
                DataColumn(label: Text('🐟')),
                DataColumn(label: Text('🦅')),
                DataColumn(label: Text('🦊')),
                DataColumn(label: Text('走廊+奖励')),
                DataColumn(label: Text('🌲')),
                DataColumn(label: Text('总分')),
              ],
              rows: [
                for (var s = 0; s < g.players; s++) _buildScoreRow(cs, g, s, breakdown[s]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildScoreRow(ColorScheme cs, GameContext g, int s, Map b) {
    final wl = (b['wildlife'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0, 0, 0, 0];
    final cTot = (b['corridorTotal'] as num?)?.toInt() ?? 0;
    final bTot = (b['bonusTotal'] as num?)?.toInt() ?? 0;
    final nTok = (b['natureTokens'] as num?)?.toInt() ?? 0;
    final tot = (b['total'] as num?)?.toInt() ?? 0;
    return DataRow(cells: [
      DataCell(Text(g.name(s), style: const TextStyle(fontWeight: FontWeight.bold))),
      for (var a = 0; a < 5; a++) DataCell(Text('${wl[a]}')),
      DataCell(Text('$cTot+$bTot')),
      DataCell(Text('$nTok')),
      DataCell(Text('$tot', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary))),
    ]);
  }

  Widget _buildResultBanner(GameContext g, List<int> scores) {
    final maxScore = scores.reduce(max);
    final winners = [for (var s = 0; s < g.players; s++) if (scores[s] == maxScore) g.name(s)];
    return ResultBanner(
      '${winners.join("、")} 获胜！($maxScore 分)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var s = 0; s < g.players; s++)
            Text('${g.name(s)}: ${scores[s]} 分'),
        ],
      ),
    );
  }
}

class _CascadiaHexPainter extends CustomPainter {
  final List<Map> hexes;
  final List<(int, int)> validCoords;
  final (int, int)? selectedHex;
  final (int, int)? selectedAnimalHex;
  final ColorScheme cs;

  _CascadiaHexPainter({
    required this.hexes,
    required this.validCoords,
    required this.selectedHex,
    required this.selectedAnimalHex,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 22.0;
    final allCoords = <(int, int)>[
      for (final h in hexes) ((h['r'] as num).toInt(), (h['c'] as num).toInt()),
      ...validCoords,
    ];
    if (allCoords.isEmpty) return;

    Offset axialToPixel(int r, int c) {
      final x = radius * sqrt(3) * (c + r / 2.0);
      final y = radius * 1.5 * r;
      return Offset(x, y);
    }

    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final rc in allCoords) {
      final p = axialToPixel(rc.$1, rc.$2);
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }
    final shift = Offset(
      size.width / 2 - (minX + maxX) / 2,
      size.height / 2 - (minY + maxY) / 2,
    );

    Path hexPath(Offset center, double r) {
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final angle = (60 * i - 30) * pi / 180;
        final pt = Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      return path;
    }

    // Draw valid placement ghost hexes
    for (final vc in validCoords) {
      final center = axialToPixel(vc.$1, vc.$2) + shift;
      final isSel = selectedHex == vc;
      final p = hexPath(center, radius - 2);
      canvas.drawPath(
        p,
        Paint()
          ..color = isSel
              ? cs.primary.withValues(alpha: 0.35)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        p,
        Paint()
          ..color = isSel ? cs.primary : cs.outline.withValues(alpha: 0.5)
          ..strokeWidth = isSel ? 2.5 : 1.2
          ..style = PaintingStyle.stroke,
      );
      _drawText(canvas, '${vc.$1},${vc.$2}', center, 9, cs.onSurface.withValues(alpha: 0.75));
    }

    // Draw placed habitat hexes
    for (final h in hexes) {
      final r = (h['r'] as num).toInt();
      final c = (h['c'] as num).toInt();
      final terrains = (h['terrains'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0];
      final animal = (h['animal'] as num?)?.toInt();
      final allowed = (h['allowedAnimals'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
      final center = axialToPixel(r, c) + shift;
      final p = hexPath(center, radius - 1.5);

      canvas.save();
      canvas.clipPath(p);
      if (terrains.length == 1) {
        canvas.drawRect(
          Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
          Paint()..color = _terrainColors[terrains[0] % 5],
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(center.dx - radius, center.dy - radius, center.dx, center.dy + radius),
          Paint()..color = _terrainColors[terrains[0] % 5],
        );
        canvas.drawRect(
          Rect.fromLTRB(center.dx, center.dy - radius, center.dx + radius, center.dy + radius),
          Paint()..color = _terrainColors[terrains[1] % 5],
        );
      }
      canvas.restore();

      final isAnimalTarget = selectedAnimalHex == (r, c);
      canvas.drawPath(
        p,
        Paint()
          ..color = isAnimalTarget ? Colors.amberAccent : Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = isAnimalTarget ? 2.8 : 1.5
          ..style = PaintingStyle.stroke,
      );

      if (animal != null) {
        canvas.drawCircle(center, 11, Paint()..color = _animalColors[animal % 5]);
        _drawText(canvas, _animalIcons[animal % 5], center, 12, Colors.white);
      } else {
        final label = allowed.map((a) => _animalNames[a % 5].substring(0, 1)).join('/');
        _drawText(canvas, label, center, 9, Colors.white);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          fontFamilyFallback: kFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CascadiaHexPainter oldDelegate) => true;
}
