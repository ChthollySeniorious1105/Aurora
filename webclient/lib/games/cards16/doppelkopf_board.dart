import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class DoppelkopfBoard extends StatelessWidget {
  final GameContext g;
  const DoppelkopfBoard(this.g, {super.key});

  static const List<(String, String, Color)> _soloContracts = [
    ('solo_D', '♦ 方块独庄 (1v3)', Color(0xFFD84315)),
    ('solo_H', '♥ 红心独庄 (1v3)', Color(0xFFC62828)),
    ('solo_S', '♠ 黑桃独庄 (1v3)', Color(0xFF1B5E20)),
    ('solo_C', '♣ 梅花独庄 (1v3)', Color(0xFF263238)),
    ('solo_queens', '👑 皇后独庄 (仅Q主)', Color(0xFF6A1B9A)),
  ];

  static String _baseCode(String code) {
    final i = code.indexOf('_');
    return i >= 0 ? code.substring(0, i) : code;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = '${v['phase'] ?? 'contract'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final forehand = (v['forehand'] as num?)?.toInt() ?? 0;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 4;
    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final contract = '${v['contract'] ?? 'normal'}';
    final contractName = '${v['contractName'] ?? '标准局'}';
    final myTeam = v['myTeam'] as String?;
    final canCallRe = v['canCallRe'] == true;
    final canCallKontra = v['canCallKontra'] == true;
    final reCalled = v['reCalled'] == true;
    final kontraCalled = v['kontraCalled'] == true;
    final fuchsRe = (v['fuchsCaughtRe'] as num?)?.toInt() ?? 0;
    final fuchsKontra = (v['fuchsCaughtKontra'] as num?)?.toInt() ?? 0;

    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List.filled(g.players, 0);
    final handPoints =
        (v['handPoints'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final tricksWon =
        (v['tricksWon'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final visibleTeams = (v['visibleTeams'] as List?)
            ?.map((e) => e == null ? null : '$e')
            .toList() ??
        List<String?>.filled(g.players, null);
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? <String>[];
    final legal = ((v['legal'] as List?)?.map((e) => '$e').toList() ?? <String>[]).toSet();
    final trick = (v['trick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = v['lastTrick'] as Map?;

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'contract') {
      statusText = isMyTurn ? '轮到你叫牌：选择 Gesund(正常局) 或宣告 Solo(独庄)' : '等待 ${g.name(turn)} 叫牌…';
    } else {
      statusText = isMyTurn ? '轮到你出牌（点击高亮手牌打出）' : '等待 ${g.name(turn)} 出牌…';
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
                    _chip(cs, '第 $round/$totalRounds 局 · 第 ${trickNumber.clamp(1, 10)}/10 墩'),
                    _chip(cs, contractName, highlight: true),
                    if (myTeam != null)
                      _chip(
                        cs,
                        '我方：$myTeam (${myTeam == 'Re' ? '庄家方' : '闲家方'})',
                        highlight: myTeam == 'Re',
                      ),
                    if (reCalled) _chip(cs, '已喊 Re (×2)', highlight: true),
                    if (kontraCalled) _chip(cs, '已喊 Kontra (×2)', highlight: true),
                    if (fuchsRe > 0 || fuchsKontra > 0)
                      _chip(cs, '捉狐狸(♦A)：Re $fuchsRe / Kontra $fuchsKontra'),
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
                        sub: '${visibleTeams[s] != null ? "[${visibleTeams[s]}] " : "[?] "}'
                            '总${scores[s]} · ${handPoints[s]}分/${tricksWon[s]}墩'
                            '${s == forehand ? " [先]" : ""}',
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
                          if (phase == 'contract')
                            _buildContractSelector(cs, isMyTurn, compact)
                          else
                            _buildTrickTable(
                              cs,
                              trick,
                              lastTrick,
                              contract,
                              canCallRe,
                              canCallKontra,
                              cardW,
                              compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Hand at bottom
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 6),
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
                          PlayingCard(
                            _baseCode(c),
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

  Widget _buildContractSelector(ColorScheme cs, bool isMyTurn, bool compact) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.all(compact ? 8 : 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMyTurn ? '请选择叫牌 (Gesund 标准秘密♣Q搭档局 / 宣告 Solo 1v3)' : '德国双头牌叫牌阶段',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '永久主牌：♥10(Dullen) > ♣Q>♠Q>♥Q>♦Q > ♣J>♠J>♥J>♦J > ♦A>♦10>♦K',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.75)),
          ),
          SizedBox(height: compact ? 6 : 10),
          FilledButton.icon(
            onPressed: isMyTurn ? () => g.act({'type': 'pass'}) : null,
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Gesund 正常局 (秘密 ♣Q 搭档 Re vs Kontra)'),
          ),
          SizedBox(height: compact ? 6 : 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final (code, title, color) in _soloContracts)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isMyTurn ? () => g.act({'type': code}) : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isMyTurn ? 0.9 : 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      title,
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
    );
  }

  Widget _buildTrickTable(
    ColorScheme cs,
    List<Map> trick,
    Map? lastTrick,
    String contract,
    bool canCallRe,
    bool canCallKontra,
    double cardW,
    bool compact,
  ) {
    final trumpRule = contract == 'solo_queens'
        ? '皇后独庄主牌：仅 ♣Q > ♠Q > ♥Q > ♦Q 为主牌（其余皆为副牌）'
        : '永久主牌：♥10(Dullen) > ♣Q>♠Q>♥Q>♦Q > ♣J>♠J>♥J>♦J > 主花色 A>10>K（同牌先出获胜）';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            trumpRule,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: cs.onSurface),
          ),
        ),
        if (canCallRe || canCallKontra) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (canCallRe)
                FilledButton.icon(
                  onPressed: () => g.act({'type': 'call_re'}),
                  icon: const Icon(Icons.campaign, size: 16),
                  label: const Text('高喊「Re!」(庄家方翻倍)'),
                ),
              if (canCallKontra)
                FilledButton.tonalIcon(
                  onPressed: () => g.act({'type': 'call_kontra'}),
                  icon: const Icon(Icons.campaign, size: 16),
                  label: const Text('高喊「Kontra!」(闲家方翻倍)'),
                ),
            ],
          ),
        ],
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
                    '等待本墩首张领出牌…（全牌240分，Re方需 ≥121 分获胜）',
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
                          PlayingCard(_baseCode('${entry['card']}'), width: cardW),
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
              '${(lastTrick['fuchsCaught'] as num? ?? 0) > 0 ? " · 捉狐狸(♦A)+${lastTrick['fuchsCaught']}!" : ""}'
              '${lastTrick['karlchen'] == true ? " · 卡尔琴(♣J终墩)+1!" : ""}',
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
