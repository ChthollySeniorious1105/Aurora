import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'c10_widgets.dart';

class CanastaBoard extends StatefulWidget {
  final GameContext g;
  const CanastaBoard(this.g, {super.key});
  @override
  State<CanastaBoard> createState() => _CanastaBoardState();
}

class _CanastaBoardState extends State<CanastaBoard> {
  final Set<int> _sel = {};
  String _key = '';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static bool _isWild(String c) => c == 'BJ' || c == 'RJ' || (c.length >= 2 && c.substring(0, c.length - 1) == '2');
  static String _rank(String c) => (c == 'BJ' || c == 'RJ') ? 'JOKER' : c.substring(0, c.length - 1);

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
    final phase = '${v['phase'] ?? 'draw'}';
    final turn = c10Int(v['turn'], 0);
    final myTurn = me >= 0 && turn == me && !g.over;
    final canTake = v['canTakePile'] == true;
    final scores = c10Ints(v['scores']);
    final counts = c10Ints(v['counts']);
    final allMelds = v['melds'] as List? ?? const [];
    final allRed3 = v['redThrees'] as List? ?? const [];

    String status;
    if (phase == 'draw') {
      status = myTurn
          ? (canTake ? '轮到你摸牌：可【摸2张牌】或【收走整个弃牌堆】！' : '轮到你摸牌：点击牌堆摸 2 张牌')
          : '等待 ${g.name(turn)} 摸牌';
    } else if (phase == 'play') {
      status = myTurn ? '出牌阶段：可选择手牌【组牌/贴牌】（满7张成篮），最后选1张【弃牌】' : '等待 ${g.name(turn)} 组牌与弃牌';
    } else if (phase == 'handEnd') {
      status = '本局结算完成';
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

        return Stack(fit: StackFit.expand, children: [
          Column(children: [
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                c10Pill('卡纳斯塔 · 第 ${v['handNo']}/${v['targetHands']} 局', Colors.indigo.shade700),
                const SizedBox(width: 6),
                c10Pill('纯篮 +500 · 混篮 +300 · 红3 +100', Colors.amber.shade800),
              ]),
            ),
            const SizedBox(height: 2),
            c10Opponents(others, (s) => _opponentPanel(s, turn, scores, counts, allMelds, allRed3, w), c.maxWidth),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: c.maxWidth * 0.03, vertical: 3),
                child: C10Felt(
                  felt: c10FeltColor(g, const Color(0xFF0D4732)),
                  child: Center(child: _centerTable(w, bottom, myTurn, phase, canTake, allMelds, allRed3)),
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
                    sub: '分数 ${scores.length > bottom ? scores[bottom] : 0} · 手牌 ${hand.length}',
                  ),
                  const SizedBox(width: 8),
                  ..._actionButtons(hand, bottom, myTurn, phase, canTake, allMelds),
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
          if (phase == 'handEnd' || phase == 'over') Center(child: SingleChildScrollView(child: _resultBanner())),
        ]);
      }),
    );
  }

  Widget _opponentPanel(
    int s,
    int turn,
    List<int> scores,
    List<int> counts,
    List allMelds,
    List allRed3,
    double w,
  ) {
    final sMelds = s < allMelds.length ? (allMelds[s] as List? ?? const []) : const [];
    final sRed3 = s < allRed3.length ? c10Strs(allRed3[s]) : const <String>[];
    final meldSummary = sMelds.map((m) {
      final map = m as Map;
      final r = '${map['rank']}';
      final len = (map['cards'] as List? ?? const []).length;
      final isC = map['isCanasta'] == true;
      final isNat = map['isNatural'] == true;
      return '$r×$len${isC ? (isNat ? "★纯" : "★混") : ""}';
    }).join(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        g.tag(
          s,
          active: turn == s && !g.over,
          size: 26,
          sub: '${scores.length > s ? scores[s] : 0}分 · 手牌${counts.length > s ? counts[s] : 0}${sRed3.isNotEmpty ? " · 红3×${sRed3.length}" : ""}',
        ),
        if (meldSummary.isNotEmpty) ...[
          const SizedBox(width: 4),
          c10Pill(meldSummary, Colors.teal.shade800, fontSize: 10),
        ],
      ]),
    );
  }

  List<Widget> _actionButtons(
    List<String> hand,
    int bottom,
    bool myTurn,
    String phase,
    bool canTake,
    List allMelds,
  ) {
    if (!myTurn) return const [];
    if (phase == 'draw') {
      return [
        FilledButton(
          onPressed: () => g.act({'type': 'draw_stock'}),
          child: const Text('摸2张牌'),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: canTake ? () => g.act({'type': 'take_pile'}) : null,
          child: const Text('收弃牌堆'),
        ),
      ];
    }

    if (phase == 'play') {
      final selCards = [for (final i in (_sel.toList()..sort())) if (i < hand.length) hand[i]];
      final myMelds = bottom < allMelds.length ? (allMelds[bottom] as List? ?? const []) : const [];
      String? meldRank;
      final naturals = selCards.where((c) => !_isWild(c)).toList();
      if (naturals.isNotEmpty) {
        final r0 = _rank(naturals.first);
        if (naturals.every((c) => _rank(c) == r0) && r0 != '3') {
          meldRank = r0;
        }
      } else if (selCards.isNotEmpty && myMelds.isNotEmpty) {
        meldRank = '${(myMelds.first as Map)['rank']}';
      }

      final canMeld = selCards.isNotEmpty && meldRank != null;
      final canDiscard = selCards.length == 1;

      return [
        FilledButton.tonal(
          onPressed: canMeld
              ? () {
                  final r = meldRank!;
                  final cards = List.of(selCards);
                  setState(() => _sel.clear());
                  g.act({'type': 'meld', 'rank': r, 'cards': cards});
                }
              : null,
          child: Text(meldRank != null ? '组牌 ($meldRank)' : '组牌/贴牌'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: canDiscard
              ? () {
                  final c = selCards.first;
                  setState(() => _sel.clear());
                  g.act({'type': 'discard', 'card': c});
                }
              : null,
          child: const Text('弃牌'),
        ),
      ];
    }
    return const [];
  }

  Widget _centerTable(
    double w,
    int bottom,
    bool myTurn,
    String phase,
    bool canTake,
    List allMelds,
    List allRed3,
  ) {
    final stockCount = c10Int(v['stockCount'], 0);
    final discardCount = c10Int(v['discardCount'], 0);
    final discardPreview = c10Strs(v['discardPreview']);
    final blocked = v['pileBlocked'] == true;
    final myMelds = bottom < allMelds.length ? (allMelds[bottom] as List? ?? const []) : const [];
    final myRed3 = bottom < allRed3.length ? c10Strs(allRed3[bottom]) : const <String>[];
    final log = c10Strs(v['log']);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Stock pile
            GestureDetector(
              onTap: myTurn && phase == 'draw' ? () => g.act({'type': 'draw_stock'}) : null,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                c10Card('back', w * 0.9, highlight: myTurn && phase == 'draw'),
                const SizedBox(height: 4),
                c10Pill('牌堆 $stockCount', Colors.black54, fontSize: 11),
              ]),
            ),
            const SizedBox(width: 18),
            // Discard pile
            GestureDetector(
              onTap: myTurn && phase == 'draw' && canTake ? () => g.act({'type': 'take_pile'}) : null,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                discardPreview.isEmpty
                    ? Container(
                        width: w * 0.9,
                        height: w * 1.26,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white30, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : c10Row(discardPreview, w * 0.85, gap: 0.32, hi: canTake ? {discardPreview.last} : const {}),
                const SizedBox(height: 4),
                c10Pill(
                  '弃牌堆 $discardCount${blocked && discardCount > 0 ? " (封锁)" : ""}',
                  blocked ? Colors.red.shade900 : Colors.black54,
                  fontSize: 11,
                ),
              ]),
            ),
            if (myRed3.isNotEmpty) ...[
              const SizedBox(width: 18),
              Column(mainAxisSize: MainAxisSize.min, children: [
                c10Row(myRed3, w * 0.72, gap: 0.45),
                const SizedBox(height: 4),
                c10Pill('红3奖牌 +${myRed3.length * 100}', Colors.redAccent.shade700, fontSize: 10),
              ]),
            ],
          ]),
          const SizedBox(height: 8),
          // My melds on the table
          if (myMelds.isEmpty)
            c10Pill('我的台面牌组：暂无（选3张及以上同点牌点击【组牌】）', Colors.black45, fontSize: 11)
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final m in myMelds) _meldBox(m as Map, w * 0.68),
              ],
            ),
          const SizedBox(height: 6),
          c10Log(log, max: 2),
        ]),
      ),
    );
  }

  Widget _meldBox(Map m, double cw) {
    final rank = '${m['rank']}';
    final cards = c10Strs(m['cards']);
    final isCanasta = m['isCanasta'] == true;
    final isNatural = m['isNatural'] == true;
    final borderColor = isCanasta
        ? (isNatural ? Colors.amberAccent : Colors.cyanAccent)
        : Colors.white38;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isCanasta ? 2 : 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        c10Row(cards.take(7).toList(), cw, gap: 0.36),
        const SizedBox(height: 2),
        Text(
          isCanasta
              ? '$rank×${cards.length} ${isNatural ? "【纯篮+500】" : "【混篮+300】"}'
              : '$rank 牌组 (${cards.length}/7)',
          style: TextStyle(
            color: isCanasta ? borderColor : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ]),
    );
  }

  Widget _resultBanner() {
    final r = v['result'] as Map?;
    final over = v['phase'] == 'over';
    final winner = c10Int(v['winner'], c10Int(r?['winner'], 0));
    final wentOut = c10Int(r?['wentOut'], -1);
    final breakdown = (r?['breakdown'] as List? ?? const []).cast<Map>();
    final scores = c10Ints(v['scores']);

    final title = over
        ? (v['resigned'] == true ? '${g.name(winner)} 获胜（对手认输）' : '比赛结束 · ${g.name(winner)} 获胜！')
        : (wentOut >= 0 ? '第 ${v['handNo']} 局 · ${g.name(wentOut)} 成功出局！' : '第 ${v['handNo']} 局结算');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: ResultBanner(
        title,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (breakdown.isNotEmpty)
            for (final b in breakdown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${g.name(c10Int(b['seat']))}：纯篮×${b['naturalCanastas']} · 混篮×${b['mixedCanastas']} · 红3×${b['redThrees']} · 牌面+${b['meldPoints']}/-${b['handPenalty']} · 本局 ${c10Int(b['delta']) >= 0 ? "+${b['delta']}" : "${b['delta']}"}（总分 ${b['total']}）',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )
          else
            for (var s = 0; s < scores.length; s++)
              Text('${g.name(s)}：${scores[s]} 分'),
          c10Continue(g),
        ]),
      ),
    );
  }
}
