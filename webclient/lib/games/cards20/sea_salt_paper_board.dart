import 'package:aurora_shared/games/cards20/sea_salt_paper.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class SeaSaltPaperBoard extends StatefulWidget {
  final GameContext g;
  const SeaSaltPaperBoard(this.g, {super.key});

  @override
  State<SeaSaltPaperBoard> createState() => _SeaSaltPaperBoardState();
}

class _SeaSaltPaperBoardState extends State<SeaSaltPaperBoard> {
  static Color _colorForCode(String color) {
    return switch (color) {
      'blue' => const Color(0xFF1565C0),
      'lightBlue' => const Color(0xFF00ACC1),
      'black' => const Color(0xFF37474F),
      'yellow' => const Color(0xFFF9A825),
      'green' => const Color(0xFF2E7D32),
      'white' => const Color(0xFF78909C),
      'purple' => const Color(0xFF7B1FA2),
      'orange' => const Color(0xFFEF6C00),
      _ => const Color(0xFF546E7A),
    };
  }

  static String _shortRule(String kind) {
    return switch (kind) {
      'crab' => '成对:弃牌检1',
      'boat' => '成对:额外回合',
      'fish' => '成对:牌库摸1',
      'shark' => '配泳者:偷1张',
      'swimmer' => '配鲨鱼:偷1张',
      'octopus' => '0/2/4/6/9分',
      'shell' => '0/2/4/6/8/10',
      'penguin' => '1/3/5分',
      'sailor' => '0/5分',
      'lighthouse' => '每⛵+1分',
      'shoal' => '每🐟+1分',
      'colony' => '每🐧+2分',
      'captain' => '每⚓+3分',
      'mermaid' => '最多色+1/集4胜',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final cs = Theme.of(context).colorScheme;
    final v = g.view;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 30;
    final phase = '${v['phase'] ?? 'draw'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;

    final rawDiscards = (v['discards'] as List?) ?? const [[], []];
    final discard0 = rawDiscards.isNotEmpty && rawDiscards[0] is List
        ? (rawDiscards[0] as List).map((e) => '$e').toList()
        : const <String>[];
    final discard1 = rawDiscards.length > 1 && rawDiscards[1] is List
        ? (rawDiscards[1] as List).map((e) => '$e').toList()
        : const <String>[];

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final handCounts =
        (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);

    final rawTab = (v['tableau'] as List?) ?? const [];
    final tableau = <List<List<String>>>[
      for (var s = 0; s < g.players; s++)
        s < rawTab.length && rawTab[s] is List
            ? [
                for (final pair in (rawTab[s] as List))
                  (pair as List).map((e) => '$e').toList(),
              ]
            : const <List<String>>[],
    ];

    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final drawnCards =
        (v['drawnCards'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final myBreakdown = (v['myBreakdown'] as Map?) ?? const {};
    final myRoundPts = (myBreakdown['total'] as num?)?.toInt() ?? 0;
    final myColorBonus = (myBreakdown['colorBonus'] as num?)?.toInt() ?? 0;
    final myMermaids = (myBreakdown['mermaids'] as num?)?.toInt() ?? 0;

    final availableDuos = <List<String>>[
      for (final d in ((v['availableDuos'] as List?) ?? const []))
        (d as List).map((e) => '$e').toList(),
    ];
    final canCallStop = v['canCallStop'] == true;
    final lastChanceCaller = (v['lastChanceCaller'] as num?)?.toInt();
    final actionLog =
        (v['actionLog'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'draw') {
      statusText = isMyTurn
          ? '轮到你摸牌：从牌库摸2留1，或直接拿取两个弃牌堆之一的顶牌'
          : '等待 ${g.name(turn)} 摸牌…';
    } else if (phase == 'choose_drawn') {
      statusText = isMyTurn
          ? '请选择保留哪张摸到的牌（另一张将放入弃牌堆）'
          : '等待 ${g.name(turn)} 从摸到的 2 张牌中选择保留…';
    } else if (phase == 'crab_pick') {
      statusText = isMyTurn
          ? '🦀 螃蟹成对效果：请从下方弃牌堆点击选择任意 1 张牌拿入手牌'
          : '等待 ${g.name(turn)} 使用螃蟹检索弃牌堆…';
    } else {
      statusText = isMyTurn
          ? '行动阶段：可打出成对行动卡${canCallStop ? "，当前满 7 分可宣告「到此为止」或「最后机会」！" : "，或结束回合"}'
          : '等待 ${g.name(turn)} 执行成对行动或结束回合…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 44.0 : 56.0;

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
                    _chip(cs, '第 $round 局 · 目标 $targetScore 分 · 牌库 $deckCount 张'),
                    _chip(
                      cs,
                      '本局卡牌分: $myRoundPts 分 (颜色奖励+$myColorBonus · 美人鱼$myMermaids/4)',
                      highlight: myRoundPts >= 7,
                    ),
                    if (lastChanceCaller != null)
                      _chip(
                        cs,
                        '🎲 ${g.name(lastChanceCaller)} 已喊「最后机会」！',
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
                        sub: '总${scores[s]}分 · 手牌${handCounts[s]} · 成对${tableau[s].length}组',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDeckAndDiscardsBar(
                            cs,
                            deckCount,
                            discard0,
                            discard1,
                            phase,
                            isMyTurn,
                            compact,
                          ),
                          if (phase == 'choose_drawn' &&
                              isMyTurn &&
                              drawnCards.isNotEmpty) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildChooseDrawnPanel(
                              cs,
                              drawnCards,
                              discard0,
                              discard1,
                              compact,
                            ),
                          ],
                          if (phase == 'crab_pick' && isMyTurn) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildCrabPickPanel(cs, discard0, discard1, compact),
                          ],
                          if (phase == 'action' && isMyTurn) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildActionControls(
                              cs,
                              availableDuos,
                              canCallStop,
                              myRoundPts,
                              myColorBonus,
                              compact,
                            ),
                          ],
                          SizedBox(height: compact ? 6 : 8),
                          _buildTableausPanel(cs, tableau, actionLog, compact),
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
                      color: cs.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '我的手牌 (${hand.length}张 · 本局当前 $myRoundPts 分)：',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        OverlapRow(
                          itemWidth: cardW,
                          maxSpacing: 1.05,
                          children: [
                            for (final c in hand) _buildSspCard(c, width: cardW),
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

  Widget _buildSspCard(
    String cardId, {
    required double width,
    VoidCallback? onTap,
  }) {
    final def = sspCard(cardId);
    final col = _colorForCode(def.color);
    final h = width * 1.42;
    final kindTitle = sspKindNames[def.kind] ?? def.kind;
    final colorTitle = sspColorNames[def.color] ?? def.color;
    final rule = _shortRule(def.kind);

    final widgetCard = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(color: col, width: 1.8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.11),
          color: col.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kindTitle,
                style: TextStyle(
                  fontSize: width * 0.25,
                  fontWeight: FontWeight.w900,
                  color: col,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: col,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  colorTitle,
                  style: TextStyle(
                    fontSize: width * 0.18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (rule.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  rule,
                  style: TextStyle(
                    fontSize: width * 0.17,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return widgetCard;
    return GestureDetector(onTap: onTap, child: widgetCard);
  }

  Widget _buildDeckAndDiscardsBar(
    ColorScheme cs,
    int deckCount,
    List<String> discard0,
    List<String> discard1,
    String phase,
    bool isMyTurn,
    bool compact,
  ) {
    final g = widget.g;
    final canDraw = isMyTurn && phase == 'draw';

    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: (canDraw && deckCount > 0)
                ? () => g.act({'type': 'draw_deck'})
                : null,
            icon: const Icon(Icons.layers, size: 16),
            label: Text('牌库摸2留1 ($deckCount张)'),
          ),
          _buildDiscardPileBox(
            cs,
            pileIndex: 0,
            cards: discard0,
            canTakeTop: canDraw && discard0.isNotEmpty,
          ),
          _buildDiscardPileBox(
            cs,
            pileIndex: 1,
            cards: discard1,
            canTakeTop: canDraw && discard1.isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscardPileBox(
    ColorScheme cs, {
    required int pileIndex,
    required List<String> cards,
    required bool canTakeTop,
  }) {
    final g = widget.g;
    final top = cards.isNotEmpty ? sspCard(cards.last) : null;
    final col = top != null ? _colorForCode(top.color) : Colors.grey;

    return OutlinedButton(
      onPressed: canTakeTop
          ? () => g.act({'type': 'take_discard', 'pile': pileIndex})
          : null,
      child: Text(
        top != null
            ? '弃牌堆${pileIndex + 1} (${cards.length}张): ${top.label}'
            : '弃牌堆${pileIndex + 1} (空)',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: top != null ? col : null,
        ),
      ),
    );
  }

  Widget _buildChooseDrawnPanel(
    ColorScheme cs,
    List<String> drawnCards,
    List<String> discard0,
    List<String> discard1,
    bool compact,
  ) {
    final g = widget.g;
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade800, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '摸到 2 张牌：请选择保留哪一张（另一张弃入弃牌堆）',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.brown.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < drawnCards.length; i++)
                FilledButton(
                  onPressed: () => g.act({
                    'type': 'keep_drawn',
                    'keepIndex': i,
                    'discardPile': discard0.isEmpty ? 0 : (discard1.isEmpty ? 1 : 0),
                  }),
                  child: Text('保留 ${sspCard(drawnCards[i]).label}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCrabPickPanel(
    ColorScheme cs,
    List<String> discard0,
    List<String> discard1,
    bool compact,
  ) {
    final g = widget.g;
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.cyan.shade50.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyan.shade700, width: 2),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final c in discard0)
            ActionChip(
              label: Text('堆1: ${sspCard(c).label}', style: const TextStyle(fontSize: 11)),
              onPressed: () =>
                  g.act({'type': 'crab_take', 'pile': 0, 'card': c}),
            ),
          for (final c in discard1)
            ActionChip(
              label: Text('堆2: ${sspCard(c).label}', style: const TextStyle(fontSize: 11)),
              onPressed: () =>
                  g.act({'type': 'crab_take', 'pile': 1, 'card': c}),
            ),
        ],
      ),
    );
  }

  Widget _buildActionControls(
    ColorScheme cs,
    List<List<String>> availableDuos,
    bool canCallStop,
    int myRoundPts,
    int myColorBonus,
    bool compact,
  ) {
    final g = widget.g;
    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final pair in availableDuos)
            FilledButton.tonalIcon(
              onPressed: () => g.act({
                'type': 'play_duo',
                'card1': pair[0],
                'card2': pair[1],
              }),
              icon: const Icon(Icons.auto_awesome, size: 15),
              label: Text(
                '打出成对: ${sspCard(pair[0]).label} + ${sspCard(pair[1]).label}',
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          if (canCallStop) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => g.act({'type': 'stop'}),
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: Text('🛑 到此为止 (全员得卡牌分 · 我+$myRoundPts分)'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => g.act({'type': 'last_chance'}),
              icon: const Icon(Icons.casino, size: 16),
              label: Text(
                '🎲 最后机会 (赢则+${myRoundPts + myColorBonus}分)',
              ),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => g.act({'type': 'end_turn'}),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('结束回合'),
          ),
        ],
      ),
    );
  }

  Widget _buildTableausPanel(
    ColorScheme cs,
    List<List<List<String>>> tableau,
    List<String> actionLog,
    bool compact,
  ) {
    final g = widget.g;
    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final s in g.seatsFromMe())
                Text(
                  '${g.name(s)}成对区: ${tableau[s].isEmpty ? "无" : tableau[s].map((p) => "${sspKindNames[sspCard(p[0]).kind]}").join("+")}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
            ],
          ),
          if (actionLog.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              actionLog.first,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              textAlign: TextAlign.center,
            ),
          ],
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
