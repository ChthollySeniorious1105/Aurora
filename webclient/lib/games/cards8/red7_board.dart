import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class Red7Board extends StatefulWidget {
  final GameContext g;
  const Red7Board(this.g, {super.key});

  @override
  State<Red7Board> createState() => _Red7BoardState();
}

class _Red7BoardState extends State<Red7Board> {
  String? _selPalette;
  String? _selCanvas;

  static const _colorPalette = <int, Color>{
    6: Color(0xFFD32F2F), // Red
    5: Color(0xFFF57C00), // Orange
    4: Color(0xFFFBC02D), // Yellow
    3: Color(0xFF388E3C), // Green
    2: Color(0xFF1976D2), // Blue
    1: Color(0xFF303F9F), // Indigo
    0: Color(0xFF7B1FA2), // Violet
  };

  static const _colorShort = <int, String>{
    6: '红·最高单牌',
    5: '橙·同数字最多',
    4: '黄·同颜色最多',
    3: '绿·偶数最多',
    2: '蓝·异色最多',
    1: '靛·最长顺子',
    0: '紫·<4最多',
  };

  static int _cardColorIdx(String code) {
    if (code.isEmpty) return 6;
    const codes = ['V', 'I', 'B', 'G', 'Y', 'O', 'R'];
    final i = codes.indexOf(code[0]);
    return i >= 0 ? i : 6;
  }

  static int _cardNum(String code) =>
      code.length >= 2 ? (int.tryParse(code[1]) ?? 1) : 1;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final seats = g.seatsFromMe();

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 3;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final leader = (v['leader'] as num?)?.toInt() ?? 0;
    final canvasColor = (v['canvasColor'] as num?)?.toInt() ?? 6;
    final ruleName = (v['ruleName'] as String?) ?? '红 (Red)';
    final ruleDesc = (v['ruleDesc'] as String?) ?? '最高单牌';
    final scores = (v['scores'] as List?)?.cast<num>() ?? const [];
    final hand = (v['hand'] as List?)?.cast<String>() ?? const <String>[];
    final handCounts = (v['handCounts'] as List?)?.cast<num>() ?? const [];
    final rawPalettes = (v['palettes'] as List?) ?? const [];
    final rawBest = (v['bestSubsets'] as List?) ?? const [];
    final folded = (v['folded'] as List?)?.cast<bool>() ?? const [];
    final legalMoves = (v['legalMoves'] as List?) ?? const [];
    final myTurn = !g.over && g.seat == turn;

    if (_selPalette != null && !hand.contains(_selPalette)) {
      _selPalette = null;
    }
    if (_selCanvas != null && !hand.contains(_selCanvas)) {
      _selCanvas = null;
    }

    bool isLegalSelection(String? p, String? c) {
      if (p == null && c == null) return false;
      for (final m in legalMoves) {
        if (m is Map) {
          final mp = m['palette'] as String?;
          final mc = m['canvas'] as String?;
          if (mp == p && mc == c) return true;
        }
      }
      return false;
    }

    final selectionLegal = isLegalSelection(_selPalette, _selCanvas);

    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (myTurn) {
      if (legalMoves.isEmpty) {
        statusText = '轮到你：当前无任何可领先出牌，请点击“弃牌”';
      } else {
        statusText = '轮到你：打入调色盘和/或画布并取得领先，否则弃牌';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxHeight < 460 || c.maxWidth < 460;
      final cardW = compact ? 36.0 : 46.0;

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(
          children: [
            Column(
              children: [
                // Top info bar: Round + Canvas Rule Banner + Status
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _colorPalette[canvasColor] ?? Colors.red,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 3),
                        ],
                      ),
                      child: Text(
                        '第$round/$maxRounds局 · 画布 [$ruleName: $ruleDesc]',
                        style: TextStyle(
                          color: canvasColor == 4
                              ? Colors.black87
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 11 : 13,
                        ),
                      ),
                    ),
                    StatusBar(statusText, highlight: myTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // 7-Color rule reference chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var col = 6; col >= 0; col--)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (_colorPalette[col] ?? Colors.grey)
                                .withValues(
                                  alpha: col == canvasColor ? 1.0 : 0.65,
                                ),
                            borderRadius: BorderRadius.circular(8),
                            border: col == canvasColor
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Text(
                            _colorShort[col] ?? '',
                            style: TextStyle(
                              fontSize: compact ? 9.5 : 11,
                              fontWeight: col == canvasColor
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: col == 4 ? Colors.black87 : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 4 : 8),

                // Players' Palettes Area
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: compact ? 6 : 10,
                      runSpacing: compact ? 6 : 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in seats)
                          _buildPlayerPaletteCard(
                            context,
                            cs: cs,
                            seat: s,
                            turn: turn,
                            leader: leader,
                            score: s < scores.length ? scores[s].toInt() : 0,
                            handCount: s < handCounts.length
                                ? handCounts[s].toInt()
                                : 0,
                            isFolded: s < folded.length && folded[s],
                            palette: s < rawPalettes.length &&
                                    rawPalettes[s] is List
                                ? [for (final x in rawPalettes[s] as List) '$x']
                                : const <String>[],
                            bestSubset:
                                s < rawBest.length && rawBest[s] is List
                                    ? {
                                        for (final x in rawBest[s] as List)
                                          '$x',
                                      }
                                    : const <String>{},
                            compact: compact,
                            cardW: cardW * 0.9,
                          ),
                      ],
                    ),
                  ),
                ),

                // Action controls for my turn
                if (myTurn) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_selPalette != null || _selCanvas != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '已选: 调色盘[${_selPalette ?? "无"}] · 画布[${_selCanvas ?? "无"}]',
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (selectionLegal)
                        FilledButton.icon(
                          onPressed: () {
                            final p = _selPalette;
                            final cCard = _selCanvas;
                            setState(() {
                              _selPalette = null;
                              _selCanvas = null;
                            });
                            g.act({
                              'type': 'play',
                              'palette': ?p,
                              'canvas': ?cCard,
                            });
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: Text(
                            '确认出牌（可领先）',
                            style: TextStyle(fontSize: compact ? 11 : 12),
                          ),
                        ),
                      if (_selPalette != null || _selCanvas != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _selPalette = null;
                            _selCanvas = null;
                          }),
                          child: Text(
                            '重选',
                            style: TextStyle(fontSize: compact ? 11 : 12),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _selPalette = null;
                            _selCanvas = null;
                          });
                          g.act({'type': 'fold'});
                        },
                        icon: const Icon(Icons.flag_outlined, size: 15),
                        label: Text(
                          '弃牌 (Fold)',
                          style: TextStyle(fontSize: compact ? 11 : 12),
                        ),
                      ),
                    ],
                  ),
                ],

                // My Hand
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 6),
                  SizedBox(
                    height: cardW * 1.48,
                    child: Center(
                      child: OverlapRow(
                        itemWidth: cardW,
                        children: [
                          for (final c in hand)
                            _Red7Card(
                              code: c,
                              width: cardW,
                              badge: _selPalette == c
                                  ? '盘'
                                  : (_selCanvas == c ? '画' : null),
                              selected: _selPalette == c || _selCanvas == c,
                              onTap: myTurn
                                  ? () {
                                      setState(() {
                                        // Cycle card assignment:
                                        // None -> Palette -> Canvas -> None
                                        if (_selPalette == c) {
                                          _selPalette = null;
                                          _selCanvas = c;
                                        } else if (_selCanvas == c) {
                                          _selCanvas = null;
                                        } else if (_selPalette == null) {
                                          _selPalette = c;
                                        } else {
                                          _selCanvas = c;
                                        }
                                      });
                                    }
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  _resultTitle(g, v),
                  child: Text(
                    '总分：${[
                      for (var s = 0; s < g.players; s++)
                        '${g.name(s)} ${s < scores.length ? scores[s] : 0}分',
                    ].join(' · ')}',
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildPlayerPaletteCard(
    BuildContext context, {
    required ColorScheme cs,
    required int seat,
    required int turn,
    required int leader,
    required int score,
    required int handCount,
    required bool isFolded,
    required List<String> palette,
    required Set<String> bestSubset,
    required bool compact,
    required double cardW,
  }) {
    final g = widget.g;
    final isLeader = !isFolded && seat == leader;
    return Container(
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isFolded ? 0.45 : 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLeader
              ? Colors.amber
              : (seat == turn && !g.over
                    ? cs.primary
                    : cs.outline.withValues(alpha: 0.3)),
          width: isLeader || (seat == turn && !g.over) ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            seat,
            active: !g.over && seat == turn,
            sub:
                '$score分 · 手牌$handCount${isFolded ? " · 已弃牌" : (isLeader ? " · ★领先" : "")}',
            size: compact ? 24 : 30,
          ),
          SizedBox(height: compact ? 4 : 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final c in palette)
                _Red7Card(
                  code: c,
                  width: cardW,
                  highlight: bestSubset.contains(c),
                  dim: isFolded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _resultTitle(GameContext g, Map<String, dynamic> v) {
    final res = v['result'] as Map?;
    final winners = (res?['winners'] as List?)?.cast<num>() ?? const [];
    if (winners.isNotEmpty) {
      return '${winners.map((w) => g.name(w.toInt())).join('、')} 赢得比赛！';
    }
    return '比赛结束';
  }
}

class _Red7Card extends StatelessWidget {
  final String code;
  final double width;
  final bool selected;
  final bool highlight;
  final bool dim;
  final String? badge;
  final VoidCallback? onTap;

  const _Red7Card({
    required this.code,
    this.width = 44,
    this.selected = false,
    this.highlight = false,
    this.dim = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colIdx = _Red7BoardState._cardColorIdx(code);
    final numVal = _Red7BoardState._cardNum(code);
    final bg = _Red7BoardState._colorPalette[colIdx] ?? Colors.red;
    final fg = colIdx == 4 ? Colors.black87 : Colors.white;
    final h = width * 1.38;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.25 : 0, 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(
          color: selected
              ? Colors.amberAccent
              : (highlight ? Colors.white : Colors.white54),
          width: selected || highlight ? 2.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$numVal',
                      style: TextStyle(
                        fontSize: width * 0.56,
                        fontWeight: FontWeight.w900,
                        color: fg,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: width * 0.22,
                        fontWeight: FontWeight.bold,
                        color: fg.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (dim) card = Opacity(opacity: 0.45, child: card);
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
