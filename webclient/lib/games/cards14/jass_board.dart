import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class JassBoard extends StatelessWidget {
  final GameContext g;
  const JassBoard(this.g, {super.key});

  static const List<(String, String, String, Color)> _contracts = [
    ('S', '♠ 黑桃主牌', 'J(20) > 9(14) > A(11)', Color(0xFF263238)),
    ('H', '♥ 红心主牌', 'J(20) > 9(14) > A(11)', Color(0xFFC62828)),
    ('D', '♦ 方块主牌', 'J(20) > 9(14) > A(11)', Color(0xFFD84315)),
    ('C', '♣ 梅花主牌', 'J(20) > 9(14) > A(11)', Color(0xFF1B5E20)),
    ('O', 'Obenabe 大牌胜', '无主 A最大 · 8=8分', Color(0xFF1565C0)),
    ('U', 'Undenufe 小牌胜', '无主 6最大(11分) · 8=8分', Color(0xFF6A1B9A)),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'choose_contract'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final forehand = (v['forehand'] as num?)?.toInt() ?? 0;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final contract = v['contract'] as String?;
    final contractName = v['contractName'] as String?;
    final schiebenUsed = v['schiebenUsed'] == true;
    final isTeamMode = v['isTeamMode'] == true;

    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final handPoints = (v['handPoints'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final tricksWon = (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal = ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'choose_contract') {
      statusText = isMyTurn
          ? (schiebenUsed ? '队友传牌给你：请选择本局定约模式' : '轮到你选择定约模式，或传牌权(Schieben)')
          : '等待 ${g.name(turn)} 选择定约模式…';
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
                // Header status & round info
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(cs, '第 $round/$totalRounds 局 · 第 ${trickNumber.clamp(1, 9)}/9 墩'),
                    if (contractName != null)
                      _chip(cs, '定约：$contractName', highlight: true)
                    else if (schiebenUsed)
                      _chip(cs, '已传牌权 (Schieben)', highlight: true),
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
                        sub: '${isTeamMode ? (s % 2 == 0 ? "A队 " : "B队 ") : ""}'
                            '总${scores[s]} · 本局${handPoints[s]}分/${tricksWon[s]}墩'
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
                          if (phase == 'choose_contract')
                            _buildContractSelector(cs, isMyTurn, schiebenUsed, compact)
                          else
                            _buildTrickTable(cs, trick, lastTrick, contract, cardW, compact),
                        ],
                      ),
                    ),
                  ),
                ),

                // My hand at bottom
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OverlapRow(
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
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(_buildResultText(scores, isTeamMode)),
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
    bool schiebenUsed,
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
            isMyTurn ? '请选择本局定约模式 (6 选 1)' : '定约模式一览',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (code, title, subtitle, color) in _contracts)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: isMyTurn
                      ? () => g.act({'type': 'choose_contract', 'contract': code})
                      : null,
                  child: Container(
                    width: compact ? 145 : 175,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 10,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isMyTurn ? 0.9 : 0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (isMyTurn && !schiebenUsed) ...[
            SizedBox(height: compact ? 6 : 10),
            FilledButton.tonalIcon(
              onPressed: () => g.act({'type': 'schieben'}),
              icon: const Icon(Icons.forward_to_inbox, size: 16),
              label: const Text('Schieben（传牌权给队友/下家）'),
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
    double cardW,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
                    '等待本墩首张领出牌…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
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
              '${lastTrick['isFinal'] == true ? " (含末墩+5分)" : ""}',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(List<int> scores, bool isTeamMode) {
    if (isTeamMode && scores.length >= 4) {
      return '比赛结束！A队(${g.name(0)}/${g.name(2)})：${scores[0]}分 vs B队(${g.name(1)}/${g.name(3)})：${scores[1]}分';
    }
    final parts = [for (var i = 0; i < scores.length; i++) '${g.name(i)}: ${scores[i]}分'];
    return '比赛结束！${parts.join(" · ")}';
  }
}
