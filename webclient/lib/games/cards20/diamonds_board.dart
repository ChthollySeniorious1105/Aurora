import 'package:aurora_shared/games/cards20/diamonds.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class DiamondsBoard extends StatelessWidget {
  final GameContext g;
  const DiamondsBoard(this.g, {super.key});

  static Color _suitColor(String suit) {
    return switch (suit) {
      'D' => const Color(0xFFD32F2F),
      'H' => const Color(0xFFC2185B),
      'S' => const Color(0xFF263238),
      'C' => const Color(0xFF2E7D32),
      _ => const Color(0xFF455A64),
    };
  }

  static String _suitSymbol(String suit) {
    return switch (suit) {
      'D' => '♦',
      'H' => '♥',
      'S' => '♠',
      'C' => '♣',
      _ => suit,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final totalTricks = (v['totalTricksInRound'] as num?)?.toInt() ?? 10;

    final showroom =
        (v['showroom'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 3);
    final vault =
        (v['vault'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 1);
    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 5);
    final tricksWon =
        (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);

    final hand =
        (v['hand'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final legalCards =
        ((v['legalCards'] as List?)?.map((e) => '$e').toList() ?? const <String>[])
            .toSet();
    final currentTrick =
        (v['currentTrick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = (v['lastTrick'] as List?)?.cast<Map>() ?? const <Map>[];
    final actionLog =
        (v['actionLog'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (isMyTurn) {
      statusText = '轮到你出牌：有花必跟；缺门垫牌或赢墩均可立即触发对应花色的钻石行动！';
    } else {
      statusText = '等待 ${g.name(turn)} 出牌…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 40.0 : 50.0;

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
                    _chip(
                      cs,
                      '第 $round/$totalRounds 局 · 第 $trickNumber/$totalTricks 墩',
                    ),
                    _chip(
                      cs,
                      '♦直接入库2分 · ♥拿1钻入展示室 · ♠转存1钻入库 · ♣偷对手展示室1钻',
                      highlight: true,
                    ),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Players row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      g.tag(
                        s,
                        active: !g.over && s == turn,
                        size: compact ? 28 : 34,
                        sub: '🔒保险箱${vault[s]}×2 + 💎展示室${showroom[s]} = ${scores[s]}分 · ${tricksWon[s]}墩',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center trick & showroom table
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTrickArea(
                            cs,
                            trickNumber,
                            totalTricks,
                            currentTrick,
                            lastTrick,
                            actionLog,
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
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '我的手牌（${hand.length}张 · 点数 1~15 无主花色）：',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        OverlapRow(
                          itemWidth: cardW,
                          maxSpacing: 1.05,
                          children: [
                            for (final c in hand)
                              _buildDiamondCard(
                                c,
                                width: cardW,
                                dim: isMyTurn && !legalCards.contains(c),
                                onTap: (isMyTurn && legalCards.contains(c))
                                    ? () => g.act({'type': 'play', 'card': c})
                                    : null,
                              ),
                          ],
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
                child: ResultBanner(_buildResultText(scores)),
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

  Widget _buildDiamondCard(
    String code, {
    required double width,
    bool dim = false,
    VoidCallback? onTap,
  }) {
    final suit = diamondsCardSuit(code);
    final rank = diamondsCardRank(code);
    final col = _suitColor(suit);
    final sym = _suitSymbol(suit);
    final h = width * 1.4;

    final card = Opacity(
      opacity: dim ? 0.45 : 1.0,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF9),
          borderRadius: BorderRadius.circular(width * 0.14),
          border: Border.all(color: col, width: 1.8),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: width * 0.44,
                    fontWeight: FontWeight.w900,
                    color: col,
                    height: 1.0,
                  ),
                ),
                Text(
                  sym,
                  style: TextStyle(
                    fontSize: width * 0.38,
                    fontWeight: FontWeight.bold,
                    color: col,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }

  Widget _buildTrickArea(
    ColorScheme cs,
    int trickNumber,
    int totalTricks,
    List<Map> currentTrick,
    List<Map> lastTrick,
    List<String> actionLog,
    bool compact,
  ) {
    final displayTrick = currentTrick.isNotEmpty ? currentTrick : lastTrick;

    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentTrick.isNotEmpty
                ? '第 $trickNumber/$totalTricks 墩桌面出牌：'
                : '上一墩回顾（第 $trickNumber/$totalTricks 墩准备领出）：',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (displayTrick.isEmpty)
            const Text(
              '等待领出本局第一张牌…',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final e in displayTrick)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDiamondCard(
                        '${e['card']}',
                        width: compact ? 38 : 46,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        g.name((e['seat'] as num).toInt()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          if (actionLog.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              actionLog.first,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _buildResultText(List<int> scores) {
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++) '${g.name(s)}: ${scores[s]}分'
    ].join(' · ')}';
  }
}
