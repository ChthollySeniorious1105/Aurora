import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class TrucoBoard extends StatelessWidget {
  final GameContext g;
  const TrucoBoard(this.g, {super.key});

  static String _stakeLabel(int stake) => switch (stake) {
        1 => '1分 (普通)',
        3 => '3分 (Truco!)',
        6 => '6分 (Seis!)',
        9 => '9分 (Nove!)',
        12 => '12分 (Doze!)',
        _ => '$stake分',
      };

  static int _nextStake(int s) => switch (s) {
        1 => 3,
        3 => 6,
        6 => 9,
        _ => 12,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'play'}';
    final handNumber = (v['handNumber'] as num?)?.toInt() ?? 1;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 12;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final leader = (v['leader'] as num?)?.toInt() ?? 0;
    final viraCard = '${v['viraCard'] ?? '4D'}';
    final manilhaRank = '${v['manilhaRank'] ?? '5'}';
    final handStake = (v['handStake'] as num?)?.toInt() ?? 1;
    final proposedStake = (v['proposedStake'] as num?)?.toInt() ?? 3;
    final trucoCallerSeat = (v['trucoCallerSeat'] as num?)?.toInt() ?? 0;
    final trucoResponderSeat = (v['trucoResponderSeat'] as num?)?.toInt() ?? 0;
    final canCallTruco = v['canCallTruco'] == true;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final sideScores =
        (v['sideScores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [0, 0];
    final trickWinners =
        (v['trickWinners'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const <int>[];
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final activeSeat = phase == 'respond_truco' ? trucoResponderSeat : turn;
    final isMyAction = !g.over && g.seat == activeSeat;

    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'respond_truco') {
      statusText = isMyAction
          ? '${g.name(trucoCallerSeat)} 喊出 ${_stakeLabel(proposedStake)}！请选择接受、反加注或弃牌'
          : '等待 ${g.name(trucoResponderSeat)} 回应 Truco 挑战…';
    } else {
      statusText = isMyAction
          ? '轮到你出牌${canCallTruco ? "（或喊出 Truco! 提升赌注）" : ""}'
          : '等待 ${g.name(turn)} 出牌…';
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
                    _chip(cs, '第 $handNumber 手 · 第 ${trickNumber.clamp(1, 3)}/3 墩 · 目标 $targetScore 分'),
                    _chip(
                      cs,
                      '王牌阶 Manilha: $manilhaRank (♣>♥>♠>♦)',
                      highlight: true,
                    ),
                    _chip(
                      cs,
                      '本手赌注: ${_stakeLabel(handStake)}',
                      highlight: handStake > 1,
                    ),
                    StatusBar(statusText, highlight: isMyAction),
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
                        active: !g.over && s == activeSeat,
                        size: compact ? 28 : 34,
                        sub: '${g.players == 4 ? "[${s % 2 == 0 ? "0&2队" : "1&3队"}] " : ""}'
                            '${scores[s]}/$targetScore分${s == leader ? " [先]" : ""}',
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
                          _buildViraAndTricksBar(
                            cs,
                            viraCard,
                            manilhaRank,
                            trickWinners,
                            cardW,
                            compact,
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          if (phase == 'respond_truco') ...[
                            _buildTrucoChallengePanel(
                              cs,
                              trucoCallerSeat,
                              trucoResponderSeat,
                              handStake,
                              proposedStake,
                              isMyAction,
                              compact,
                            ),
                            SizedBox(height: compact ? 6 : 8),
                          ],
                          _buildTrickArea(cs, trick, lastTrick, manilhaRank, cardW, compact),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom hand + Truco button
                if (hand.isNotEmpty || (phase == 'play' && isMyAction && canCallTruco)) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (hand.isNotEmpty)
                          OverlapRow(
                            itemWidth: cardW,
                            children: [
                              for (final c in hand)
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    PlayingCard(
                                      c,
                                      width: cardW,
                                      selected: phase == 'play' && isMyAction,
                                      onTap: (phase == 'play' && isMyAction)
                                          ? () => g.act({'type': 'play', 'card': c})
                                          : null,
                                    ),
                                    if (c.startsWith(manilhaRank))
                                      Positioned(
                                        right: -2,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade800,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            '王牌',
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
                        if (phase == 'play' && isMyAction && canCallTruco)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.deepOrange.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => g.act({'type': 'truco'}),
                            icon: const Icon(Icons.local_fire_department, size: 16),
                            label: Text('喊 ${_stakeLabel(_nextStake(handStake))}!'),
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

  Widget _buildViraAndTricksBar(
    ColorScheme cs,
    String viraCard,
    String manilhaRank,
    List<int> trickWinners,
    double cardW,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.84),
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
              PlayingCard(viraCard, width: cardW * 0.78),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '指示牌 Vira: $viraCard',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
                    ),
                    Text(
                      '四大王牌: ♣$manilhaRank > ♥$manilhaRank > ♠$manilhaRank > ♦$manilhaRank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      '普通阶序: 3>2>A>K>J>Q>7>6>5>4 (同点平墩)',
                      style: TextStyle(fontSize: 10.5, color: cs.onSurface.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: i < trickWinners.length
                        ? (trickWinners[i] == -1
                            ? Colors.amber.withValues(alpha: 0.25)
                            : cs.primaryContainer)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    i < trickWinners.length
                        ? '第${i + 1}墩:${_sideLabel(trickWinners[i])}'
                        : '第${i + 1}墩:待战',
                    style: TextStyle(
                      fontSize: 11,
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

  String _sideLabel(int side) {
    if (side < 0) return '平局(Empate)';
    if (g.players == 4) {
      return side == 0 ? '0&2队胜' : '1&3队胜';
    }
    return '${g.name(side)}胜';
  }

  Widget _buildTrucoChallengePanel(
    ColorScheme cs,
    int callerSeat,
    int responderSeat,
    int handStake,
    int proposedStake,
    bool isMyAction,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🔥 ${g.name(callerSeat)} 发起 ${_stakeLabel(proposedStake)} 挑战！',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          if (isMyAction)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => g.act({'type': 'accept'}),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: Text('接受挑战 ($proposedStake分)'),
                ),
                if (proposedStake < 12)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => g.act({'type': 'raise'}),
                    icon: const Icon(Icons.trending_up, size: 16),
                    label: Text('反加注 ${_stakeLabel(_nextStake(proposedStake))}!'),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => g.act({'type': 'fold'}),
                  icon: const Icon(Icons.flag, size: 16),
                  label: Text('弃牌认输 (对方得$handStake分)'),
                ),
              ],
            )
          else
            Text(
              '等待 ${g.name(responderSeat)} 决定是否应战…',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildTrickArea(
    ColorScheme cs,
    List<Map> trick,
    Map? lastTrick,
    String manilhaRank,
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
                    '等待本墩出牌…（若第1墩平局，第2墩赢家直接获胜；若第2/3墩平局，第1墩赢家获胜！）',
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
                          PlayingCard('${entry['card']}', width: cardW),
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
              lastTrick['isTie'] == true
                  ? '上一墩：平墩 (Empate)！'
                  : '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 获胜',
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
