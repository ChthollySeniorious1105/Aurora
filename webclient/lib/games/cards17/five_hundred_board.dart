import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class FiveHundredBoard extends StatefulWidget {
  final GameContext g;
  const FiveHundredBoard(this.g, {super.key});

  @override
  State<FiveHundredBoard> createState() => _FiveHundredBoardState();
}

class _FiveHundredBoardState extends State<FiveHundredBoard> {
  final Set<String> _selectedDiscards = {};

  static const List<(String, String, int, Color)> _strains = [
    ('S', '♠', 40, Color(0xFF263238)),
    ('C', '♣', 60, Color(0xFF1B5E20)),
    ('D', '♦', 80, Color(0xFFD84315)),
    ('H', '♥', 100, Color(0xFFC62828)),
    ('NT', 'NT', 120, Color(0xFF1565C0)),
  ];

  static String _cardForWidget(String code) => code == 'JK' ? 'RJ' : code;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'bid'}';
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 3;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final declarer = (v['declarer'] as num?)?.toInt() ?? -1;
    final contractTricks = (v['contractTricks'] as num?)?.toInt() ?? 6;
    final contractStrain = '${v['contractStrain'] ?? 'S'}';
    final contractStrainName = '${v['contractStrainName'] ?? '♠ 黑桃'}';
    final contractValue = (v['contractValue'] as num?)?.toInt() ?? 0;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final tricksWon =
        (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal =
        ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final bidHistory = (v['bidHistory'] as List?)?.cast<Map>() ?? const <Map>[];
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    _selectedDiscards.removeWhere((c) => !hand.contains(c));

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'bid') {
      statusText = isMyTurn ? '轮到你叫牌 (6~8 墩 / Misère 零墩) 或 Pass' : '等待 ${g.name(turn)} 叫牌…';
    } else if (phase == 'kitty') {
      statusText = isMyTurn
          ? '你已收起 3 张底牌 (共13张)，请点击 3 张手牌弃置 (${_selectedDiscards.length}/3)'
          : '等待庄家 ${g.name(turn)} 交换 3 张底牌…';
    } else {
      statusText = isMyTurn ? '轮到你出牌（正副 J 及大王在有将定约中均属主花色）' : '等待 ${g.name(turn)} 出牌…';
    }

    final contractBadge = declarer < 0
        ? '尚未叫牌'
        : (contractStrain == 'MISERE'
            ? '定约: Misère 零墩 (250分) · 庄:${g.name(declarer)}'
            : '定约: $contractTricks$contractStrainName ($contractValue分) · 庄:${g.name(declarer)}');

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 38.0 : 50.0;

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
                    _chip(cs, '第 $round/$totalRounds 局 · 第 ${trickNumber.clamp(1, 10)}/10 墩'),
                    _chip(cs, contractBadge, highlight: true),
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
                        sub: '${g.players == 4 ? "[${s % 2 == 0 ? "0&2队" : "1&3队"}] " : ""}'
                            '${s == declarer ? "[庄] " : ""}'
                            '${scores[s]}分 · 赢${tricksWon[s]}墩',
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
                          if (phase == 'bid')
                            _buildBiddingPanel(
                              g,
                              cs,
                              isMyTurn,
                              contractValue,
                              bidHistory,
                              compact,
                            )
                          else if (phase == 'kitty')
                            _buildKittyPanel(g, cs, isMyTurn, hand, compact)
                          else
                            _buildPlayTable(
                              g,
                              cs,
                              contractStrain,
                              trick,
                              lastTrick,
                              cardW,
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
                      color: cs.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          PlayingCard(
                            _cardForWidget(c),
                            width: cardW,
                            selected: phase == 'kitty'
                                ? _selectedDiscards.contains(c)
                                : (phase == 'play' && isMyTurn && legal.contains(c)),
                            dim: phase == 'play' && isMyTurn && !legal.contains(c),
                            onTap: (phase == 'kitty' && isMyTurn)
                                ? () {
                                    setState(() {
                                      if (_selectedDiscards.contains(c)) {
                                        _selectedDiscards.remove(c);
                                      } else if (_selectedDiscards.length < 3) {
                                        _selectedDiscards.add(c);
                                      }
                                    });
                                  }
                                : (phase == 'play' && isMyTurn && legal.contains(c))
                                    ? () => g.act({'type': 'play', 'card': c})
                                    : null,
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
                child: ResultBanner(_buildResultText(g, scores)),
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

  Widget _buildBiddingPanel(
    GameContext g,
    ColorScheme cs,
    bool isMyTurn,
    int currentHighValue,
    List<Map> bidHistory,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Avondale 竞叫表（🃏大王 > 正J > 同色副J > A > K > Q...）',
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          for (var tricks = 6; tricks <= 8; tricks++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (final (strain, sym, base, color) in _strains)
                    Builder(builder: (context) {
                      final val = base + (tricks - 6) * 100;
                      final canBid = isMyTurn && val > currentHighValue;
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: canBid
                            ? () => g.act({'type': 'bid', 'tricks': tricks, 'strain': strain})
                            : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 8 : 10,
                            vertical: compact ? 4 : 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: canBid ? 0.92 : 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$tricks$sym ($val)',
                            style: TextStyle(
                              color: canBid ? Colors.white : Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: (isMyTurn && 250 > currentHighValue)
                    ? () => g.act({'type': 'misere'})
                    : null,
                icon: const Icon(Icons.visibility_off, size: 15),
                label: const Text('Misère 零墩定约 (250分)'),
              ),
              if (isMyTurn)
                OutlinedButton.icon(
                  onPressed: () => g.act({'type': 'pass'}),
                  icon: const Icon(Icons.skip_next, size: 15),
                  label: const Text('不叫 (Pass)'),
                ),
            ],
          ),
          if (bidHistory.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '叫牌记录：${bidHistory.map((b) => "${g.name((b['seat'] as num).toInt())}:${b['label']}").join(" -> ")}',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.78)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKittyPanel(
    GameContext g,
    ColorScheme cs,
    bool isMyTurn,
    List<String> hand,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.all(compact ? 8 : 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMyTurn ? '底牌交换阶段 (Kitty Exchange)' : '等待庄家弃置 3 张底牌…',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          if (isMyTurn)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _selectedDiscards.length == 3
                      ? () {
                          final cards = _selectedDiscards.toList();
                          _selectedDiscards.clear();
                          g.act({'type': 'discard', 'cards': cards});
                        }
                      : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('确认弃置已选 (${_selectedDiscards.length}/3)'),
                ),
                if (hand.length >= 3)
                  OutlinedButton.icon(
                    onPressed: () {
                      final last3 = hand.reversed.take(3).toList();
                      _selectedDiscards.clear();
                      g.act({'type': 'discard', 'cards': last3});
                    },
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('快速弃末 3 张'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPlayTable(
    GameContext g,
    ColorScheme cs,
    String contractStrain,
    List<Map> trick,
    Map? lastTrick,
    double cardW,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              contractStrain == 'NT' || contractStrain == 'MISERE'
                  ? '无将阶序：🃏大王(最高) > A > K > Q > J > 10 > 9...'
                  : '有将阶序：🃏大王 > 正J(主花色J) > 副J(同色花色J，计入主牌！) > A > K > Q > 10...',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ),
        const SizedBox(height: 6),
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
                  padding: EdgeInsets.all(compact ? 8 : 14),
                  child: const Text(
                    '等待本墩领出牌…（防守方每赢 1 墩得 +10 分）',
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
                          PlayingCard(_cardForWidget('${entry['card']}'), width: cardW),
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
              '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 赢得第 ${lastTrick['trickNumber']} 墩',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(GameContext g, List<int> scores) {
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++) '${g.name(s)}: ${scores[s]}分'
    ].join(' · ')}';
  }
}
