import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class MusBoard extends StatefulWidget {
  final GameContext g;
  const MusBoard(this.g, {super.key});

  @override
  State<MusBoard> createState() => _MusBoardState();
}

class _MusBoardState extends State<MusBoard> {
  final Set<int> _selectedDiscard = {};

  /// Maps Spanish suit (`O, C, E, B`) to `PlayingCard` suit (`D, H, S, C`).
  static String _toStandardCardCode(String code) {
    if (code.length < 2) return code;
    final rank = code.substring(0, code.length - 1);
    final suit = code[code.length - 1];
    final stdSuit = switch (suit) {
      'O' => 'D', // Oros (金币 ♦)
      'C' => 'H', // Copas (圣杯 ♥)
      'E' => 'S', // Espadas (宝剑 ♠)
      'B' => 'C', // Bastos (权杖 ♣)
      _ => suit,
    };
    return '$rank$stdSuit';
  }

  static String _cardBadge(String code) {
    if (code.length < 2) return '';
    final r = code.substring(0, code.length - 1);
    if (r == '3') return '=K(10)';
    if (r == '2') return '=A(1)';
    if (r == 'K' || r == 'Q' || r == 'J') return '10点';
    if (r == 'A') return '1点';
    return '$r点';
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final cs = Theme.of(context).colorScheme;
    final v = g.view;

    final handNumber = (v['handNumber'] as num?)?.toInt() ?? 1;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 30;
    final mano = (v['mano'] as num?)?.toInt() ?? 0;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'mus'}';
    final stage = (v['stage'] as num?)?.toInt() ?? 0;
    final stageName = '${v['stageName'] ?? ''}';
    final stageBet = (v['stageBet'] as num?)?.toInt() ?? 0;
    final prevBet = (v['prevBet'] as num?)?.toInt() ?? 1;
    final ordagoActive = v['ordagoActive'] == true;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final sideScores =
        (v['sideScores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players == 4 ? 2 : g.players, 0);
    final discardDone =
        (v['discardDone'] as List?)?.map((e) => e == true).toList() ?? const [];
    final paresDecls =
        (v['paresDeclarations'] as List?)?.map((e) => e == true).toList() ??
            List.filled(g.players, false);
    final juegoDecls =
        (v['juegoDeclarations'] as List?)?.map((e) => e == true).toList() ??
            List.filled(g.players, false);

    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final myPares = v['myPares'] as Map?;
    final mySum = (v['mySum'] as num?)?.toInt() ?? 0;
    final stageResults =
        (v['stageResults'] as List?)?.cast<Map>() ?? const <Map>[];
    final actionLog =
        (v['actionLog'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final lastSummary = v['lastHandSummary'] as Map?;

    final myDiscardPending = phase == 'discard' &&
        !g.spectator &&
        (g.seat >= discardDone.length || !discardDone[g.seat]);
    final isMyTurn = !g.over &&
        ((phase == 'discard' && myDiscardPending) ||
            (phase != 'discard' && g.seat == turn));

    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'mus') {
      statusText = isMyTurn
          ? '轮到你表态：选择「Mus (同意换牌)」或「Cortar (切牌开赌)」'
          : '等待 ${g.name(turn)} 表态 Mus / Cortar…';
    } else if (phase == 'discard') {
      statusText = isMyTurn
          ? '全员同意 Mus！请点击要弃换的手牌后确认'
          : '等待其他玩家提交换牌…';
    } else {
      statusText = isMyTurn
          ? (stageBet == 0
              ? '轮到你在「$stageName」叫注：Paso(过牌) / Envido(加注) / Órdago!(全押)'
              : '对手在「$stageName」下注 ${ordagoActive ? "Órdago!" : "$stageBet分"}：请响应跟注、加注或弃牌')
          : '「$stageName」等待 ${g.name(turn)} 行动…';
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
                    _chip(cs, '第 $handNumber 局 · 目标 $targetScore 分'),
                    _chip(
                      cs,
                      '八王制: 3=K(10点) · 2=A(1点) · 31点最强!',
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
                      Builder(builder: (_) {
                        final side = g.players == 4 ? (s % 2) : s;
                        final hasP = s < paresDecls.length && paresDecls[s];
                        final hasJ = s < juegoDecls.length && juegoDecls[s];
                        return g.tag(
                          s,
                          active: !g.over &&
                              ((phase == 'discard' &&
                                      s < discardDone.length &&
                                      !discardDone[s]) ||
                                  (phase != 'discard' && s == turn)),
                          size: compact ? 28 : 34,
                          sub: '${g.players == 4 ? "[${side == 0 ? "0&2队" : "1&3队"}] " : ""}'
                              '${scores[s]}/$targetScore分'
                              '${s == mano ? " [Mano先]" : ""}'
                              '${phase == 'bet' && stage >= 2 ? " · ${hasP ? "有对" : "无对"}" : ""}'
                              '${phase == 'bet' && stage == 3 ? "/${hasJ ? "≥31" : "<31"}" : ""}',
                        );
                      }),
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
                          _buildFourStagesBar(cs, stageResults, phase, stage, compact),
                          SizedBox(height: compact ? 6 : 8),
                          if (isMyTurn)
                            _buildActionControls(
                              cs,
                              phase,
                              stageName,
                              stageBet,
                              prevBet,
                              ordagoActive,
                              hand,
                              compact,
                            ),
                          if (actionLog.isNotEmpty || lastSummary != null) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildLogAndSummaryBox(cs, actionLog, lastSummary, compact),
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
                      color: cs.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '我的手牌 · 对子: ${myPares?['label'] ?? '-'} · 点数和: $mySum点 '
                          '(${mySum >= 31 ? "Juego! [31>32>40>37..33]" : "Punto $mySum点"}):',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        OverlapRow(
                          itemWidth: cardW,
                          maxSpacing: 1.15,
                          children: [
                            for (var i = 0; i < hand.length; i++)
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  PlayingCard(
                                    _toStandardCardCode(hand[i]),
                                    width: cardW,
                                    selected: phase == 'discard' &&
                                        _selectedDiscard.contains(i),
                                    onTap: (phase == 'discard' && isMyTurn)
                                        ? () => setState(() {
                                              if (_selectedDiscard.contains(i)) {
                                                _selectedDiscard.remove(i);
                                              } else {
                                                _selectedDiscard.add(i);
                                              }
                                            })
                                        : null,
                                  ),
                                  Positioned(
                                    right: -2,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (hand[i].startsWith('3') ||
                                                hand[i].startsWith('K'))
                                            ? Colors.amber.shade800
                                            : cs.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _cardBadge(hand[i]),
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

  Widget _buildFourStagesBar(
    ColorScheme cs,
    List<Map> stageResults,
    String phase,
    int activeStage,
    bool compact,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < stageResults.length; i++)
          Builder(builder: (_) {
            final r = stageResults[i];
            final name = '${r['name'] ?? ''}';
            final status = '${r['status'] ?? 'pending'}';
            final stake = (r['stake'] as num?)?.toInt() ?? 1;
            final isCur = phase == 'bet' && activeStage == i;
            final statusLabel = switch (status) {
              'paso' => '过牌 (1分)',
              'accepted' => '已锁注 $stake分',
              'folded' => '弃牌 (Deje +$stake)',
              'skipped' => '自动跳过',
              'ordago_accepted' => 'Órdago 决胜!',
              _ => isCur ? '🔥 当前叫注' : '待进行',
            };
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: isCur
                    ? Colors.amber.withValues(alpha: 0.28)
                    : cs.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCur ? Colors.amber.shade700 : cs.outline.withValues(alpha: 0.3),
                  width: isCur ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isCur ? cs.primary : cs.onSurface,
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildActionControls(
    ColorScheme cs,
    String phase,
    String stageName,
    int stageBet,
    int prevBet,
    bool ordagoActive,
    List<String> hand,
    bool compact,
  ) {
    final g = widget.g;
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (phase == 'mus') ...[
            Text(
              '是否同意本轮换牌 (Mus)？只要有一人切牌 (Cortar) 即刻开始比大！',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => g.act({'type': 'mus'}),
                  icon: const Icon(Icons.autorenew, size: 16),
                  label: const Text('Mus! (同意换牌)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => g.act({'type': 'cortar'}),
                  icon: const Icon(Icons.content_cut, size: 16),
                  label: const Text('Cortar! (不换牌·立即开赌)'),
                ),
              ],
            ),
          ] else if (phase == 'discard') ...[
            Text(
              '请点击下方手牌选择要弃换的牌（已选 ${_selectedDiscard.length} 张）：',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    final cards = [
                      for (final idx in _selectedDiscard)
                        if (idx >= 0 && idx < hand.length) hand[idx],
                    ];
                    _selectedDiscard.clear();
                    g.act({'type': 'discard', 'cards': cards});
                  },
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: Text('确认弃换 (${_selectedDiscard.length} 张)'),
                ),
                OutlinedButton(
                  onPressed: () {
                    _selectedDiscard.clear();
                    g.act({'type': 'discard', 'cards': const <String>[]});
                  },
                  child: const Text('保留全部 (换 0 张)'),
                ),
              ],
            ),
          ] else if (phase == 'bet') ...[
            Text(
              stageBet == 0
                  ? '【$stageName】当前无人加注 (En Paso)：'
                  : (ordagoActive
                      ? '🔥【$stageName】对手喊出 Órdago!（全押整场胜负，不跟则对方得 $prevBet 分）：'
                      : '【$stageName】当前注额 $stageBet 分（弃牌则对方立即得 $prevBet 分）：'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ordagoActive ? Colors.deepOrange.shade700 : cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (stageBet == 0)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => g.act({'type': 'pass'}),
                    icon: const Icon(Icons.skip_next, size: 16),
                    label: const Text('Paso (过牌 1分)'),
                  ),
                  FilledButton.icon(
                    onPressed: () => g.act({'type': 'envido', 'amount': 2}),
                    icon: const Icon(Icons.trending_up, size: 16),
                    label: const Text('Envido (+2分)'),
                  ),
                  FilledButton.icon(
                    onPressed: () => g.act({'type': 'envido', 'amount': 5}),
                    icon: const Icon(Icons.double_arrow, size: 16),
                    label: const Text('Envido (+5分)'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => g.act({'type': 'ordago'}),
                    icon: const Icon(Icons.local_fire_department, size: 16),
                    label: const Text('Órdago! (全押胜负)'),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => g.act({'type': 'accept'}),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: Text(
                      ordagoActive ? 'Quiero! (接下 Órdago 决胜)' : 'Quiero (跟注 $stageBet分)',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => g.act({'type': 'fold'}),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text('No quiero (弃牌·让出$prevBet分)'),
                  ),
                  if (!ordagoActive) ...[
                    OutlinedButton.icon(
                      onPressed: () => g.act({'type': 'raise', 'amount': 2}),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('反加 +2分'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => g.act({'type': 'raise', 'amount': 5}),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('反加 +5分'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepOrange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => g.act({'type': 'ordago'}),
                      icon: const Icon(Icons.local_fire_department, size: 16),
                      label: const Text('Órdago! (全押)'),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogAndSummaryBox(
    ColorScheme cs,
    List<String> actionLog,
    Map? lastSummary,
    bool compact,
  ) {
    final breakdown = (lastSummary?['breakdown'] as List?)?.cast<Map>() ?? const <Map>[];
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in actionLog.take(3))
            Text(
              line,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final b in breakdown)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '上局${b['name']}: +${b['points']}分',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildResultText(List<int> scores, List<int> sideScores) {
    final g = widget.g;
    if (g.players == 4 && sideScores.length >= 2) {
      return '比赛结束！0&2队: ${sideScores[0]}分 vs 1&3队: ${sideScores[1]}分';
    }
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++) '${g.name(s)}: ${scores[s]}分'
    ].join(' · ')}';
  }
}
