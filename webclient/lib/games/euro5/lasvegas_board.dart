import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class LasVegasBoard extends StatelessWidget {
  final GameContext g;
  const LasVegasBoard(this.g, {super.key});

  static const List<String> _casinoTitles = [
    '1号 · 金沙娱乐场',
    '2号 · 百乐宫赌场',
    '3号 · 凯撒皇宫',
    '4号 · 威尼斯人',
    '5号 · 永利皇宫',
    '6号 · 米高梅酒店',
  ];

  static const List<Color> _seatColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
  ];

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final round = asInt(v['round'], 1);
    final totalRounds = asInt(v['totalRounds'], 4);
    final useNeutral = asBool(v['useNeutral']);
    final turn = asInt(v['turn'], 0);
    final money = asIntList(v['money']);
    final remOwn = asIntList(v['remainingOwn']);
    final remNeu = asIntList(v['remainingNeutral']);
    final lastEvent = asStr(v['lastEvent']);

    final casinoBanknotes = (v['casinoBanknotes'] as List?) ?? const [];
    final casinoDice = (v['casinoDice'] as List?) ?? const [];
    final casinoNeutral = asIntList(v['casinoNeutral']);
    final rolledOwn = asIntList(v['rolledOwn']);
    final rolledNeutral = asIntList(v['rolledNeutral']);
    final faceCounts = (v['faceCounts'] as Map?)?.cast<String, dynamic>() ?? const {};

    final isMyTurn = !g.over && g.seat == turn;
    final statusText = g.over
        ? '全 $totalRounds 轮结束！'
        : '第 $round/$totalRounds 轮 · 轮到 ${g.name(turn)} 选择点数押注赌场';

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusBar(statusText, highlight: isMyTurn),
                      if (lastEvent.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            lastEvent,
                            style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Current turn dice tray
                  if (!g.over)
                    _buildDiceTray(
                      context,
                      turn: turn,
                      isMyTurn: isMyTurn,
                      rolledOwn: rolledOwn,
                      rolledNeutral: rolledNeutral,
                      faceCounts: faceCounts,
                    ),

                  const SizedBox(height: 10),

                  // 6 Casinos grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var c = 0; c < 6; c++)
                        _buildCasinoCard(
                          context,
                          cIdx: c,
                          banknotes: c < casinoBanknotes.length ? asIntList(casinoBanknotes[c]) : const [],
                          dicePerSeat: c < casinoDice.length ? asIntList(casinoDice[c]) : const [],
                          neutralDice: c < casinoNeutral.length ? casinoNeutral[c] : 0,
                          useNeutral: useNeutral,
                          canPlace: isMyTurn && faceCounts.containsKey('${c + 1}'),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Players bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: !g.over && s == turn,
                          size: 34,
                          sub: '💵 \$${s < money.length ? money[s] : 0}k · 🎲 ${s < remOwn.length ? remOwn[s] : 0}${useNeutral ? '+${s < remNeu.length ? remNeu[s] : 0}白' : ''}',
                          trailing: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _seatColors[s % _seatColors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(context, money),
            ),
        ],
      ),
    );
  }

  Widget _buildDiceTray(
    BuildContext context, {
    required int turn,
    required bool isMyTurn,
    required List<int> rolledOwn,
    required List<int> rolledNeutral,
    required Map<String, dynamic> faceCounts,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMyTurn ? cs.primary : cs.outline.withValues(alpha: 0.35), width: isMyTurn ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎲 ${g.name(turn)} 本次投掷结果${isMyTurn ? '（点击点数或下方对应赌场押注）' : ''}：',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final d in rolledOwn)
                DieFace(
                  d,
                  size: 32,
                  onTap: isMyTurn ? () => g.act({'type': 'place', 'face': d}) : null,
                ),
              for (final d in rolledNeutral)
                DieFace(
                  d,
                  size: 32,
                  held: true,
                  onTap: isMyTurn ? () => g.act({'type': 'place', 'face': d}) : null,
                ),
            ],
          ),
          if (isMyTurn && faceCounts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final entry in faceCounts.entries)
                  Builder(builder: (context) {
                    final f = int.tryParse(entry.key) ?? 1;
                    final m = (entry.value as Map).cast<String, dynamic>();
                    final own = asInt(m['own'], 0);
                    final neu = asInt(m['neutral'], 0);
                    final label = neu > 0 ? '押 $f 号 ($own己+$neu白)' : '押 $f 号 ($own颗)';
                    return FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () => g.act({'type': 'place', 'face': f}),
                      child: Text(label, style: const TextStyle(fontSize: 12)),
                    );
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCasinoCard(
    BuildContext context, {
    required int cIdx,
    required List<int> banknotes,
    required List<int> dicePerSeat,
    required int neutralDice,
    required bool useNeutral,
    required bool canPlace,
  }) {
    final cs = Theme.of(context).colorScheme;
    final face = cIdx + 1;

    // Compute tie status among non-zero counts
    final counts = <int, int>{};
    for (var s = 0; s < dicePerSeat.length; s++) {
      if (dicePerSeat[s] > 0) counts[s] = dicePerSeat[s];
    }
    if (useNeutral && neutralDice > 0) {
      counts[-1] = neutralDice;
    }
    final freq = <int, int>{};
    for (final cnt in counts.values) {
      freq[cnt] = (freq[cnt] ?? 0) + 1;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: canPlace ? () => g.act({'type': 'place', 'face': face}) : null,
      child: Container(
        width: 182,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canPlace ? Colors.amber : cs.outline.withValues(alpha: 0.35),
            width: canPlace ? 2.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                DieFace(face, size: 26),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _casinoTitles[cIdx],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Banknotes row
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final b in banknotes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '\$${b}k',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (counts.isEmpty)
              Text('暂无玩家押注', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
            else
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final entry in counts.entries)
                    Builder(builder: (context) {
                      final seat = entry.key;
                      final cnt = entry.value;
                      final isTied = (freq[cnt] ?? 0) >= 2;
                      final who = seat < 0 ? '中立庄家' : g.name(seat);
                      final dotColor = seat < 0 ? Colors.grey : _seatColors[seat % _seatColors.length];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTied
                              ? Colors.red.withValues(alpha: 0.18)
                              : cs.secondaryContainer.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isTied ? Colors.redAccent : dotColor, width: 1),
                        ),
                        child: Text(
                          '$who: $cnt骰${isTied ? '(平局抵消)' : ''}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            decoration: isTied ? TextDecoration.lineThrough : null,
                            color: isTied ? Colors.redAccent : cs.onSecondaryContainer,
                          ),
                        ),
                      );
                    }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBanner(BuildContext context, List<int> money) {
    final placings = asIntList(g.view['placings']);
    final lines = <String>[];
    for (var s = 0; s < g.players; s++) {
      final rank = s < placings.length ? placings[s] : 1;
      lines.add('第 $rank 名：${g.name(s)} — 累计奖金 \$${s < money.length ? money[s] : 0}k');
    }
    return ResultBanner(
      '拉斯维加斯 · 终局结算',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final l in lines) Text(l, style: const TextStyle(fontSize: 13))],
      ),
    );
  }
}
