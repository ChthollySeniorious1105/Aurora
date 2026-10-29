import 'package:aurora_shared/games/cards11/pinochle.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class PinochleBoard extends StatefulWidget {
  final GameContext g;
  const PinochleBoard(this.g, {super.key});

  @override
  State<PinochleBoard> createState() => _PinochleBoardState();
}

class _PinochleBoardState extends State<PinochleBoard> {
  String _chosenTrump = 'S';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  List<int> _intList(Object? raw) =>
      raw is List ? [for (final x in raw) (x as num).toInt()] : const [];

  List<String> _strList(Object? raw) =>
      raw is List ? [for (final x in raw) '$x'] : const [];

  List<bool> _boolList(Object? raw) =>
      raw is List ? [for (final x in raw) x == true] : const [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 2;
    final phase = (v['phase'] as String?) ?? 'bid';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final declarer = (v['declarer'] as num?)?.toInt() ?? 0;
    final currentBid = (v['currentBid'] as num?)?.toInt() ?? 190;
    final bidValue = (v['bidValue'] as num?)?.toInt() ?? 200;
    final trumpSuit = (v['trumpSuit'] as String?) ?? 'S';
    final tricksPlayed = (v['tricksPlayed'] as num?)?.toInt() ?? 0;
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;

    final passed = _boolList(v['passed']);
    final meldPoints = _intList(v['meldPoints']);
    final trickPoints = _intList(v['trickPoints']);
    final tricksWon = _intList(v['tricksWon']);
    final scores = _intList(v['scores']);
    final handCounts = _intList(v['handCounts']);
    final myHand = _strList(v['myHand']);
    final legalCards = _strList(v['legalCards']).toSet();

    final breakdownsRaw = v['meldBreakdowns'] as List? ?? const [];
    final meldBreakdowns = [
      for (final list in breakdownsRaw)
        if (list is List)
          [
            for (final item in list)
              if (item is Map) item.cast<String, dynamic>(),
          ]
        else
          const <Map<String, dynamic>>[],
    ];

    final trickRaw = v['currentTrick'] as List? ?? const [];
    final currentTrick = [
      for (final e in trickRaw)
        if (e is Map) e.cast<String, dynamic>(),
    ];

    final lastTrickRaw = v['lastTrick'];
    final lastTrick =
        lastTrickRaw is Map ? lastTrickRaw.cast<String, dynamic>() : null;

    final seats = g.seatsFromMe();
    final mySeat = seats.first;
    final oppSeats = seats.sublist(1);
    final isMyTurn = !g.spectator && !g.over && turn == g.seat;

    String statusText;
    if (g.over) {
      statusText = '整场对局结束';
    } else if (phase == 'bid') {
      statusText = isMyTurn
          ? '轮到你叫分（200分起叫，选定主花色）'
          : '等待 ${g.name(turn)} 叫分…';
    } else if (phase == 'meld') {
      statusText = isMyTurn
          ? '亮牌组合阶段：请确认全员组合分并开始吃墩'
          : '亮牌组合阶段：等待庄家 ${g.name(turn)} 确认开打…';
    } else {
      statusText = isMyTurn
          ? '轮到你出牌（主花色 ${kPinochleSuitNames[trumpSuit]}，牌序 A>10>K>Q>J>9）'
          : '轮到 ${g.name(turn)} 出牌';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 450 || w < 440;
          final cardW = compact ? 36.0 : 46.0;

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
                            '局 $round/$maxRounds · 墩 $tricksPlayed/12'
                            '${phase != 'bid' ? ' · 主 ${kPinochleSuitNames[trumpSuit]}' : ''}',
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
                            isDeclarer: phase != 'bid' && s == declarer,
                            passed: s < passed.length && passed[s],
                            score: s < scores.length ? scores[s] : 0,
                            meld: s < meldPoints.length ? meldPoints[s] : 0,
                            trickPts: s < trickPoints.length ? trickPoints[s] : 0,
                            tricks: s < tricksWon.length ? tricksWon[s] : 0,
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
                            child: _buildCenterContent(
                              phase: phase,
                              isMyTurn: isMyTurn,
                              currentBid: currentBid,
                              bidValue: bidValue,
                              declarer: declarer,
                              trumpSuit: trumpSuit,
                              stockCount: stockCount,
                              meldPoints: meldPoints,
                              meldBreakdowns: meldBreakdowns,
                              currentTrick: currentTrick,
                              lastTrick: lastTrick,
                              cardW: cardW,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // My player bar
                    _buildSeatChip(
                      s: mySeat,
                      active: !g.over && turn == mySeat,
                      isDeclarer: phase != 'bid' && mySeat == declarer,
                      passed: mySeat < passed.length && passed[mySeat],
                      score: mySeat < scores.length ? scores[mySeat] : 0,
                      meld: mySeat < meldPoints.length ? meldPoints[mySeat] : 0,
                      trickPts: mySeat < trickPoints.length ? trickPoints[mySeat] : 0,
                      tricks: mySeat < tricksWon.length ? tricksWon[mySeat] : 0,
                      cards: mySeat < handCounts.length ? handCounts[mySeat] : 0,
                      compact: compact,
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
                                  dim: isMyTurn &&
                                      phase == 'play' &&
                                      !legalCards.contains(c),
                                  onTap: isMyTurn &&
                                          phase == 'play' &&
                                          legalCards.contains(c)
                                      ? () => g.act({'type': 'play', 'card': c})
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
                          '${g.name(s)}: ${s < scores.length ? scores[s] : 0}分',
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

  String _buildWinnerTitle(List<int> scores) {
    if (scores.isEmpty) return '对局结束';
    var best = 0;
    for (var s = 1; s < scores.length; s++) {
      if (scores[s] > scores[best]) best = s;
    }
    return '${g.name(best)} 赢得皮诺克胜利！';
  }

  Widget _buildSeatChip({
    required int s,
    required bool active,
    required bool isDeclarer,
    required bool passed,
    required int score,
    required int meld,
    required int trickPts,
    required int tricks,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: g.tag(
              s,
              active: active,
              size: compact ? 25 : 30,
              sub: '总分 $score · 组合 $meld · 吃墩 $trickPts ($tricks墩) · 牌 $cards',
            ),
          ),
          if (isDeclarer || passed) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDeclarer ? Colors.amber.shade800 : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDeclarer ? '庄家' : 'Pass',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCenterContent({
    required String phase,
    required bool isMyTurn,
    required int currentBid,
    required int bidValue,
    required int declarer,
    required String trumpSuit,
    required int stockCount,
    required List<int> meldPoints,
    required List<List<Map<String, dynamic>>> meldBreakdowns,
    required List<Map<String, dynamic>> currentTrick,
    required Map<String, dynamic>? lastTrick,
    required double cardW,
  }) {
    if (phase == 'bid') {
      final minBid = currentBid < 200 ? 200 : currentBid + 10;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '当前最高叫分：${currentBid >= 200 ? '$currentBid 分' : '尚未起叫 (最低200)'}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (isMyTurn) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final s in kPinochleSuits)
                  ChoiceChip(
                    label: Text('预选主 ${kPinochleSuitNames[s]}'),
                    selected: _chosenTrump == s,
                    onSelected: (_) => setState(() => _chosenTrump = s),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final b in [minBid, minBid + 10, minBid + 20])
                  FilledButton.tonal(
                    onPressed: () => g.act({
                      'type': 'bid',
                      'value': b,
                      'trump': _chosenTrump,
                    }),
                    child: Text('叫 $b 分'),
                  ),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'pass'}),
                  child: const Text('不叫 (Pass)'),
                ),
              ],
            ),
          ],
        ],
      );
    }

    if (phase == 'meld') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '庄家 ${g.name(declarer)} ($bidValue分) · 主花色：${kPinochleSuitNames[trumpSuit]}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var s = 0; s < g.players; s++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${g.name(s)}：组合 +${s < meldPoints.length ? meldPoints[s] : 0} 分',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (s < meldBreakdowns.length &&
                          meldBreakdowns[s].isNotEmpty)
                        for (final item in meldBreakdowns[s])
                          Text(
                            '• ${item['name']} (+${item['points']})',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                            ),
                          )
                      else
                        const Text(
                          '• 无特殊组合',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          if (isMyTurn) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => g.act({'type': 'meld'}),
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('确认组合分并开始 12 墩吃墩'),
            ),
          ],
        ],
      );
    }

    // Play phase
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            _badge(
              '庄家 ${g.name(declarer)} (叫分 $bidValue)',
              Colors.indigo.shade800,
            ),
            _badge(
              '主花色: ${kPinochleSuitNames[trumpSuit]}',
              Colors.deepOrange.shade800,
            ),
            if (stockCount > 0)
              _badge('余牌库 $stockCount 张 (归末墩赢家)', Colors.teal.shade800),
          ],
        ),
        const SizedBox(height: 8),
        if (currentTrick.isNotEmpty)
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final e in currentTrick)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayingCard('${e['card']}', width: cardW),
                    const SizedBox(height: 2),
                    Text(
                      g.name((e['seat'] as num?)?.toInt() ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          )
        else if (lastTrick != null)
          Text(
            '上一墩赢家：${g.name((lastTrick['winner'] as num?)?.toInt() ?? 0)} '
            '(+${lastTrick['points'] ?? 0} 分)',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          )
        else
          const Text(
            '每张 A / 10 / K 计 10 分，第 12 墩赢家额外 +10 分（共 250 分）',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    );
  }

  Widget _badge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
