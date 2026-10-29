import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class EuchreBoard extends StatefulWidget {
  final GameContext g;
  const EuchreBoard(this.g, {super.key});

  @override
  State<EuchreBoard> createState() => _EuchreBoardState();
}

class _EuchreBoardState extends State<EuchreBoard> {
  bool _aloneToggle = false;

  static const _suitSym = {'S': '♠', 'H': '♥', 'D': '♦', 'C': '♣'};
  static const _suitName = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方块', 'C': '♣梅花'};

  Color _suitColor(String? s) =>
      (s == 'H' || s == 'D') ? const Color(0xFFE53935) : const Color(0xFF263238);

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'bid1';
    final handNumber = (v['handNumber'] as num?)?.toInt() ?? 1;
    final dealer = (v['dealer'] as num?)?.toInt() ?? 0;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 10;
    final stickDealer = v['stickDealer'] == true;
    final upCard = v['upCard'] as String?;
    final turnedDownSuit = v['turnedDownSuit'] as String?;
    final trumpSuit = v['trumpSuit'] as String?;
    final rightBower = v['rightBower'] as String?;
    final leftBower = v['leftBower'] as String?;
    final makerSeat = (v['makerSeat'] as num?)?.toInt() ?? -1;
    final goingAlone = v['goingAlone'] == true;
    final sittingOutSeat = (v['sittingOutSeat'] as num?)?.toInt() ?? -1;
    final trickNum = (v['trickNum'] as num?)?.toInt() ?? 1;

    final teamScores = (v['teamScores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final teamTricks = (v['teamTricks'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final tricksWon = (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0, 0, 0];
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0, 0, 0];
    final myHand = (v['hand'] as List?)?.cast<String>() ?? const <String>[];
    final legalPlays = (v['legalPlays'] as List?)?.cast<String>() ?? const <String>[];
    final currentTrick = (v['currentTrick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;
    final lastHandResult = v['lastHandResult'] as Map?;
    final over = v['over'] == true || g.over;
    final winnerTeam = (v['winnerTeam'] as num?)?.toInt() ?? -1;

    final seats = g.seatsFromMe(); // [bottom, right, top, left]
    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;

    String statusText;
    if (over) {
      statusText = '比赛结束：${winnerTeam == 0 ? "蓝队(0&2)" : "红队(1&3)"} 获胜！';
    } else if (phase == 'bid1') {
      statusText = isMyTurn ? '请决定是否令庄家拾起底牌定主' : '等待 ${g.name(turn)} 叫牌（第一轮）';
    } else if (phase == 'dealer_discard') {
      statusText = isMyTurn ? '你已拾起底牌，请点击一张手牌弃掉' : '等待庄家 ${g.name(turn)} 弃一张牌';
    } else if (phase == 'bid2') {
      statusText = isMyTurn ? '请指定本局主花色或过牌' : '等待 ${g.name(turn)} 选主（第二轮）';
    } else {
      statusText = isMyTurn ? '轮到你出牌（第 $trickNum/5 墩）' : '等待 ${g.name(turn)} 出牌（第 $trickNum/5 墩）';
    }

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
                // Top Info Bar
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _infoChip(cs, '第 $handNumber 局', Icons.style),
                      const SizedBox(width: 6),
                      _infoChip(
                        cs,
                        '蓝队(0&2) ${teamScores[0]}/$targetScore  :  ${teamScores[1]}/$targetScore 红队(1&3)',
                        Icons.scoreboard,
                        highlight: true,
                      ),
                      const SizedBox(width: 6),
                      _infoChip(cs, '本局墩数 蓝 ${teamTricks[0]} : ${teamTricks[1]} 红', Icons.layers),
                      if (trumpSuit != null) ...[
                        const SizedBox(width: 6),
                        _trumpBadge(cs, trumpSuit, rightBower, leftBower),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: compact ? 2 : 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StatusBar(statusText, highlight: isMyTurn),
                ),
                SizedBox(height: compact ? 2 : 6),

                // Top Partner Seat (seats[2])
                _buildSeatHeader(g, seats[2], turn, dealer, makerSeat, goingAlone, sittingOutSeat, tricksWon, handCounts, compact),

                // Middle Table Area with Left/Right Opponents + Center Trick/Bid Area
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildSeatHeader(
                            g,
                            seats[3],
                            turn,
                            dealer,
                            makerSeat,
                            goingAlone,
                            sittingOutSeat,
                            tricksWon,
                            handCounts,
                            true,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCenterTable(
                                  cs: cs,
                                  g: g,
                                  phase: phase,
                                  upCard: upCard,
                                  turnedDownSuit: turnedDownSuit,
                                  trumpSuit: trumpSuit,
                                  currentTrick: currentTrick,
                                  lastTrick: lastTrick,
                                  lastHandResult: lastHandResult,
                                  cardW: compact ? 38.0 : 48.0,
                                  compact: compact,
                                ),
                                if (isMyTurn && (phase == 'bid1' || phase == 'bid2')) ...[
                                  SizedBox(height: compact ? 4 : 8),
                                  _buildBidControls(
                                    cs: cs,
                                    g: g,
                                    phase: phase,
                                    upCard: upCard,
                                    turnedDownSuit: turnedDownSuit,
                                    mustCall: phase == 'bid2' && stickDealer && g.seat == dealer,
                                    compact: compact,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildSeatHeader(
                            g,
                            seats[1],
                            turn,
                            dealer,
                            makerSeat,
                            goingAlone,
                            sittingOutSeat,
                            tricksWon,
                            handCounts,
                            true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom My Seat + Hand
                _buildSeatHeader(g, seats[0], turn, dealer, makerSeat, goingAlone, sittingOutSeat, tricksWon, handCounts, compact),
                if (myHand.isNotEmpty) ...[
                  SizedBox(height: compact ? 2 : 6),
                  SizedBox(
                    height: cardW * 1.48,
                    child: Center(
                      child: OverlapRow(
                        itemWidth: cardW + 8,
                        children: [
                          for (final c in myHand)
                            _buildMyCard(
                              card: c,
                              cardW: cardW,
                              trumpSuit: trumpSuit,
                              rightBower: rightBower,
                              leftBower: leftBower,
                              canTap: isMyTurn &&
                                  (phase == 'dealer_discard' || (phase == 'play' && legalPlays.contains(c))),
                              dim: isMyTurn && phase == 'play' && !legalPlays.contains(c),
                              onTap: () {
                                if (phase == 'dealer_discard') {
                                  g.act({'type': 'discard', 'card': c});
                                } else if (phase == 'play') {
                                  g.act({'type': 'play', 'card': c});
                                }
                              },
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
                  winnerTeam == 0 ? '蓝队 (座位 0 & 2) 获胜！' : '红队 (座位 1 & 3) 获胜！',
                  child: Text('最终比分：蓝队 ${teamScores[0]} : ${teamScores[1]} 红队'),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _infoChip(ColorScheme cs, String text, IconData icon, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (highlight ? cs.primaryContainer : cs.surface).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: highlight ? cs.onPrimaryContainer : cs.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: highlight ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trumpBadge(ColorScheme cs, String suit, String? rightBower, String? leftBower) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade800, width: 1.5),
      ),
      child: Text(
        '主花色: ${_suitName[suit] ?? suit} (正:$rightBower 副:$leftBower)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _suitColor(suit),
        ),
      ),
    );
  }

  Widget _buildSeatHeader(
    GameContext g,
    int s,
    int turn,
    int dealer,
    int makerSeat,
    bool goingAlone,
    int sittingOutSeat,
    List<int> tricksWon,
    List<int> handCounts,
    bool compact,
  ) {
    final teamLabel = s % 2 == 0 ? '蓝队' : '红队';
    final badges = <String>[teamLabel];
    if (s == dealer) badges.add('庄');
    if (s == makerSeat) badges.add(goingAlone ? '独打叫主' : '叫主');
    if (s == sittingOutSeat) badges.add('旁观');
    final sub = '${badges.join("·")} | 墩:${tricksWon[s]} 手牌:${handCounts[s]}';
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: g.tag(
        s,
        active: turn == s,
        sub: sub,
        size: compact ? 28 : 34,
      ),
    );
  }

  Widget _buildCenterTable({
    required ColorScheme cs,
    required GameContext g,
    required String phase,
    required String? upCard,
    required String? turnedDownSuit,
    required String? trumpSuit,
    required List<Map> currentTrick,
    required Map? lastTrick,
    required Map? lastHandResult,
    required double cardW,
    required bool compact,
  }) {
    if (phase == 'bid1' || phase == 'dealer_discard') {
      return Container(
        padding: EdgeInsets.all(compact ? 6 : 12),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              phase == 'bid1' ? '底牌翻开 (Up-Card)' : '庄家已拾起底牌，等待弃牌',
              style: TextStyle(fontSize: compact ? 11 : 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (upCard != null) PlayingCard(upCard, width: cardW),
            if (lastHandResult != null) ...[
              const SizedBox(height: 4),
              Text(
                '上局：${lastHandResult['reason'] ?? ''}',
                style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      );
    }

    if (phase == 'bid2') {
      return Container(
        padding: EdgeInsets.all(compact ? 6 : 12),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '第二轮自由选主（不可选 ${_suitName[turnedDownSuit] ?? turnedDownSuit}）',
              style: TextStyle(fontSize: compact ? 11 : 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // Play phase: show currentTrick or lastTrick
    final showCurrent = currentTrick.isNotEmpty;
    final cardsList = showCurrent
        ? currentTrick
        : ((lastTrick?['cards'] as List?)?.cast<Map>() ?? const <Map>[]);

    return Container(
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            showCurrent
                ? '当前出牌桌面'
                : (lastTrick != null
                    ? '上一墩 (${g.name((lastTrick['winner'] as num).toInt())} 赢墩)'
                    : '等待领出本局第一墩'),
            style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (cardsList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('桌面暂无出牌', style: TextStyle(fontSize: 12)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final item in cardsList)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayingCard(item['card'] as String, width: cardW),
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

  Widget _buildBidControls({
    required ColorScheme cs,
    required GameContext g,
    required String phase,
    required String? upCard,
    required String? turnedDownSuit,
    required bool mustCall,
    required bool compact,
  }) {
    if (phase == 'bid1') {
      final suit = upCard != null && upCard.isNotEmpty ? upCard.substring(upCard.length - 1) : 'S';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => g.act({'type': 'order_up', 'alone': _aloneToggle}),
              icon: const Icon(Icons.arrow_upward, size: 16),
              label: Text('上牌定主 (${_suitName[suit]})${_aloneToggle ? "·独打" : ""}'),
            ),
            FilterChip(
              label: const Text('独打 (Alone)'),
              selected: _aloneToggle,
              onSelected: (v) => setState(() => _aloneToggle = v),
            ),
            OutlinedButton(
              onPressed: () => g.act({'type': 'pass'}),
              child: const Text('过牌 (Pass)'),
            ),
          ],
        ),
      );
    }

    // phase == 'bid2'
    final allowedSuits = ['S', 'H', 'D', 'C'].where((s) => s != turnedDownSuit).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          for (final s in allowedSuits)
            FilledButton.tonal(
              onPressed: () => g.act({'type': 'call', 'suit': s, 'alone': _aloneToggle}),
              child: Text(
                '${_suitSym[s]}选${_suitName[s]?.substring(1)}${_aloneToggle ? "(独)" : ""}',
                style: TextStyle(color: _suitColor(s), fontWeight: FontWeight.bold),
              ),
            ),
          FilterChip(
            label: const Text('独打'),
            selected: _aloneToggle,
            onSelected: (v) => setState(() => _aloneToggle = v),
          ),
          if (!mustCall)
            OutlinedButton(
              onPressed: () => g.act({'type': 'pass'}),
              child: const Text('过牌'),
            ),
        ],
      ),
    );
  }

  Widget _buildMyCard({
    required String card,
    required double cardW,
    required String? trumpSuit,
    required String? rightBower,
    required String? leftBower,
    required bool canTap,
    required bool dim,
    required VoidCallback onTap,
  }) {
    String? badge;
    Color badgeColor = Colors.deepOrange;
    if (card == rightBower) {
      badge = '正司令';
      badgeColor = Colors.redAccent.shade700;
    } else if (card == leftBower) {
      badge = '副司令(${_suitSym[trumpSuit] ?? "主"})';
      badgeColor = Colors.deepPurple;
    } else if (trumpSuit != null && card.endsWith(trumpSuit)) {
      badge = '主';
      badgeColor = Colors.amber.shade800;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: PlayingCard(
            card,
            width: cardW,
            dim: dim,
            onTap: canTap ? onTap : null,
          ),
        ),
        if (badge != null)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
