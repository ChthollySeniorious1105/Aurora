import 'package:aurora_shared/games/cards11/skat.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class SkatBoard extends StatefulWidget {
  final GameContext g;
  const SkatBoard(this.g, {super.key});

  @override
  State<SkatBoard> createState() => _SkatBoardState();
}

class _SkatBoardState extends State<SkatBoard> {
  final Set<String> _selectedDiscards = {};

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
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 3;
    final forehand = (v['forehand'] as num?)?.toInt() ?? 0;
    final phase = (v['phase'] as String?) ?? 'bid';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final declarer = (v['declarer'] as num?)?.toInt() ?? -1;
    final currentBid = (v['currentBid'] as num?)?.toInt() ?? 0;
    final bidValue = (v['bidValue'] as num?)?.toInt() ?? 18;
    final pickedSkat = v['pickedSkat'] == true;
    final handGame = v['handGame'] == true;
    final contract = (v['contract'] as String?) ?? '';
    final matadors = (v['matadors'] as num?)?.toInt() ?? 1;
    final tricksPlayed = (v['tricksPlayed'] as num?)?.toInt() ?? 0;
    final skatCount = (v['skatCount'] as num?)?.toInt() ?? 0;

    final passed = _boolList(v['passed']);
    final tricksWon = _intList(v['tricksWon']);
    final trickPoints = _intList(v['trickPoints']);
    final scores = _intList(v['scores']);
    final handCounts = _intList(v['handCounts']);
    final myHand = _strList(v['myHand']);
    final legalCards = _strList(v['legalCards']).toSet();
    final buriedSkat = _strList(v['buriedSkat']);

    _selectedDiscards.removeWhere((c) => !myHand.contains(c));

    final trickRaw = v['currentTrick'] as List? ?? const [];
    final currentTrick = [
      for (final e in trickRaw)
        if (e is Map) e.cast<String, dynamic>(),
    ];

    final lastTrickRaw = v['lastTrick'];
    final lastTrick =
        lastTrickRaw is Map ? lastTrickRaw.cast<String, dynamic>() : null;

    final summaryRaw = v['lastHandSummary'];
    final summary =
        summaryRaw is Map ? summaryRaw.cast<String, dynamic>() : null;

    final seats = g.seatsFromMe();
    final mySeat = seats.first;
    final oppSeats = seats.sublist(1);
    final isMyTurn = !g.spectator && !g.over && turn == g.seat;

    String statusText;
    if (g.over) {
      statusText = '整场对局已结束';
    } else if (phase == 'bid') {
      statusText = isMyTurn
          ? '轮到你叫牌（当前最高 $currentBid 分）'
          : '等待 ${g.name(turn)} 叫牌（当前最高 $currentBid 分）';
    } else if (phase == 'skat') {
      statusText = isMyTurn
          ? (pickedSkat
              ? '已拿起底牌：请从 12 张手牌中选择 2 张埋入得分堆'
              : '你是独庄！选择「提底埋牌 (Take Skat)」或「明手不看底 (Hand)」')
          : '等待独庄 ${g.name(turn)} 处理 2 张 Skat 底牌…';
    } else if (phase == 'contract') {
      statusText = isMyTurn
          ? '请选择本局定约（D/H/S/C 花色、Grand 大满贯或 Null 空门）'
          : '等待独庄 ${g.name(turn)} 选择定约…';
    } else {
      statusText = isMyTurn ? '轮到你出牌（4张J在花色/大满贯中均为最高主牌）' : '轮到 ${g.name(turn)} 出牌';
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
                    // Top status bar
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
                            '局 $round/$maxRounds · 墩 $tricksPlayed/10'
                            '${contract.isNotEmpty ? ' · ${kSkatContractNames[contract] ?? contract}' : ''}',
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
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in oppSeats)
                          _buildSeatChip(
                            s: s,
                            active: !g.over && turn == s,
                            isDeclarer: s == declarer,
                            isForehand: s == forehand,
                            passed: s < passed.length && passed[s],
                            score: s < scores.length ? scores[s] : 0,
                            tricks: s < tricksWon.length ? tricksWon[s] : 0,
                            pts: s < trickPoints.length ? trickPoints[s] : 0,
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
                              pickedSkat: pickedSkat,
                              handGame: handGame,
                              contract: contract,
                              matadors: matadors,
                              skatCount: skatCount,
                              buriedSkat: buriedSkat,
                              currentTrick: currentTrick,
                              lastTrick: lastTrick,
                              summary: summary,
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
                      isDeclarer: mySeat == declarer,
                      isForehand: mySeat == forehand,
                      passed: mySeat < passed.length && passed[mySeat],
                      score: mySeat < scores.length ? scores[mySeat] : 0,
                      tricks: mySeat < tricksWon.length ? tricksWon[mySeat] : 0,
                      pts: mySeat < trickPoints.length ? trickPoints[mySeat] : 0,
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
                                  selected: phase == 'skat' &&
                                      pickedSkat &&
                                      _selectedDiscards.contains(c),
                                  dim: isMyTurn &&
                                      phase == 'play' &&
                                      !legalCards.contains(c),
                                  onTap: isMyTurn
                                      ? () {
                                          if (phase == 'skat' && pickedSkat) {
                                            setState(() {
                                              if (_selectedDiscards.contains(c)) {
                                                _selectedDiscards.remove(c);
                                              } else if (_selectedDiscards.length < 2) {
                                                _selectedDiscards.add(c);
                                              }
                                            });
                                          } else if (phase == 'play' &&
                                              legalCards.contains(c)) {
                                            g.act({'type': 'play', 'card': c});
                                          }
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
    var bestSeat = 0;
    for (var s = 1; s < scores.length; s++) {
      if (scores[s] > scores[bestSeat]) bestSeat = s;
    }
    return '${g.name(bestSeat)} 赢得全场胜利！';
  }

  Widget _buildSeatChip({
    required int s,
    required bool active,
    required bool isDeclarer,
    required bool isForehand,
    required bool passed,
    required int score,
    required int tricks,
    required int pts,
    required int cards,
    required bool compact,
  }) {
    final role = isDeclarer
        ? '独庄 Declarer'
        : (isForehand ? '先手 Forehand' : '防守方');
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
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
              size: compact ? 26 : 32,
              sub: '总分 $score · 吃墩 $pts分 ($tricks墩) · 手牌 $cards',
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDeclarer
                  ? Colors.amber.shade800
                  : (passed ? Colors.grey.shade700 : Colors.blueGrey.shade700),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              passed && !isDeclarer ? '不叫 Pass' : role,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterContent({
    required String phase,
    required bool isMyTurn,
    required int currentBid,
    required int bidValue,
    required bool pickedSkat,
    required bool handGame,
    required String contract,
    required int matadors,
    required int skatCount,
    required List<String> buriedSkat,
    required List<Map<String, dynamic>> currentTrick,
    required Map<String, dynamic>? lastTrick,
    required Map<String, dynamic>? summary,
    required double cardW,
  }) {
    if (phase == 'bid') {
      final nextBids =
          kSkatBidValues.where((b) => b > currentBid).take(5).toList();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayingCard('back', width: cardW * 0.9, faceDown: true),
              const SizedBox(width: 6),
              PlayingCard('back', width: cardW * 0.9, faceDown: true),
              const SizedBox(width: 10),
              Text(
                'Skat 底牌 ($skatCount 张)\n当前最高叫分：${currentBid > 0 ? currentBid : '未起叫'}',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (isMyTurn) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final b in nextBids)
                  FilledButton.tonal(
                    onPressed: () => g.act({'type': 'bid', 'value': b}),
                    child: Text('叫 $b 分'),
                  ),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'pass'}),
                  child: const Text('不叫 (Pass)'),
                ),
              ],
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: 6),
            _buildSummaryBanner(summary),
          ],
        ],
      );
    }

    if (phase == 'skat') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '中标分值：$bidValue 分',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          if (isMyTurn && !pickedSkat)
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => g.act({'type': 'pick_skat'}),
                  icon: const Icon(Icons.layers, size: 16),
                  label: const Text('拿起 2 张底牌 (Take Skat)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => g.act({'type': 'hand'}),
                  icon: const Icon(Icons.front_hand, size: 16),
                  label: const Text('明手不看底 (Hand +1倍)'),
                ),
              ],
            )
          else if (isMyTurn && pickedSkat)
            FilledButton.icon(
              onPressed: _selectedDiscards.length == 2
                  ? () {
                      final d = _selectedDiscards.toList();
                      setState(() => _selectedDiscards.clear());
                      g.act({'type': 'take_skat', 'discards': d});
                    }
                  : null,
              icon: const Icon(Icons.archive, size: 16),
              label: Text('确认埋入底牌 (${_selectedDiscards.length}/2)'),
            )
          else
            const Text(
              '独庄正在处理底牌…',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      );
    }

    if (phase == 'contract') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '选择本局定约 (${handGame ? 'Hand 明手' : '已埋底 2 张'})',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (isMyTurn)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in kSkatContractNames.entries)
                  FilledButton.tonal(
                    onPressed: () =>
                        g.act({'type': 'contract', 'contract': entry.key}),
                    child: Text(entry.value),
                  ),
              ],
            )
          else
            const Text(
              '等待独庄宣布定约…',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
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
              '定约: ${kSkatContractNames[contract] ?? contract}',
              Colors.indigo.shade800,
            ),
            _badge(
              '叫分 $bidValue · 系数 ×${1 + matadors + (handGame ? 1 : 0)}',
              Colors.teal.shade800,
            ),
            if (buriedSkat.isNotEmpty)
              _badge(
                '已埋底: ${buriedSkat.join(' ')}',
                Colors.brown.shade700,
              ),
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
            '请先手引出第 1 墩牌（独庄需满 61 分获胜，Null 定约需 0 墩获胜）',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildSummaryBanner(Map<String, dynamic> s) {
    final decl = (s['declarer'] as num?)?.toInt() ?? 0;
    final won = s['declarerWon'] == true;
    final pts = (s['declarerPoints'] as num?)?.toInt() ?? 0;
    final delta = (s['delta'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (won ? Colors.green.shade900 : Colors.red.shade900)
            .withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '上局结算：独庄 ${g.name(decl)} 拿 $pts 分，${won ? '达成定约 +$delta' : '定约失败 $delta'} 分',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
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
