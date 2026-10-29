import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class SchottenTottenBoard extends StatefulWidget {
  final GameContext g;
  const SchottenTottenBoard(this.g, {super.key});

  @override
  State<SchottenTottenBoard> createState() => _SchottenTottenBoardState();
}

class _SchottenTottenBoardState extends State<SchottenTottenBoard> {
  String? _selectedCard;

  static const List<(String, String, String, Color)> _clans = [
    ('R', '🟥', '红氏族', Color(0xFFC62828)),
    ('B', '🟦', '蓝氏族', Color(0xFF1565C0)),
    ('G', '🟩', '绿氏族', Color(0xFF2E7D32)),
    ('Y', '🟨', '黄氏族', Color(0xFFF9A825)),
    ('P', '🟪', '紫氏族', Color(0xFF6A1B9A)),
    ('O', '🟧', '橙氏族', Color(0xFFEF6C00)),
  ];

  static (String, String, Color) _clanInfo(String code) {
    if (code.isEmpty) return ('🟥', '红', const Color(0xFFC62828));
    final c = code[0].toUpperCase();
    for (final (k, emoji, name, col) in _clans) {
      if (k == c) return (emoji, name, col);
    }
    return ('🟥', '红', const Color(0xFFC62828));
  }

  static String _rankStr(String code) =>
      code.length >= 2 ? code.substring(1) : code;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [0, 0];
    final stoneOwner =
        (v['stoneOwner'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(9, -1);
    final firstToThree =
        (v['firstToThree'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(9, -1);
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final claimable = ((v['claimableStones'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const <int>[])
        .toSet();
    final playable = ((v['playableStones'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const <int>[])
        .toSet();

    final rawStones = v['stones'] as List?;
    final stones = <List<List<String>>>[
      for (var st = 0; st < 9; st++)
        [
          for (var p = 0; p < 2; p++)
            (rawStones != null &&
                    st < rawStones.length &&
                    rawStones[st] is List &&
                    p < (rawStones[st] as List).length &&
                    (rawStones[st] as List)[p] is List)
                ? ((rawStones[st] as List)[p] as List)
                    .map((e) => '$e')
                    .toList()
                : <String>[],
        ],
    ];

    if (_selectedCard == null || !hand.contains(_selectedCard)) {
      _selectedCard = hand.isNotEmpty ? hand.first : null;
    }

    final mySeat = g.seat >= 0 && g.seat < 2 ? g.seat : 0;
    final oppSeat = 1 - mySeat;
    final isMyTurn = !g.over && g.seat == turn;

    final stones0 = stoneOwner.where((o) => o == 0).length;
    final stones1 = stoneOwner.where((o) => o == 1).length;

    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (isMyTurn) {
      statusText = '轮到你：先选下方手牌，再点击未满 3 张的界石放置（连夺3石或累计5石获胜）';
    } else {
      statusText = '等待 ${g.name(turn)} 部署氏族牌…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 42.0 : 54.0;

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(
          children: [
            Column(
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(cs, '第 $round/$totalRounds 局 · 氏族牌库剩余 $deckCount 张'),
                    _chip(
                      cs,
                      '阵型：同花顺(5) > 三条(4) > 同花(3) > 顺子(2) > 散牌总和(1)',
                      highlight: true,
                    ),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Players row
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      g.tag(
                        s,
                        active: !g.over && s == turn,
                        size: compact ? 28 : 34,
                        sub: '已夺界石: ${s == 0 ? stones0 : stones1}/5 · 胜局: ${scores[s]}',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // 9 Boundary Stones battle line
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: compact ? 4 : 6,
                        runSpacing: compact ? 4 : 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var st = 0; st < 9; st++)
                            _buildStoneColumn(
                              g,
                              cs,
                              st,
                              mySeat,
                              oppSeat,
                              stones[st],
                              stoneOwner[st],
                              firstToThree[st],
                              isMyTurn && playable.contains(st) && _selectedCard != null,
                              claimable.contains(st),
                              compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom hand
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.76),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          _ClanCardWidget(
                            c,
                            width: cardW,
                            selected: c == _selectedCard,
                            onTap: () => setState(() => _selectedCard = c),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  '比赛结束！${g.name(0)}: $stones0石 (${scores[0]}胜) vs ${g.name(1)}: $stones1石 (${scores[1]}胜)',
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _chip(ColorScheme cs, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? cs.primaryContainer.withValues(alpha: 0.92)
            : cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? cs.primary : cs.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: highlight ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildStoneColumn(
    GameContext g,
    ColorScheme cs,
    int st,
    int mySeat,
    int oppSeat,
    List<List<String>> stoneSides,
    int owner,
    int first3,
    bool canPlayHere,
    bool canClaimHere,
    bool compact,
  ) {
    final oppCards = stoneSides[oppSeat];
    final myCards = stoneSides[mySeat];
    final colW = compact ? 64.0 : 76.0;

    Color borderCol = Colors.white24;
    Color bgCol = Colors.black.withValues(alpha: 0.24);
    if (owner == mySeat) {
      borderCol = Colors.greenAccent;
      bgCol = Colors.green.shade900.withValues(alpha: 0.42);
    } else if (owner == oppSeat) {
      borderCol = Colors.redAccent;
      bgCol = Colors.red.shade900.withValues(alpha: 0.42);
    } else if (canPlayHere) {
      borderCol = Colors.amber;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: canPlayHere && _selectedCard != null
          ? () => g.act({'type': 'play', 'stone': st, 'card': _selectedCard})
          : null,
      child: Container(
        width: colW,
        padding: EdgeInsets.all(compact ? 4 : 6),
        decoration: BoxDecoration(
          color: bgCol,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol, width: canPlayHere || owner >= 0 ? 1.8 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opponent's 3 slots
            _buildMiniSlots(oppCards, compact),
            const SizedBox(height: 4),

            // Stone badge in the middle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              decoration: BoxDecoration(
                color: owner == mySeat
                    ? Colors.green.shade700
                    : (owner == oppSeat
                        ? Colors.red.shade700
                        : cs.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      owner == mySeat
                          ? '🏆 #${st + 1} 我方'
                          : (owner == oppSeat ? '🏴 #${st + 1} 对方' : '🪨 界石#${st + 1}'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: owner >= 0 ? Colors.white : cs.onSurface,
                      ),
                    ),
                  ),
                  if (first3 >= 0 && owner == -1)
                    Text(
                      first3 == mySeat ? '我方先满3' : '对方先满3',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),

            if (canClaimHere) ...[
              const SizedBox(height: 3),
              InkWell(
                onTap: () => g.act({'type': 'claim', 'stone': st}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '夺石!',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 4),
            // My 3 slots
            _buildMiniSlots(myCards, compact),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSlots(List<String> cards, bool compact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            height: compact ? 18 : 21,
            width: double.infinity,
            decoration: BoxDecoration(
              color: i < cards.length
                  ? _clanInfo(cards[i]).$3
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: i < cards.length ? Colors.white54 : Colors.white24,
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: i < cards.length
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_clanInfo(cards[i]).$1} ${_rankStr(cards[i])}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : const Text(
                    '·',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
          ),
      ],
    );
  }
}

class _ClanCardWidget extends StatelessWidget {
  final String code;
  final double width;
  final bool selected;
  final VoidCallback? onTap;

  const _ClanCardWidget(
    this.code, {
    required this.width,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (emoji, name, color) = _SchottenTottenBoardState._clanInfo(code);
    final rank = _SchottenTottenBoardState._rankStr(code);
    final h = width * 1.4;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.28 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: selected ? Colors.amber : color,
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(width * 0.09),
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  rank,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.28,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(emoji, style: TextStyle(fontSize: width * 0.34)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 2, right: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                style: TextStyle(
                  color: color,
                  fontSize: width * 0.19,
                  fontWeight: FontWeight.bold,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
