import 'package:aurora_shared/games/cards11/yaniv.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class YanivBoard extends StatefulWidget {
  final GameContext g;
  const YanivBoard(this.g, {super.key});

  @override
  State<YanivBoard> createState() => _YanivBoardState();
}

class _YanivBoardState extends State<YanivBoard> {
  final Set<String> _selected = {};

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  List<int> _intList(Object? raw) =>
      raw is List ? [for (final x in raw) (x as num).toInt()] : const [];

  List<String> _strList(Object? raw) =>
      raw is List ? [for (final x in raw) '$x'] : const [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final targetLimit = (v['targetLimit'] as num?)?.toInt() ?? 100;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final scores = _intList(v['scores']);
    final handCounts = _intList(v['handCounts']);
    final myHand = _strList(v['myHand']);
    final mySum = (v['mySum'] as num?)?.toInt() ?? 0;
    final canYaniv = v['canYaniv'] == true;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final lastDiscard = _strList(v['lastDiscard']);

    _selected.removeWhere((c) => !myHand.contains(c));
    if (_selected.isEmpty && myHand.isNotEmpty) {
      _selected.add(myHand.last);
    }
    final selectedList = _selected.toList();
    final validDiscard = isValidYanivDiscard(selectedList);

    final summaryRaw = v['lastRoundSummary'];
    final summary =
        summaryRaw is Map ? summaryRaw.cast<String, dynamic>() : null;

    final seats = g.seatsFromMe();
    final mySeat = seats.first;
    final oppSeats = seats.sublist(1);
    final isMyTurn = !g.spectator && !g.over && turn == g.seat;

    String statusText;
    if (g.over) {
      statusText = '对局结束（最低罚分获胜）';
    } else if (isMyTurn) {
      statusText = canYaniv
          ? '手牌仅 $mySum 点 (<=7)！可立即高呼「Yaniv!」或继续弃牌摸牌'
          : '轮到你：选择单张/对子/同花顺弃牌，并从牌库或弃牌堆摸 1 张';
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 450 || w < 440;
          final cardW = compact ? 38.0 : 48.0;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(compact ? 4 : 8),
                child: Column(
                  children: [
                    // Top header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '第 $round 局 · 淘汰线 $targetLimit 分 · 整50/100减半',
                            style: TextStyle(
                              fontSize: compact ? 10 : 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // Opponents row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in oppSeats)
                          _buildSeatChip(
                            s: s,
                            active: !g.over && turn == s,
                            score: s < scores.length ? scores[s] : 0,
                            targetLimit: targetLimit,
                            cards: s < handCounts.length ? handCounts[s] : 0,
                            compact: compact,
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // Center table area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 6 : 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Deck & Discard pile
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PlayingCard(
                                          'back',
                                          width: cardW,
                                          faceDown: true,
                                          onTap: isMyTurn && validDiscard
                                              ? () => _submitPlay('deck', null)
                                              : null,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '摸牌堆 ($deckCount)',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Wrap(
                                          spacing: 4,
                                          children: [
                                            for (final c in lastDiscard)
                                              PlayingCard(
                                                c,
                                                width: cardW,
                                                onTap: isMyTurn && validDiscard
                                                    ? () => _submitPlay(
                                                          'discard',
                                                          c,
                                                        )
                                                    : null,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        const Text(
                                          '上家弃牌 (可摸取)',
                                          style: TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (isMyTurn) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      if (canYaniv)
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                Colors.amber.shade700,
                                            foregroundColor: Colors.black,
                                          ),
                                          onPressed: () =>
                                              g.act({'type': 'yaniv'}),
                                          icon: const Icon(
                                            Icons.campaign,
                                            size: 18,
                                          ),
                                          label: Text(
                                            '高呼 YANIV! ($mySum 点)',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      FilledButton.tonalIcon(
                                        onPressed: validDiscard
                                            ? () => _submitPlay('deck', null)
                                            : null,
                                        icon: const Icon(
                                          Icons.layers,
                                          size: 16,
                                        ),
                                        label: Text(
                                          '弃 ${selectedList.length} 张 · 摸牌库',
                                        ),
                                      ),
                                      if (lastDiscard.isNotEmpty)
                                        OutlinedButton.icon(
                                          onPressed: validDiscard
                                              ? () => _submitPlay(
                                                    'discard',
                                                    lastDiscard.first,
                                                  )
                                              : null,
                                          icon: const Icon(
                                            Icons.pan_tool_alt,
                                            size: 16,
                                          ),
                                          label: Text(
                                            '弃 ${selectedList.length} 张 · 拿 ${lastDiscard.first}',
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                if (summary != null) ...[
                                  const SizedBox(height: 8),
                                  _buildRoundSummary(summary),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // My player bar
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 3 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: g.tag(
                              mySeat,
                              active: !g.over && turn == mySeat,
                              size: compact ? 26 : 32,
                              sub: '累计罚分 ${mySeat < scores.length ? scores[mySeat] : 0}/$targetLimit',
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: mySum <= 7
                                  ? Colors.green.shade700
                                  : Colors.blueGrey.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '当前手牌总点数：$mySum 点${mySum <= 7 ? ' (可喊 Yaniv!)' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: compact ? 3 : 6),

                    // My hand
                    if (!g.spectator && myHand.isNotEmpty)
                      SizedBox(
                        height: cardW * 1.52,
                        child: Center(
                          child: OverlapRow(
                            itemWidth: cardW,
                            children: [
                              for (final c in myHand)
                                PlayingCard(
                                  c,
                                  width: cardW,
                                  selected: _selected.contains(c),
                                  onTap: isMyTurn
                                      ? () {
                                          setState(() {
                                            if (_selected.contains(c)) {
                                              _selected.remove(c);
                                            } else {
                                              _selected.add(c);
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
                ),
              ),
              if (g.over)
                Center(
                  child: ResultBanner(
                    _buildWinnerTitle(scores),
                    child: Text(
                      [
                        for (var s = 0; s < g.players; s++)
                          '${g.name(s)}: ${s < scores.length ? scores[s] : 0}罚分',
                      ].join('  |  '),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _submitPlay(String drawFrom, String? drawCard) {
    final cards = _selected.toList();
    if (!isValidYanivDiscard(cards)) return;
    setState(() => _selected.clear());
    g.act({
      'type': 'play',
      'cards': cards,
      'drawFrom': drawFrom,
      'drawCard': ?drawCard,
    });
  }

  String _buildWinnerTitle(List<int> scores) {
    if (scores.isEmpty) return '对局结束';
    var best = 0;
    for (var s = 1; s < scores.length; s++) {
      if (scores[s] < scores[best]) best = s;
    }
    return '${g.name(best)} 以最低罚分 (${scores[best]}) 获胜！';
  }

  Widget _buildSeatChip({
    required int s,
    required bool active,
    required int score,
    required int targetLimit,
    required int cards,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: g.tag(
        s,
        active: active,
        size: compact ? 25 : 30,
        sub: '罚分 $score/$targetLimit · 手牌 $cards 张',
      ),
    );
  }

  Widget _buildRoundSummary(Map<String, dynamic> s) {
    final caller = (s['caller'] as num?)?.toInt() ?? 0;
    final callerSum = (s['callerSum'] as num?)?.toInt() ?? 0;
    final assaf = s['assaf'] == true;
    final deltas = _intList(s['deltas']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (assaf ? Colors.red.shade900 : Colors.green.shade900)
            .withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        assaf
            ? '⚡ 上局 ASSAF 反杀！${g.name(caller)} ($callerSum点) 遭反杀 +${caller < deltas.length ? deltas[caller] : 30} 罚分！'
            : '🎉 上局 ${g.name(caller)} ($callerSum点) 成功宣告 Yaniv (+0 罚分)！',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
