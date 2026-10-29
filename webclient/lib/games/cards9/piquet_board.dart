import 'package:aurora_shared/games/cards9/piquet.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class PiquetBoard extends StatefulWidget {
  final GameContext g;
  const PiquetBoard(this.g, {super.key});

  @override
  State<PiquetBoard> createState() => _PiquetBoardState();
}

class _PiquetBoardState extends State<PiquetBoard> {
  final Set<String> _selectedExchange = {};

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  List<int> _intList(Object? raw) =>
      raw is List ? [for (final x in raw) (x as num).toInt()] : const [];

  List<String> _strList(Object? raw) =>
      raw is List ? [for (final x in raw) '$x'] : const [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final handNumber = (v['handNumber'] as num?)?.toInt() ?? 1;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 100;
    final elder = (v['elder'] as num?)?.toInt() ?? 0;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = (v['phase'] as String?) ?? 'exchange';
    final talonCount = (v['talonCount'] as num?)?.toInt() ?? 8;
    final tricksPlayed = (v['tricksPlayed'] as num?)?.toInt() ?? 0;
    final repique = v['repiqueAwarded'] == true;
    final pique = v['piqueAwarded'] == true;

    final myHand = _strList(v['myHand']);
    final handCounts = _intList(v['handCounts']);
    final tricksWon = _intList(v['tricksWon']);
    final handPoints = _intList(v['handPoints']);
    final scores = _intList(v['scores']);
    final exchangedCounts = _intList(v['exchangedCounts']);

    final declRaw = v['declarationsSummary'];
    final decl = declRaw is Map ? declRaw.cast<String, dynamic>() : null;

    final trickRaw = v['currentTrick'] as List? ?? const [];
    final currentTrick = [
      for (final e in trickRaw)
        if (e is Map) e.cast<String, dynamic>(),
    ];

    final lastTrickRaw = v['lastTrick'];
    final lastTrick = lastTrickRaw is Map ? lastTrickRaw.cast<String, dynamic>() : null;

    final mySeat = g.seat >= 0 && g.seat < 2 ? g.seat : 0;
    final oppSeat = 1 - mySeat;
    final isMyTurn = !g.spectator && !g.over && turn == g.seat;

    _selectedExchange.removeWhere((c) => !myHand.contains(c));
    final maxExchange = mySeat == elder
        ? (talonCount < 5 ? talonCount : 5)
        : talonCount;
    final minExchange = mySeat == elder ? 1 : 0;

    // Legal play cards in 'play' phase
    Set<String> legalPlayCards = {};
    if (isMyTurn && phase == 'play') {
      if (currentTrick.isEmpty) {
        legalPlayCards = myHand.toSet();
      } else {
        final ledSuit = piquetSuit('${currentTrick.first['card'] ?? '7S'}');
        final sameSuit = myHand.where((c) => piquetSuit(c) == ledSuit).toSet();
        legalPlayCards = sameSuit.isNotEmpty ? sameSuit : myHand.toSet();
      }
    }

    String statusText;
    if (g.over) {
      statusText = '对局结束';
    } else if (phase == 'exchange') {
      statusText = isMyTurn
          ? '换牌阶段：请选择 $minExchange~$maxExchange 张手牌弃置并从底牌堆补牌'
          : '等待 ${g.name(turn)} 从底牌堆换牌…';
    } else {
      statusText = isMyTurn ? '轮到你出牌（无主花色，必须跟出首引花色）' : '轮到 ${g.name(turn)} 出牌';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 460 || w < 440;
          final cardW = compact ? 40.0 : 50.0;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(compact ? 6 : 10),
                child: Column(
                  children: [
                    // Top Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '第 $handNumber 局 · 目标 $targetScore 分 · 墩 $tricksPlayed/12',
                            style: TextStyle(
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 8),

                    // Opponent Bar
                    _buildPlayerBar(
                      context,
                      seat: oppSeat,
                      isElder: oppSeat == elder,
                      active: !g.over && turn == oppSeat,
                      totalScore: oppSeat < scores.length ? scores[oppSeat] : 0,
                      handPts: oppSeat < handPoints.length ? handPoints[oppSeat] : 0,
                      tricks: oppSeat < tricksWon.length ? tricksWon[oppSeat] : 0,
                      handCount: oppSeat < handCounts.length ? handCounts[oppSeat] : 0,
                      exchangedCount: oppSeat < exchangedCounts.length ? exchangedCounts[oppSeat] : 0,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 4 : 8),

                    // Center Table Area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 6 : 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.24),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: phase == 'exchange'
                                ? _buildExchangeCenter(
                                    isMyTurn: isMyTurn,
                                    talonCount: talonCount,
                                    minExchange: minExchange,
                                    maxExchange: maxExchange,
                                    cardW: cardW,
                                  )
                                : _buildPlayCenter(
                                    decl: decl,
                                    repique: repique,
                                    pique: pique,
                                    currentTrick: currentTrick,
                                    lastTrick: lastTrick,
                                    cardW: cardW,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 8),

                    // My Player Bar
                    _buildPlayerBar(
                      context,
                      seat: mySeat,
                      isElder: mySeat == elder,
                      active: !g.over && turn == mySeat,
                      totalScore: mySeat < scores.length ? scores[mySeat] : 0,
                      handPts: mySeat < handPoints.length ? handPoints[mySeat] : 0,
                      tricks: mySeat < tricksWon.length ? tricksWon[mySeat] : 0,
                      handCount: mySeat < handCounts.length ? handCounts[mySeat] : 0,
                      exchangedCount: mySeat < exchangedCounts.length ? exchangedCounts[mySeat] : 0,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // My Hand (OverlapRow)
                    if (!g.spectator && myHand.isNotEmpty)
                      SizedBox(
                        height: cardW * 1.55,
                        child: Center(
                          child: OverlapRow(
                            itemWidth: cardW,
                            children: [
                              for (final c in myHand)
                                PlayingCard(
                                  c,
                                  width: cardW,
                                  selected: phase == 'exchange' && _selectedExchange.contains(c),
                                  dim: isMyTurn &&
                                      phase == 'play' &&
                                      !legalPlayCards.contains(c),
                                  onTap: isMyTurn
                                      ? () {
                                          if (phase == 'exchange') {
                                            setState(() {
                                              if (_selectedExchange.contains(c)) {
                                                _selectedExchange.remove(c);
                                              } else if (_selectedExchange.length < maxExchange) {
                                                _selectedExchange.add(c);
                                              }
                                            });
                                          } else if (phase == 'play' && legalPlayCards.contains(c)) {
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
                    _buildOverTitle(scores),
                    child: Text(
                      '${g.name(0)}: ${scores.isNotEmpty ? scores[0] : 0} 分   |   '
                      '${g.name(1)}: ${scores.length > 1 ? scores[1] : 0} 分',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _buildOverTitle(List<int> scores) {
    if (scores.length < 2) return '对局结束';
    if (scores[0] > scores[1]) return '${g.name(0)} 获胜！';
    if (scores[1] > scores[0]) return '${g.name(1)} 获胜！';
    return '平局！';
  }

  Widget _buildPlayerBar(
    BuildContext context, {
    required int seat,
    required bool isElder,
    required bool active,
    required int totalScore,
    required int handPts,
    required int tricks,
    required int handCount,
    required int exchangedCount,
    required bool compact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Flexible(
            child: g.tag(
              seat,
              active: active,
              size: compact ? 28 : 34,
              sub: '总分 $totalScore · 本局 $handPts 分 · 赢 $tricks 墩',
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isElder ? Colors.amber.shade800 : Colors.blueGrey.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isElder ? '先手 (Elder)' : '后手 (Younger)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '手牌 $handCount${exchangedCount > 0 ? ' (已换$exchangedCount)' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeCenter({
    required bool isMyTurn,
    required int talonCount,
    required int minExchange,
    required int maxExchange,
    required double cardW,
  }) {
    final validSelection =
        _selectedExchange.length >= minExchange && _selectedExchange.length <= maxExchange;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayingCard('back', width: cardW, faceDown: true),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '底牌堆 (Talon)：剩余 $talonCount 张',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMyTurn
                      ? '可换 $minExchange ~ $maxExchange 张（已选 ${_selectedExchange.length} 张）'
                      : '等待对方完成换牌…',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        if (isMyTurn) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: validSelection
                ? () {
                    final cards = _selectedExchange.toList();
                    setState(() => _selectedExchange.clear());
                    g.act({'type': 'exchange', 'cards': cards});
                  }
                : null,
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: Text('确认换牌 (${_selectedExchange.length} 张)'),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayCenter({
    required Map<String, dynamic>? decl,
    required bool repique,
    required bool pique,
    required List<Map<String, dynamic>> currentTrick,
    required Map<String, dynamic>? lastTrick,
    required double cardW,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (decl != null) _buildDeclarationsSummary(decl, repique, pique),
        const SizedBox(height: 8),
        if (currentTrick.isNotEmpty)
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final e in currentTrick)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayingCard('${e['card'] ?? 'AS'}', width: cardW),
                    const SizedBox(height: 3),
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
            '上一墩赢家：${g.name((lastTrick['winner'] as num?)?.toInt() ?? 0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          )
        else
          const Text(
            '首引第一张牌后将自动比拼双方长套、同花顺与同点组宣告',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildDeclarationsSummary(
    Map<String, dynamic> decl,
    bool repique,
    bool pique,
  ) {
    final pWin = (decl['pointWinner'] as num?)?.toInt();
    final pPts = (decl['pointPts'] as num?)?.toInt() ?? 0;
    final sWin = (decl['seqWinner'] as num?)?.toInt();
    final sPts = (decl['seqPts'] as num?)?.toInt() ?? 0;
    final setWin = (decl['setWinner'] as num?)?.toInt();
    final setPts = (decl['setPts'] as num?)?.toInt() ?? 0;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        _declBadge(
          '长套 Point: ${pWin != null ? '${g.name(pWin)} +$pPts' : '平局'}',
          Colors.indigo.shade800,
        ),
        _declBadge(
          '顺子 Seq: ${sWin != null && sPts > 0 ? '${g.name(sWin)} +$sPts' : '无'}',
          Colors.teal.shade800,
        ),
        _declBadge(
          '同点 Set: ${setWin != null && setPts > 0 ? '${g.name(setWin)} +$setPts' : '无'}',
          Colors.deepPurple.shade800,
        ),
        if (repique) _declBadge('暗倍 Repique +60!', Colors.redAccent.shade700),
        if (pique) _declBadge('明倍 Pique +30!', Colors.orange.shade800),
      ],
    );
  }

  Widget _declBadge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
