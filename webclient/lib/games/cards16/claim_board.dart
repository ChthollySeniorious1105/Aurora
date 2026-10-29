import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class ClaimBoard extends StatelessWidget {
  final GameContext g;
  const ClaimBoard(this.g, {super.key});

  static const List<(String, String, String, Color)> _factions = [
    ('G', '👹', '哥布林', Color(0xFF2E7D32)),
    ('K', '⚔️', '骑士', Color(0xFF1565C0)),
    ('U', '💀', '亡灵', Color(0xFF6A1B9A)),
    ('D', '⛏️', '矮人', Color(0xFFD84315)),
    ('M', '🎭', '变形怪', Color(0xFF37474F)),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'phase1'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final leader = (v['leader'] as num?)?.toInt() ?? 0;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 1;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final prizeCard = v['prizeCard'] as String?;
    final followerDeckCount = (v['followerDeckCount'] as num?)?.toInt() ?? 0;

    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final rawPiles = v['scorePile'] as List?;
    final scorePile = <List<int>>[
      for (var s = 0; s < g.players; s++)
        (rawPiles != null && s < rawPiles.length && rawPiles[s] is List)
            ? (rawPiles[s] as List).map((e) => (e as num).toInt()).toList()
            : List<int>.filled(5, 0),
    ];
    final phase2Hand =
        (v['phase2Hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal = ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    final phaseTitle = phase == 'phase1' ? '第1阶段：招募随从' : '第2阶段：争夺王座';
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (isMyTurn) {
      statusText = phase == 'phase1'
          ? '轮到你出牌：赢墩夺取明牌随从，亡灵(💀)直接入得分堆'
          : '轮到你出牌：赢墩收牌入得分堆，矮人(⛏️)归输家';
    } else {
      statusText = '等待 ${g.name(turn)} 出牌…';
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
                    _chip(cs, '第 $round/$totalRounds 局 · 第 ${trickNumber.clamp(1, 13)}/13 墩'),
                    _chip(cs, phaseTitle, highlight: true),
                    if (phase == 'phase1' && phase2Hand.isNotEmpty)
                      _chip(cs, '已募第2阶段手牌：${phase2Hand.length} 张'),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Players row
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      g.tag(
                        s,
                        active: !g.over && s == turn,
                        size: compact ? 28 : 34,
                        sub: '总胜票:${scores[s]} · 得分堆:'
                            '👹${scorePile[s][0]} ⚔️${scorePile[s][1]} 💀${scorePile[s][2]} ⛏️${scorePile[s][3]} 🎭${scorePile[s][4]}'
                            '${s == leader ? " [领]" : ""}',
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
                          _buildFactionScoreboard(cs, scorePile, compact),
                          SizedBox(height: compact ? 4 : 8),
                          _buildCenterTable(
                            cs,
                            phase,
                            prizeCard,
                            followerDeckCount,
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
                          _ClaimCard(
                            c,
                            width: cardW,
                            selected: isMyTurn && legal.contains(c),
                            dim: isMyTurn && !legal.contains(c),
                            onTap: (isMyTurn && legal.contains(c))
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

  Widget _buildFactionScoreboard(
    ColorScheme cs,
    List<List<int>> scorePile,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '五大阵营异能：👹哥布林(被跟牌⚔️骑士通杀) · 💀亡灵(阶段1入分堆) · ⛏️矮人(阶段2归输家) · 🎭变形怪(百搭跟牌)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (var f = 0; f < 5; f++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _factions[f].$4.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _factions[f].$4.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${_factions[f].$2}${_factions[f].$3}: '
                    '${g.name(0)} ${scorePile[0][f]} vs ${g.name(1)} ${scorePile[1][f]}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterTable(
    ColorScheme cs,
    String phase,
    String? prizeCard,
    int followerDeckCount,
    List<Map> trick,
    Map? lastTrick,
    double cardW,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (phase == 'phase1' && prizeCard != null)
              Container(
                padding: EdgeInsets.all(compact ? 6 : 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '本墩奖励随从',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _ClaimCard(prizeCard, width: cardW),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '随从盲抽堆',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: cardW * 0.85,
                          height: cardW * 1.18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF283593),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: Center(
                            child: Text(
                              '$followerDeckCount张',
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
                  ],
                ),
              ),

            // Current trick box
            Container(
              constraints: const BoxConstraints(minWidth: 190, maxWidth: 360),
              padding: EdgeInsets.all(compact ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: trick.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(compact ? 8 : 14),
                      child: Text(
                        phase == 'phase1'
                            ? '等待先手领出卡牌（赢家获明牌随从，输家盲抽1张）…'
                            : '等待先手领出卡牌（赢取 ≥3 个阵营多数选票即可登基）…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                              _ClaimCard('${entry['card']}', width: cardW),
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
          ],
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
              '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 赢墩'
              '${lastTrick['prizeCard'] != null ? " (招募 ${lastTrick['prizeCard']})" : ""}'
              '${(lastTrick['undeadScored'] as num? ?? 0) > 0 ? " · 亡灵+${lastTrick['undeadScored']}入分堆" : ""}'
              '${(lastTrick['dwarvesToLoser'] as num? ?? 0) > 0 ? " · 矮人+${lastTrick['dwarvesToLoser']}归输家" : ""}',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(List<int> scores) {
    final parts = [for (var i = 0; i < scores.length; i++) '${g.name(i)}: ${scores[i]}票'];
    return '王位争夺结束！${parts.join(" vs ")}';
  }
}

class _ClaimCard extends StatelessWidget {
  final String code;
  final double width;
  final bool selected;
  final bool dim;
  final VoidCallback? onTap;

  const _ClaimCard(
    this.code, {
    required this.width,
    this.selected = false,
    this.dim = false,
    this.onTap,
  });

  static const Map<String, (String, String, String, Color)> _theme = {
    'G': ('👹', '哥布林', '惧骑士', Color(0xFF2E7D32)),
    'K': ('⚔️', '骑士', '斩哥布林', Color(0xFF1565C0)),
    'U': ('💀', '亡灵', '阶段1得分', Color(0xFF6A1B9A)),
    'D': ('⛏️', '矮人', '阶段2归输', Color(0xFFD84315)),
    'M': ('🎭', '变形怪', '百搭跟花', Color(0xFF37474F)),
  };

  @override
  Widget build(BuildContext context) {
    final h = width * 1.42;
    final base = code.split('_').first;
    final prefix = base.isNotEmpty ? base[0].toUpperCase() : 'G';
    final rankStr = base.length >= 2 ? base.substring(1) : '0';
    final (emoji, label, powerTag, color) =
        _theme[prefix] ?? ('👹', '哥布林', '惧骑士', const Color(0xFF2E7D32));

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.28 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: selected ? Colors.amber : color.withValues(alpha: 0.7),
          width: selected ? 2.2 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$rankStr $emoji',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  powerTag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (dim) card = Opacity(opacity: 0.48, child: card);
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
