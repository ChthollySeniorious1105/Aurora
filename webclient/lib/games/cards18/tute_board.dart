import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class TuteBoard extends StatelessWidget {
  final GameContext g;
  const TuteBoard(this.g, {super.key});

  /// Maps Spanish suit code (`O, C, E, B`) to `PlayingCard` suit code (`D, H, S, C`).
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

  static String _suitShort(String suit) => switch (suit) {
        'O' => '♦金币(Oros)',
        'C' => '♥圣杯(Copas)',
        'E' => '♠宝剑(Espadas)',
        'B' => '♣权杖(Bastos)',
        _ => suit,
      };

  static int _cardPts(String code) {
    if (code.length < 2) return 0;
    return switch (code.substring(0, code.length - 1)) {
      'A' => 11,
      '3' => 10,
      'K' => 4,
      'Q' => 3,
      'J' => 2,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final leader = (v['leader'] as num?)?.toInt() ?? 0;
    final trumpCard = '${v['trumpCard'] ?? '2O'}';
    final trumpSuit = '${v['trumpSuit'] ?? 'O'}';
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;
    final strictFollowing = v['strictFollowing'] == true;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final sideScores =
        (v['sideScores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players == 4 ? 2 : g.players, 0);
    final handCardPoints = (v['handCardPoints'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players == 4 ? 2 : g.players, 0);
    final handCantePoints = (v['handCantePoints'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players == 4 ? 2 : g.players, 0);

    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal =
        ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final availableCantes =
        (v['availableCantes'] as List?)?.map((e) => '$e').toList() ??
            const <String>[];
    final availableTute = v['availableTute'] as String?;
    final canteLog = (v['canteLog'] as List?)?.cast<Map>() ?? const <Map>[];
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (isMyTurn) {
      statusText = availableTute != null
          ? '轮到你：可宣告 Tute! 直接获胜，或点击手牌出牌'
          : (availableCantes.isNotEmpty
              ? '轮到你：可先宣告 Cante (王后组合 +40/+20分)，再点击手牌领出'
              : '轮到你出牌（A>3>K>Q>J>7>6>5>4>2）');
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 40.0 : 52.0;

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
                    _chip(cs, '第 $round/$totalRounds 局 · 第 $trickNumber 墩'),
                    _chip(
                      cs,
                      '主牌: ${_suitShort(trumpSuit)}',
                      highlight: true,
                    ),
                    _chip(
                      cs,
                      strictFollowing
                          ? '严苛跟牌 (Montar必压/Fallar必毙)'
                          : '牌库剩余 $stockCount 张',
                      highlight: strictFollowing,
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
                        final cPts = side < handCardPoints.length ? handCardPoints[side] : 0;
                        final mPts = side < handCantePoints.length ? handCantePoints[side] : 0;
                        return g.tag(
                          s,
                          active: !g.over && s == turn,
                          size: compact ? 28 : 34,
                          sub: '${g.players == 4 ? "[${side == 0 ? "0&2队" : "1&3队"}] " : ""}'
                              '总${scores[s]} · 本局$cPts+$mPts分${s == leader ? " [先]" : ""}',
                        );
                      }),
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
                          _buildTrumpAndRulesBar(
                            cs,
                            trumpCard,
                            trumpSuit,
                            stockCount,
                            canteLog,
                            cardW,
                            compact,
                          ),
                          if (isMyTurn &&
                              (availableTute != null || availableCantes.isNotEmpty)) ...[
                            SizedBox(height: compact ? 6 : 8),
                            _buildDeclarationButtons(
                              cs,
                              availableTute,
                              availableCantes,
                              trumpSuit,
                              compact,
                            ),
                          ],
                          SizedBox(height: compact ? 6 : 8),
                          _buildTrickArea(cs, trick, lastTrick, cardW, compact),
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
                      color: cs.surface.withValues(alpha: 0.76),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              PlayingCard(
                                _toStandardCardCode(c),
                                width: cardW,
                                selected: isMyTurn && legal.contains(c),
                                dim: isMyTurn && !legal.contains(c),
                                onTap: (isMyTurn && legal.contains(c))
                                    ? () => g.act({'type': 'play', 'card': c})
                                    : null,
                              ),
                              if (_cardPts(c) > 0)
                                Positioned(
                                  right: -2,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.endsWith(trumpSuit)
                                          ? Colors.amber.shade800
                                          : cs.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+${_cardPts(c)}',
                                      style: const TextStyle(
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

  Widget _buildTrumpAndRulesBar(
    ColorScheme cs,
    String trumpCard,
    String trumpSuit,
    int stockCount,
    List<Map> canteLog,
    double cardW,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
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
              PlayingCard(_toStandardCardCode(trumpCard), width: cardW * 0.76),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '主牌指示牌: $trumpCard (${_suitShort(trumpSuit)})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      '阶序与分值: A(11) > 3(10) > K(4) > Q(3) > J(2) > 7..2(0) · 末墩+10分',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canteLog.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final entry in canteLog)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade700),
                    ),
                    child: Text(
                      '${g.name((entry['seat'] as num).toInt())}: ${_suitShort('${entry['suit']}')}+${entry['points']}',
                      style: TextStyle(
                        fontSize: 10.5,
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

  Widget _buildDeclarationButtons(
    ColorScheme cs,
    String? availableTute,
    List<String> availableCantes,
    String trumpSuit,
    bool compact,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        if (availableTute != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => g.act({'type': 'tute'}),
            icon: const Icon(Icons.emoji_events, size: 16),
            label: Text(
              '宣告 Tute! (${availableTute == 'kings' ? '四张K' : '四张Q'} 立即获胜)',
            ),
          ),
        for (final suit in availableCantes)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor:
                  suit == trumpSuit ? Colors.amber.shade800 : cs.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => g.act({'type': 'cante', 'suit': suit}),
            icon: const Icon(Icons.campaign, size: 16),
            label: Text(
              suit == trumpSuit
                  ? '宣告 Las Cuarenta (${_suitShort(suit)} K+Q +40分)'
                  : '宣告 Veinte (${_suitShort(suit)} K+Q +20分)',
            ),
          ),
      ],
    );
  }

  Widget _buildTrickArea(
    ColorScheme cs,
    List<Map> trick,
    Map? lastTrick,
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
                    '等待本墩领出…（牌库空后强制执行 Montar 有花必压大 & Fallar 无花必出主牌！）',
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
                          PlayingCard(
                            _toStandardCardCode('${entry['card']}'),
                            width: cardW,
                          ),
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
              '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 赢得 +${lastTrick['points']} 分'
              '${lastTrick['deUltimas'] == true ? " (含末墩 +10 分!)" : ""}',
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
