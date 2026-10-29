import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

int _asInt(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
List<int> _asInts(Object? v) => [for (final x in (v as List? ?? const [])) (x as num).toInt()];
List<String> _asStrs(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];

const Map<String, String> _suitLabel = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方片', 'C': '♣梅花'};

Widget _pill(String text, Color color, {double fontSize = 11}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          fontFamilyFallback: kFontFallback,
        ),
      ),
    );

class OhHellBoard extends StatelessWidget {
  final GameContext g;
  const OhHellBoard(this.g, {super.key});

  Map<String, dynamic> get v => g.view;

  @override
  Widget build(BuildContext context) {
    final me = g.seat;
    final phase = '${v['phase'] ?? 'bid'}';
    final roundNo = _asInt(v['roundNo'], 1);
    final totalRounds = _asInt(v['totalRounds'], 5);
    final roundCards = _asInts(v['roundCards']);
    final cardsThisRound = _asInt(v['cardsThisRound'], 5);
    final dealer = _asInt(v['dealer'], 0);
    final turn = _asInt(v['turn'], 0);
    final trumpCard = '${v['trumpCard'] ?? ''}';
    final trumpSuit = '${v['trumpSuit'] ?? 'S'}';
    final hand = _asStrs(v['hand']);
    final legal = _asStrs(v['legalCards']).toSet();
    final bids = _asInts(v['bids']);
    final tricksWon = _asInts(v['tricksWon']);
    final scores = _asInts(v['scores']);
    final forbiddenBid = v['forbiddenBid'] is num ? (v['forbiddenBid'] as num).toInt() : null;
    final scoringMode = '${v['scoringMode'] ?? 'standard'}';

    final myTurn = me >= 0 && turn == me && !g.over;
    final seats = g.seatsFromMe();
    final bottomSeat = seats.first;
    final others = seats.sublist(1);

    String statusText;
    if (phase == 'bid') {
      if (myTurn) {
        statusText = forbiddenBid != null
            ? '轮到你叫墩（0~$cardsThisRound 墩，⚠️庄家禁手：禁叫 $forbiddenBid 墩）'
            : '轮到你叫墩（预测本局赢几墩：0~$cardsThisRound）';
      } else {
        statusText = '等待 ${g.name(turn)} 叫墩…';
      }
    } else if (phase == 'play') {
      statusText = myTurn ? '轮到你出牌（有领出花色须跟花色）' : '等待 ${g.name(turn)} 出牌…';
    } else {
      statusText = '全场比赛结束';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final compact = h < 480;
        final cardW = (w / (w > h ? 15 : 8.5)).clamp(28.0, compact ? 42.0 : 56.0);

        return Stack(fit: StackFit.expand, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(children: [
              // Header bar: round schedule & trump
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _pill('猜墩牌 · 第 $roundNo/$totalRounds 局 ($cardsThisRound张)', Colors.indigo.shade800),
                  const SizedBox(width: 6),
                  _pill('赛程: ${roundCards.join('-')}', Colors.blueGrey.shade700),
                  const SizedBox(width: 6),
                  _pill('王牌: ${_suitLabel[trumpSuit] ?? trumpSuit}',
                      trumpSuit == 'H' || trumpSuit == 'D' ? Colors.red.shade700 : Colors.grey.shade900),
                  const SizedBox(width: 6),
                  _pill(scoringMode == 'penalty' ? '罚分模式' : '标准10+墩', Colors.teal.shade700),
                ]),
              ),
              const SizedBox(height: 4),
              // Opponents row
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final s in others)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildPlayerCard(s, turn, dealer, bids, tricksWon, scores, compact),
                    ),
                ]),
              ),
              const SizedBox(height: 4),
              // Center table area
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(compact ? 6 : 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildCenterArea(
                          cardW,
                          phase,
                          trumpCard,
                          trumpSuit,
                          cardsThisRound,
                          bids,
                          myTurn,
                          forbiddenBid,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Status bar
              FittedBox(
                fit: BoxFit.scaleDown,
                child: StatusBar(statusText, highlight: myTurn),
              ),
              const SizedBox(height: 4),
              // Bottom player tag
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildPlayerCard(bottomSeat, turn, dealer, bids, tricksWon, scores, compact),
              ),
              if (me >= 0 && hand.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: cardW * 1.4 + (compact ? 6 : 10),
                  width: w - 24,
                  child: Center(
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          PlayingCard(
                            c,
                            width: cardW,
                            dim: myTurn && phase == 'play' && !legal.contains(c),
                            onTap: myTurn && phase == 'play' && legal.contains(c)
                                ? () => g.act({'type': 'play', 'card': c})
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
          ),
          if (g.over)
            Center(
              child: SingleChildScrollView(
                child: _buildOverBanner(scores),
              ),
            ),
        ]);
      }),
    );
  }

  Widget _buildPlayerCard(
    int s,
    int turn,
    int dealer,
    List<int> bids,
    List<int> tricksWon,
    List<int> scores,
    bool compact,
  ) {
    final b = s < bids.length ? bids[s] : -1;
    final w = s < tricksWon.length ? tricksWon[s] : 0;
    final sc = s < scores.length ? scores[s] : 0;
    final bidStr = b < 0 ? '未叫' : '叫$b · 赢$w';
    final sub = '$sc分 · $bidStr${dealer == s ? ' · 庄' : ''}';
    return g.tag(
      s,
      active: !g.over && turn == s,
      size: compact ? 24 : 30,
      sub: sub,
    );
  }

  Widget _buildCenterArea(
    double cardW,
    String phase,
    String trumpCard,
    String trumpSuit,
    int cardsThisRound,
    List<int> bids,
    bool myTurn,
    int? forbiddenBid,
  ) {
    final currentTrick = (v['currentTrick'] as List?) ?? const [];
    final lastTrick = v['lastTrick'] as Map?;
    final lastRound = v['lastRoundResult'] as Map?;
    final log = _asStrs(v['log']);
    final placedBids = bids.where((b) => b >= 0).toList();
    final bidSum = placedBids.fold<int>(0, (a, b) => a + b);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Trump card box
        Column(mainAxisSize: MainAxisSize.min, children: [
          PlayingCard(trumpCard.isEmpty ? 'back' : trumpCard, width: cardW * 0.9, faceDown: trumpCard.isEmpty),
          const SizedBox(height: 4),
          _pill('本局王牌 $trumpCard', Colors.deepPurple.shade700),
        ]),
        const SizedBox(width: 20),
        // Contract sum box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('全场已叫墩数 / 本局总墩数', style: TextStyle(color: Colors.white70, fontSize: 11)),
            Text(
              '$bidSum / $cardsThisRound 墩',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (placedBids.length == g.players)
              Text(
                bidSum > cardsThisRound ? '超叫 ${bidSum - cardsThisRound} 墩' : '少叫 ${cardsThisRound - bidSum} 墩',
                style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 11),
              ),
          ]),
        ),
        const SizedBox(width: 20),
        // Trick area
        if (currentTrick.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final item in currentTrick)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  PlayingCard('${(item as Map)['card']}', width: cardW),
                  const SizedBox(height: 3),
                  _pill(g.name(_asInt(item['seat'])), Colors.black54, fontSize: 10),
                ]),
              ),
          ])
        else if (lastTrick != null)
          Column(mainAxisSize: MainAxisSize.min, children: [
            _pill('上一墩胜者: ${g.name(_asInt(lastTrick['winner']))} (${lastTrick['winCard']})',
                Colors.green.shade800),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final item in (lastTrick['plays'] as List? ?? const []))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: PlayingCard('${(item as Map)['card']}', width: cardW * 0.72),
                ),
            ]),
          ]),
      ]),
      // Bid buttons when it's my turn in 'bid' phase
      if (phase == 'bid' && myTurn) ...[
        const SizedBox(height: 10),
        if (forbiddenBid != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _pill('⚠️ 庄家禁手规则：总叫墩数不可等于 $cardsThisRound，本轮禁止叫 $forbiddenBid 墩！',
                Colors.red.shade800,
                fontSize: 12),
          ),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
          for (var b = 0; b <= cardsThisRound; b++)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: b == forbiddenBid ? Colors.red.shade900 : Colors.amber.shade800,
              ),
              onPressed: b == forbiddenBid ? null : () => g.act({'type': 'bid', 'bid': b}),
              child: Text(b == forbiddenBid ? '禁叫 $b' : '叫 $b 墩'),
            ),
        ]),
      ],
      if (lastRound != null && currentTrick.isEmpty && phase == 'bid') ...[
        const SizedBox(height: 8),
        _pill(
          '上局结算 (第${lastRound['round']}局): ${[
            for (var s = 0; s < g.players; s++)
              '${g.name(s)} ${(_asInts(lastRound['deltas'])[s] >= 0 ? '+${_asInts(lastRound['deltas'])[s]}' : '${_asInts(lastRound['deltas'])[s]}')}',
          ].join(' · ')}',
          Colors.teal.shade800,
        ),
      ],
      if (log.isNotEmpty) ...[
        const SizedBox(height: 6),
        for (final line in (log.length > 2 ? log.sublist(log.length - 2) : log))
          Text(line, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    ]);
  }

  Widget _buildOverBanner(List<int> scores) {
    final placings = _asInts(v['placings']);
    final winners = [
      for (var s = 0; s < g.players; s++)
        if (s < placings.length && placings[s] == 1) g.name(s),
    ];
    return ResultBanner(
      '🏆 比赛结束 · 冠军：${winners.join('、')}',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
          for (var s = 0; s < g.players; s++)
            _pill(
              '#${s < placings.length ? placings[s] : 1} ${g.name(s)}: ${s < scores.length ? scores[s] : 0} 分',
              s < placings.length && placings[s] == 1 ? Colors.green.shade700 : Colors.blueGrey.shade700,
              fontSize: 12,
            ),
        ]),
      ]),
    );
  }
}
