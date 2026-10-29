import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class LinkoBoard extends StatefulWidget {
  final GameContext g;
  const LinkoBoard(this.g, {super.key});

  @override
  State<LinkoBoard> createState() => _LinkoBoardState();
}

class _LinkoBoardState extends State<LinkoBoard> {
  int? _selectedRank;

  static Color _colorForRank(int r) {
    return switch (r) {
      14 => const Color(0xFFD81B60), // Joker 'X'
      13 => const Color(0xFFE53935),
      12 => const Color(0xFFFB8C00),
      11 => const Color(0xFFFDD835),
      10 => const Color(0xFF43A047),
      9 => const Color(0xFF00897B),
      8 => const Color(0xFF00ACC1),
      7 => const Color(0xFF1E88E5),
      6 => const Color(0xFF3949AB),
      5 => const Color(0xFF5E35B1),
      4 => const Color(0xFF8E24AA),
      3 => const Color(0xFF6D4C41),
      2 => const Color(0xFF546E7A),
      _ => const Color(0xFF78909C),
    };
  }

  static String _labelForRank(int r) => r == 14 ? 'X' : '$r';

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final cs = Theme.of(context).colorScheme;
    final v = g.view;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final phase = '${v['phase'] ?? 'play'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final pool =
        (v['pool'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const <int>[];

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final handCounts =
        (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final tableauCounts = (v['tableauCounts'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players, 0);

    final rawTab = (v['tableau'] as List?) ?? const [];
    final tableau = <List<Map>>[
      for (var s = 0; s < g.players; s++)
        s < rawTab.length && rawTab[s] is List
            ? (rawTab[s] as List).cast<Map>()
            : const <Map>[],
    ];

    final hand =
        (v['hand'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const <int>[];
    final legalPlays =
        (v['legalPlays'] as List?)?.cast<Map>() ?? const <Map>[];
    final pendingSnatches =
        (v['pendingSnatches'] as List?)?.cast<Map>() ?? const <Map>[];
    final actionLog =
        (v['actionLog'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'snatch') {
      statusText = isMyTurn
          ? '⚡ 触发林科抢牌！请选择将抢下的对手牌组「收入手牌」还是「退回对方」'
          : '等待 ${g.name(turn)} 处理抢夺的牌组…';
    } else {
      statusText = isMyTurn
          ? '轮到你出牌：打出同点数牌组到面前，抢夺所有「张数相同且点数更小」的对手牌组！'
          : '等待 ${g.name(turn)} 出牌…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 36.0 : 46.0;

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
                    _chip(cs, '第 $round/$totalRounds 局 · 牌库 $deckCount 张'),
                    _chip(
                      cs,
                      '抢牌铁律：同张数 + 更高点数 = 抢走全部对应牌组！',
                      highlight: true,
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
                        sub: '总${scores[s]} · 桌面+${tableauCounts[s]} / 手牌-${handCounts[s]} '
                            '(净${tableauCounts[s] - handCounts[s]})',
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
                          _buildPoolAndLogBar(cs, pool, deckCount, actionLog, compact),
                          if (phase == 'snatch' && pendingSnatches.isNotEmpty) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildSnatchDecisionPanel(
                              cs,
                              pendingSnatches.first,
                              isMyTurn,
                              compact,
                            ),
                          ],
                          SizedBox(height: compact ? 6 : 8),
                          _buildTableausGrid(cs, tableau, compact),
                          if (isMyTurn && phase == 'play' && legalPlays.isNotEmpty) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildPlayControls(cs, legalPlays, tableau, compact),
                          ],
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '我的手牌（共 ${hand.length} 张 · 局末剩余每张 -1 分 · X=14 为百搭牌）：',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        OverlapRow(
                          itemWidth: cardW,
                          maxSpacing: 1.06,
                          children: [
                            for (final r in hand)
                              _buildLinkoCard(
                                r,
                                width: cardW,
                                selected: _selectedRank == r,
                                onTap: (isMyTurn && phase == 'play')
                                    ? () => setState(() {
                                          _selectedRank =
                                              _selectedRank == r ? null : r;
                                        })
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

  Widget _buildLinkoCard(
    int rank, {
    required double width,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final h = width * 1.38;
    final col = _colorForRank(rank);
    final label = _labelForRank(rank);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.25 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(width * 0.15),
        border: Border.all(
          color: selected ? Colors.amber : col,
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.12),
          color: col.withValues(alpha: 0.14),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: width * 0.48,
                    fontWeight: FontWeight.w900,
                    color: col,
                    height: 1.0,
                  ),
                ),
                if (rank == 14)
                  Text(
                    '百搭',
                    style: TextStyle(
                      fontSize: width * 0.2,
                      fontWeight: FontWeight.bold,
                      color: col,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }

  Widget _buildPoolAndLogBar(
    ColorScheme cs,
    List<int> pool,
    int deckCount,
    List<String> actionLog,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
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
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '公共市场明牌池 (${pool.length}张 · 牌库$deckCount张):',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              for (final r in pool)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _colorForRank(r).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _colorForRank(r)),
                  ),
                  child: Text(
                    _labelForRank(r),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: _colorForRank(r),
                    ),
                  ),
                ),
            ],
          ),
          if (actionLog.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              actionLog.first,
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurface.withValues(alpha: 0.78),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSnatchDecisionPanel(
    ColorScheme cs,
    Map snatch,
    bool isMyTurn,
    bool compact,
  ) {
    final g = widget.g;
    final victim = (snatch['victim'] as num?)?.toInt() ?? 0;
    final rank = (snatch['rank'] as num?)?.toInt() ?? 1;
    final count = (snatch['count'] as num?)?.toInt() ?? 1;

    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepOrange.shade700, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '⚡ 林科抢牌！成功抢下 ${g.name(victim)} 的 $count 张 [${_labelForRank(rank)}]',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange.shade900,
            ),
          ),
          const SizedBox(height: 6),
          if (isMyTurn)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepOrange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      g.act({'type': 'snatch_choice', 'choice': 'take'}),
                  icon: const Icon(Icons.download, size: 16),
                  label: Text('收入自己手牌 (${g.name(victim)} 补摸 $count 张)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => g.act({
                    'type': 'snatch_choice',
                    'choice': 'return',
                    'discard': false,
                  }),
                  icon: const Icon(Icons.reply, size: 16),
                  label: Text('退回 ${g.name(victim)} 手牌 (增加其扣分)'),
                ),
                OutlinedButton(
                  onPressed: () => g.act({
                    'type': 'snatch_choice',
                    'choice': 'return',
                    'discard': true,
                  }),
                  child: Text('迫使 ${g.name(victim)} 弃掉并重摸'),
                ),
              ],
            )
          else
            Text(
              '等待抢牌方决定处理方式…',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
            ),
        ],
      ),
    );
  }

  Widget _buildTableausGrid(
    ColorScheme cs,
    List<List<Map>> tableau,
    bool compact,
  ) {
    final g = widget.g;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final s in g.seatsFromMe())
          Container(
            constraints: const BoxConstraints(minWidth: 150, maxWidth: 300),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 5 : 7,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: s == g.seat ? Colors.amber.withValues(alpha: 0.7) : Colors.white24,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${g.name(s)} 的面前陈列 (${tableau[s].length}组):',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (tableau[s].isEmpty)
                  const Text(
                    '暂无陈列牌组',
                    style: TextStyle(color: Colors.white54, fontSize: 10.5),
                  )
                else
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (final set in tableau[s])
                        Builder(builder: (_) {
                          final r = (set['rank'] as num?)?.toInt() ?? 1;
                          final k = (set['count'] as num?)?.toInt() ?? 1;
                          final j = (set['jokers'] as num?)?.toInt() ?? 0;
                          final col = _colorForRank(r);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: col, width: 1.5),
                            ),
                            child: Text(
                              '$k×[${_labelForRank(r)}]${j > 0 && r < 14 ? "(+$j★)" : ""}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: col,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  int _snatchCountForPlay(int rank, int count, List<List<Map>> tableau) {
    final g = widget.g;
    var snatches = 0;
    for (var s = 0; s < g.players; s++) {
      if (s == g.seat) continue;
      for (final oppSet in tableau[s]) {
        final oppR = (oppSet['rank'] as num?)?.toInt() ?? 0;
        final oppK = (oppSet['count'] as num?)?.toInt() ?? 0;
        if (oppK == count && oppR < rank) snatches++;
      }
    }
    return snatches;
  }

  Widget _buildPlayControls(
    ColorScheme cs,
    List<Map> legalPlays,
    List<List<Map>> tableau,
    bool compact,
  ) {
    final g = widget.g;
    final filtered = _selectedRank != null
        ? legalPlays
            .where((p) => (p['rank'] as num?)?.toInt() == _selectedRank)
            .toList()
        : legalPlays;
    final displayPlays = (filtered.isNotEmpty ? filtered : legalPlays).take(8);

    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final p in displayPlays)
            Builder(builder: (_) {
              final r = (p['rank'] as num).toInt();
              final k = (p['count'] as num).toInt();
              final j = (p['jokers'] as num).toInt();
              final sn = _snatchCountForPlay(r, k, tableau);
              return ActionChip(
                backgroundColor: sn > 0
                    ? Colors.amber.withValues(alpha: 0.28)
                    : null,
                label: Text(
                  '出 $k×[${_labelForRank(r)}]'
                  '${j > 0 && r < 14 ? " (含${j}X)" : ""}'
                  '${sn > 0 ? " ⚡抢$sn组!" : ""}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: sn > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onPressed: () {
                  setState(() => _selectedRank = null);
                  g.act({
                    'type': 'play',
                    'rank': r,
                    'count': k,
                    'jokers': j,
                  });
                },
              );
            }),
        ],
      ),
    );
  }

  String _buildResultText(List<int> scores) {
    final g = widget.g;
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++) '${g.name(s)}: ${scores[s]}分'
    ].join(' · ')}';
  }
}
