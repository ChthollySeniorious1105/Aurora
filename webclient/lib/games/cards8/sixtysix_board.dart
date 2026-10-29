import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class SixtySixBoard extends StatelessWidget {
  final GameContext g;
  const SixtySixBoard(this.g, {super.key});

  static const _suitNames = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方片', 'C': '♣梅花'};
  static const _suitSym = {'S': '♠', 'H': '♥', 'D': '♦', 'C': '♣'};

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final seats = g.seatsFromMe();
    final me = seats.first;
    final opp = seats.length > 1 ? seats[1] : 1 - me;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final targetPoints = (v['targetPoints'] as num?)?.toInt() ?? 7;
    final gameScores = (v['gameScores'] as List?)?.cast<num>() ?? const [0, 0];
    final effectivePoints =
        (v['effectivePoints'] as List?)?.cast<num>() ?? const [0, 0];
    final tricksWon = (v['tricksWon'] as List?)?.cast<num>() ?? const [0, 0];
    final handCounts = (v['handCounts'] as List?)?.cast<num>() ?? const [0, 0];
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;
    final trumpCard = v['trumpCard'] as String?;
    final trumpSuit = (v['trumpSuit'] as String?) ?? 'S';
    final closed = v['closed'] == true;
    final strict = v['strict'] == true;
    final leadCard = v['leadCard'] as String?;
    final hand = (v['hand'] as List?)?.cast<String>() ?? const <String>[];
    final legalPlays =
        ((v['legalPlays'] as List?)?.cast<String>() ?? const <String>[])
            .toSet();
    final marriageCards =
        ((v['marriageCards'] as List?)?.cast<String>() ?? const <String>[])
            .toSet();
    final canSwapTrump = v['canSwapTrump'] == true;
    final canClose = v['canClose'] == true;
    final lastTrick = v['lastTrick'] as Map?;
    final lastHandResult = v['lastHandResult'] as Map?;
    final myTurn = !g.over && g.seat == turn;

    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (myTurn) {
      statusText = leadCard == null
          ? '轮到你领出牌（可换底牌或关闭牌库）'
          : (strict ? '轮到你跟牌（严格跟花色/上吃阶段）' : '轮到你跟牌（自由跟牌阶段）');
    } else {
      statusText = '等待 ${g.name(turn)} 出牌…';
    }

    String subFor(int s) {
      final gs = s < gameScores.length ? gameScores[s] : 0;
      final ep = s < effectivePoints.length ? effectivePoints[s] : 0;
      final tw = s < tricksWon.length ? tricksWon[s] : 0;
      return '局分 $gs/$targetPoints · 本局 $ep/66分 · $tw墩';
    }

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxHeight < 460 || c.maxWidth < 460;
      final cardW = compact ? 42.0 : 54.0;

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 12),
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar: opponent info + status
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    g.tag(
                      opp,
                      active: !g.over && turn == opp,
                      sub: subFor(opp),
                      size: compact ? 28 : 34,
                      trailing: Text(
                        '手牌 ${opp < handCounts.length ? handCounts[opp] : 0}',
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    StatusBar(statusText, highlight: myTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),

                // Center table area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: compact ? 12 : 24,
                        runSpacing: compact ? 8 : 12,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Stock & Trump panel
                          Container(
                            padding: EdgeInsets.all(compact ? 8 : 12),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (trumpCard != null && !closed) ...[
                                  PlayingCard(trumpCard, width: cardW * 0.9),
                                  const SizedBox(width: 8),
                                ],
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '王牌花色: ${_suitNames[trumpSuit] ?? trumpSuit}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: compact ? 12 : 14,
                                        color: (trumpSuit == 'H' ||
                                                trumpSuit == 'D')
                                            ? Colors.redAccent
                                            : cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      closed
                                          ? '牌库状态: 已关闭 ($stockCount张)'
                                          : '牌库剩余: $stockCount 张',
                                      style: TextStyle(
                                        fontSize: compact ? 11 : 12,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                    Text(
                                      strict ? '规则: 严格跟花色/上吃' : '规则: 自由跟牌',
                                      style: TextStyle(
                                        fontSize: compact ? 11 : 12,
                                        color: strict
                                            ? cs.error
                                            : cs.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Current trick / Last trick panel
                          Container(
                            padding: EdgeInsets.all(compact ? 8 : 12),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: leadCard != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '领出 (${g.name((v['leader'] as num?)?.toInt() ?? 0)})',
                                            style: TextStyle(
                                              fontSize: compact ? 11 : 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          PlayingCard(leadCard, width: cardW),
                                        ],
                                      ),
                                      if (v['lastMarriageBonus'] != null) ...[
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(
                                            '婚姻 +${v['lastMarriageBonus']}',
                                            style: TextStyle(
                                              fontSize: compact ? 11 : 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : lastTrick != null
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PlayingCard(
                                            '${lastTrick['leadCard'] ?? ''}',
                                            width: cardW * 0.85,
                                          ),
                                          const SizedBox(width: 6),
                                          PlayingCard(
                                            '${lastTrick['followCard'] ?? ''}',
                                            width: cardW * 0.85,
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '上墩赢家: ${g.name((lastTrick['winner'] as num?)?.toInt() ?? 0)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: compact ? 11 : 12,
                                                ),
                                              ),
                                              Text(
                                                '+${lastTrick['points'] ?? 0} 分',
                                                style: TextStyle(
                                                  fontSize: compact ? 11 : 12,
                                                  color: cs.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          '新的一局开始，请领出第一张牌',
                                          style: TextStyle(
                                            fontSize: compact ? 12 : 13,
                                          ),
                                        ),
                                      ),
                          ),

                          if (lastHandResult != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '上局: ${g.name((lastHandResult['winner'] as num?)?.toInt() ?? 0)} +${lastHandResult['gamePoints']}局分 (${lastHandResult['reason']})',
                                style: TextStyle(
                                  fontSize: compact ? 11 : 12,
                                  color: cs.onSecondaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom area: my tag, action buttons, and my hand
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    g.tag(
                      me,
                      active: !g.over && turn == me,
                      sub: subFor(me),
                      size: compact ? 28 : 34,
                    ),
                    if (myTurn && canSwapTrump)
                      FilledButton.tonalIcon(
                        onPressed: () => g.act({'type': 'swap_trump'}),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: Text(
                          '用 J${_suitSym[trumpSuit] ?? ''} 换底牌',
                          style: TextStyle(fontSize: compact ? 11 : 13),
                        ),
                      ),
                    if (myTurn && canClose)
                      OutlinedButton.icon(
                        onPressed: () => g.act({'type': 'close'}),
                        icon: const Icon(Icons.lock_outline, size: 16),
                        label: Text(
                          '关闭牌库',
                          style: TextStyle(fontSize: compact ? 11 : 13),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),
                if (hand.isNotEmpty)
                  SizedBox(
                    height: cardW * 1.45,
                    child: Center(
                      child: OverlapRow(
                        itemWidth: cardW,
                        children: [
                          for (final c in hand)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                PlayingCard(
                                  c,
                                  width: cardW,
                                  dim: myTurn && !legalPlays.contains(c),
                                  onTap: myTurn && legalPlays.contains(c)
                                      ? () => g.act({'type': 'play', 'card': c})
                                      : null,
                                ),
                                if (marriageCards.contains(c))
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade700,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '婚',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  _resultTitle(v),
                  child: Text(
                    '最终局分：${g.name(0)} ${gameScores[0]} : ${gameScores.length > 1 ? gameScores[1] : 0} ${g.name(1)}',
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  String _resultTitle(Map<String, dynamic> v) {
    final res = v['result'] as Map?;
    final w = (res?['winner'] as num?)?.toInt();
    if (w != null) return '${g.name(w)} 赢得比赛！';
    return '比赛结束';
  }
}
