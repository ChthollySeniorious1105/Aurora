import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class BriscolaBoard extends StatelessWidget {
  final GameContext g;
  const BriscolaBoard(this.g, {super.key});

  static const _suitName = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方块', 'C': '♣梅花'};

  int _cardPts(String c) {
    if (c.isEmpty) return 0;
    switch (c.substring(0, c.length - 1)) {
      case 'A':
        return 11;
      case '3':
        return 10;
      case 'K':
        return 4;
      case 'Q':
        return 3;
      case 'J':
        return 2;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final handNumber = (v['handNumber'] as num?)?.toInt() ?? 1;
    final maxHands = (v['maxHands'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final trumpCard = (v['trumpCard'] as String?) ?? '2S';
    final trumpSuit = (v['trumpSuit'] as String?) ?? 'S';
    final trumpInStock = v['trumpInStock'] == true;
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;
    final trickNum = (v['trickNum'] as num?)?.toInt() ?? 1;
    final totalTricks = (v['totalTricksInHand'] as num?)?.toInt() ?? 10;
    final isPartnership = v['isPartnership'] == true;
    final over = v['over'] == true || g.over;

    final handPoints = (v['handPoints'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final teamPoints = (v['teamPoints'] as List?)?.map((e) => (e as num).toInt()).toList();
    final tricksWon = (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final handWins = (v['handWins'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final myHand = (v['hand'] as List?)?.cast<String>() ?? const <String>[];
    final currentTrick = (v['currentTrick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final seats = g.seatsFromMe();
    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;

    final statusText = over
        ? '全场比赛结束！'
        : (isMyTurn
            ? '轮到你出牌（第 $trickNum/$totalTricks 墩 · 可自由出任意牌）'
            : '等待 ${g.name(turn)} 出牌（第 $trickNum/$totalTricks 墩）');

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
      final cardW = compact ? 42.0 : 54.0;

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 4 : 8),
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _chip(cs, '局 $handNumber/$maxHands · 墩 $trickNum/$totalTricks'),
                      const SizedBox(width: 6),
                      _chip(cs, '王牌花色: ${_suitName[trumpSuit] ?? trumpSuit} (底牌 $trumpCard)', highlight: true),
                      const SizedBox(width: 6),
                      _chip(cs, '剩余牌堆: $stockCount 张'),
                      if (isPartnership && teamPoints != null) ...[
                        const SizedBox(width: 6),
                        _chip(cs, '蓝队(0&2) ${teamPoints[0]}分 : ${teamPoints[1]}分 红队(1&3)', highlight: true),
                      ],
                      const SizedBox(width: 6),
                      _chip(cs, '分值: A=11 3=10 K=4 Q=3 J=2'),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StatusBar(statusText, highlight: isMyTurn),
                ),
                SizedBox(height: compact ? 2 : 6),

                // Opponents row
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in seats.skip(1))
                        _seatTag(g, s, turn, handPoints, tricksWon, handWins, handCounts, maxHands, isPartnership, compact),
                    ],
                  ),
                ),

                // Center Table: Stock + Briscola + Current/Last Trick
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.center,
                          children: [
                            // Briscola & Stock widget
                            Container(
                              padding: EdgeInsets.all(compact ? 6 : 10),
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        trumpInStock ? '底牌王牌' : '王牌(已摸)',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      PlayingCard(
                                        trumpCard,
                                        width: compact ? 36 : 44,
                                        dim: !trumpInStock,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '牌堆 ($stockCount)',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      PlayingCard(
                                        'XX',
                                        faceDown: true,
                                        width: compact ? 36 : 44,
                                        dim: stockCount == 0,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Trick Area
                            _buildTrickPanel(
                              cs: cs,
                              g: g,
                              currentTrick: currentTrick,
                              lastTrick: lastTrick,
                              trumpSuit: trumpSuit,
                              cardW: compact ? 38.0 : 48.0,
                              compact: compact,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom My Seat + My Hand
                _seatTag(g, seats.first, turn, handPoints, tricksWon, handWins, handCounts, maxHands, isPartnership, compact),
                if (myHand.isNotEmpty) ...[
                  SizedBox(height: compact ? 2 : 6),
                  SizedBox(
                    height: cardW * 1.48,
                    child: Center(
                      child: OverlapRow(
                        itemWidth: cardW + 10,
                        children: [
                          for (final c in myHand)
                            _buildHandCard(
                              card: c,
                              cardW: cardW,
                              trumpSuit: trumpSuit,
                              canTap: isMyTurn,
                              onTap: () => g.act({'type': 'play', 'card': c}),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (over)
              Center(
                child: ResultBanner(
                  _winnerTitle(handWins, handPoints, teamPoints, isPartnership),
                  child: Text(
                    isPartnership && teamPoints != null
                        ? '本局得分：蓝队 ${teamPoints[0]} 分 : ${teamPoints[1]} 分 红队'
                        : '各座得分：${[for (var s = 0; s < g.players; s++) "${g.name(s)}: ${handPoints[s]}分"].join(" · ")}',
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  String _winnerTitle(List<int> handWins, List<int> handPoints, List<int>? teamPoints, bool isPartnership) {
    if (isPartnership) {
      final w0 = handWins[0];
      final w1 = handWins[1];
      return w0 >= w1 ? '蓝队 (座位 0 & 2) 获胜！' : '红队 (座位 1 & 3) 获胜！';
    }
    var bestSeat = 0;
    for (var s = 1; s < handWins.length; s++) {
      if (handWins[s] > handWins[bestSeat] ||
          (handWins[s] == handWins[bestSeat] && handPoints[s] > handPoints[bestSeat])) {
        bestSeat = s;
      }
    }
    return '${g.name(bestSeat)} 获胜！';
  }

  Widget _chip(ColorScheme cs, String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (highlight ? cs.primaryContainer : cs.surface).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: highlight ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
  }

  Widget _seatTag(
    GameContext g,
    int s,
    int turn,
    List<int> handPoints,
    List<int> tricksWon,
    List<int> handWins,
    List<int> handCounts,
    int maxHands,
    bool isPartnership,
    bool compact,
  ) {
    final teamPrefix = isPartnership ? '${s % 2 == 0 ? "蓝队" : "红队"}·' : '';
    final winsPart = maxHands > 1 ? ' 胜局:${handWins[s]}' : '';
    final sub = '$teamPrefix${handPoints[s]}分 | ${tricksWon[s]}墩$winsPart | 手牌:${handCounts[s]}';
    return g.tag(s, active: turn == s, sub: sub, size: compact ? 28 : 34);
  }

  Widget _buildTrickPanel({
    required ColorScheme cs,
    required GameContext g,
    required List<Map> currentTrick,
    required Map? lastTrick,
    required String trumpSuit,
    required double cardW,
    required bool compact,
  }) {
    final showCurrent = currentTrick.isNotEmpty;
    final cardsList = showCurrent
        ? currentTrick
        : ((lastTrick?['cards'] as List?)?.cast<Map>() ?? const <Map>[]);

    return Container(
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            showCurrent
                ? '当前墩出牌'
                : (lastTrick != null
                    ? '上一墩 (${g.name((lastTrick['winner'] as num).toInt())} 收 +${lastTrick['points']}分)'
                    : '等待首引出牌'),
            style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (cardsList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('桌面暂无出牌', style: TextStyle(fontSize: 12)),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final item in cardsList)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHandCard(
                        card: item['card'] as String,
                        cardW: cardW,
                        trumpSuit: trumpSuit,
                        canTap: false,
                        onTap: () {},
                      ),
                      const SizedBox(height: 2),
                      Text(
                        g.name((item['seat'] as num).toInt()),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHandCard({
    required String card,
    required double cardW,
    required String trumpSuit,
    required bool canTap,
    required VoidCallback onTap,
  }) {
    final pts = _cardPts(card);
    final isTrump = card.endsWith(trumpSuit);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: PlayingCard(
            card,
            width: cardW,
            onTap: canTap ? onTap : null,
          ),
        ),
        if (pts > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+$pts',
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (isTrump)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.amber.shade800,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '王',
                style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
