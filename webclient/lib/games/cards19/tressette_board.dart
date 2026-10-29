import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class TressetteBoard extends StatelessWidget {
  final GameContext g;
  const TressetteBoard(this.g, {super.key});

  /// Maps Italian suit (`D, C, S, B`) to `PlayingCard` suit (`D, H, S, C`).
  static String _toStandardCardCode(String code) {
    if (code.length < 2) return code;
    final rank = code.substring(0, code.length - 1);
    final suit = code[code.length - 1];
    final stdSuit = switch (suit) {
      'D' => 'D', // Denari (金币 ♦)
      'C' => 'H', // Coppe (圣杯 ♥)
      'S' => 'S', // Spade (宝剑 ♠)
      'B' => 'C', // Bastoni (权杖 ♣)
      _ => suit,
    };
    return '$rank$stdSuit';
  }

  static String _cardValueBadge(String code) {
    if (code.length < 2) return '';
    final r = code.substring(0, code.length - 1);
    if (r == 'A') return '+1分';
    if (r == '3' || r == '2' || r == 'K' || r == 'Q' || r == 'J') return '+⅓';
    return '';
  }

  static String _formatThirds(int thirds) {
    final full = thirds ~/ 3;
    final rem = thirds % 3;
    if (rem == 0) return '$full分';
    if (rem == 1) return '$full⅓分';
    return '$full⅔分';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final leader = (v['leader'] as num?)?.toInt() ?? 0;
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final sideScores =
        (v['sideScores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players == 4 ? 2 : g.players, 0);
    final handCardThirds = (v['handCardThirds'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players == 4 ? 2 : g.players, 0);
    final handMeldPoints = (v['handMeldPoints'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players == 4 ? 2 : g.players, 0);

    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal =
        ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final availableAccuse =
        (v['availableAccuse'] as List?)?.cast<Map>() ?? const <Map>[];
    final accuseLog = (v['accuseLog'] as List?)?.cast<Map>() ?? const <Map>[];
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (isMyTurn) {
      statusText = availableAccuse.isNotEmpty
          ? '轮到你（第1墩）：可先宣告 Napoli / Bongioco 组合得分，再点击手牌出牌'
          : '轮到你出牌（无主牌 · 阶序 3 > 2 > A > K > Q > J > 7..4 · 有花必跟）';
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 40.0 : 52.0;

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
                    _chip(cs, '第 $round/$totalRounds 局 · 第 $trickNumber 墩'),
                    _chip(
                      cs,
                      '无主牌 · 阶序: 3 > 2 > A > K > Q > J > 7..4',
                      highlight: true,
                    ),
                    _chip(
                      cs,
                      stockCount > 0 ? '牌库剩余 $stockCount 张' : '有花必跟 · 末墩+1分',
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
                      Builder(builder: (_) {
                        final side = g.players == 4 ? (s % 2) : s;
                        final thirds = side < handCardThirds.length ? handCardThirds[side] : 0;
                        final mPts = side < handMeldPoints.length ? handMeldPoints[side] : 0;
                        return g.tag(
                          s,
                          active: !g.over && s == turn,
                          size: compact ? 28 : 34,
                          sub: '${g.players == 4 ? "[${side == 0 ? "0&2队" : "1&3队"}] " : ""}'
                              '总${scores[s]} · 墩${_formatThirds(thirds)}'
                              '${mPts > 0 ? "+宣告$mPts分" : ""}'
                              '${s == leader ? " [先]" : ""}',
                        );
                      }),
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
                          _buildRulesAndAccuseBar(cs, accuseLog, compact),
                          if (isMyTurn && availableAccuse.isNotEmpty) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildAccuseButtons(cs, availableAccuse),
                          ],
                          SizedBox(height: compact ? 6 : 8),
                          _buildTrickArea(cs, trick, lastTrick, cardW, compact),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom hand
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              PlayingCard(
                                _toStandardCardCode(c),
                                width: cardW,
                                selected: isMyTurn && legal.contains(c),
                                dim: isMyTurn && !legal.contains(c),
                                onTap: (isMyTurn && legal.contains(c))
                                    ? () => g.act({'type': 'play', 'card': c})
                                    : null,
                              ),
                              if (_cardValueBadge(c).isNotEmpty)
                                Positioned(
                                  right: -2,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.startsWith('A')
                                          ? Colors.amber.shade800
                                          : cs.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _cardValueBadge(c),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
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
                child: ResultBanner(_buildResultText(scores, sideScores)),
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

  Widget _buildRulesAndAccuseBar(
    ColorScheme cs,
    List<Map> accuseLog,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '计分: A = 1分 (3/3) · 3,2,K,Q,J = ⅓分 (1/3) · 末墩(Ultima) = +1分 · 首墩可宣告 Napoli/Bongioco',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          if (accuseLog.isNotEmpty) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final entry in accuseLog)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Text(
                      '${g.name((entry['seat'] as num).toInt())}: ${entry['label']}',
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
        ],
      ),
    );
  }

  Widget _buildAccuseButtons(ColorScheme cs, List<Map> availableAccuse) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final m in availableAccuse)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => g.act({'type': 'accusa', 'id': m['id']}),
            icon: const Icon(Icons.campaign, size: 16),
            label: Text('宣告 ${m['label']}'),
          ),
      ],
    );
  }

  Widget _buildTrickArea(
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
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 520),
          padding: EdgeInsets.all(compact ? 8 : 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: trick.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(compact ? 8 : 12),
                  child: const Text(
                    '等待本墩领出…（特雷塞特无主牌：领出花色中 3 > 2 > A 最大者赢墩！）',
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
                          PlayingCard(
                            _toStandardCardCode('${entry['card']}'),
                            width: cardW,
                          ),
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
              '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 赢得 '
              '${_formatThirds((lastTrick['thirds'] as num?)?.toInt() ?? 0)}'
              '${lastTrick['ultima'] == true ? " (含末墩 Ultima +1整分!)" : ""}',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(List<int> scores, List<int> sideScores) {
    if (g.players == 4 && sideScores.length >= 2) {
      return '比赛结束！0&2队: ${sideScores[0]}分 vs 1&3队: ${sideScores[1]}分';
    }
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++) '${g.name(s)}: ${scores[s]}分'
    ].join(' · ')}';
  }
}
