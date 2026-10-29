import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class FoxInTheForestBoard extends StatelessWidget {
  final GameContext g;
  const FoxInTheForestBoard(this.g, {super.key});

  static String _trickTierLabel(int t) {
    if (t <= 3) return '谦逊(6分)';
    if (t == 4) return '败北(1分)';
    if (t == 5) return '败北(2分)';
    if (t == 6) return '败北(3分)';
    if (t <= 9) return '凯旋(6分)';
    return '贪婪(0分!)';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'play'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final leader = (v['leader'] as num?)?.toInt() ?? 0;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final decreeCard = '${v['decreeCard'] ?? '1B'}';
    final trumpSuitName = '${v['trumpSuitName'] ?? '🔔 铃铛'}';
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;

    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final tricksWon = (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final bonusPoints =
        (v['bonusPoints'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal = ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'fox_swap') {
      statusText = isMyTurn
          ? '狐狸(3)异能：点击一张手牌与法令牌交换，或点击「不交换」'
          : '等待 ${g.name(turn)} 决定是否发动狐狸(3)交换法令牌…';
    } else if (phase == 'woodcutter_discard') {
      statusText = isMyTurn
          ? '樵夫(5)异能：已抽 1 张牌，请点击 1 张手牌弃置到牌库底'
          : '等待 ${g.name(turn)} 执行樵夫(5)弃牌…';
    } else {
      statusText = isMyTurn ? '轮到你出牌（点击高亮手牌打出）' : '等待 ${g.name(turn)} 出牌…';
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
                    _chip(cs, '第 $round/$totalRounds 局 · 第 ${trickNumber.clamp(1, 13)}/13 墩'),
                    _chip(cs, '王牌：$trumpSuitName (法令 $decreeCard)', highlight: true),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Players row
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      g.tag(
                        s,
                        active: !g.over && s == turn,
                        size: compact ? 28 : 34,
                        sub: '总${scores[s]}分 · 本局${tricksWon[s]}墩[${_trickTierLabel(tricksWon[s])}]'
                            '${bonusPoints[s] > 0 ? " +宝藏${bonusPoints[s]}" : ""}'
                            '${s == leader ? " [领]" : ""}',
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
                          _buildScoringAndPowersBanner(cs, compact),
                          SizedBox(height: compact ? 4 : 8),
                          _buildCenterArea(
                            cs,
                            phase,
                            isMyTurn,
                            decreeCard,
                            stockCount,
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

                // My hand at bottom
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          _FoxCard(
                            c,
                            width: cardW,
                            selected: isMyTurn &&
                                (phase != 'play' || legal.contains(c)),
                            dim: isMyTurn && phase == 'play' && !legal.contains(c),
                            onTap: _cardTapHandler(isMyTurn, phase, legal, c),
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

  VoidCallback? _cardTapHandler(
    bool isMyTurn,
    String phase,
    Set<String> legal,
    String card,
  ) {
    if (!isMyTurn) return null;
    if (phase == 'fox_swap') {
      return () => g.act({'type': 'fox_swap', 'card': card});
    }
    if (phase == 'woodcutter_discard') {
      return () => g.act({'type': 'woodcutter_discard', 'card': card});
    }
    if (phase == 'play' && legal.contains(card)) {
      return () => g.act({'type': 'play', 'card': card});
    }
    return null;
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

  Widget _buildScoringAndPowersBanner(ColorScheme cs, bool compact) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '谦逊/贪婪计分：0~3墩=6分(谦逊) · 4墩=1分 · 5墩=2分 · 6墩=3分 · 7~9墩=6分(凯旋) · 10~13墩=0分(贪婪爆分!)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '奇数异能：1天鹅(输墩抢先) · 3狐狸(换法令牌) · 5樵夫(抽1弃1) · 7宝藏(+1分) · 9女巫(单9视为主牌) · 11君王(逼出1或最大)',
              style: TextStyle(fontSize: 10.5, color: cs.onSurface.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArea(
    ColorScheme cs,
    String phase,
    bool isMyTurn,
    String decreeCard,
    int stockCount,
    List<Map> trick,
    Map? lastTrick,
    double cardW,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Decree card & stock box
            Container(
              padding: EdgeInsets.all(compact ? 6 : 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '法令牌 (王牌)',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _FoxCard(decreeCard, width: cardW),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '森林牌库',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: cardW * 0.85,
                        height: cardW * 1.18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Center(
                          child: Text(
                            '$stockCount张',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Current trick box
            Container(
              constraints: const BoxConstraints(minWidth: 190, maxWidth: 360),
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
                        '等待先手领出本墩卡牌…',
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
                              _FoxCard('${entry['card']}', width: cardW),
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
          ],
        ),

        if (phase == 'fox_swap' && isMyTurn) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => g.act({'type': 'pass'}),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('不交换法令牌 (保持当前王牌花色)'),
          ),
        ],

        if (lastTrick != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '上一墩：${g.name((lastTrick['winner'] as num).toInt())} 赢墩'
              '${(lastTrick['treasureBonus'] as num? ?? 0) > 0 ? " (宝藏+${lastTrick['treasureBonus']}分)" : ""}'
              '${lastTrick['swanTriggered'] == true ? " · 天鹅(1)触发由 ${g.name((lastTrick['nextLeader'] as num).toInt())} 先手!" : ""}',
              style: TextStyle(fontSize: 11, color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }

  String _buildResultText(List<int> scores) {
    final parts = [for (var i = 0; i < scores.length; i++) '${g.name(i)}: ${scores[i]}分'];
    return '比赛结束！${parts.join(" vs ")}';
  }
}

class _FoxCard extends StatelessWidget {
  final String code;
  final double width;
  final bool selected;
  final bool dim;
  final VoidCallback? onTap;

  const _FoxCard(
    this.code, {
    required this.width,
    this.selected = false,
    this.dim = false,
    this.onTap,
  });

  static const Map<String, (String, String, Color)> _suitTheme = {
    'B': ('🔔', '铃铛', Color(0xFFB71C1C)),
    'K': ('🗝️', '钥匙', Color(0xFFE65100)),
    'M': ('🌙', '月亮', Color(0xFF1A237E)),
  };

  static const Map<int, String> _oddShort = {
    1: '天鹅',
    3: '狐狸',
    5: '樵夫',
    7: '宝藏+1',
    9: '女巫',
    11: '君王',
  };

  @override
  Widget build(BuildContext context) {
    final h = width * 1.42;
    final suitChar = code.isNotEmpty ? code[code.length - 1] : 'B';
    final rankStr = code.length >= 2 ? code.substring(0, code.length - 1) : '1';
    final rank = int.tryParse(rankStr) ?? 1;
    final (emoji, suitLabel, color) =
        _suitTheme[suitChar] ?? ('🔔', '铃铛', const Color(0xFFB71C1C));
    final oddName = _oddShort[rank];

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.28 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: selected ? Colors.amber : color.withValues(alpha: 0.65),
          width: selected ? 2.2 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$rankStr $emoji',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                suitLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
              if (oddName != null) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    oddName,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (dim) card = Opacity(opacity: 0.48, child: card);
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
