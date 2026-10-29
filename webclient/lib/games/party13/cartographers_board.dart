import 'package:flutter/material.dart';
import '../../widgets/common.dart';

class CartographersBoard extends StatefulWidget {
  final GameContext g;
  const CartographersBoard(this.g, {super.key});

  @override
  State<CartographersBoard> createState() => _CartographersBoardState();
}

class _CartographersBoardState extends State<CartographersBoard> {
  int _viewingSeat = -1;
  int? _selectedTerrain;
  final Set<(int, int)> _selectedCells = {};

  static const _terrainNames = ['空地', '森林', '村落', '农田', '水域', '山脉', '魔物'];
  static const _terrainIcons = ['⬜', '🌲', '🏘️', '🌾', '💧', '⛰️', '👹'];
  static const _terrainColors = [
    Color(0xFF90A4AE),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFFF9A825),
    Color(0xFF1565C0),
    Color(0xFF5D4037),
    Color(0xFF6A1B9A),
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final rawMaps = (v['maps'] as List?) ?? const [];
    final maps = [
      for (final m in rawMaps)
        [
          for (final row in (m as List))
            [for (final cell in (row as List)) (cell as num).toInt()]
        ]
    ];
    final coins = [
      for (final x in (v['coins'] as List? ?? const [])) (x as num).toInt()
    ];
    final scores = [
      for (final x in (v['scores'] as List? ?? const [])) (x as num).toInt()
    ];
    final monsterPenalties = [
      for (final x in (v['monsterPenalties'] as List? ?? const []))
        (x as num).toInt()
    ];
    final placedThisTurn = [
      for (final x in (v['placedThisTurn'] as List? ?? const [])) x == true
    ];

    final seasonName = (v['seasonName'] as String?) ?? '春季';
    final seasonTime = (v['seasonTime'] as num?)?.toInt() ?? 0;
    final seasonThreshold = (v['seasonThreshold'] as num?)?.toInt() ?? 7;
    final edicts = (v['edicts'] as List?) ?? const [];
    final card = (v['currentCard'] as Map?)?.cast<String, dynamic>() ?? const {};
    final samplePlacement = [
      for (final p in (v['samplePlacement'] as List? ?? const []))
        if (p is List && p.length >= 2)
          [(p[0] as num).toInt(), (p[1] as num).toInt()]
    ];
    final lastLog = (v['lastLog'] as String?) ?? '';
    final over = v['over'] == true || g.over;

    final terrainOptions = [
      for (final t in (card['terrainOptions'] as List? ?? const [1]))
        (t as num).toInt()
    ];
    final effectiveTerrain =
        (_selectedTerrain != null && terrainOptions.contains(_selectedTerrain))
            ? _selectedTerrain!
            : (terrainOptions.isNotEmpty ? terrainOptions.first : 1);

    final mySeat = g.seat >= 0 && g.seat < g.players ? g.seat : 0;
    final displaySeat =
        (_viewingSeat >= 0 && _viewingSeat < g.players) ? _viewingSeat : mySeat;
    final canPlace =
        !over && g.seat >= 0 && g.seat < placedThisTurn.length && !placedThisTurn[g.seat];

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720 &&
              constraints.maxWidth > constraints.maxHeight * 1.15;

          final topBar = _buildTopBar(
            g: g,
            cs: cs,
            seasonName: seasonName,
            seasonTime: seasonTime,
            seasonThreshold: seasonThreshold,
            scores: scores,
            coins: coins,
            monsterPenalties: monsterPenalties,
            placedThisTurn: placedThisTurn,
            displaySeat: displaySeat,
            canPlace: canPlace,
            lastLog: lastLog,
          );

          final mapGrid = maps.isNotEmpty && displaySeat < maps.length
              ? _buildKingdomMap(
                  cs: cs,
                  map: maps[displaySeat],
                  interactive: canPlace && displaySeat == mySeat,
                )
              : const SizedBox();

          final sidePanel = _buildSidePanel(
            g: g,
            cs: cs,
            card: card,
            terrainOptions: terrainOptions,
            effectiveTerrain: effectiveTerrain,
            edicts: edicts,
            canPlace: canPlace,
            samplePlacement: samplePlacement,
            over: over,
            scores: scores,
          );

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        topBar,
                        const SizedBox(height: 6),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: mapGrid,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: sidePanel,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                topBar,
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: mapGrid,
                ),
                const SizedBox(height: 8),
                sidePanel,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar({
    required GameContext g,
    required ColorScheme cs,
    required String seasonName,
    required int seasonTime,
    required int seasonThreshold,
    required List<int> scores,
    required List<int> coins,
    required List<int> monsterPenalties,
    required List<bool> placedThisTurn,
    required int displaySeat,
    required bool canPlace,
    required String lastLog,
  }) {
    final statusStr = g.over
        ? '制图完成'
        : canPlace
            ? '请在你的 8×8 王国地图上绘制当前探索卡地形'
            : '等待其他制图师完成本回合绘制...';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBar(statusStr, highlight: canPlace),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '🗓️ $seasonName · 进度 $seasonTime/$seasonThreshold',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (var s = 0; s < g.players; s++)
              GestureDetector(
                onTap: () => setState(() => _viewingSeat = s),
                child: g.tag(
                  s,
                  active: displaySeat == s,
                  sub:
                      '⭐${s < scores.length ? scores[s] : 0}分 🪙${s < coins.length ? coins[s] : 0} 👹-${s < monsterPenalties.length ? monsterPenalties[s] : 0}',
                  size: 30,
                ),
              ),
          ],
        ),
        if (lastLog.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            lastLog,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.8)),
          ),
        ],
      ],
    );
  }

  Widget _buildKingdomMap({
    required ColorScheme cs,
    required List<List<int>> map,
    required bool interactive,
  }) {
    const cellSize = 44.0;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 8; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < 8; c++)
                  _buildMapCell(
                    cs: cs,
                    r: r,
                    c: c,
                    terrain: map[r][c],
                    selected: _selectedCells.contains((r, c)),
                    interactive: interactive,
                    cellSize: cellSize,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMapCell({
    required ColorScheme cs,
    required int r,
    required int c,
    required int terrain,
    required bool selected,
    required bool interactive,
    required double cellSize,
  }) {
    final safeTerrain = (terrain >= 0 && terrain < _terrainIcons.length) ? terrain : 0;
    final baseColor = _terrainColors[safeTerrain];

    return GestureDetector(
      onTap: interactive && terrain == 0
          ? () {
              setState(() {
                if (_selectedCells.contains((r, c))) {
                  _selectedCells.remove((r, c));
                } else {
                  _selectedCells.add((r, c));
                }
              });
            }
          : null,
      child: Container(
        width: cellSize,
        height: cellSize,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.45)
              : (safeTerrain == 0
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
                  : baseColor.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? cs.primary
                : (safeTerrain == 0
                    ? cs.outline.withValues(alpha: 0.25)
                    : baseColor.withValues(alpha: 0.7)),
            width: selected ? 2.2 : 1.0,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              safeTerrain == 0
                  ? (selected ? '✏️' : '')
                  : _terrainIcons[safeTerrain],
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel({
    required GameContext g,
    required ColorScheme cs,
    required Map<String, dynamic> card,
    required List<int> terrainOptions,
    required int effectiveTerrain,
    required List<dynamic> edicts,
    required bool canPlace,
    required List<List<int>> samplePlacement,
    required bool over,
    required List<int> scores,
  }) {
    final cardName = (card['name'] as String?) ?? '探索卡';
    final cardTime = (card['time'] as num?)?.toInt() ?? 1;
    final isMonster = card['isMonster'] == true;
    final rawShapes = (card['shapes'] as List?) ?? const [];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (over) ...[
            ResultBanner('四季制图结束！最高分: ${scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b)} 分'),
            const SizedBox(height: 8),
          ],
          // Explore card info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isMonster ? Colors.purple : cs.primary).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (isMonster ? Colors.purpleAccent : cs.primary).withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '🧭 探索卡：【$cardName】',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Text(
                      '⏳ 时间 +$cardTime',
                      style: TextStyle(fontSize: 12, color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('可选地形:', style: TextStyle(fontSize: 12)),
                    for (final t in terrainOptions)
                      ChoiceChip(
                        label: Text(
                          '${t < _terrainIcons.length ? _terrainIcons[t] : ""} ${t < _terrainNames.length ? _terrainNames[t] : t}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: effectiveTerrain == t,
                        onSelected: canPlace
                            ? (_) => setState(() => _selectedTerrain = t)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('可用形状:', style: TextStyle(fontSize: 12)),
                    for (var i = 0; i < rawShapes.length; i++)
                      _buildMiniShapePreview(cs, rawShapes[i] as List),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.brush, size: 16),
                label: Text('确认绘制 (${_selectedCells.length}格)'),
                onPressed: canPlace && _selectedCells.isNotEmpty
                    ? () {
                        final cells = [
                          for (final (r, c) in _selectedCells) [r, c]
                        ];
                        setState(() => _selectedCells.clear());
                        g.act({
                          'type': 'place',
                          'terrain': effectiveTerrain,
                          'cells': cells,
                        });
                      }
                    : null,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('推荐落点绘制'),
                onPressed: canPlace && samplePlacement.isNotEmpty
                    ? () {
                        setState(() => _selectedCells.clear());
                        g.act({
                          'type': 'place',
                          'terrain': effectiveTerrain,
                          'cells': samplePlacement,
                        });
                      }
                    : null,
              ),
              if (_selectedCells.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selectedCells.clear()),
                  child: const Text('清空选格'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '📜 四季王国计分诏令：',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          for (final e in edicts)
            if (e is Map)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: e['activeThisSeason'] == true
                      ? cs.primaryContainer.withValues(alpha: 0.45)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '[${e['slot']}] ${e['name']}：${e['desc']}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: e['activeThisSeason'] == true
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMiniShapePreview(ColorScheme cs, List rawShape) {
    final pts = <(int, int)>{};
    var maxR = 0, maxC = 0;
    for (final p in rawShape) {
      if (p is List && p.length >= 2) {
        final r = (p[0] as num).toInt();
        final c = (p[1] as num).toInt();
        pts.add((r, c));
        if (r > maxR) maxR = r;
        if (c > maxC) maxC = c;
      }
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r <= maxR; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c <= maxC; c++)
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: pts.contains((r, c))
                          ? cs.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
