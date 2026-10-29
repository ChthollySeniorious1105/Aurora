import 'package:flutter/material.dart';
import '../../widgets/common.dart';

class Flip7Board extends StatelessWidget {
  final GameContext g;
  const Flip7Board(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 200;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final discardCount = (v['discardCount'] as num?)?.toInt() ?? 0;

    final rawNumCards = (v['numberCards'] as List?) ?? const [];
    final numberCards = [
      for (final list in rawNumCards)
        [for (final x in (list as List)) (x as num).toInt()]
    ];
    final rawMods = (v['modifiers'] as List?) ?? const [];
    final modifiers = [
      for (final list in rawMods)
        [for (final x in (list as List)) '$x']
    ];
    final hasSecondChance = [
      for (final x in (v['hasSecondChance'] as List? ?? const [])) x == true
    ];
    final playerStatus = [
      for (final x in (v['playerStatus'] as List? ?? const [])) '$x'
    ];
    final currentRoundScores = [
      for (final x in (v['currentRoundScores'] as List? ?? const []))
        (x as num).toInt()
    ];
    final scores = [
      for (final x in (v['scores'] as List? ?? const [])) (x as num).toInt()
    ];
    final lastCardDrawn = (v['lastCardDrawn'] as String?) ?? '';
    final lastActionText = (v['lastActionText'] as String?) ?? '';
    final over = v['over'] == true || g.over;

    final myTurn = !over &&
        g.seat == turn &&
        (turn < playerStatus.length && playerStatus[turn] == 'active');

    final statusText = over
        ? '翻转七号对局结束'
        : myTurn
            ? '轮到你抉择：继续翻牌 (Hit) 还是 见好就收 (Stay)？'
            : '第 $round 轮 · 等待 ${g.name(turn)} 操作...';

    return Container(
      color: g.table,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBar(statusText, highlight: myTurn),
                _badge(cs, '🏆 目标: $targetScore分', cs.primary),
                _badge(cs, '🃏 牌堆: $deckCount 张 (弃牌 $discardCount)', cs.secondary),
                if (lastCardDrawn.isNotEmpty)
                  _badge(cs, '✨ 最新翻出: ${_formatCardName(lastCardDrawn)}', Colors.amber.shade800),
              ],
            ),
            if (lastActionText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                lastActionText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.85)),
              ),
            ],
            if (over) ...[
              const SizedBox(height: 8),
              Center(
                child: ResultBanner(
                  lastActionText.isNotEmpty ? lastActionText : '对局结束',
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Action bar when it's player's turn
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: myTurn ? cs.primary : cs.outline.withValues(alpha: 0.3),
                  width: myTurn ? 2 : 1,
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.local_fire_department, size: 18),
                    label: const Text('继续翻牌 (Hit)'),
                    onPressed: myTurn ? () => g.act({'type': 'hit'}) : null,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.savings, size: 18),
                    label: Text(
                      g.seat >= 0 && g.seat < currentRoundScores.length
                          ? '见好就收 (Stay +${currentRoundScores[g.seat]}分)'
                          : '见好就收 (Stay)',
                    ),
                    onPressed: myTurn ? () => g.act({'type': 'stay'}) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Players tableau list
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in g.seatsFromMe())
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
                    child: _buildPlayerTableau(
                      cs: cs,
                      seat: s,
                      isTurn: !over && turn == s,
                      nums: s < numberCards.length ? numberCards[s] : const [],
                      mods: s < modifiers.length ? modifiers[s] : const [],
                      secondChance: s < hasSecondChance.length && hasSecondChance[s],
                      status: s < playerStatus.length ? playerStatus[s] : 'active',
                      roundPts:
                          s < currentRoundScores.length ? currentRoundScores[s] : 0,
                      totalPts: s < scores.length ? scores[s] : 0,
                      targetScore: targetScore,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCardName(String c) {
    if (c == 'second_chance') return '🛡️免死金牌';
    if (c == 'freeze') return '❄️冰冻';
    if (c == 'flip3') return '⚡连翻三张';
    if (c == 'x2') return '×2 翻倍';
    return c;
  }

  Widget _badge(ColorScheme cs, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildPlayerTableau({
    required ColorScheme cs,
    required int seat,
    required bool isTurn,
    required List<int> nums,
    required List<String> mods,
    required bool secondChance,
    required String status,
    required int roundPts,
    required int totalPts,
    required int targetScore,
  }) {
    final isBusted = status == 'busted';
    final isStayed = status == 'stayed';
    final isFlip7 = status == 'flip7' || nums.length >= 7;

    final statusLabel = isFlip7
        ? '🎉 FLIP 7 (+15)'
        : isBusted
            ? '💥 爆牌 (0分)'
            : isStayed
                ? '🔒 已锁定 (+$roundPts分)'
                : '🔥 博弈中 (暂+$roundPts分)';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTurn
              ? cs.primary
              : isBusted
                  ? Colors.redAccent.withValues(alpha: 0.6)
                  : cs.outline.withValues(alpha: 0.3),
          width: isTurn ? 2.2 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: g.tag(
                  seat,
                  active: isTurn,
                  sub: '总分: $totalPts / $targetScore',
                  size: 30,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isBusted
                          ? Colors.red
                          : isStayed
                              ? Colors.teal
                              : Colors.amber)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '数字牌进度: ${nums.length} / 7 张',
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
              if (secondChance)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: const Text(
                    '🛡️ 免死金牌',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (nums.isEmpty)
                Text(
                  '暂无数字牌',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              for (final n in nums) _buildNumberCardChip(cs, n, isBusted),
              for (final m in mods) _buildModifierChip(cs, m),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberCardChip(ColorScheme cs, int n, bool isBusted) {
    return Container(
      width: 34,
      height: 44,
      decoration: BoxDecoration(
        color: isBusted
            ? Colors.red.shade900.withValues(alpha: 0.35)
            : cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$n',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: cs.onPrimaryContainer,
                ),
              ),
              Text(
                '×${n == 0 ? 1 : n}张',
                style: TextStyle(
                  fontSize: 8.5,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModifierChip(ColorScheme cs, String mod) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
      ),
      child: Center(
        child: Text(
          mod == 'x2' ? '×2' : mod,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ),
    );
  }
}
