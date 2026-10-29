import 'package:aurora_shared/games/cards20/fantasy_realms.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class FantasyRealmsBoard extends StatelessWidget {
  final GameContext g;
  const FantasyRealmsBoard(this.g, {super.key});

  static Color _suitColor(String suit) {
    return switch (suit) {
      'army' => const Color(0xFFB71C1C),
      'leader' => const Color(0xFF6A1B9A),
      'wizard' => const Color(0xFF283593),
      'weapon' => const Color(0xFF455A64),
      'artifact' => const Color(0xFFF57F17),
      'beast' => const Color(0xFF2E7D32),
      'land' => const Color(0xFF5D4037),
      'flood' => const Color(0xFF0277BD),
      'flame' => const Color(0xFFD84315),
      'weather' => const Color(0xFF00838F),
      'wild' => const Color(0xFFAD1457),
      _ => const Color(0xFF546E7A),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;

    final discardLimit = (v['discardLimit'] as num?)?.toInt() ?? 10;
    final phase = '${v['phase'] ?? 'draw'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final discardArea =
        (v['discardArea'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final hand =
        (v['hand'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final myTotalScore = (v['myTotalScore'] as num?)?.toInt() ?? 0;
    final rawCardScores = (v['cardScores'] as Map?) ?? const {};
    final cardScores = <String, int>{
      for (final e in rawCardScores.entries) '${e.key}': (e.value as num).toInt(),
    };
    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final handCounts =
        (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 7);
    final actionLog =
        (v['actionLog'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'draw') {
      statusText = isMyTurn
          ? '轮到你摸牌：从牌库摸 1 张暗牌，或点击公共弃牌区的任意明牌拿入手中'
          : '等待 ${g.name(turn)} 摸牌…';
    } else {
      statusText = isMyTurn
          ? '请从 8 张手牌中点击弃掉 1 张放入公共弃牌区（保留 7 张最佳组合）'
          : '等待 ${g.name(turn)} 弃牌…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 52.0 : 68.0;

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
                      '公共弃牌区: ${discardArea.length}/$discardLimit 张 · 牌库 $deckCount 张',
                    ),
                    _chip(
                      cs,
                      '我的手牌实时总战力: $myTotalScore 分',
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
                        sub: g.over || s == g.seat
                            ? '手牌${handCounts[s]}张 · ${scores[s]}分'
                            : '手牌${handCounts[s]}张',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center public discard area & draw button
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 700),
                            padding: EdgeInsets.all(compact ? 8 : 12),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    FilledButton.icon(
                                      onPressed:
                                          (isMyTurn && phase == 'draw' && deckCount > 0)
                                              ? () => g.act({'type': 'draw_deck'})
                                              : null,
                                      icon: const Icon(Icons.style, size: 16),
                                      label: Text('从牌库摸 1 张暗牌 ($deckCount)'),
                                    ),
                                    Text(
                                      '公共弃牌区 (${discardArea.length}/$discardLimit 满额即终局)：',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (discardArea.isEmpty)
                                  Text(
                                    '公共弃牌区暂无卡牌',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurface.withValues(alpha: 0.6),
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      for (final c in discardArea)
                                        _buildFrChipCard(
                                          c,
                                          canTap: isMyTurn && phase == 'draw',
                                          onTap: () => g.act({
                                            'type': 'take_discard',
                                            'card': c,
                                          }),
                                        ),
                                    ],
                                  ),
                                if (actionLog.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    actionLog.first,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: cs.onSurface.withValues(alpha: 0.75),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
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
                          isMyTurn && phase == 'discard'
                              ? '点击下方 1 张手牌将其弃入公共弃牌区（当前 ${hand.length} 张 → 保留 7 张）：'
                              : '我的奇幻手牌（${hand.length}张 · 实时协同总分 $myTotalScore 分）：',
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
                              _buildFrCard(
                                c,
                                width: cardW,
                                effectiveScore: cardScores[c],
                                onTap: (isMyTurn && phase == 'discard')
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

  Widget _buildFrChipCard(
    String cardId, {
    required bool canTap,
    required VoidCallback onTap,
  }) {
    final def = frCard(cardId);
    final col = _suitColor(def.suit);
    return ActionChip(
      backgroundColor: col.withValues(alpha: 0.14),
      side: BorderSide(color: col),
      label: Text(
        '${def.suitLabel} ${def.name} (战力${def.base})',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: col,
        ),
      ),
      onPressed: canTap ? onTap : null,
    );
  }

  Widget _buildFrCard(
    String cardId, {
    required double width,
    int? effectiveScore,
    VoidCallback? onTap,
  }) {
    final def = frCard(cardId);
    final col = _suitColor(def.suit);
    final h = width * 1.44;
    final scoreVal = effectiveScore ?? def.base;

    final cardWidget = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: col, width: 1.8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.1),
          color: col.withValues(alpha: 0.1),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: width * 1.25,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  def.suitLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: col,
                  ),
                ),
                Text(
                  def.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: col,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '基础${def.base} → 计$scoreVal分',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  def.ruleText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 8.5, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return cardWidget;
    return GestureDetector(onTap: onTap, child: cardWidget);
  }

  String _buildResultText(List<int> scores) {
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++) '${g.name(s)}: ${scores[s]}分'
    ].join(' · ')}';
  }
}
