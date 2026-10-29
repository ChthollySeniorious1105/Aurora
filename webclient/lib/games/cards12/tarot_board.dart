import 'package:aurora_shared/games/cards12/tarot.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class TarotBoard extends StatefulWidget {
  final GameContext g;
  const TarotBoard(this.g, {super.key});

  @override
  State<TarotBoard> createState() => _TarotBoardState();
}

class _TarotBoardState extends State<TarotBoard> {
  final Set<String> _selectedChien = {};

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
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 3;
    final forehand = (v['forehand'] as num?)?.toInt() ?? 0;
    final phase = (v['phase'] as String?) ?? 'bid';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final declarer = (v['declarer'] as num?)?.toInt() ?? -1;
    final contractBid = (v['contractBid'] as num?)?.toInt() ?? 0;
    final chienSize = (v['chienSize'] as num?)?.toInt() ?? 6;
    final tricksPlayed = (v['tricksPlayed'] as num?)?.toInt() ?? 0;
    final totalTricks = (v['totalTricks'] as num?)?.toInt() ?? 18;
    final declarerPoints = (v['declarerPoints'] as num?)?.toDouble() ?? 0.0;

    final playerBids = _intList(v['playerBids']);
    final tricksWon = _intList(v['tricksWon']);
    final handCounts = _intList(v['handCounts']);
    final scores = _intList(v['scores']);
    final revealedChien = _strList(v['revealedChien']);
    final declarerOudlers = _strList(v['declarerOudlers']);
    final myHand = _strList(v['myHand']);
    final legalCards = _strList(v['legalCards']).toSet();
    final legalDiscards = _strList(v['legalDiscards']).toSet();

    _selectedChien.removeWhere((c) => !myHand.contains(c));

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

    final targetPts = tarotTargetPoints(declarerOudlers.length);

    String statusText;
    if (g.over) {
      statusText = '整场对局已结束';
    } else if (phase == 'bid') {
      statusText = isMyTurn
          ? '轮到你叫牌（可选小契约 Petite ×1 / 守护 Garde ×2 / 无底守护 Garde sans ×4）'
          : '等待 ${g.name(turn)} 叫牌…';
    } else if (phase == 'chien') {
      statusText = isMyTurn
          ? '你是独庄！请从手牌中选择 $chienSize 张可扣副牌放入底牌得分堆'
          : '等待独庄 ${g.name(turn)} 扣下 $chienSize 张底牌（Chien）…';
    } else {
      statusText = isMyTurn
          ? '轮到你出牌（副牌断门须出主牌且强制上打；愚者 T0 随时可出）'
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
                            '局 $round/$maxRounds · 墩 $tricksPlayed/$totalTricks'
                            '${contractBid > 0 ? ' · ${kTarotContractNames[contractBid] ?? ''}' : ''}',
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
                    SizedBox(height: compact ? 3 : 6),

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
                            isDeclarer: s == declarer,
                            isForehand: s == forehand,
                            bidCode: s < playerBids.length ? playerBids[s] : 0,
                            score: s < scores.length ? scores[s] : 0,
                            tricks: s < tricksWon.length ? tricksWon[s] : 0,
                            cards: s < handCounts.length ? handCounts[s] : 0,
                            compact: compact,
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 3 : 6),

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
                              declarer: declarer,
                              contractBid: contractBid,
                              chienSize: chienSize,
                              revealedChien: revealedChien,
                              declarerPoints: declarerPoints,
                              declarerOudlers: declarerOudlers,
                              targetPts: targetPts,
                              currentTrick: currentTrick,
                              lastTrick: lastTrick,
                              summary: summary,
                              cardW: cardW,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 3 : 6),

                    // My player bar
                    _buildSeatChip(
                      s: mySeat,
                      active: !g.over && turn == mySeat,
                      isDeclarer: mySeat == declarer,
                      isForehand: mySeat == forehand,
                      bidCode:
                          mySeat < playerBids.length ? playerBids[mySeat] : 0,
                      score: mySeat < scores.length ? scores[mySeat] : 0,
                      tricks: mySeat < tricksWon.length ? tricksWon[mySeat] : 0,
                      cards:
                          mySeat < handCounts.length ? handCounts[mySeat] : 0,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 3 : 6),

                    // My hand
                    if (!g.spectator && myHand.isNotEmpty)
                      SizedBox(
                        height: cardW * 1.5,
                        child: Center(
                          child: OverlapRow(
                            itemWidth: cardW,
                            children: [
                              for (final c in myHand)
                                _buildTarotCard(
                                  c,
                                  width: cardW,
                                  selected: phase == 'chien' &&
                                      _selectedChien.contains(c),
                                  dim: isMyTurn &&
                                      ((phase == 'play' &&
                                              !legalCards.contains(c)) ||
                                          (phase == 'chien' &&
                                              !legalDiscards.contains(c))),
                                  onTap: isMyTurn
                                      ? () {
                                          if (phase == 'chien' &&
                                              legalDiscards.contains(c)) {
                                            setState(() {
                                              if (_selectedChien.contains(c)) {
                                                _selectedChien.remove(c);
                                              } else if (_selectedChien.length <
                                                  chienSize) {
                                                _selectedChien.add(c);
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
    var best = 0;
    for (var s = 1; s < scores.length; s++) {
      if (scores[s] > scores[best]) best = s;
    }
    return '${g.name(best)} 赢得全场胜利！';
  }

  Widget _buildSeatChip({
    required int s,
    required bool active,
    required bool isDeclarer,
    required bool isForehand,
    required int bidCode,
    required int score,
    required int tricks,
    required int cards,
    required bool compact,
  }) {
    String role;
    if (isDeclarer) {
      role = '独庄 Declarer';
    } else if (bidCode == -1) {
      role = '不叫 Pass';
    } else if (isForehand) {
      role = '先手 Forehand';
    } else {
      role = '防守方';
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2 : 4,
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
              size: compact ? 24 : 30,
              sub: '总分 $score · 赢 $tricks墩 · 手牌 $cards',
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDeclarer
                  ? Colors.amber.shade800
                  : Colors.blueGrey.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role,
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
    required int declarer,
    required int contractBid,
    required int chienSize,
    required List<String> revealedChien,
    required double declarerPoints,
    required List<String> declarerOudlers,
    required int targetPts,
    required List<Map<String, dynamic>> currentTrick,
    required Map<String, dynamic>? lastTrick,
    required Map<String, dynamic>? summary,
    required double cardW,
  }) {
    if (phase == 'bid') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '底牌（Chien）共 $chienSize 张 · 当前最高契约：'
            '${contractBid > 0 ? kTarotContractNames[contractBid] : '未起叫'}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (isMyTurn) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in kTarotContractNames.entries)
                  if (entry.key > contractBid)
                    FilledButton.tonal(
                      onPressed: () =>
                          g.act({'type': 'bid', 'bid': entry.key}),
                      child: Text(entry.value),
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

    if (phase == 'chien') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (revealedChien.isNotEmpty) ...[
            const Text(
              '翻开的底牌（Chien）：',
              style: TextStyle(color: Colors.amberAccent, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final c in revealedChien)
                  _buildTarotCard(c, width: cardW * 0.85),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (isMyTurn)
            FilledButton.icon(
              onPressed: _selectedChien.length == chienSize
                  ? () {
                      final cards = _selectedChien.toList();
                      setState(() => _selectedChien.clear());
                      g.act({'type': 'discard_chien', 'cards': cards});
                    }
                  : null,
              icon: const Icon(Icons.archive, size: 16),
              label: Text('确认扣底 (${_selectedChien.length}/$chienSize)'),
            )
          else
            Text(
              '独庄 ${g.name(declarer)} 正在扣下 $chienSize 张底牌…',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      );
    }

    // Play phase
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            _badge(
              '独庄: ${declarer >= 0 ? g.name(declarer) : '-'} (${kTarotContractNames[contractBid] ?? ''})',
              Colors.indigo.shade800,
            ),
            _badge(
              '已抓关键牌(Oudlers): ${declarerOudlers.length}/3 → 目标 $targetPts 分',
              Colors.purple.shade800,
            ),
            _badge(
              '独庄当前得分: ${declarerPoints.toStringAsFixed(1)} 分',
              Colors.teal.shade800,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (currentTrick.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final e in currentTrick)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTarotCard('${e['card']}', width: cardW),
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
            '上一墩赢家：${g.name((lastTrick['winner'] as num?)?.toInt() ?? 0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          )
        else
          const Text(
            '请先手引出第 1 墩（三大关键牌 T0/T1/T21 决定目标分线 56/51/41/36）',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildSummaryBanner(Map<String, dynamic> s) {
    final decl = (s['declarer'] as num?)?.toInt() ?? 0;
    final won = s['declarerWon'] == true;
    final oudlers = (s['oudlerCount'] as num?)?.toInt() ?? 0;
    final target = (s['targetPoints'] as num?)?.toInt() ?? 56;
    final pts = (s['declarerPoints'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (won ? Colors.green.shade900 : Colors.red.shade900)
            .withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '上局结算：独庄 ${g.name(decl)} 抓 $oudlers 张关键牌(目标$target)，实得 ${pts.toStringAsFixed(1)} 分 (${won ? '成功' : '失败'})',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _buildTarotCard(
    String code, {
    required double width,
    bool selected = false,
    bool dim = false,
    VoidCallback? onTap,
  }) {
    if (code != 'T0' && !isTarotTrump(code)) {
      return PlayingCard(
        code,
        width: width,
        selected: selected,
        dim: dim,
        onTap: onTap,
      );
    }

    final isOudler = isTarotOudler(code);
    final isFool = code == 'T0';
    final label = isFool ? '愚者' : code;
    final subLabel = isFool
        ? '★Excuse'
        : (code == 'T1'
            ? '★Petit'
            : (code == 'T21' ? '★Monde' : '主牌'));
    final bg = isOudler ? const Color(0xFF4A148C) : const Color(0xFF1A237E);
    final fg = isOudler ? Colors.amberAccent : Colors.white;
    final h = width * 1.4;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.3 : 0, 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(
          color: selected
              ? Colors.amber
              : (isOudler ? Colors.amberAccent : Colors.white54),
          width: selected || isOudler ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: width * 0.34,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
              Icon(
                isOudler ? Icons.stars : Icons.shield,
                size: width * 0.42,
                color: fg,
              ),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: width * 0.21,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (dim) card = Opacity(opacity: 0.45, child: card);
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
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
