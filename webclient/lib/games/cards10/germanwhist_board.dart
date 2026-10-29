import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'c10_widgets.dart';

class GermanWhistBoard extends StatefulWidget {
  final GameContext g;
  const GermanWhistBoard(this.g, {super.key});
  @override
  State<GermanWhistBoard> createState() => _GermanWhistBoardState();
}

class _GermanWhistBoardState extends State<GermanWhistBoard> {
  String? _sel;
  String _key = '';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static const Map<String, String> _suitNames = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方块', 'C': '♣梅花'};

  @override
  Widget build(BuildContext context) {
    final hand = c10Strs(v['hand']);
    final legal = c10Strs(v['legal']).toSet();
    final k = '${hand.join(",")}|${v['phase']}|${v['turn']}';
    if (k != _key) {
      _key = k;
      if (_sel != null && !hand.contains(_sel)) _sel = null;
    }

    final me = g.seat;
    final bottom = me >= 0 ? me : 0;
    final foe = 1 - bottom;
    final phase = '${v['phase'] ?? 'forhand'}';
    final turn = c10Int(v['turn'], 0);
    final myTurn = me >= 0 && turn == me && (phase == 'forhand' || phase == 'endgame') && !g.over;
    final trumpSuit = '${v['trumpSuit'] ?? 'S'}';
    final upCard = v['upCard'] as String?;
    final stockCount = c10Int(v['stockCount'], 0);
    final scores = c10Ints(v['scores']);
    final p1Tricks = c10Ints(v['phase1Tricks']);
    final p2Tricks = c10Ints(v['phase2Tricks']);
    final counts = c10Ints(v['counts']);
    final knownRaw = v['knownUpCards'] as List? ?? const [[], []];
    final foeKnown = foe < knownRaw.length ? c10Strs(knownRaw[foe]) : const <String>[];

    String status;
    if (phase == 'forhand') {
      status = myTurn
          ? '【前13墩夺牌战】轮到你出牌（赢家收明牌 ${upCard ?? ""}，输家暗摸底牌）'
          : '【前13墩夺牌战】等待 ${g.name(turn)} 出牌';
    } else if (phase == 'endgame') {
      status = myTurn ? '【后13墩决胜战】轮到你出牌（超过6墩即可得分！）' : '【后13墩决胜战】等待 ${g.name(turn)} 出牌';
    } else if (phase == 'handEnd') {
      status = '本局结算完成';
    } else {
      status = '比赛结束';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight * 1.3;
        final w = (c.maxWidth / (landscape ? 16 : 9))
            .clamp(28.0, 62.0)
            .toDouble()
            .clamp(22.0, c.maxHeight / (landscape ? 6.8 : 8.2))
            .toDouble();

        final dimSet = myTurn ? hand.where((card) => !legal.contains(card)).toSet() : const <String>{};
        final selIdx = _sel != null ? hand.indexOf(_sel!) : -1;
        final canPlaySel = myTurn && _sel != null && legal.contains(_sel);

        return Stack(fit: StackFit.expand, children: [
          Column(children: [
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                c10Pill('德国惠斯特 · 第 ${v['handNo']}/${v['targetHands']} 局', Colors.indigo.shade700),
                const SizedBox(width: 6),
                c10Pill(
                  phase == 'forhand' ? '阶段1：前13墩夺牌战（牌堆 $stockCount）' : '阶段2：后13墩决胜战',
                  phase == 'forhand' ? Colors.teal.shade700 : Colors.deepOrange.shade700,
                ),
                const SizedBox(width: 6),
                c10Pill('主花色：${_suitNames[trumpSuit] ?? trumpSuit}', Colors.purple.shade700),
              ]),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                g.tag(
                  foe,
                  active: turn == foe && !g.over,
                  size: 28,
                  sub: '总分 ${scores.length > foe ? scores[foe] : 0} · 前墩 ${p1Tricks.length > foe ? p1Tricks[foe] : 0} · 决胜墩 ${p2Tricks.length > foe ? p2Tricks[foe] : 0}',
                ),
                const SizedBox(width: 8),
                c10Backs(counts.length > foe ? counts[foe] : 0, w),
                if (foeKnown.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  c10Pill('已知名牌', Colors.amber.shade800, fontSize: 10),
                  const SizedBox(width: 4),
                  c10Row(foeKnown.take(6).toList(), w * 0.55, gap: 0.45),
                ],
              ]),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: c.maxWidth * 0.04, vertical: 3),
                child: C10Felt(
                  felt: c10FeltColor(g, const Color(0xFF0A5236)),
                  child: Center(child: _tableArea(w, bottom, foe, phase, upCard, stockCount)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(fit: BoxFit.scaleDown, child: StatusBar(status, highlight: myTurn)),
            ),
            const SizedBox(height: 3),
            if (me >= 0) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  g.tag(
                    bottom,
                    active: myTurn,
                    size: 26,
                    sub: '总分 ${scores.length > bottom ? scores[bottom] : 0} · 前墩 ${p1Tricks.length > bottom ? p1Tricks[bottom] : 0} · 决胜墩 ${p2Tricks.length > bottom ? p2Tricks[bottom] : 0}',
                  ),
                  const SizedBox(width: 8),
                  if (myTurn)
                    FilledButton(
                      onPressed: canPlaySel
                          ? () {
                              final card = _sel!;
                              setState(() => _sel = null);
                              g.act({'type': 'play', 'card': card});
                            }
                          : null,
                      child: const Text('出牌'),
                    ),
                ]),
              ),
              const SizedBox(height: 2),
              C10Hand(
                cards: hand,
                sel: selIdx >= 0 ? {selIdx} : const {},
                dimCards: dimSet,
                layout: C10HandLayout.compute(hand.length, c.maxWidth - 16, w, maxRows: landscape ? 1 : 2),
                onToggle: (idx) {
                  if (!myTurn) return;
                  final card = hand[idx];
                  if (!legal.contains(card)) return;
                  if (_sel == card) {
                    setState(() => _sel = null);
                    g.act({'type': 'play', 'card': card});
                  } else {
                    setState(() => _sel = card);
                  }
                },
              ),
            ],
            const SizedBox(height: 4),
          ]),
          if (phase == 'handEnd' || phase == 'over') Center(child: SingleChildScrollView(child: _resultBanner())),
        ]);
      }),
    );
  }

  Widget _tableArea(double w, int bottom, int foe, String phase, String? upCard, int stockCount) {
    final trick = (v['trick'] as List? ?? const []).cast<Map>();
    final last = v['lastTrick'] as Map?;
    final p2Tricks = c10Ints(v['phase2Tricks']);
    final log = c10Strs(v['log']);

    String? cardBySeat(List<Map> list, int s) {
      for (final m in list) {
        if (c10Int(m['seat']) == s) return '${m['card']}';
      }
      return null;
    }

    final curBottom = cardBySeat(trick, bottom);
    final curFoe = cardBySeat(trick, foe);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Stock + UpCard or Phase 2 scoreboard
            if (phase == 'forhand' && upCard != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    c10Card('back', w * 0.85),
                    const SizedBox(height: 3),
                    c10Pill('底牌 ${stockCount - 1}', Colors.blueGrey.shade800, fontSize: 10),
                  ]),
                  const SizedBox(width: 10),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    c10Card(upCard, w * 0.95, highlight: true),
                    const SizedBox(height: 3),
                    c10Pill('本墩明牌', Colors.amber.shade800, fontSize: 10),
                  ]),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.7)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  c10Pill('后13墩决胜计分（>6墩得分）', Colors.deepOrange.shade700, fontSize: 11),
                  const SizedBox(height: 6),
                  Text(
                    '${g.name(bottom)}: ${p2Tricks.length > bottom ? p2Tricks[bottom] : 0} 墩  vs  ${g.name(foe)}: ${p2Tricks.length > foe ? p2Tricks[foe] : 0} 墩',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ]),
              ),
            const SizedBox(width: 20),
            // Current trick area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(g.name(foe), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  curFoe != null
                      ? c10Card(curFoe, w)
                      : Container(
                          width: w,
                          height: w * 1.4,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                ]),
                const SizedBox(width: 14),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(g.name(bottom), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  curBottom != null
                      ? c10Card(curBottom, w)
                      : Container(
                          width: w,
                          height: w * 1.4,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                ]),
              ]),
            ),
            if (last != null) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('上墩赢家: ${g.name(c10Int(last['winner']))}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(height: 3),
                  c10Row([for (final m in (last['cards'] as List? ?? const [])) '${(m as Map)['card']}'], w * 0.65,
                      gap: 0.55),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          c10Log(log, max: 2),
        ]),
      ),
    );
  }

  Widget _resultBanner() {
    final r = v['result'] as Map?;
    final over = v['phase'] == 'over';
    final winner = c10Int(v['winner'], c10Int(r?['winner'], 0));
    final scores = c10Ints(v['scores']);
    final p1 = c10Ints(r?['phase1Tricks'] ?? v['phase1Tricks']);
    final p2 = c10Ints(r?['phase2Tricks'] ?? v['phase2Tricks']);
    final pts = c10Int(r?['points'], 0);
    final title = over
        ? (v['resigned'] == true
            ? '${g.name(winner)} 获胜（对手认输）'
            : (winner < 0 ? '比赛结束 · 平局' : '比赛结束 · ${g.name(winner)} 获胜！'))
        : '第 ${v['handNo']} 局结束 · ${g.name(c10Int(r?['winner'], 0))} +$pts 分';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: ResultBanner(
        title,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var s = 0; s < 2; s++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${g.name(s)}：', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('前13墩 ${p1.length > s ? p1[s] : 0} 墩 · 后13墩 ${p2.length > s ? p2[s] : 0} 墩 · 总分 ${scores.length > s ? scores[s] : 0}'),
                ]),
              ),
            ),
          c10Continue(g),
        ]),
      ),
    );
  }
}
