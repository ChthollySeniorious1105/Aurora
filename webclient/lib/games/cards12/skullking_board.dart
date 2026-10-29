import 'package:aurora_shared/games/cards12/skullking.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class SkullKingBoard extends StatefulWidget {
  final GameContext g;
  const SkullKingBoard(this.g, {super.key});

  @override
  State<SkullKingBoard> createState() => _SkullKingBoardState();
}

class _SkullKingBoardState extends State<SkullKingBoard> {
  String _tigressMode = 'pirate'; // 'pirate' | 'escape'

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  List<int> _intList(Object? raw) =>
      raw is List ? [for (final x in raw) (x as num).toInt()] : const [];

  List<int?> _nullableIntList(Object? raw) => raw is List
      ? [for (final x in raw) x is num ? x.toInt() : null]
      : const [];

  List<String> _strList(Object? raw) =>
      raw is List ? [for (final x in raw) '$x'] : const [];

  List<bool> _boolList(Object? raw) =>
      raw is List ? [for (final x in raw) x == true] : const [];

  static const Map<String, String> _suitNames = {
    'Y': '黄宝箱',
    'P': '紫罗兰',
    'G': '绿鹦鹉',
    'B': '黑旗主牌',
    'CHAR': '特殊牌(无花色限制)',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 6;
    final roundCards = (v['roundCards'] as num?)?.toInt() ?? 1;
    final phase = (v['phase'] as String?) ?? 'bid';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final tricksPlayed = (v['tricksPlayed'] as num?)?.toInt() ?? 0;
    final ledSuit = v['ledSuit'] as String?;

    final bids = _nullableIntList(v['bids']);
    final bidLocked = _boolList(v['bidLocked']);
    final tricksWon = _intList(v['tricksWon']);
    final roundBonus = _intList(v['roundBonus']);
    final handCounts = _intList(v['handCounts']);
    final scores = _intList(v['scores']);
    final myHand = _strList(v['myHand']);
    final legalCards = _strList(v['legalCards']).toSet();

    final trickRaw = v['currentTrick'] as List? ?? const [];
    final currentTrick = [
      for (final e in trickRaw)
        if (e is Map) e.cast<String, dynamic>(),
    ];

    final lastTrickRaw = v['lastTrick'];
    final lastTrick =
        lastTrickRaw is Map ? lastTrickRaw.cast<String, dynamic>() : null;

    final summaryRaw = v['lastRoundSummary'];
    final summary =
        summaryRaw is Map ? summaryRaw.cast<String, dynamic>() : null;

    final seats = g.seatsFromMe();
    final mySeat = seats.first;
    final oppSeats = seats.sublist(1);
    final myBidLocked = mySeat < bidLocked.length && bidLocked[mySeat];
    final isMyTurn = !g.spectator &&
        !g.over &&
        ((phase == 'bid' && !myBidLocked) ||
            (phase == 'play' && turn == g.seat));

    String statusText;
    if (g.over) {
      statusText = '整场对局已结束';
    } else if (phase == 'bid') {
      statusText = isMyTurn
          ? '请同时暗叫本轮预计赢下的准确墩数（0..$roundCards 墩）'
          : '已锁定叫墩，等待其他玩家完成叫墩…';
    } else {
      statusText = isMyTurn
          ? '轮到你出牌（骷髅王克海盗 +30/张，美人鱼诱捕骷髅王 +40）'
          : '轮到 ${g.name(turn)} 出牌';
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
                            '轮 $round/$maxRounds ($roundCards张) · 墩 $tricksPlayed/$roundCards',
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
                            phase: phase,
                            active: !g.over &&
                                ((phase == 'bid' &&
                                        !(s < bidLocked.length &&
                                            bidLocked[s])) ||
                                    (phase == 'play' && turn == s)),
                            bid: s < bids.length ? bids[s] : null,
                            locked: s < bidLocked.length && bidLocked[s],
                            won: s < tricksWon.length ? tricksWon[s] : 0,
                            bonus: s < roundBonus.length ? roundBonus[s] : 0,
                            score: s < scores.length ? scores[s] : 0,
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
                              roundCards: roundCards,
                              ledSuit: ledSuit,
                              myHand: myHand,
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
                      phase: phase,
                      active: isMyTurn,
                      bid: mySeat < bids.length ? bids[mySeat] : null,
                      locked: myBidLocked,
                      won: mySeat < tricksWon.length ? tricksWon[mySeat] : 0,
                      bonus:
                          mySeat < roundBonus.length ? roundBonus[mySeat] : 0,
                      score: mySeat < scores.length ? scores[mySeat] : 0,
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
                              for (var i = 0; i < myHand.length; i++)
                                _buildSkullKingCard(
                                  myHand[i],
                                  width: cardW,
                                  dim: isMyTurn &&
                                      phase == 'play' &&
                                      !legalCards.contains(myHand[i]),
                                  onTap: isMyTurn &&
                                          phase == 'play' &&
                                          legalCards.contains(myHand[i])
                                      ? () {
                                          final c = myHand[i];
                                          g.act({
                                            'type': 'play',
                                            'card': c,
                                            if (c == 'TIG')
                                              'mode': _tigressMode,
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
    return '${g.name(best)} 夺得海盗霸主！';
  }

  Widget _buildSeatChip({
    required int s,
    required String phase,
    required bool active,
    required int? bid,
    required bool locked,
    required int won,
    required int bonus,
    required int score,
    required int cards,
    required bool compact,
  }) {
    final bidText = phase == 'bid'
        ? (bid != null ? '已叫$bid墩' : (locked ? '已暗叫' : '思考中'))
        : '叫${bid ?? 0}墩 / 赢$won墩';
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
              sub: '总分 $score · 手牌 $cards${bonus > 0 ? ' · 奖+$bonus' : ''}',
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: phase != 'bid' && bid != null && won == bid
                  ? Colors.green.shade800
                  : Colors.blueGrey.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bidText,
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
    required int roundCards,
    required String? ledSuit,
    required List<String> myHand,
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
            '第 $roundCards 张牌轮次：请同时暗叫本轮预计赢下的墩数',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '命中≥1墩: +20×叫墩+奖励分 | 失误: -10×差值 | 叫0墩: ±10×本轮总牌数',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (isMyTurn) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (var b = 0; b <= roundCards; b++)
                  FilledButton.tonal(
                    onPressed: () => g.act({'type': 'bid', 'bid': b}),
                    child: Text('叫 $b 墩'),
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

    // Play phase
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _badge(
              '本墩引牌: ${ledSuit != null ? (_suitNames[ledSuit] ?? ledSuit) : '尚未定花'}',
              Colors.indigo.shade800,
            ),
            _badge('克制: 美人鱼>骷髅王>海盗>黑旗主牌>普通花色>白旗', Colors.teal.shade800),
            if (isMyTurn && myHand.contains('TIG')) ...[
              ChoiceChip(
                label: const Text('女海盗: 海盗(Pirate)', style: TextStyle(fontSize: 10)),
                selected: _tigressMode == 'pirate',
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _tigressMode = 'pirate'),
              ),
              ChoiceChip(
                label: const Text('女海盗: 逃跑(Escape)', style: TextStyle(fontSize: 10)),
                selected: _tigressMode == 'escape',
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _tigressMode = 'escape'),
              ),
            ],
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
                    _buildSkullKingCard(
                      '${e['card']}',
                      mode: e['mode'] as String?,
                      width: cardW,
                    ),
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
            '(${lastTrick['winningCard']})'
            '${((lastTrick['bonusPoints'] as num?)?.toInt() ?? 0) > 0 ? ' +${lastTrick['bonusPoints']}奖励分!' : ''}',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
          )
        else
          const Text(
            '请先手引出本轮第 1 墩牌（特殊角色牌可无视跟花限制随时打出）',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildSummaryBanner(Map<String, dynamic> s) {
    final r = (s['round'] as num?)?.toInt() ?? 1;
    final deltas = _intList(s['deltas']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.brown.shade900.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '第$r轮结算：'
        '${[for (var i = 0; i < g.players && i < deltas.length; i++) '${g.name(i)} ${deltas[i] >= 0 ? '+${deltas[i]}' : deltas[i]}'].join(' | ')}',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _buildSkullKingCard(
    String code, {
    String? mode,
    required double width,
    bool dim = false,
    VoidCallback? onTap,
  }) {
    final h = width * 1.4;
    String title;
    String subtitle;
    Color bg;
    Color fg = Colors.white;
    IconData icon;

    if (code == 'SK') {
      title = '骷髅王';
      subtitle = 'SK +30/海盗';
      bg = const Color(0xFF880E4F);
      fg = Colors.amberAccent;
      icon = Icons.dangerous;
    } else if (code == 'MER') {
      title = '美人鱼';
      subtitle = '克SK +40';
      bg = const Color(0xFF006064);
      fg = Colors.cyanAccent;
      icon = Icons.water;
    } else if (code == 'PIR') {
      title = '海盗';
      subtitle = '压所有数牌';
      bg = const Color(0xFFB71C1C);
      icon = Icons.gavel;
    } else if (code == 'TIG') {
      title = '女海盗';
      subtitle = mode == 'escape'
          ? '作:白旗逃跑'
          : (mode == 'pirate' ? '作:海盗' : '海盗/逃跑');
      bg = const Color(0xFF4A148C);
      fg = Colors.orangeAccent;
      icon = Icons.switch_account;
    } else if (code == 'ESC') {
      title = '白旗';
      subtitle = '逃跑(0胜)';
      bg = const Color(0xFF455A64);
      icon = Icons.flag;
    } else {
      final suit = skullKingSuit(code);
      final rank = skullKingRank(code);
      title = '$rank';
      if (suit == 'B') {
        subtitle = '黑旗主牌';
        bg = const Color(0xFF212121);
        fg = Colors.amberAccent;
        icon = Icons.flag_circle;
      } else if (suit == 'Y') {
        subtitle = '黄宝箱';
        bg = const Color(0xFFF57F17);
        icon = Icons.inventory_2;
      } else if (suit == 'P') {
        subtitle = '紫罗兰';
        bg = const Color(0xFF6A1B9A);
        icon = Icons.local_florist;
      } else {
        subtitle = '绿鹦鹉';
        bg = const Color(0xFF2E7D32);
        icon = Icons.flutter_dash;
      }
    }

    Widget card = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(color: fg.withValues(alpha: 0.7), width: 1.5),
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
                title,
                style: TextStyle(
                  fontSize: width * 0.34,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
              Icon(icon, size: width * 0.42, color: fg),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: width * 0.2,
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
