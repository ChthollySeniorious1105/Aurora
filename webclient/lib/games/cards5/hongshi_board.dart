import 'package:aurora_shared/games/cards5/hongshi.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

List<int> _ints(Object? l) => [for (final x in (l as List? ?? const [])) (x as num).toInt()];
List<String> _strs(Object? l) => [for (final x in (l as List? ?? const [])) '$x'];
int _int(Object? x, [int d = -1]) => x is num ? x.toInt() : d;

Widget _pill(String t, Color c, {double fontSize = 11}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(t, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize)),
    );

class HongshiBoard extends StatefulWidget {
  final GameContext g;
  const HongshiBoard(this.g, {super.key});

  @override
  State<HongshiBoard> createState() => _HongshiBoardState();
}

class _HongshiBoardState extends State<HongshiBoard> {
  final Set<int> _sel = {};
  String _handKey = '';
  int _hintIdx = -1;
  String _hintKey = '';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;
  List<String> get hand => _strs(v['hand']);

  void _sync() {
    final k = hand.join(',');
    if (k != _handKey) {
      _handKey = k;
      _sel.clear();
    }
    final hk = '$k|${v['tableSeat']}|${_strs(v['tableCards']).join(',')}|${v['turn']}|${v['phase']}';
    if (hk != _hintKey) {
      _hintKey = hk;
      _hintIdx = -1;
    }
  }

  List<String> get _selCards {
    final h = hand;
    return [for (final i in (_sel.toList()..sort())) if (i >= 0 && i < h.length) h[i]];
  }

  void _doHint() {
    final h = hand;
    final lead = v['lead'] == true;
    final target = lead ? null : HsCombo.fromJson(v['table']);
    final cands = hsCandidates(h, target);
    if (cands.isEmpty) {
      if (!lead) g.act({'type': 'pass'});
      return;
    }
    _hintIdx = (_hintIdx + 1) % cands.length;
    final used = <int>{};
    for (final c in cands[_hintIdx]) {
      for (var i = 0; i < h.length; i++) {
        if (!used.contains(i) && h[i] == c) {
          used.add(i);
          break;
        }
      }
    }
    setState(() {
      _sel
        ..clear()
        ..addAll(used);
    });
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final phase = '${v['phase'] ?? 'play'}';
    final turn = _int(v['turn']);
    final me = g.seat;
    final scores = _ints(v['scores']);
    final counts = _ints(v['counts']);
    final visibleReds = _ints(v['visibleReds']);
    final liang = (v['liang'] as List?)?.map((e) => e == true).toList() ?? const <bool>[];
    final declared = (v['declared'] as List?)?.map((e) => e == true).toList() ?? const <bool>[];
    final finish = _ints(v['finish']);
    final stakes = _int(v['stakes'], 1);

    final myDeclare = phase == 'declare' &&
        me >= 0 &&
        v['hasRedTen'] == true &&
        (me < declared.length && !declared[me]) &&
        !g.over;
    final myPlay = phase == 'play' && me >= 0 && turn == me && !g.over;
    final lead = v['lead'] == true;

    String status;
    if (phase == 'declare') {
      status = myDeclare ? '你持有红十！请选择【亮十】（翻倍）或【暗打】' : '等待持有红十的玩家选择亮十或暗打…';
    } else if (phase == 'play') {
      if (myPlay) {
        final t = v['table'] as Map?;
        status = lead || t == null ? '轮到你自由出牌' : '轮到你：管上 ${g.name(_int(v['tableSeat']))} 的 ${t['label']}，或不要';
      } else {
        status = '等待 ${g.name(turn)} 出牌';
      }
    } else if (phase == 'roundEnd') {
      status = '本局结束';
    } else {
      status = '比赛结束';
    }

    final others = g.seatsFromMe().where((s) => s != me).toList();
    final selCombo = _sel.isEmpty ? null : hsClassify(_selCards);

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, c) {
        final isShort = c.maxHeight < 460;
        final cardW = (c.maxWidth / (c.maxWidth < 500 ? 9.5 : 16)).clamp(28.0, isShort ? 38.0 : 52.0);
        return Stack(fit: StackFit.expand, children: [
          Column(children: [
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _pill('红十', Colors.red.shade800),
                  const SizedBox(width: 6),
                  _pill('第 ${v['round'] ?? 1}/${v['rounds'] ?? 4} 局', Colors.brown),
                  const SizedBox(width: 6),
                  _pill('倍数 ×$stakes', stakes > 1 ? Colors.deepOrange : Colors.blueGrey),
                ]),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in others)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildOpponent(s, scores, counts, visibleReds, liang, finish, turn, phase),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: phase == 'declare' ? _buildDeclareCenter(myDeclare) : _buildPlayCenter(cardW),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(fit: BoxFit.scaleDown, child: StatusBar(status, highlight: myDeclare || myPlay)),
            ),
            const SizedBox(height: 3),
            if (me >= 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    g.tag(
                      me,
                      active: myDeclare || myPlay,
                      size: 26,
                      sub: '${me < scores.length ? scores[me] : 0}分',
                      trailing: visibleReds.contains(me)
                          ? _pill(me < liang.length && liang[me] ? '亮十' : '红十', Colors.red.shade700, fontSize: 10)
                          : null,
                    ),
                    if (selCombo != null) ...[
                      const SizedBox(width: 6),
                      _pill(selCombo.label, Colors.deepPurple),
                    ],
                    const SizedBox(width: 8),
                    if (myDeclare) ...[
                      OutlinedButton(
                        onPressed: () => g.act({'type': 'an'}),
                        child: const Text('暗打'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () => g.act({'type': 'liang'}),
                        child: const Text('亮十（×2）'),
                      ),
                    ],
                    if (myPlay) ...[
                      OutlinedButton(
                        onPressed: lead ? null : () => g.act({'type': 'pass'}),
                        child: const Text('不要'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(onPressed: _doHint, child: const Text('提示')),
                      if (_sel.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        OutlinedButton(onPressed: () => setState(_sel.clear), child: const Text('重选')),
                      ],
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: selCombo == null ? null : () => g.act({'type': 'play', 'cards': _selCards}),
                        child: const Text('出牌'),
                      ),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 2),
              if (hand.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 10, right: 10, top: cardW * 0.25, bottom: 4),
                  child: OverlapRow(
                    itemWidth: cardW,
                    children: [
                      for (var i = 0; i < hand.length; i++)
                        _buildCard(
                          hand[i],
                          cardW,
                          selected: _sel.contains(i),
                          onTap: () => setState(() {
                            if (!_sel.remove(i)) _sel.add(i);
                          }),
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ]),
          if (phase == 'roundEnd' || phase == 'over')
            Center(child: SingleChildScrollView(child: _buildResultBanner())),
        ]);
      }),
    );
  }

  Widget _buildCard(String code, double w, {bool selected = false, VoidCallback? onTap}) {
    final isRed10 = hsIsRedTen(code);
    Widget card = PlayingCard(code, width: w, selected: selected, onTap: onTap);
    if (isRed10) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(w * 0.1),
          boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 6, spreadRadius: 1)],
        ),
        child: card,
      );
    }
    return card;
  }

  Widget _buildOpponent(
    int s,
    List<int> scores,
    List<int> counts,
    List<int> visibleReds,
    List<bool> liang,
    List<int> finish,
    int turn,
    String phase,
  ) {
    final active = phase == 'play' && turn == s && !g.over;
    final n = s < counts.length ? counts[s] : 0;
    final sc = s < scores.length ? scores[s] : 0;
    final place = finish.indexOf(s);
    final acts = v['acts'] as List?;
    final act = (acts != null && s < acts.length) ? acts[s] as Map? : null;

    Widget? badge;
    if (visibleReds.contains(s)) {
      badge = _pill(s < liang.length && liang[s] ? '亮十' : '红十', Colors.red.shade700, fontSize: 10);
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      g.tag(s, active: active, size: 28, sub: '$sc分 · 剩$n张', trailing: badge),
      const SizedBox(height: 2),
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (place >= 0) _pill('第${place + 1}名', Colors.amber.shade800, fontSize: 10),
        if (act != null && act['pass'] == true) _pill('不要', Colors.blueGrey, fontSize: 10),
        if (act != null && act['label'] != null) _pill('${act['label']}', Colors.teal, fontSize: 10),
      ]),
    ]);
  }

  Widget _buildDeclareCenter(bool myDeclare) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        PlayingCard('TH', width: 44),
        const SizedBox(width: 8),
        PlayingCard('TD', width: 44),
      ]),
      const SizedBox(height: 8),
      Text(
        myDeclare ? '你抓到了红十！是否亮十翻倍？' : '亮十阶段：等待红十玩家表态',
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ]);
  }

  Widget _buildPlayCenter(double cardW) {
    final cards = _strs(v['tableCards']);
    final ts = _int(v['tableSeat']);
    final table = v['table'] as Map?;
    final logs = _strs(v['log']);
    final recentLogs = logs.length > 2 ? logs.sublist(logs.length - 2) : logs;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (cards.isNotEmpty) ...[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildCard(c, cardW * 0.95),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _pill('${g.name(ts)} · ${table?['label'] ?? ''}', Colors.black54, fontSize: 12),
          if (table?['bomb'] == true) ...[
            const SizedBox(width: 6),
            _pill('炸弹', Colors.red.shade700, fontSize: 12),
          ],
        ]),
      ] else
        Text(
          '${g.name(_int(v['turn'], 0))} 自由领出',
          style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      if (recentLogs.isNotEmpty) ...[
        const SizedBox(height: 6),
        for (final l in recentLogs)
          Text(l, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    ]);
  }

  Widget _buildResultBanner() {
    final r = v['result'] as Map?;
    final scores = _ints(v['scores']);
    final over = v['phase'] == 'over';
    final redWin = r?['redWin'] == true;
    final order = r == null ? List.generate(g.players, (i) => i) : _ints(r['order']);
    final delta = r == null ? List.filled(g.players, 0) : _ints(r['delta']);
    final redSeats = r == null ? <int>[] : _ints(r['redSeats']);
    final notes = _strs(r?['notes']);
    final ready = (v['ready'] as List?)?.map((e) => e == true).toList();
    final me = g.seat;

    final title = over
        ? '比赛结束 · ${redWin ? '红十方' : '黑十方'}赢下末局'
        : '本局结束 · ${redWin ? '红十方获胜' : '黑十方获胜'} ${notes.join(' ')}';

    return ResultBanner(
      title,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < order.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 72, child: Text(g.name(order[i]), overflow: TextOverflow.ellipsis)),
                _pill(redSeats.contains(order[i]) ? '红十方' : '黑十方',
                    redSeats.contains(order[i]) ? Colors.red.shade700 : Colors.blueGrey),
                const SizedBox(width: 8),
                Text('第${i + 1}名'),
                const SizedBox(width: 8),
                Text(
                  delta[order[i]] >= 0 ? '+${delta[order[i]]}' : '${delta[order[i]]}',
                  style: TextStyle(
                    color: delta[order[i]] >= 0 ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text('总分 ${scores[order[i]]}'),
              ]),
            ),
          ),
        if (!over && ready != null && me >= 0 && me < ready.length && !g.replay)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton(
              onPressed: ready[me] ? null : () => g.act({'type': 'continue'}),
              child: Text(ready[me] ? '等待其他玩家…' : '继续下一局'),
            ),
          ),
      ]),
    );
  }
}
