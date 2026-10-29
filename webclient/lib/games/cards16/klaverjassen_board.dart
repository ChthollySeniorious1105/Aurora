import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class KlaverjassenBoard extends StatelessWidget {
  final GameContext g;
  const KlaverjassenBoard(this.g, {super.key});

  static const List<(String, String, Color)> _suitButtons = [
    ('S', '♠ 黑桃 (Schoppen)', Color(0xFF1B5E20)),
    ('H', '♥ 红心 (Harten)', Color(0xFFC62828)),
    ('D', '♦ 方块 (Ruiten)', Color(0xFFD84315)),
    ('C', '♣ 梅花 (Klaveren)', Color(0xFF263238)),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'trump'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final forehand = (v['forehand'] as num?)?.toInt() ?? 0;
    final declarer = (v['declarer'] as num?)?.toInt() ?? 0;
    final declarerTeam = (v['declarerTeam'] as num?)?.toInt() ?? 0;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 4;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final proposedSuit = '${v['proposedSuit'] ?? 'C'}';
    final proposedSuitName = '${v['proposedSuitName'] ?? '♣ 梅花'}';
    final trumpSuitName = '${v['trumpSuitName'] ?? '♣ 梅花'}';

    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final teamScores =
        (v['teamScores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [0, 0];
    final teamBasePoints =
        (v['teamBasePoints'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [0, 0];
    final teamRoem =
        (v['teamRoem'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [0, 0];
    final teamTricks =
        (v['teamTricks'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [0, 0];
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal = ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'trump') {
      statusText = isMyTurn ? '轮到你选定主牌花色或选择不叫(Pass)' : '等待 ${g.name(turn)} 选主…';
    } else {
      statusText = isMyTurn ? '轮到你出牌（无领出花色时必须用主牌毙牌并尽量超毙）' : '等待 ${g.name(turn)} 出牌…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 42.0 : 54.0;

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(
          children: [
            Column(
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(cs, '第 $round/$totalRounds 局 · 第 ${trickNumber.clamp(1, 8)}/8 墩'),
                    _chip(
                      cs,
                      phase == 'trump'
                          ? '候选主牌：$proposedSuitName'
                          : '主牌：$trumpSuitName · 庄家：${declarerTeam == 0 ? "0&2队" : "1&3队"}',
                      highlight: true,
                    ),
                    _chip(
                      cs,
                      '0&2队：总${teamScores[0]} (${teamBasePoints[0]}分'
                      '${teamRoem[0] > 0 ? "+Roem${teamRoem[0]}" : ""}/${teamTricks[0]}墩)',
                    ),
                    _chip(
                      cs,
                      '1&3队：总${teamScores[1]} (${teamBasePoints[1]}分'
                      '${teamRoem[1] > 0 ? "+Roem${teamRoem[1]}" : ""}/${teamTricks[1]}墩)',
                    ),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Players row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      g.tag(
                        s,
                        active: !g.over && s == turn,
                        size: compact ? 28 : 34,
                        sub: '[${s % 2 == 0 ? "0&2队" : "1&3队"}]'
                            '${phase == 'play' && s == declarer ? "[庄] " : " "}'
                            '总${scores[s]}分${s == forehand ? " [先]" : ""}',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center table area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (phase == 'trump')
                            _buildTrumpSelector(
                              cs,
                              isMyTurn,
                              proposedSuit,
                              proposedSuitName,
                              compact,
                            )
                          else
                            _buildTrickTable(
                              cs,
                              trick,
                              lastTrick,
                              cardW,
                              compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Hand at bottom
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          PlayingCard(
                            c,
                            width: cardW,
                            selected: phase == 'play' && isMyTurn && legal.contains(c),
                            dim: phase == 'play' && isMyTurn && !legal.contains(c),
                            onTap: (phase == 'play' && isMyTurn && legal.contains(c))
                                ? () => g.act({'type': 'play', 'card': c})
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(_buildResultText(teamScores)),
              ),
          ],
        ),
      );
    });
  }

  Widget _chip(ColorScheme cs, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? cs.primaryContainer.withValues(alpha: 0.92)
            : cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? cs.primary : cs.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: highlight ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildTrumpSelector(
    ColorScheme cs,
    bool isMyTurn,
    String proposedSuit,
    String proposedSuitName,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.all(compact ? 8 : 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMyTurn ? '请选择本局主牌花色 (成为庄家队)' : '荷兰克劳弗牌选主阶段',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '主牌：J(Jas=20分) > 9(Nel=14分) > A(11) > 10(10) > K(4) > Q(3) > 8 > 7',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.75)),
          ),
          SizedBox(height: compact ? 6 : 10),
          FilledButton.icon(
            onPressed: isMyTurn ? () => g.act({'type': 'accept'}) : null,
            icon: const Icon(Icons.verified, size: 16),
            label: Text('认领候选主牌：$proposedSuitName'),
          ),
          SizedBox(height: compact ? 6 : 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final (suit, title, color) in _suitButtons)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isMyTurn
                      ? () => g.act({'type': 'choose_trump', 'suit': suit})
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isMyTurn ? 0.9 : 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: suit == proposedSuit ? Colors.amber : Colors.white30,
                        width: suit == proposedSuit ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (isMyTurn) ...[
            SizedBox(height: compact ? 6 : 10),
            OutlinedButton.icon(
              onPressed: () => g.act({'type': 'pass'}),
              icon: const Icon(Icons.skip_next, size: 16),
              label: const Text('不叫 (Pass)'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrickTable(
    ColorScheme cs,
    List<Map> trick,
    Map? lastTrick,
    double cardW,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '主牌：J(20)>9(14)>A(11)>10(10)>K(4)>Q(3)>8>7 · Roem：3顺+20 / 4顺+50 / 主K+Q(Stuk)+20 / 四条+100',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
          padding: EdgeInsets.all(compact ? 8 : 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: trick.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(compact ? 8 : 14),
                  child: const Text(
                    '等待本墩首张领出牌…（庄家队须严格超过半数分，否则 Nat 宕牌归零！）',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final entry in trick)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayingCard('${entry['card']}', width: cardW),
                          const SizedBox(height: 4),
                          Text(
                            g.name((entry['seat'] as num).toInt()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        if (lastTrick != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 赢得 +${lastTrick['points']} 分'
              '${(lastTrick['roem'] as num? ?? 0) > 0 ? " · Roem +${lastTrick['roem']}分!" : ""}'
              '${(lastTrick['lastTrickBonus'] as num? ?? 0) > 0 ? " (含末墩+10分)" : ""}',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(List<int> teamScores) {
    return '比赛结束！0&2队 (${g.name(0)}/${g.name(2)}): ${teamScores[0]}分 vs '
        '1&3队 (${g.name(1)}/${g.name(3)}): ${teamScores[1]}分';
  }
}
