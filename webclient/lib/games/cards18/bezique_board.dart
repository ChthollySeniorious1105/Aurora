import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class BeziqueBoard extends StatelessWidget {
  final GameContext g;
  const BeziqueBoard(this.g, {super.key});

  static String _baseCode(String code) {
    final i = code.indexOf('_');
    return i >= 0 ? code.substring(0, i) : code;
  }

  static bool _isBrisque(String code) {
    final b = _baseCode(code);
    return b.startsWith('A') || b.startsWith('T');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 1;
    final stage = (v['stage'] as num?)?.toInt() ?? 1;
    final phase = '${v['phase'] ?? 'play'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final leader = (v['leader'] as num?)?.toInt() ?? 0;
    final trumpCard = '${v['trumpCard'] ?? '7S_0'}';
    final trumpSuitName = '${v['trumpSuitName'] ?? '♠ 黑桃'}';
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final handMeldPoints = (v['handMeldPoints'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players, 0);
    final handBrisquePoints = (v['handBrisquePoints'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players, 0);
    final tricksWon =
        (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);

    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal =
        ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final availableMelds =
        (v['availableMelds'] as List?)?.cast<Map>() ?? const <Map>[];
    final meldLog = (v['meldLog'] as List?)?.cast<Map>() ?? const <Map>[];
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'meld') {
      statusText = isMyTurn
          ? '你赢下本墩！可宣告 1 项组合 (Meld) 立即拿分，或跳过直接摸牌'
          : '等待 ${g.name(turn)} 决定是否宣告组合…';
    } else {
      statusText = isMyTurn
          ? (stage == 1
              ? '轮到你出牌（第1阶段自由出牌，赢墩后可宣告组合！）'
              : '轮到你出牌（第2阶段最后8墩：必须有花跟花且能大必大、无花必出主牌！）')
          : '等待 ${g.name(turn)} 出牌…';
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
                      '主牌: $trumpSuitName',
                      highlight: true,
                    ),
                    _chip(
                      cs,
                      stage == 1
                          ? '第1阶段 (牌库 $stockCount 张 · 自由跟牌+赢墩亮组合)'
                          : '第2阶段 (最后8墩 · 严苛跟牌超毙)',
                      highlight: stage == 2,
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
                        sub: '总${scores[s]}分 (组合${handMeldPoints[s]}+A/10墩${handBrisquePoints[s]}) · ${tricksWon[s]}墩${s == leader ? " [先]" : ""}',
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
                          _buildTrumpAndMeldBar(
                            cs,
                            trumpCard,
                            trumpSuitName,
                            stockCount,
                            meldLog,
                            cardW,
                            compact,
                          ),
                          if (phase == 'meld' && isMyTurn) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildMeldPanel(cs, availableMelds, compact),
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
                      color: cs.surface.withValues(alpha: 0.76),
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
                                _baseCode(c),
                                width: cardW,
                                selected: phase == 'play' && isMyTurn && legal.contains(c),
                                dim: phase == 'play' && isMyTurn && !legal.contains(c),
                                onTap: (phase == 'play' && isMyTurn && legal.contains(c))
                                    ? () => g.act({'type': 'play', 'card': c})
                                    : null,
                              ),
                              if (_isBrisque(c))
                                Positioned(
                                  right: -2,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade800,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '+10',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
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

  Widget _buildTrumpAndMeldBar(
    ColorScheme cs,
    String trumpCard,
    String trumpSuitName,
    int stockCount,
    List<Map> meldLog,
    double cardW,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayingCard(_baseCode(trumpCard), width: cardW * 0.76),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '王牌指示牌: ${_baseCode(trumpCard)} ($trumpSuitName) · 牌库: $stockCount 张',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      '阶序: A > 10 > K > Q > J > 9 > 8 > 7 · 贝济克(♠Q+♦J)=40/500 · 主顺=250',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (meldLog.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in meldLog.reversed.take(4))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Text(
                      '${g.name((entry['seat'] as num).toInt())}: ${entry['title']}',
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

  Widget _buildMeldPanel(
    ColorScheme cs,
    List<Map> availableMelds,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '✨ 你赢下了本墩！可宣告以下手牌组合 (Meld) 立即得分：',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 12.5 : 14,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final m in availableMelds)
                FilledButton.icon(
                  onPressed: () => g.act({'type': 'meld', 'meld': m['id']}),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text('${m['title']}'),
                ),
              OutlinedButton.icon(
                onPressed: () => g.act({'type': 'skip_meld'}),
                icon: const Icon(Icons.skip_next, size: 16),
                label: const Text('跳过宣告 (直接摸牌)'),
              ),
            ],
          ),
        ],
      ),
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
                    '等待本墩出牌…（每张 A 与 10 赢入墩中计 +10 分，末墩 +10 分！）',
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
                            _baseCode('${entry['card']}'),
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
              '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 获胜'
              '${(lastTrick['points'] as num? ?? 0) > 0 ? " (+${lastTrick['points']} 分)" : ""}',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(List<int> scores) {
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++) '${g.name(s)}: ${scores[s]}分'
    ].join(' vs ')}';
  }
}
