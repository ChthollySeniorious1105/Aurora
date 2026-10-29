import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class BeloteBoard extends StatefulWidget {
  final GameContext g;
  const BeloteBoard(this.g, {super.key});

  @override
  State<BeloteBoard> createState() => _BeloteBoardState();
}

class _BeloteBoardState extends State<BeloteBoard> {
  static const _suitNames = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方块', 'C': '♣梅花'};
  static const _suitSymbols = {'S': '♠', 'H': '♥', 'D': '♦', 'C': '♣'};

  Color _suitColor(String suit, ColorScheme cs) =>
      (suit == 'H' || suit == 'D') ? Colors.redAccent : cs.onSurface;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'bid';
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 3;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final bidRound = (v['bidRound'] as num?)?.toInt() ?? 1;
    final upCard = (v['upCard'] as String?) ?? '';
    final trumpSuit = (v['trumpSuit'] as String?) ?? '';
    final taker = (v['taker'] as num?)?.toInt() ?? -1;
    final beloteSeat = (v['beloteSeat'] as num?)?.toInt();
    final hand = (v['hand'] as List?)?.cast<String>() ?? const [];
    final legalCards = (v['legalCards'] as List?)?.cast<String>() ?? const [];
    final currentTrick = (v['currentTrick'] as List?)?.cast<Map>() ?? const [];
    final tricksWon = (v['tricksWon'] as List?)?.cast<num>() ?? const [];
    final capturedPoints = (v['capturedPoints'] as List?)?.cast<num>() ?? const [];
    final scores = (v['scores'] as List?)?.cast<num>() ?? const [];
    final summary = v['lastHandSummary'] as Map?;

    final isMyTurn = !g.over && g.seat >= 0 && g.seat == turn;
    final seats = g.seatsFromMe();
    final opponents = seats.length > 1 ? seats.sublist(1) : const <int>[];

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxHeight < 460 || c.maxWidth < 460;
      final cardW = compact ? 38.0 : 52.0;

      final statusText = g.over
          ? '法国贝洛特结束'
          : (phase == 'bid'
              ? '第 $round/$totalRounds 局 · 第 $bidRound 轮叫主 · 轮到 ${g.name(turn)}'
              : '第 $round/$totalRounds 局 · 主花色 ${_suitNames[trumpSuit] ?? trumpSuit} · 轮到 ${g.name(turn)}');

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(children: [
          Column(children: [
            // Top bar: Status + Trump & Contract info
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBar(statusText, highlight: isMyTurn),
                if (trumpSuit.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary),
                    ),
                    child: Text(
                      '主花色: ${_suitNames[trumpSuit] ?? trumpSuit}'
                      '${taker >= 0 ? " · 庄家: ${g.name(taker)}" : ""}'
                      '${beloteSeat != null ? " · Belote(+20): ${g.name(beloteSeat)}" : ""}',
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.bold,
                        color: _suitColor(trumpSuit, cs),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 4 : 8),

            // Opponents row
            if (opponents.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in opponents)
                    _buildPlayerTag(g, s, turn, taker, tricksWon, capturedPoints, scores, compact),
                ],
              ),
            SizedBox(height: compact ? 4 : 8),

            // Center table area
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (phase == 'bid')
                        _buildBidPanel(g, cs, upCard, bidRound, isMyTurn, cardW, compact)
                      else
                        _buildTrickPanel(g, cs, currentTrick, cardW, compact),
                      if (summary != null) ...[
                        const SizedBox(height: 6),
                        _buildSummaryChip(g, cs, summary, compact),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom area: My tag & hand
            if (seats.isNotEmpty) ...[
              _buildPlayerTag(
                g,
                seats.first,
                turn,
                taker,
                tricksWon,
                capturedPoints,
                scores,
                compact,
              ),
              SizedBox(height: compact ? 4 : 6),
            ],
            if (hand.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: compact ? 2 : 6),
                child: OverlapRow(
                  itemWidth: cardW,
                  children: [
                    for (final card in hand)
                      Builder(builder: (_) {
                        final canPlay =
                            isMyTurn && phase == 'play' && legalCards.contains(card);
                        final dim =
                            isMyTurn && phase == 'play' && !legalCards.contains(card);
                        return PlayingCard(
                          card,
                          width: cardW,
                          dim: dim,
                          onTap: canPlay
                              ? () => g.act({'type': 'play', 'card': card})
                              : null,
                        );
                      }),
                  ],
                ),
              ),
          ]),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(_buildFinalResultText(g, scores)),
            ),
        ]),
      );
    });
  }

  Widget _buildPlayerTag(
    GameContext g,
    int s,
    int turn,
    int taker,
    List<num> tricksWon,
    List<num> capturedPoints,
    List<num> scores,
    bool compact,
  ) {
    final tw = s < tricksWon.length ? tricksWon[s].toInt() : 0;
    final cp = s < capturedPoints.length ? capturedPoints[s].toInt() : 0;
    final sc = s < scores.length ? scores[s].toInt() : 0;
    final role = s == taker ? '[庄] ' : '';
    return g.tag(
      s,
      active: !g.over && s == turn,
      size: compact ? 28 : 34,
      sub: '$role墩:$tw · 本局:$cp · 总分:$sc',
    );
  }

  Widget _buildBidPanel(
    GameContext g,
    ColorScheme cs,
    String upCard,
    int bidRound,
    bool isMyTurn,
    double cardW,
    bool compact,
  ) {
    final upSuit = upCard.length >= 2 ? upCard.substring(upCard.length - 1) : '';
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            bidRound == 1
                ? '第一轮叫主：拿取候选明牌（${_suitNames[upSuit] ?? upSuit}为主）或过牌'
                : '第二轮叫主：任选候选花色以外的花色定主或过牌',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 12 : 14,
            ),
          ),
          const SizedBox(height: 8),
          if (upCard.isNotEmpty) PlayingCard(upCard, width: cardW),
          if (isMyTurn) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (bidRound == 1)
                  FilledButton.icon(
                    onPressed: () => g.act({'type': 'take'}),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('拿牌定主 (${_suitSymbols[upSuit] ?? upSuit})'),
                  )
                else
                  for (final s in ['S', 'H', 'D', 'C'])
                    if (s != upSuit)
                      FilledButton.tonal(
                        onPressed: () =>
                            g.act({'type': 'choose_suit', 'suit': s}),
                        child: Text('选 ${_suitNames[s]}'),
                      ),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'pass'}),
                  child: const Text('过牌 (Pass)'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrickPanel(
    GameContext g,
    ColorScheme cs,
    List<Map> currentTrick,
    double cardW,
    bool compact,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: currentTrick.isEmpty
          ? Text(
              '等待领出新一墩…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: compact ? 12 : 14,
              ),
            )
          : Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final e in currentTrick)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayingCard('${e['card'] ?? ''}', width: cardW),
                      const SizedBox(height: 4),
                      Text(
                        g.name((e['seat'] as num?)?.toInt() ?? 0),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  Widget _buildSummaryChip(
    GameContext g,
    ColorScheme cs,
    Map summary,
    bool compact,
  ) {
    final ok = summary['contractSuccess'] == true;
    final takerSeat = (summary['taker'] as num?)?.toInt() ?? 0;
    final tPts = summary['takerAwarded'] ?? 0;
    final dPts = summary['defenderAwarded'] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '上局结算：庄家 ${g.name(takerSeat)} ${ok ? "成约" : "崩盘 Dedans"} · 庄 $tPts : 防 $dPts',
        style: TextStyle(fontSize: compact ? 10 : 12),
      ),
    );
  }

  String _buildFinalResultText(GameContext g, List<num> scores) {
    if (scores.isEmpty) return '对局结束';
    var maxScore = scores.first.toInt();
    for (final s in scores) {
      if (s.toInt() > maxScore) maxScore = s.toInt();
    }
    final winners = [
      for (var i = 0; i < scores.length; i++)
        if (scores[i].toInt() == maxScore) g.name(i),
    ];
    return '${winners.join(" & ")} 获胜！（$maxScore 分）';
  }
}
