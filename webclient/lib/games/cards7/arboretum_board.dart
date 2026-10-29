import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class ArboretumBoard extends StatefulWidget {
  final GameContext g;
  const ArboretumBoard(this.g, {super.key});

  @override
  State<ArboretumBoard> createState() => _ArboretumBoardState();
}

class _ArboretumBoardState extends State<ArboretumBoard> {
  String? _selectedCard;
  int? _inspectingSeat;

  static const List<String> _speciesNames = [
    '樱花',
    '枫树',
    '橡树',
    '蓝花楹',
    '柳树',
    '金合欢',
    '桦树',
    '松树',
    '雪松',
    '紫荆',
  ];

  static const List<Color> _speciesColors = [
    Color(0xFFD81B60), // 0 樱花
    Color(0xFFE53935), // 1 枫树
    Color(0xFF6D4C41), // 2 橡树
    Color(0xFF7E57C2), // 3 蓝花楹
    Color(0xFF00897B), // 4 柳树
    Color(0xFFF9A825), // 5 金合欢
    Color(0xFF00ACC1), // 6 桦树
    Color(0xFF2E7D32), // 7 松树
    Color(0xFF3949AB), // 8 雪松
    Color(0xFFAD1457), // 9 紫荆
  ];

  int _spOf(String card) {
    final i = card.indexOf('-');
    return i > 0 ? (int.tryParse(card.substring(0, i)) ?? 0) : 0;
  }

  int _rkOf(String card) {
    final i = card.indexOf('-');
    return i > 0 ? (int.tryParse(card.substring(i + 1)) ?? 1) : 1;
  }

  String _spName(int sp) => (sp >= 0 && sp < _speciesNames.length) ? _speciesNames[sp] : '树$sp';
  Color _spColor(int sp) => _speciesColors[sp % _speciesColors.length];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final step = (v['step'] as String?) ?? 'draw1';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final turnCount = (v['turnCount'] as num?)?.toInt() ?? 1;
    final numSpecies = (v['numSpecies'] as num?)?.toInt() ?? 6;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;

    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final myHand = (v['hand'] as List?)?.cast<String>() ?? const <String>[];
    final discardsRaw = (v['discards'] as List?) ?? const [];
    final discards = [
      for (var s = 0; s < g.players; s++)
        s < discardsRaw.length ? (discardsRaw[s] as List).cast<String>() : const <String>[],
    ];
    final gridsRaw = (v['grids'] as List?) ?? const [];
    final grids = [
      for (var s = 0; s < g.players; s++)
        s < gridsRaw.length
            ? (gridsRaw[s] as Map).map((k, val) => MapEntry(k.toString(), val.toString()))
            : const <String, String>{},
    ];
    final validSlotsRaw = (v['validSlots'] as List?) ?? const [];
    final validSlots = [
      for (final item in validSlotsRaw)
        if (item is List && item.length >= 2)
          [(item[0] as num).toInt(), (item[1] as num).toInt()],
    ];
    final totalScores = (v['totalScores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final speciesBreakdown = (v['speciesBreakdown'] as List?)?.cast<Map>() ?? const <Map>[];

    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;
    final activeSelected = (myHand.contains(_selectedCard))
        ? _selectedCard
        : (myHand.isNotEmpty ? myHand.first : null);

    final defaultSeat = g.seat >= 0 ? g.seat : 0;
    final viewSeat = (isMyTurn && step == 'plant')
        ? defaultSeat
        : (_inspectingSeat != null && _inspectingSeat! < g.players ? _inspectingSeat! : defaultSeat);

    String statusText;
    if (over) {
      statusText = '植物园终局结算完成！';
    } else if (isMyTurn) {
      switch (step) {
        case 'draw1':
          statusText = '步骤 1/4：请点击【中央摸牌堆】或任意玩家的【弃牌堆顶】摸第 1 张牌';
          break;
        case 'draw2':
          statusText = '步骤 2/4：请摸第 2 张牌（牌库或任意非空弃牌堆）';
          break;
        case 'plant':
          statusText = '步骤 3/4：点选下方手牌，再点击植物园网格中的【+空位】栽种';
          break;
        case 'discard':
          statusText = '步骤 4/4：请点击下方一张手牌将其弃入你的个人弃牌堆';
          break;
        default:
          statusText = '轮到你操作';
      }
    } else {
      final stepLabel = step == 'draw1'
          ? '摸第1张'
          : (step == 'draw2' ? '摸第2张' : (step == 'plant' ? '栽种树木' : '弃置手牌'));
      statusText = '等待 ${g.name(turn)} 操作（$stepLabel）';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
      final cardW = compact ? 42.0 : 52.0;

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 4 : 8),
        child: Stack(
          children: [
            Column(
              children: [
                // Top Info & Status
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _infoPill(cs, '回合 $turnCount · 树种 $numSpecies 种'),
                      const SizedBox(width: 6),
                      _infoPill(cs, '中央牌库剩余: $deckCount 张', highlight: deckCount <= 6),
                      const SizedBox(width: 6),
                      StatusBar(statusText, highlight: isMyTurn),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),

                // Draw Deck + Player Tabs & Discard Piles
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Central Deck button
                      _buildDeckTile(
                        cs: cs,
                        deckCount: deckCount,
                        canDraw: isMyTurn && (step == 'draw1' || step == 'draw2') && deckCount > 0,
                        compact: compact,
                        onTap: () => g.act({'type': 'draw', 'source': 'deck'}),
                      ),
                      const SizedBox(width: 8),
                      for (var s = 0; s < g.players; s++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _buildPlayerDiscardCard(
                            cs: cs,
                            g: g,
                            seat: s,
                            isTurn: turn == s,
                            isViewing: viewSeat == s,
                            handCount: handCounts[s],
                            treeCount: grids[s].length,
                            discardPile: discards[s],
                            canDrawDiscard: isMyTurn &&
                                (step == 'draw1' || step == 'draw2') &&
                                discards[s].isNotEmpty,
                            compact: compact,
                            onSelectView: () => setState(() => _inspectingSeat = s),
                            onDrawDiscard: () => g.act({'type': 'draw', 'source': 'discard', 'seat': s}),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),

                // Main Arboretum Grid Viewport
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(compact ? 4 : 8),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.park, size: 15, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${g.name(viewSeat)} 的植物园（已种 ${grids[viewSeat].length} 棵）',
                                style: TextStyle(
                                  fontSize: compact ? 11 : 13,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                              ),
                              if (isMyTurn && step == 'plant' && activeSelected != null) ...[
                                const SizedBox(width: 10),
                                Text(
                                  '待种卡牌: ${_spName(_spOf(activeSelected))} ${_rkOf(activeSelected)}',
                                  style: TextStyle(
                                    fontSize: compact ? 11 : 12,
                                    fontWeight: FontWeight.bold,
                                    color: _spColor(_spOf(activeSelected)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Center(
                            child: _buildArboretumGrid(
                              cs: cs,
                              grid: grids[viewSeat],
                              validSlots: (viewSeat == g.seat && isMyTurn && step == 'plant')
                                  ? validSlots
                                  : const [],
                              selectedCard: activeSelected,
                              compact: compact,
                              onPlantAt: (r, c) {
                                if (activeSelected != null) {
                                  g.act({'type': 'plant', 'card': activeSelected, 'r': r, 'c': c});
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom My Hand Bar
                if (myHand.isNotEmpty) ...[
                  SizedBox(height: compact ? 3 : 6),
                  Row(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            isMyTurn && step == 'plant'
                                ? '点选要种的树:'
                                : (isMyTurn && step == 'discard' ? '点击弃置手牌:' : '我的手牌(${myHand.length}):'),
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: cardW * 1.38,
                          child: Center(
                            child: OverlapRow(
                              itemWidth: cardW + 6,
                              children: [
                                for (final c in myHand)
                                  _buildTreeCard(
                                    card: c,
                                    width: cardW,
                                    selected: isMyTurn && (step == 'plant' || step == 'discard') && c == activeSelected,
                                    onTap: () {
                                      if (isMyTurn && step == 'discard') {
                                        g.act({'type': 'discard', 'card': c});
                                      } else {
                                        setState(() => _selectedCard = c);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isMyTurn && step == 'discard' && activeSelected != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: FilledButton.tonal(
                            onPressed: () => g.act({'type': 'discard', 'card': activeSelected}),
                            child: const Text('弃置'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            if (over)
              Center(
                child: ResultBanner(
                  _winnerBannerText(g, totalScores),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200, maxWidth: 520),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            [
                              for (var s = 0; s < g.players; s++) '${g.name(s)}: ${totalScores[s]}分',
                            ].join('  |  '),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          for (final item in speciesBreakdown)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Text(
                                '${item['name']}: 计分权 [${((item['rightHolders'] as List?) ?? []).map((s) => g.name((s as num).toInt())).join(",")}] '
                                '-> 得分 ${item['scores']}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  String _winnerBannerText(GameContext g, List<int> scores) {
    if (scores.isEmpty) return '游戏结束';
    final maxSc = scores.reduce(max);
    final winners = [
      for (var s = 0; s < scores.length; s++)
        if (scores[s] == maxSc) g.name(s),
    ];
    return '${winners.join(" & ")} 获胜！（$maxSc 分）';
  }

  Widget _infoPill(ColorScheme cs, String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (highlight ? cs.errorContainer : cs.surface).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: highlight ? cs.onErrorContainer : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildDeckTile({
    required ColorScheme cs,
    required int deckCount,
    required bool canDraw,
    required bool compact,
    required VoidCallback onTap,
  }) {
    final box = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: canDraw ? cs.primary : cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: canDraw ? Colors.amber : cs.outline.withValues(alpha: 0.35),
          width: canDraw ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_motion, size: 16, color: canDraw ? cs.onPrimary : cs.primary),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '中央牌库 ($deckCount)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: canDraw ? cs.onPrimary : cs.onSurface,
                ),
              ),
              Text(
                canDraw ? '点击摸暗牌' : '暗牌堆',
                style: TextStyle(
                  fontSize: 9,
                  color: (canDraw ? cs.onPrimary : cs.onSurface).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!canDraw) return box;
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: box));
  }

  Widget _buildPlayerDiscardCard({
    required ColorScheme cs,
    required GameContext g,
    required int seat,
    required bool isTurn,
    required bool isViewing,
    required int handCount,
    required int treeCount,
    required List<String> discardPile,
    required bool canDrawDiscard,
    required bool compact,
    required VoidCallback onSelectView,
    required VoidCallback onDrawDiscard,
  }) {
    final topDiscard = discardPile.isNotEmpty ? discardPile.last : null;
    final topSp = topDiscard != null ? _spOf(topDiscard) : 0;
    final topRk = topDiscard != null ? _rkOf(topDiscard) : 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: (isViewing ? cs.primaryContainer : cs.surface).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurn ? cs.primary : cs.outline.withValues(alpha: 0.3),
          width: isTurn ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onSelectView,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(g.avatar(seat), size: compact ? 24 : 28, bot: g.bot(seat)),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name(seat),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '手:$handCount 园:$treeCount',
                      style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Discard pile badge / button
          GestureDetector(
            onTap: canDrawDiscard ? onDrawDiscard : onSelectView,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: topDiscard != null
                    ? _spColor(topSp).withValues(alpha: 0.18)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canDrawDiscard ? Colors.amber.shade700 : (topDiscard != null ? _spColor(topSp) : Colors.black26),
                  width: canDrawDiscard ? 2 : 1,
                ),
              ),
              child: Text(
                topDiscard != null
                    ? '弃:${_spName(topSp)}$topRk(${discardPile.length})'
                    : '弃牌:空',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: topDiscard != null ? _spColor(topSp) : cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArboretumGrid({
    required ColorScheme cs,
    required Map<String, String> grid,
    required List<List<int>> validSlots,
    required String? selectedCard,
    required bool compact,
    required void Function(int r, int c) onPlantAt,
  }) {
    final slotSet = {for (final s in validSlots) '${s[0]},${s[1]}'};
    final allCoords = <(int, int)>[];

    for (final k in grid.keys) {
      final parts = k.split(',');
      if (parts.length == 2) {
        allCoords.add((int.parse(parts[0]), int.parse(parts[1])));
      }
    }
    for (final s in validSlots) {
      allCoords.add((s[0], s[1]));
    }
    if (allCoords.isEmpty) {
      allCoords.add((0, 0));
    }

    var minR = allCoords.first.$1, maxR = allCoords.first.$1;
    var minC = allCoords.first.$2, maxC = allCoords.first.$2;
    for (final (r, c) in allCoords) {
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }

    final cellW = compact ? 46.0 : 56.0;
    final cellH = compact ? 58.0 : 70.0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = minR; r <= maxR; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = minC; c <= maxC; c++)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: _buildGridCell(
                      cs: cs,
                      r: r,
                      c: c,
                      plantedCard: grid['$r,$c'],
                      isValidSlot: slotSet.contains('$r,$c'),
                      cellW: cellW,
                      cellH: cellH,
                      onTapSlot: () => onPlantAt(r, c),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGridCell({
    required ColorScheme cs,
    required int r,
    required int c,
    required String? plantedCard,
    required bool isValidSlot,
    required double cellW,
    required double cellH,
    required VoidCallback onTapSlot,
  }) {
    if (plantedCard != null) {
      return _buildTreeCard(card: plantedCard, width: cellW, selected: false, onTap: null);
    }
    if (isValidSlot) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTapSlot,
          child: Container(
            width: cellW,
            height: cellH,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade700, width: 1.8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline, size: 20, color: Colors.green.shade800),
                    Text(
                      '($r,$c)',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(width: cellW, height: cellH);
  }

  Widget _buildTreeCard({
    required String card,
    required double width,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final sp = _spOf(card);
    final rk = _rkOf(card);
    final color = _spColor(sp);
    final h = width * 1.28;

    final widgetCard = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.22 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.amber.shade700 : color,
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1.5))],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$rk',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.0,
                ),
              ),
              Icon(Icons.park, size: 18, color: color),
              Text(
                _spName(sp),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return widgetCard;
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: widgetCard));
  }
}
