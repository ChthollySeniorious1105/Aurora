import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class SchafkopfBoard extends StatelessWidget {
  final GameContext g;
  const SchafkopfBoard(this.g, {super.key});

  static const List<(String, String, Color)> _soloContracts = [
    ('wenz', 'Wenz 温茨独庄 (仅4张J主)', Color(0xFF6A1B9A)),
    ('solo_C', 'Solo ♣ 梅花独庄', Color(0xFF263238)),
    ('solo_S', 'Solo ♠ 黑桃独庄', Color(0xFF1B5E20)),
    ('solo_H', 'Solo ♥ 红心独庄', Color(0xFFC62828)),
    ('solo_D', 'Solo ♦ 方块独庄', Color(0xFFD84315)),
  ];

  static const Map<String, String> _aceLabels = {
    'AC': '呼唤 ♣A (梅花A)',
    'AS': '呼唤 ♠A (黑桃A)',
    'AD': '呼唤 ♦A (方块A)',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'contract'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final forehand = (v['forehand'] as num?)?.toInt() ?? 0;
    final declarer = (v['declarer'] as num?)?.toInt() ?? 0;
    final partner = (v['partner'] as num?)?.toInt();
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 4;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final contract = v['contract'] as String?;
    final contractName = v['contractName'] as String?;
    final calledAce = v['calledAce'] as String?;

    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final handPoints = (v['handPoints'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final tricksWon = (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal = ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final callableAces =
        (v['callableAces'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'contract') {
      statusText = isMyTurn ? '轮到你叫牌：可呼唤A搭档、宣告独庄或不叫' : '等待 ${g.name(turn)} 叫牌…';
    } else {
      statusText = isMyTurn ? '轮到你出牌（点击高亮手牌打出）' : '等待 ${g.name(turn)} 出牌…';
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
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(cs, '第 $round/$totalRounds 局 · 第 ${trickNumber.clamp(1, 8)}/8 墩'),
                    if (contractName != null)
                      _chip(
                        cs,
                        '定约：$contractName${calledAce != null ? " ($calledAce)" : ""}',
                        highlight: true,
                      ),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),

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
                        sub: '${phase == 'play' && s == declarer ? "[庄] " : ""}'
                            '${phase == 'play' && partner == s ? "[搭] " : ""}'
                            '总${scores[s]} · ${handPoints[s]}分/${tricksWon[s]}墩'
                            '${s == forehand ? " [先]" : ""}',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),

                // Center table area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (phase == 'contract')
                            _buildContractSelector(cs, isMyTurn, callableAces, compact)
                          else
                            _buildTrickTable(
                              cs,
                              trick,
                              lastTrick,
                              contract,
                              calledAce,
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
                  SizedBox(height: compact ? 4 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.7),
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
                child: ResultBanner(_buildResultText(scores)),
              ),
          ],
        ),
      );
    });
  }

  Widget _chip(ColorScheme cs, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: highlight ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildContractSelector(
    ColorScheme cs,
    bool isMyTurn,
    List<String> callableAces,
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
            isMyTurn ? '请选择叫牌定约 (Rufspiel 2v2 / 独庄 1v3 / 不叫)' : '巴伐利亚羊头牌叫牌阶段',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '永久顶主：QC > QS > QH > QD > JC > JS > JH > JD（Wenz仅4张J为主）',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.75)),
          ),
          SizedBox(height: compact ? 6 : 10),
          if (callableAces.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final ace in callableAces)
                  FilledButton.icon(
                    onPressed: isMyTurn
                        ? () => g.act({'type': 'ruf', 'ace': ace})
                        : null,
                    icon: const Icon(Icons.people, size: 16),
                    label: Text(_aceLabels[ace] ?? '呼唤 $ace'),
                  ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final (code, title, color) in _soloContracts)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isMyTurn ? () => g.act({'type': code}) : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isMyTurn ? 0.9 : 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white30),
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
    String? contract,
    String? calledAce,
    double cardW,
    bool compact,
  ) {
    final trumpRule = contract == 'wenz'
        ? 'Wenz 主牌：仅 JC > JS > JH > JD（四门副牌 A > 10 > K > Q > 9 > 8 > 7）'
        : '主牌顺序：QC > QS > QH > QD > JC > JS > JH > JD > 主花色 A > 10 > K > 9 > 8 > 7';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            trumpRule,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: cs.onSurface),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
          padding: EdgeInsets.all(compact ? 8 : 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: trick.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(compact ? 8 : 16),
                  child: const Text(
                    '等待本墩首张领出牌…（庄家方需 ≥61 分获胜，≥91 分施耐德）',
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
              '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 赢得 +${lastTrick['points']} 分',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(List<int> scores) {
    final parts = [for (var i = 0; i < scores.length; i++) '${g.name(i)}: ${scores[i]}分'];
    return '比赛结束！${parts.join(" · ")}';
  }
}
