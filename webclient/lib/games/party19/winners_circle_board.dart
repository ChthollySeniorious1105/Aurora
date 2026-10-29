import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class WinnersCircleBoard extends StatefulWidget {
  final GameContext g;
  const WinnersCircleBoard(this.g, {super.key});

  @override
  State<WinnersCircleBoard> createState() => _WinnersCircleBoardState();
}

class _WinnersCircleBoardState extends State<WinnersCircleBoard> {
  int _selectedChip = 2;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final race = (v['race'] as num?)?.toInt() ?? 1;
    final totalRaces = (v['totalRaces'] as num?)?.toInt() ?? 3;
    final cycle = (v['cycle'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final dieFace = (v['dieFace'] as num?)?.toInt() ?? 0;
    final dieSymbol = v['dieSymbol'] as String? ?? '🐎 马头';
    final phase = v['phase'] as String? ?? 'bet';
    final horseNames = (v['horseNames'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final speeds = (v['speeds'] as List?) ?? const [];
    final horsePos = (v['horsePos'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(7, 0);
    final movedInCycle = (v['movedInCycle'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(7, false);
    final finishOrder = (v['finishOrder'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final myChips = (v['myChips'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final bets = (v['bets'] as List?) ?? const [];
    final oddsPreview = (v['oddsPreview'] as List?) ?? const [];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    final activeChip = myChips.contains(_selectedChip)
        ? _selectedChip
        : (myChips.isNotEmpty ? myChips.last : 0);

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
                  Center(
                    child: StatusBar(
                      g.over
                          ? '皇家赛马会 — 全场完赛结算'
                          : '第 $race/$totalRaces 场 · ${phase == "bet" ? "💰赛前暗置押注" : "🏇第 $cycle 轮赛跑（骰面: $dieSymbol）"} · ${canAct ? "轮到你行动" : "等待 ${g.name(turn)}"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.9)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Bet Chip Selector or Race Die Banner
                  if (canAct && phase == 'bet' && myChips.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '🎯 第 1 步选择筹码面值（再点击下方名驹押注）:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          for (final cVal in myChips)
                            ChoiceChip(
                              label: Text(
                                cVal == 0 ? '0 注 (虚张稀释)' : '$cVal 注筹码',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: activeChip == cVal,
                              onSelected: (_) => setState(() => _selectedChip = cVal),
                            ),
                        ],
                      ),
                    ),
                  if (phase == 'race')
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '🎲 当前四象符号骰：【$dieSymbol】 · 每轮每匹赛马仅限移动 1 次！',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          if (finishOrder.isNotEmpty)
                            Text(
                              '🏁 已冲线: ${finishOrder.map((h) => h < horseNames.length ? horseNames[h] : "#$h").join(" → ")} (${finishOrder.length}/3)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                  // 7 Horses Track & Betting Table
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '🏟️ 18 格皇家草地赛道 & 动态赔率表（点击名驹押注或推进）',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        for (var h = 0; h < horseNames.length; h++)
                          _buildHorseRow(
                            cs: cs,
                            g: g,
                            h: h,
                            name: horseNames[h],
                            spd: h < speeds.length
                                ? (speeds[h] as List).map((e) => (e as num).toInt()).toList()
                                : const [3, 3, 3, 3],
                            pos: h < horsePos.length ? horsePos[h] : 0,
                            moved: h < movedInCycle.length ? movedInCycle[h] : false,
                            finishRank: finishOrder.indexOf(h),
                            horseBets: h < bets.length ? (bets[h] as List) : const [],
                            odds: h < oddsPreview.length
                                ? (oddsPreview[h] as List).map((e) => (e as num).toInt()).toList()
                                : const [10, 6, 4],
                            phase: phase,
                            dieFace: dieFace,
                            canAct: canAct,
                            activeChip: activeChip,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          sub: '💰${s < scores.length ? scores[s] : 0}分',
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
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '皇家赛马会结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildHorseRow({
    required ColorScheme cs,
    required GameContext g,
    required int h,
    required String name,
    required List<int> spd,
    required int pos,
    required bool moved,
    required int finishRank,
    required List horseBets,
    required List<int> odds,
    required String phase,
    required int dieFace,
    required bool canAct,
    required int activeChip,
  }) {
    final canBetHere = canAct && phase == 'bet';
    final canMoveHere = canAct && phase == 'race' && pos < 18 && !moved;
    final clampedPos = pos.clamp(0, 18);
    final curSpeed = dieFace >= 0 && dieFace < spd.length ? spd[dieFace] : 1;

    final betTags = <String>[];
    for (final b in horseBets) {
      if (b is Map) {
        final s = (b['seat'] as num?)?.toInt() ?? 0;
        final c = (b['chip'] as num?)?.toInt() ?? -1;
        betTags.add('P${s + 1}:${c >= 0 ? "$c注" : "❓"}');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: moved
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : cs.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (canBetHere || canMoveHere) ? cs.primary : cs.outline.withValues(alpha: 0.3),
          width: (canBetHere || canMoveHere) ? 1.6 : 1.0,
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$name [🐎${spd[0]} 🏇${spd[1]} 🧲${spd[2]} 🥕${spd[3]}]',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            finishRank >= 0
                ? '🏁第${finishRank + 1}名冲线!'
                : '位置: $clampedPos/18 ${moved ? "(本轮已跑)" : "(本轮未跑 · 当前+$curSpeed步)"}',
            style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
          ),
          Text(
            '赔率[冠×${odds[0]}/亚×${odds[1]}/季×${odds[2]}] · 押注(${horseBets.length}): ${betTags.isEmpty ? "无" : betTags.join(" ")}',
            style: const TextStyle(fontSize: 10),
          ),
          if (canBetHere)
            FilledButton.tonal(
              onPressed: () => g.act({'type': 'bet', 'horse': h, 'chip': activeChip}),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: Text('押 $activeChip 注', style: const TextStyle(fontSize: 11)),
            ),
          if (canMoveHere)
            FilledButton(
              onPressed: () => g.act({'type': 'move', 'horse': h}),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: Text('推进 +$curSpeed 步', style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
