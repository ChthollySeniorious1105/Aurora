import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'c10_widgets.dart';

class DaifugoBoard extends StatefulWidget {
  final GameContext g;
  const DaifugoBoard(this.g, {super.key});
  @override
  State<DaifugoBoard> createState() => _DaifugoBoardState();
}

class _DaifugoBoardState extends State<DaifugoBoard> {
  final Set<int> _sel = {};
  String _key = '';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  @override
  Widget build(BuildContext context) {
    final hand = c10Strs(v['hand']);
    final k = '${hand.join(",")}|${v['phase']}|${v['turn']}';
    if (k != _key) {
      _key = k;
      _sel.removeWhere((i) => i < 0 || i >= hand.length);
    }

    final me = g.seat;
    final bottom = me >= 0 ? me : 0;
    final others = [
      for (final s in g.seatsFromMe())
        if (s != bottom) s,
    ];
    final phase = '${v['phase'] ?? 'play'}';
    final turn = c10Int(v['turn'], 0);
    final myTurn = me >= 0 && turn == me && !g.over;
    final rev = v['revolution'] == true;
    final table = v['table'] as Map?;
    final scores = c10Ints(v['scores']);
    final counts = c10Ints(v['counts']);
    final titles = c10Strs(v['titles']);
    final passed = c10Ints(v['passed']).toSet();
    final finishOrder = c10Ints(v['finishOrder']);

    String status;
    if (phase == 'exchange') {
      final trib = c10Strs(v['exchangeTribute']).join(' ');
      status = myTurn
          ? '【局间换牌】大贫民已进贡 ($trib)，请选 2 张手牌回赐给大贫民'
          : '【局间换牌】等待大富豪 ${g.name(turn)} 选择 2 张手牌回赐';
    } else if (phase == 'play') {
      status = myTurn
          ? (table == null ? '轮到你领出（可出单张/对子/三张/四张革命，出8直接8切清空！）' : '轮到你跟牌（须同张数更大牌组，或点【不出】）')
          : '等待 ${g.name(turn)} 出牌';
    } else if (phase == 'roundEnd') {
      status = '本局阶梯排定完成';
    } else {
      status = '比赛结束';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, c) {
        final landscape = c.maxWidth > c.maxHeight * 1.3;
        final w = (c.maxWidth / (landscape ? 16 : 9.5))
            .clamp(26.0, 58.0)
            .toDouble()
            .clamp(20.0, c.maxHeight / (landscape ? 7.0 : 8.5))
            .toDouble();

        final selCards = [for (final i in (_sel.toList()..sort())) if (i < hand.length) hand[i]];

        return Stack(fit: StackFit.expand, children: [
          Column(children: [
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                c10Pill('大富豪 · 第 ${v['roundNo']}/${v['targetRounds']} 局', Colors.indigo.shade700),
                const SizedBox(width: 6),
                c10Pill(
                  rev ? '🔥 革命中（2最小 < ... < 3最大 < 王）' : '常规序（3最小 < ... < 2最大 < 王）',
                  rev ? Colors.red.shade800 : Colors.teal.shade700,
                ),
                const SizedBox(width: 6),
                c10Pill('8切 · 四张革命${v['spade3Rule'] == true ? " · ♠3返王" : ""}', Colors.deepPurple.shade700),
              ]),
            ),
            const SizedBox(height: 2),
            c10Opponents(
              others,
              (s) => _opponentPanel(s, turn, scores, counts, titles, passed, finishOrder, w),
              c.maxWidth,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: c.maxWidth * 0.03, vertical: 3),
                child: C10Felt(
                  felt: c10FeltColor(g, rev ? const Color(0xFF5D1919) : const Color(0xFF0B5239)),
                  child: Center(child: _centerTable(w, table, rev)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(fit: BoxFit.scaleDown, child: StatusBar(status, highlight: myTurn)),
            ),
            const SizedBox(height: 2),
            if (me >= 0) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  g.tag(
                    bottom,
                    active: myTurn,
                    size: 26,
                    sub: '${titles.length > bottom ? titles[bottom] : "平民"} · ${scores.length > bottom ? scores[bottom] : 0}分',
                  ),
                  const SizedBox(width: 8),
                  if (myTurn && phase == 'exchange')
                    FilledButton(
                      onPressed: selCards.length == 2
                          ? () {
                              final cards = List.of(selCards);
                              setState(() => _sel.clear());
                              g.act({'type': 'exchange', 'cards': cards});
                            }
                          : null,
                      child: const Text('回赐这2张牌'),
                    ),
                  if (myTurn && phase == 'play') ...[
                    FilledButton(
                      onPressed: selCards.isNotEmpty
                          ? () {
                              final cards = List.of(selCards);
                              setState(() => _sel.clear());
                              g.act({'type': 'play', 'cards': cards});
                            }
                          : null,
                      child: const Text('出牌'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: table != null
                          ? () {
                              setState(() => _sel.clear());
                              g.act({'type': 'pass'});
                            }
                          : null,
                      child: const Text('不出 (Pass)'),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 2),
              C10Hand(
                cards: hand,
                sel: _sel,
                layout: C10HandLayout.compute(hand.length, c.maxWidth - 16, w, maxRows: landscape ? 1 : 2),
                onToggle: (idx) {
                  setState(() {
                    if (_sel.contains(idx)) {
                      _sel.remove(idx);
                    } else {
                      _sel.add(idx);
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: 4),
          ]),
          if (phase == 'roundEnd' || phase == 'over') Center(child: SingleChildScrollView(child: _resultBanner())),
        ]);
      }),
    );
  }

  Widget _opponentPanel(
    int s,
    int turn,
    List<int> scores,
    List<int> counts,
    List<String> titles,
    Set<int> passed,
    List<int> finishOrder,
    double w,
  ) {
    final title = titles.length > s ? titles[s] : '平民';
    final cnt = counts.length > s ? counts[s] : 0;
    final finIdx = finishOrder.indexOf(s);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        g.tag(
          s,
          active: turn == s && !g.over,
          size: 26,
          sub: '$title · ${scores.length > s ? scores[s] : 0}分 · 剩$cnt张',
        ),
        const SizedBox(width: 4),
        if (finIdx >= 0)
          c10Pill('第${finIdx + 1}名', Colors.amber.shade800, fontSize: 10)
        else if (passed.contains(s))
          c10Pill('不出', Colors.blueGrey.shade700, fontSize: 10)
        else
          c10Backs(cnt, w * 0.72),
      ]),
    );
  }

  Widget _centerTable(double w, Map? table, bool rev) {
    final lastEx = v['lastExchange'] as Map?;
    final log = c10Strs(v['log']);
    final tCards = table != null ? c10Strs(table['cards']) : const <String>[];
    final tSeat = table != null ? c10Int(table['seat'], 0) : -1;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (rev)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: c10Pill('⚡ 革命状态生效中：点数大小完全反转 ⚡', Colors.redAccent.shade700, fontSize: 12),
            ),
          if (table == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                '桌面已清空 · 当前玩家自由领出',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.7), width: 1.5),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  '${g.name(tSeat)} 打出（${tCards.length}张）：',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                c10Row(tCards, w, gap: 0.6, hi: tCards.toSet()),
              ]),
            ),
          if (lastEx != null) ...[
            const SizedBox(height: 6),
            c10Pill(
              '本局换牌：大贫民进贡 ${c10Strs(lastEx['tribute']).join(" ")} ⇄ 大富豪回赐 ${c10Strs(lastEx['returned']).join(" ")}',
              Colors.brown.shade700,
              fontSize: 10,
            ),
          ],
          const SizedBox(height: 6),
          c10Log(log, max: 2),
        ]),
      ),
    );
  }

  Widget _resultBanner() {
    final r = v['result'] as Map?;
    final over = v['phase'] == 'over';
    final winner = c10Int(v['winner'], 0);
    final order = c10Ints(r?['order'] ?? v['finishOrder']);
    final titles = c10Strs(r?['titles'] ?? v['titles']);
    final roundPts = c10Ints(r?['roundPoints']);
    final scores = c10Ints(v['scores']);

    final title = over
        ? (v['resigned'] == true ? '${g.name(winner)} 获胜（对手认输）' : '比赛结束 · 总冠军 ${g.name(winner)}！')
        : '第 ${v['roundNo']} 局结束 · 大富豪：${order.isNotEmpty ? g.name(order.first) : ""}';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: ResultBanner(
        title,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < order.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  c10Pill(
                    '第${i + 1}名 · ${titles.length > order[i] ? titles[order[i]] : ""}',
                    i == 0 ? Colors.amber.shade800 : (i == order.length - 1 ? Colors.blueGrey.shade700 : Colors.teal.shade700),
                    fontSize: 11,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${g.name(order[i])}：本局 +${roundPts.length > order[i] ? roundPts[order[i]] : 0} 分（总分 ${scores.length > order[i] ? scores[order[i]] : 0}）',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ]),
              ),
            ),
          c10Continue(g),
        ]),
      ),
    );
  }
}
