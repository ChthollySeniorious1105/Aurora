import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class WizardBoard extends StatelessWidget {
  final GameContext g;
  const WizardBoard(this.g, {super.key});

  static const List<(String, String, Color)> _suits = [
    ('S', '♠ 黑桃', Color(0xFF263238)),
    ('H', '♥ 红心', Color(0xFFC62828)),
    ('D', '♦ 方块', Color(0xFFD84315)),
    ('C', '♣ 梅花', Color(0xFF1B5E20)),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'bid'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final dealer = (v['dealer'] as num?)?.toInt() ?? 0;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 6;
    final roundCards = (v['roundCards'] as num?)?.toInt() ?? 1;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final trumpCard = v['trumpCard'] as String?;
    final trumpSuitName = '${v['trumpSuitName'] ?? '无主牌'}';

    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final bids = (v['bids'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ??
        List.filled(g.players, null);
    final tricksWon = (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal = ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'choose_trump') {
      statusText = isMyTurn ? '翻出巫师牌！请选择本轮主牌花色' : '等待发牌人 ${g.name(turn)} 选择主牌花色…';
    } else if (phase == 'bid') {
      statusText = isMyTurn ? '请预测你本轮能赢得的墩数 (0~$roundCards)' : '等待 ${g.name(turn)} 预测叫墩…';
    } else {
      statusText = isMyTurn ? '轮到你出牌（巫师必胜，小丑必败）' : '等待 ${g.name(turn)} 出牌…';
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
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(
                      cs,
                      '第 $round/$totalRounds 轮 ($roundCards张) · 第 ${trickNumber.clamp(1, roundCards)}/$roundCards 墩',
                    ),
                    _chip(
                      cs,
                      '主牌：$trumpSuitName${trumpCard != null ? " ($trumpCard)" : ""}',
                      highlight: true,
                    ),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),

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
                        size: compact ? 26 : 32,
                        sub: '总${scores[s]} · '
                            '墩${tricksWon[s]}/${bids[s] != null ? "${bids[s]}" : "?"}'
                            '${s == dealer ? " [发]" : ""}',
                      ),
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
                          if (phase == 'choose_trump')
                            _buildChooseTrumpPanel(cs, isMyTurn, trumpCard, cardW, compact)
                          else if (phase == 'bid')
                            _buildBidPanel(cs, isMyTurn, roundCards, bids, trumpCard, cardW, compact)
                          else
                            _buildTrickTable(cs, trick, lastTrick, trumpCard, cardW, compact),
                        ],
                      ),
                    ),
                  ),
                ),

                // My hand at bottom
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          _WizardCard(
                            c,
                            width: cardW,
                            selected: phase == 'play' && isMyTurn && legal.contains(c),
                            dim: phase == 'play' && isMyTurn && !legal.contains(c),
                            onTap: (phase == 'play' && isMyTurn && legal.contains(c))
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
                child: ResultBanner(_buildResultText(scores)),
              ),
          ],
        ),
      );
    });
  }

  Widget _chip(ColorScheme cs, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: highlight ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildChooseTrumpPanel(
    ColorScheme cs,
    bool isMyTurn,
    String? trumpCard,
    double cardW,
    bool compact,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.all(compact ? 8 : 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trumpCard != null) ...[
            _WizardCard(trumpCard, width: cardW * 0.9),
            const SizedBox(height: 6),
          ],
          Text(
            isMyTurn ? '翻出巫师！请指定本轮主牌花色' : '等待发牌人指定主牌花色',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (code, label, color) in _suits)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isMyTurn
                      ? () => g.act({'type': 'choose_trump', 'suit': code})
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isMyTurn ? 0.9 : 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBidPanel(
    ColorScheme cs,
    bool isMyTurn,
    int roundCards,
    List<int?> bids,
    String? trumpCard,
    double cardW,
    bool compact,
  ) {
    final totalBidSoFar = bids.whereType<int>().fold<int>(0, (a, b) => a + b);
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: EdgeInsets.all(compact ? 8 : 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trumpCard != null) ...[
                _WizardCard(trumpCard, width: cardW * 0.85),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMyTurn ? '请选择本轮预测赢墩数' : '预测叫墩阶段',
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      '当前合计已叫 $totalBidSoFar / $roundCards 墩 · 猜中得 20+10×墩数，猜错每差1墩-10分',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.78)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var b = 0; b <= roundCards; b++)
                FilledButton.tonal(
                  onPressed: isMyTurn ? () => g.act({'type': 'bid', 'bid': b}) : null,
                  child: Text('$b 墩 (+${20 + 10 * b}分)'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrickTable(
    ColorScheme cs,
    List<Map> trick,
    Map? lastTrick,
    String? trumpCard,
    double cardW,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 540),
          padding: EdgeInsets.all(compact ? 8 : 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: trick.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(compact ? 8 : 14),
                  child: const Text(
                    '等待本墩领出牌…（首张巫师W必胜 · 小丑J必败除非全小丑）',
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
                          _WizardCard('${entry['card']}', width: cardW),
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
              '上一墩由 ${g.name((lastTrick['winner'] as num).toInt())} 赢得',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(List<int> scores) {
    final parts = [for (var i = 0; i < scores.length; i++) '${g.name(i)}: ${scores[i]}分'];
    return '比赛结束！${parts.join(" · ")}';
  }
}

class _WizardCard extends StatelessWidget {
  final String code;
  final double width;
  final bool selected;
  final bool dim;
  final VoidCallback? onTap;

  const _WizardCard(
    this.code, {
    required this.width,
    this.selected = false,
    this.dim = false,
    this.onTap,
  });

  bool get _isWizard => code.startsWith('W');
  bool get _isJester =>
      code == 'J' || code == 'J1' || code == 'J2' || code == 'J3' || code == 'J4';

  @override
  Widget build(BuildContext context) {
    if (!_isWizard && !_isJester) {
      return PlayingCard(
        code,
        width: width,
        selected: selected,
        dim: dim,
        onTap: onTap,
      );
    }

    final h = width * 1.4;
    final colors = _isWizard
        ? const [Color(0xFF4A148C), Color(0xFF7B1FA2)]
        : const [Color(0xFF00695C), Color(0xFF00897B)];
    final accent = _isWizard ? Colors.amberAccent : Colors.orangeAccent;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.3 : 0, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(
          color: selected ? Colors.amber : accent.withValues(alpha: 0.8),
          width: selected ? 2.2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isWizard ? 'WIZARD' : 'JESTER',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                _isWizard ? Icons.auto_fix_high : Icons.theater_comedy,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                _isWizard ? '巫师 $code' : '小丑 $code',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (dim) card = Opacity(opacity: 0.5, child: card);
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
