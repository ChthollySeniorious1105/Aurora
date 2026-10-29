import 'package:aurora_shared/games/cards20/phase10.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class Phase10Board extends StatelessWidget {
  final GameContext g;
  const Phase10Board(this.g, {super.key});

  static Color _cardColor(String card) {
    if (card == 'W') return const Color(0xFF8E24AA);
    if (card == 'S') return const Color(0xFF37474F);
    return switch (phase10CardColor(card)) {
      'R' => const Color(0xFFD32F2F),
      'B' => const Color(0xFF1976D2),
      'G' => const Color(0xFF388E3C),
      'Y' => const Color(0xFFF57F17),
      _ => const Color(0xFF546E7A),
    };
  }

  static String _cardTitle(String card) {
    if (card == 'W') return 'W百搭';
    if (card == 'S') return 'S跳过';
    final col = phase10ColorNames[phase10CardColor(card)] ?? '';
    final num = phase10CardNumber(card) ?? 0;
    return '$col$num';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxPhase = (v['maxPhase'] as num?)?.toInt() ?? 5;
    final phase = '${v['phase'] ?? 'draw'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final discardTop = v['discardTop'] as String?;

    final phaseIndex =
        (v['phaseIndex'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 1);
    final phaseTitles =
        (v['phaseTitles'] as List?)?.map((e) => '$e').toList() ??
            List.filled(g.players, '阶段1');
    final phaseCompleted =
        (v['phaseCompleted'] as List?)?.map((e) => e == true).toList() ??
            List.filled(g.players, false);
    final penalties =
        (v['penalties'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final handCounts =
        (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 10);

    final hand =
        (v['hand'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final canCompletePhase = v['canCompletePhase'] == true;
    final tableMelds =
        (v['tableMelds'] as List?)?.cast<Map>() ?? const <Map>[];
    final actionLog =
        (v['actionLog'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    final isMyTurn = !g.over && g.seat == turn;
    final myPhaseDone =
        g.seat >= 0 && g.seat < g.players && phaseCompleted[g.seat];
    final myPhaseTitle =
        g.seat >= 0 && g.seat < g.players ? phaseTitles[g.seat] : '阶段1';

    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'draw') {
      statusText = isMyTurn
          ? '轮到你摸牌：从牌库摸 1 张牌，或拿取弃牌堆顶牌（跳过牌 S 不可拿）'
          : '等待 ${g.name(turn)} 摸牌…';
    } else {
      statusText = isMyTurn
          ? (canCompletePhase
              ? '🎉 手牌已凑齐【$myPhaseTitle】！点击「完成阶段铺牌」，随后弃 1 张牌结束回合'
              : (myPhaseDone
                  ? '你已完成本局阶段！可向桌面牌组贴牌 (Hit)，或点击 1 张手牌弃出'
                  : '请点击 1 张手牌将其弃入弃牌堆结束回合'))
          : '等待 ${g.name(turn)} 行动与弃牌…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 40.0 : 50.0;

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
                    _chip(
                      cs,
                      '第 $round 局 · 目标 $maxPhase 阶段 · 牌库 $deckCount 张',
                    ),
                    _chip(
                      cs,
                      '我的当前目标: $myPhaseTitle ${myPhaseDone ? "(本局已完成✓)" : ""}',
                      highlight: canCompletePhase || myPhaseDone,
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
                        sub: '阶段${phaseIndex[s]}/$maxPhase${phaseCompleted[s] ? "✓" : ""} · '
                            '罚分${penalties[s]} · 手牌${handCounts[s]}',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center area: draw/discard piles, phase meld button, table melds
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDrawAndMeldBar(
                            cs,
                            deckCount,
                            discardTop,
                            phase,
                            isMyTurn,
                            canCompletePhase,
                            myPhaseTitle,
                            compact,
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          _buildTableMeldsArea(
                            cs,
                            tableMelds,
                            hand,
                            isMyTurn && phase == 'action' && myPhaseDone,
                            actionLog,
                            compact,
                          ),
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
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isMyTurn && phase == 'action'
                              ? '我的手牌（点击卡牌弃牌 · W=百搭25分, S=跳过对手15分）：'
                              : '我的手牌（共 ${hand.length} 张）：',
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
                            for (final c in hand)
                              _buildPhase10Card(
                                c,
                                width: cardW,
                                onTap: (isMyTurn && phase == 'action')
                                    ? () => g.act({'type': 'discard', 'card': c})
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
                child: ResultBanner(_buildResultText(phaseIndex, penalties, maxPhase)),
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

  Widget _buildPhase10Card(
    String card, {
    required double width,
    VoidCallback? onTap,
  }) {
    final col = _cardColor(card);
    final h = width * 1.4;
    final label = card == 'W'
        ? 'W'
        : (card == 'S' ? 'S' : '${phase10CardNumber(card) ?? card}');
    final sub = card == 'W'
        ? '百搭'
        : (card == 'S'
            ? '跳过'
            : (phase10ColorNames[phase10CardColor(card)] ?? ''));

    final wCard = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(color: col, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.11),
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
                    fontSize: width * 0.45,
                    fontWeight: FontWeight.w900,
                    color: col,
                    height: 1.0,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: width * 0.22,
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

    if (onTap == null) return wCard;
    return GestureDetector(onTap: onTap, child: wCard);
  }

  Widget _buildDrawAndMeldBar(
    ColorScheme cs,
    int deckCount,
    String? discardTop,
    String phase,
    bool isMyTurn,
    bool canCompletePhase,
    String myPhaseTitle,
    bool compact,
  ) {
    final canDraw = isMyTurn && phase == 'draw';
    final canTakeDiscard =
        canDraw && discardTop != null && !phase10IsSkip(discardTop);

    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: canDraw ? () => g.act({'type': 'draw_deck'}) : null,
            icon: const Icon(Icons.layers, size: 16),
            label: Text('摸牌库 ($deckCount张)'),
          ),
          OutlinedButton.icon(
            onPressed:
                canTakeDiscard ? () => g.act({'type': 'take_discard'}) : null,
            icon: const Icon(Icons.download, size: 16),
            label: Text(
              discardTop != null
                  ? '弃牌堆顶: ${_cardTitle(discardTop)}${phase10IsSkip(discardTop) ? "(不可拿)" : ""}'
                  : '弃牌堆(空)',
            ),
          ),
          if (isMyTurn && phase == 'action' && canCompletePhase)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () => g.act({'type': 'complete_phase'}),
              icon: const Icon(Icons.verified, size: 16),
              label: Text('🎉 完成阶段铺牌 ($myPhaseTitle)'),
            ),
        ],
      ),
    );
  }

  Widget _buildTableMeldsArea(
    ColorScheme cs,
    List<Map> tableMelds,
    List<String> hand,
    bool canHit,
    List<String> actionLog,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '桌面已完成的阶段牌组 (${tableMelds.length}组 · 完成自身阶段后可贴牌 Hit)：',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (tableMelds.isEmpty)
            const Text(
              '本局暂无玩家完成阶段铺牌',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (var idx = 0; idx < tableMelds.length; idx++)
                  Builder(builder: (_) {
                    final m = tableMelds[idx];
                    final owner = (m['owner'] as num?)?.toInt() ?? 0;
                    final cards = (m['cards'] as List?)
                            ?.map((e) => '$e')
                            .toList() ??
                        const <String>[];
                    // Find first card in hand that can hit this meld
                    String? hittableCard;
                    if (canHit) {
                      for (final c in hand) {
                        if (phase10CanHitMeld(
                          Map<String, dynamic>.of(m.cast<String, dynamic>()),
                          c,
                        )) {
                          hittableCard = c;
                          break;
                        }
                      }
                    }

                    return ActionChip(
                      backgroundColor: hittableCard != null
                          ? Colors.amber.shade100
                          : Colors.white.withValues(alpha: 0.9),
                      label: Text(
                        '${g.name(owner)}: [${cards.map(_cardTitle).join(" ")}]'
                        '${hittableCard != null ? " (+贴${_cardTitle(hittableCard)})" : ""}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      onPressed: hittableCard != null
                          ? () => g.act({
                                'type': 'hit_meld',
                                'meldIndex': idx,
                                'card': hittableCard,
                              })
                          : null,
                    );
                  }),
              ],
            ),
          if (actionLog.isNotEmpty) ...[
            const SizedBox(height: 6),
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

  String _buildResultText(
    List<int> phaseIndex,
    List<int> penalties,
    int maxPhase,
  ) {
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++)
        '${g.name(s)}: 阶段${phaseIndex[s]}/$maxPhase (罚分${penalties[s]})'
    ].join(' · ')}';
  }
}
