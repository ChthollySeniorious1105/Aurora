import 'package:aurora_shared/games/cards5/sanguosha.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

List<int> _ints(Object? l) => [for (final x in (l as List? ?? const [])) (x as num).toInt()];
List<String> _strs(Object? l) => [for (final x in (l as List? ?? const [])) '$x'];
int _int(Object? x, [int d = -1]) => x is num ? x.toInt() : d;

Widget _pill(String t, Color c, {double fontSize = 11}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(t, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: fontSize)),
    );

Color _roleColor(String r) => switch (r) {
      'lord' => const Color(0xFFD4AF37),
      'loyalist' => Colors.orange.shade800,
      'rebel' => Colors.red.shade700,
      'spy' => Colors.blue.shade700,
      _ => Colors.blueGrey,
    };

Color _kingdomColor(String k) => switch (k) {
      '蜀' => Colors.red.shade700,
      '魏' => Colors.indigo.shade700,
      '吴' => Colors.green.shade700,
      _ => Colors.purple.shade700,
    };

class SanguoshaBoard extends StatefulWidget {
  final GameContext g;
  const SanguoshaBoard(this.g, {super.key});

  @override
  State<SanguoshaBoard> createState() => _SanguoshaBoardState();
}

class _SanguoshaBoardState extends State<SanguoshaBoard> {
  final Set<int> _sel = {};
  int? _target;
  int? _target2;
  String _handKey = '';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;
  List<String> get hand => _strs(v['hand']);

  void _sync() {
    final k = hand.join(',');
    if (k != _handKey) {
      _handKey = k;
      _sel.clear();
    }
    final alive = (v['alive'] as List?)?.map((e) => e == true).toList() ?? const <bool>[];
    if (_target != null && (_target! < 0 || _target! >= alive.length || !alive[_target!] || _target == g.seat)) {
      _target = null;
    }
    if (_target2 != null && (_target2! < 0 || _target2! >= alive.length || !alive[_target2!] || _target2 == g.seat)) {
      _target2 = null;
    }
  }

  List<String> get _selCards {
    final h = hand;
    return [for (final i in (_sel.toList()..sort())) if (i >= 0 && i < h.length) h[i]];
  }

  int _defaultTarget(List<bool> alive, List<bool> inRange, {bool requireRange = false}) {
    if (_target != null && alive[_target!]) {
      if (!requireRange || inRange[_target!]) return _target!;
    }
    for (var s = 0; s < g.players; s++) {
      if (s != g.seat && s < alive.length && alive[s]) {
        if (!requireRange || (s < inRange.length && inRange[s])) return s;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final phase = '${v['phase'] ?? 'play'}';
    final turn = _int(v['turn'], 0);
    final me = g.seat;
    final roles = _strs(v['roles']);
    final myRole = '${v['myRole'] ?? ''}';
    final hp = _ints(v['hp']);
    final maxHp = _ints(v['maxHp']);
    final alive = (v['alive'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, true);
    final counts = _ints(v['counts']);
    final distances = _ints(v['distances']);
    final inRange = (v['inRange'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, false);
    final generals = (v['generals'] as List?)?.cast<Map>() ?? const <Map>[];
    final equips = (v['equips'] as List?)?.cast<Map>() ?? const <Map>[];
    final judges = (v['judges'] as List?) ?? const [];
    final pending = v['pending'] as Map?;

    var myResponder = false;
    var responderSeat = turn;
    if (pending != null) {
      final pType = '${pending['type']}';
      final pQueue = _ints(pending['queue']);
      responderSeat = (pType == 'wuxie' || pType == 'dying')
          ? (pQueue.isNotEmpty ? pQueue.first : _int(pending['target']))
          : _int(pending['target']);
      myResponder = me >= 0 && responderSeat == me && !g.over;
    }
    final myPlay = phase == 'play' && pending == null && me >= 0 && turn == me && !g.over;
    final myDiscard = phase == 'discard' && pending == null && me >= 0 && turn == me && !g.over;
    final picked = (v['picked'] as List?)?.map((e) => e == true).toList() ?? const <bool>[];
    final myPick = phase == 'pick' && me >= 0 && me < picked.length && !picked[me] && !g.over;

    String status;
    if (phase == 'pick') {
      status = myPick ? '请选择你的出战武将' : '等待其他玩家选将…';
    } else if (pending != null) {
      final pType = '${pending['type']}';
      final cardName = '${pending['cardName'] ?? ''}';
      if (pType == 'dying') {
        final dyingS = _int(pending['dyingSeat']);
        status = '${g.name(dyingS)} 濒死！${myResponder ? '请使用【桃】救援或放弃' : '等待 ${g.name(responderSeat)} 响应求桃'}';
      } else if (pType == 'wuxie') {
        status = '锦囊【$cardName】即将生效：${myResponder ? '是否打出【无懈可击】？' : '等待无懈可击响应'}';
      } else if (pType == 'shan') {
        status = '响应【$cardName】：${myResponder ? '请打出【闪】或放弃承受伤害' : '等待 ${g.name(responderSeat)} 出【闪】'}';
      } else {
        status = '响应【$cardName】：${myResponder ? '请打出【杀】或放弃承受伤害' : '等待 ${g.name(responderSeat)} 出【杀】'}';
      }
    } else if (phase == 'discard') {
      final need = hand.length - (me >= 0 && me < hp.length ? (hp[me] > 0 ? hp[me] : 0) : 0);
      status = myDiscard ? '弃牌阶段：请选择 $need 张手牌弃置' : '等待 ${g.name(turn)} 弃牌';
    } else if (phase == 'play') {
      status = myPlay ? '你的出牌阶段：选牌并点击目标角色出牌，或发动武将技能' : '${g.name(turn)} 的出牌阶段';
    } else {
      status = '游戏结束';
    }

    final others = g.seatsFromMe().where((s) => s != me).toList();

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, c) {
        final isShort = c.maxHeight < 460;
        final cardW = (c.maxWidth / (c.maxWidth < 500 ? 7.5 : 13)).clamp(38.0, isShort ? 46.0 : 62.0);
        return Stack(fit: StackFit.expand, children: [
          Column(children: [
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _pill('三国杀', Colors.red.shade900),
                  const SizedBox(width: 6),
                  _pill('第 ${v['roundCount'] ?? 1} 轮', Colors.brown),
                  const SizedBox(width: 6),
                  _pill('牌堆 ${v['deckCount'] ?? 0}', Colors.blueGrey),
                  if (myRole.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _pill('我的身份：${sgRoleName(myRole)}', _roleColor(myRole)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 3),
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
                        child: _buildOpponentPanel(
                          s,
                          turn: turn,
                          responderSeat: responderSeat,
                          roles: roles,
                          generals: generals,
                          hp: hp,
                          maxHp: maxHp,
                          alive: alive,
                          counts: counts,
                          distances: distances,
                          inRange: inRange,
                          equips: equips,
                          judges: judges,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: phase == 'pick'
                            ? _buildPickGeneralCenter(myPick)
                            : _buildBattleCenter(turn, generals, pending),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: StatusBar(status, highlight: myPlay || myDiscard || myResponder || myPick),
              ),
            ),
            const SizedBox(height: 2),
            if (me >= 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildMyControlBar(
                    me,
                    myPlay: myPlay,
                    myDiscard: myDiscard,
                    myResponder: myResponder,
                    pending: pending,
                    generals: generals,
                    hp: hp,
                    maxHp: maxHp,
                    alive: alive,
                    inRange: inRange,
                    equips: equips,
                    judges: judges,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              if (hand.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: 10, right: 10, top: cardW * 0.22, bottom: 4),
                  child: OverlapRow(
                    itemWidth: cardW,
                    children: [
                      for (var i = 0; i < hand.length; i++)
                        _buildSgCard(
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
                const SizedBox(height: 6),
            ],
          ]),
          if (phase == 'over')
            Center(child: SingleChildScrollView(child: _buildResultBanner())),
        ]);
      }),
    );
  }

  Widget _buildOpponentPanel(
    int s, {
    required int turn,
    required int responderSeat,
    required List<String> roles,
    required List<Map> generals,
    required List<int> hp,
    required List<int> maxHp,
    required List<bool> alive,
    required List<int> counts,
    required List<int> distances,
    required List<bool> inRange,
    required List<Map> equips,
    required List judges,
  }) {
    final isAlive = s < alive.length ? alive[s] : true;
    final gen = s < generals.length ? generals[s] : const {};
    final role = s < roles.length ? roles[s] : 'unknown';
    final curHp = s < hp.length ? hp[s] : 0;
    final mHp = s < maxHp.length ? maxHp[s] : 4;
    final nCards = s < counts.length ? counts[s] : 0;
    final dist = s < distances.length ? distances[s] : 1;
    final atk = s < inRange.length && inRange[s];
    final eq = s < equips.length ? equips[s] : const {};
    final jList = s < judges.length ? _strs(judges[s]) : const <String>[];
    final selectedTarget = _target == s || _target2 == s;
    final active = (turn == s || responderSeat == s) && !g.over;

    return GestureDetector(
      onTap: !isAlive
          ? null
          : () => setState(() {
                if (_target == s) {
                  _target = null;
                } else if (_target == null) {
                  _target = s;
                } else {
                  _target2 = _target;
                  _target = s;
                }
              }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selectedTarget
              ? Colors.amber.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: isAlive ? 0.35 : 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedTarget ? Colors.amber : (active ? Colors.greenAccent : Colors.white24),
            width: selectedTarget || active ? 2 : 1,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            g.tag(
              s,
              active: active,
              size: 24,
              sub: '${gen['name'] ?? ''} · ${gen['skillName'] ?? ''}',
              trailing: _pill(
                role == 'unknown' ? '身份?' : sgRoleName(role),
                _roleColor(role),
                fontSize: 10,
              ),
            ),
          ]),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (!isAlive)
              _pill('已阵亡', Colors.grey.shade800, fontSize: 10)
            else ...[
              _pill('HP $curHp/$mHp', curHp <= 1 ? Colors.red : Colors.green.shade700, fontSize: 10),
              const SizedBox(width: 4),
              _pill('手牌 $nCards', Colors.blueGrey, fontSize: 10),
              const SizedBox(width: 4),
              _pill('距$dist${atk ? '·可杀' : ''}', atk ? Colors.deepOrange : Colors.black54, fontSize: 10),
            ],
            if (selectedTarget) ...[
              const SizedBox(width: 4),
              _pill(_target == s ? '目标1' : '目标2', Colors.amber.shade900, fontSize: 10),
            ],
          ]),
          if (eq['weapon'] != null || eq['armor'] != null || eq['minusHorse'] != null || eq['plusHorse'] != null || jList.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (eq['weapon'] != null) _pill(sgCardName('${eq['weapon']}'), Colors.red.shade900, fontSize: 9),
              if (eq['armor'] != null) ...[
                const SizedBox(width: 2),
                _pill(sgCardName('${eq['armor']}'), Colors.teal.shade800, fontSize: 9),
              ],
              if (eq['minusHorse'] != null) ...[
                const SizedBox(width: 2),
                _pill('-1马', Colors.brown, fontSize: 9),
              ],
              if (eq['plusHorse'] != null) ...[
                const SizedBox(width: 2),
                _pill('+1马', Colors.indigo, fontSize: 9),
              ],
              if (jList.isNotEmpty) ...[
                const SizedBox(width: 2),
                _pill('乐', Colors.purple, fontSize: 9),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _buildPickGeneralCenter(bool myPick) {
    final choices = (v['generalChoices'] as List?)?.cast<Map>() ?? const <Map>[];
    if (!myPick || choices.isEmpty) {
      return const Text('等待所有玩家完成武将选择…', style: TextStyle(color: Colors.white, fontSize: 16));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('请选择你的出战武将', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final gMap in choices)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                onTap: () => g.act({'type': 'pick', 'general': gMap['id']}),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _pill('${gMap['kingdom']}', _kingdomColor('${gMap['kingdom']}')),
                      const SizedBox(width: 6),
                      Text('${gMap['name']}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    Text('体力上限：${gMap['maxHp']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('【${gMap['skillName']}】${gMap['skillDesc']}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    ]);
  }

  Widget _buildBattleCenter(int turn, List<Map> generals, Map? pending) {
    final logs = _strs(v['log']);
    final recent = logs.length > 4 ? logs.sublist(logs.length - 4) : logs;
    final curGen = turn >= 0 && turn < generals.length ? generals[turn] : const {};

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (curGen.isNotEmpty)
        Row(mainAxisSize: MainAxisSize.min, children: [
          _pill('${curGen['kingdom'] ?? '群'}', _kingdomColor('${curGen['kingdom']}')),
          const SizedBox(width: 6),
          Text(
            '当前回合：${g.name(turn)}（${curGen['name']} · ${curGen['skillName']}）',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ]),
      if (pending != null) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.deepOrange.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orangeAccent),
          ),
          child: Text(
            '正在结算【${pending['cardName']}】→ 目标：${g.name(_int(pending['target']))}',
            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
      const SizedBox(height: 6),
      for (final l in recent)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ),
    ]);
  }

  Widget _buildMyControlBar(
    int me, {
    required bool myPlay,
    required bool myDiscard,
    required bool myResponder,
    required Map? pending,
    required List<Map> generals,
    required List<int> hp,
    required List<int> maxHp,
    required List<bool> alive,
    required List<bool> inRange,
    required List<Map> equips,
    required List judges,
  }) {
    final myGen = me < generals.length ? generals[me] : const {};
    final genId = '${myGen['id'] ?? ''}';
    final curHp = me < hp.length ? hp[me] : 4;
    final mHp = me < maxHp.length ? maxHp[me] : 4;
    final eq = me < equips.length ? equips[me] : const {};
    final sel = _selCards;
    final firstCard = sel.isNotEmpty ? sel.first : null;
    final firstKind = firstCard != null ? sgKind(firstCard) : '';

    return Row(mainAxisSize: MainAxisSize.min, children: [
      g.tag(
        me,
        active: myPlay || myDiscard || myResponder,
        size: 26,
        sub: '${myGen['name'] ?? ''} · HP $curHp/$mHp',
        trailing: _pill('${myGen['skillName'] ?? ''}', _kingdomColor('${myGen['kingdom']}')),
      ),
      if (eq['weapon'] != null) ...[
        const SizedBox(width: 4),
        _pill(sgCardName('${eq['weapon']}'), Colors.red.shade900, fontSize: 10),
      ],
      if (eq['armor'] != null) ...[
        const SizedBox(width: 4),
        _pill(sgCardName('${eq['armor']}'), Colors.teal.shade800, fontSize: 10),
      ],
      const SizedBox(width: 8),
      if (myResponder && pending != null) ...[
        FilledButton(
          onPressed: firstCard == null
              ? null
              : () => g.act({'type': '${pending['type']}', 'card': firstCard}),
          child: Text('打出 ${firstCard != null ? sgCardName(firstCard) : '响应牌'}'),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: () => g.act({'type': 'pass'}),
          child: const Text('放弃响应'),
        ),
      ],
      if (myDiscard) ...[
        FilledButton(
          onPressed: sel.isEmpty ? null : () => g.act({'type': 'discard', 'cards': sel}),
          child: Text('确认弃牌 (${sel.length})'),
        ),
      ],
      if (myPlay) ...[
        FilledButton(
          onPressed: firstCard == null
              ? null
              : () {
                  final needRange = firstKind == 'sha';
                  final t = _defaultTarget(alive, inRange, requireRange: needRange);
                  g.act({'type': 'play', 'card': firstCard, if (t >= 0) 'target': t});
                },
          child: const Text('出牌'),
        ),
        // 武将主动/转化技能按钮
        if (genId == 'liubei' && sel.isNotEmpty) ...[
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () {
              final t = _defaultTarget(alive, inRange);
              if (t >= 0) g.act({'type': 'skill', 'skill': 'rende', 'cards': sel, 'target': t});
            },
            child: const Text('仁德'),
          ),
        ],
        if (genId == 'sunquan' && v['zhihengUsed'] != true && sel.isNotEmpty) ...[
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => g.act({'type': 'skill', 'skill': 'zhiheng', 'cards': sel}),
            child: const Text('制衡'),
          ),
        ],
        if ((genId == 'guanyu' || genId == 'zhaoyun') && firstCard != null) ...[
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () {
              final t = _defaultTarget(alive, inRange, requireRange: true);
              if (t >= 0) g.act({'type': 'play', 'card': firstCard, 'as': 'sha', 'target': t});
            },
            child: Text(genId == 'guanyu' ? '武圣(当杀)' : '龙胆(当杀)'),
          ),
        ],
        if (genId == 'ganning' && firstCard != null) ...[
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () {
              final t = _defaultTarget(alive, inRange);
              if (t >= 0) g.act({'type': 'skill', 'skill': 'qixi', 'card': firstCard, 'target': t});
            },
            child: const Text('奇袭(当拆)'),
          ),
        ],
        if (genId == 'diaochan' && v['lijianUsed'] != true && firstCard != null && _target != null && _target2 != null) ...[
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => g.act({
              'type': 'skill',
              'skill': 'lijian',
              'card': firstCard,
              'targets': [_target, _target2],
            }),
            child: const Text('离间'),
          ),
        ],
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: () => g.act({'type': 'endPlay'}),
          child: const Text('结束回合'),
        ),
      ],
    ]);
  }

  Widget _buildSgCard(String card, double w, {bool selected = false, VoidCallback? onTap}) {
    final red = sgIsRed(card);
    final suit = sgSuitSymbol(card);
    final rStr = sgRankStr(sgRank(card));
    final title = sgCardName(card);
    final cat = sgCategory(card);
    final catLabel = switch (cat) {
      'basic' => '基本',
      'scroll' => '锦囊',
      'delay' => '延时',
      _ => '装备',
    };
    final catColor = switch (cat) {
      'basic' => const Color(0xFF5D4037),
      'scroll' || 'delay' => const Color(0xFF1565C0),
      _ => const Color(0xFF2E7D32),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: w,
        height: w * 1.4,
        transform: Matrix4.translationValues(0, selected ? -w * 0.25 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(w * 0.12),
          border: Border.all(color: selected ? Colors.amber : Colors.black38, width: selected ? 2.2 : 1),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2))],
        ),
        padding: EdgeInsets.all(w * 0.06),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 64,
            height: 88,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$suit$rStr',
                        style: TextStyle(
                          color: red ? Colors.red.shade700 : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(4)),
                        child: Text(catLabel, style: const TextStyle(color: Colors.white, fontSize: 8)),
                      ),
                    ],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    final r = v['result'] as Map?;
    final winLabel = '${r?['winLabel'] ?? '游戏结束'}';
    final roles = _strs(r?['roles'] ?? v['roles']);
    final generals = (v['generals'] as List?)?.cast<Map>() ?? const <Map>[];
    final winners = _ints(r?['winners']);

    return ResultBanner(
      winLabel,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var s = 0; s < g.players; s++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 72, child: Text(g.name(s), overflow: TextOverflow.ellipsis)),
                _pill(s < roles.length ? sgRoleName(roles[s]) : '', _roleColor(s < roles.length ? roles[s] : '')),
                const SizedBox(width: 8),
                Text(s < generals.length ? '${generals[s]['name']}' : ''),
                const SizedBox(width: 8),
                _pill(winners.contains(s) ? '胜利' : '落败', winners.contains(s) ? Colors.green : Colors.blueGrey),
              ]),
            ),
          ),
      ]),
    );
  }
}
