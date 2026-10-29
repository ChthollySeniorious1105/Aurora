import 'package:aurora_shared/games/cards5/gwent.dart';
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

class GwentBoard extends StatefulWidget {
  final GameContext g;
  const GwentBoard(this.g, {super.key});

  @override
  State<GwentBoard> createState() => _GwentBoardState();
}

class _GwentBoardState extends State<GwentBoard> {
  int? _selIdx;
  int _selRow = 0;
  String _handKey = '';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;
  List<String> get hand => _strs(v['hand']);

  void _sync() {
    final k = hand.join(',');
    if (k != _handKey) {
      _handKey = k;
      _selIdx = null;
    }
    if (_selIdx != null && (_selIdx! < 0 || _selIdx! >= hand.length)) {
      _selIdx = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final phase = '${v['phase'] ?? 'play'}';
    final round = _int(v['round'], 1);
    final turn = _int(v['turn'], 0);
    final me = g.seat < 0 ? 0 : g.seat;
    final opp = 1 - me;
    final isSpectator = g.seat < 0;

    final gems = _ints(v['gems']);
    final passed = (v['passed'] as List?)?.map((e) => e == true).toList() ?? [false, false];
    final mulligansLeft = _ints(v['mulligansLeft']);
    final mulliganDone = (v['mulliganDone'] as List?)?.map((e) => e == true).toList() ?? [true, true];
    final counts = _ints(v['counts']);
    final totalPowers = _ints(v['totalPowers']);
    final weather = (v['weather'] as List?)?.map((e) => e == true).toList() ?? [false, false, false];
    final hornsRaw = v['horns'] as List?;
    final rowPowersRaw = v['rowPowers'] as List?;
    final rowUnitsRaw = v['rowUnitPowers'] as List?;

    final myMulligan = !isSpectator && phase == 'mulligan' && me < mulliganDone.length && !mulliganDone[me] && !g.over;
    final myPlay = !isSpectator && phase == 'play' && turn == me && !(me < passed.length && passed[me]) && !g.over;

    final selCard = (_selIdx != null && _selIdx! < hand.length) ? hand[_selIdx!] : null;
    final selDef = selCard != null ? gwDef(selCard) : null;

    String status;
    if (phase == 'mulligan') {
      final left = me < mulligansLeft.length ? mulligansLeft[me] : 0;
      status = myMulligan ? '开局调度（剩余 $left 次）：点击手牌可更换，或点击【完成调度】' : '等待对手完成手牌调度…';
    } else if (phase == 'play') {
      if (myPlay) {
        status = selDef != null
            ? '已选【${selDef.name}】：${selDef.desc}'
            : '轮到你行动：选择 1 张手牌打出，或选择【放弃跟牌】';
      } else {
        status = '等待 ${g.name(turn)} 行动…';
      }
    } else {
      status = '比赛结束';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, c) {
        final isShort = c.maxHeight < 460;
        final cardW = (c.maxWidth / (c.maxWidth < 500 ? 8.5 : 13.5)).clamp(34.0, isShort ? 42.0 : 58.0);
        return Stack(fit: StackFit.expand, children: [
          Column(children: [
            const SizedBox(height: 3),
            // 顶部信息栏 + 对手状态合并，节省纵向空间
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _pill('昆特牌 · 第 $round/3 局', Colors.amber.shade900),
                  const SizedBox(width: 6),
                  if (weather[0]) _pill('❄冰霜(近战=1)', Colors.lightBlue.shade700),
                  if (weather[1]) _pill('🌫浓雾(远程=1)', Colors.blueGrey.shade600),
                  if (weather[2]) _pill('🌧大雨(攻城=1)', Colors.indigo.shade700),
                  if (!weather.any((w) => w)) _pill('☀晴朗', Colors.teal.shade700),
                  const SizedBox(width: 10),
                  _buildPlayerSummary(opp, gems, totalPowers, counts, passed, turn == opp && phase == 'play'),
                ]),
              ),
            ),
            const SizedBox(height: 2),
            // 六排战场区域（对手3排：攻城2、远程1、近战0；己方3排：近战0、远程1、攻城2）
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  children: [
                    for (final r in const [2, 1, 0])
                      Expanded(
                        child: _buildBattleRow(
                          seat: opp,
                          row: r,
                          isMine: false,
                          weatherOn: r < weather.length && weather[r],
                          hornOn: _hasHorn(hornsRaw, opp, r),
                          power: _getRowPower(rowPowersRaw, opp, r),
                          units: _getRowUnits(rowUnitsRaw, opp, r),
                        ),
                      ),
                    const Divider(height: 3, thickness: 1, color: Colors.amberAccent),
                    for (final r in const [0, 1, 2])
                      Expanded(
                        child: _buildBattleRow(
                          seat: me,
                          row: r,
                          isMine: true,
                          selectedForHorn: selDef?.type == 'horn' && _selRow == r,
                          weatherOn: r < weather.length && weather[r],
                          hornOn: _hasHorn(hornsRaw, me, r),
                          power: _getRowPower(rowPowersRaw, me, r),
                          units: _getRowUnits(rowUnitsRaw, me, r),
                          onTap: () => setState(() => _selRow = r),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: StatusBar(status, highlight: myMulligan || myPlay),
              ),
            ),
            const SizedBox(height: 2),
            // 己方状态与操作按钮栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _buildPlayerSummary(me, gems, totalPowers, counts, passed, myPlay || myMulligan),
                  const SizedBox(width: 10),
                  if (myMulligan) ...[
                    if (selCard != null) ...[
                      FilledButton(
                        onPressed: () => g.act({'type': 'mulligan', 'card': selCard}),
                        child: Text('更换【${selDef?.name ?? ''}】'),
                      ),
                      const SizedBox(width: 6),
                    ],
                    OutlinedButton(
                      onPressed: () => g.act({'type': 'done'}),
                      child: const Text('完成调度'),
                    ),
                  ],
                  if (myPlay) ...[
                    if (selDef?.type == 'horn') ...[
                      for (var r = 0; r < 3; r++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            label: Text('${kGwRowNames[r]}排'),
                            selected: _selRow == r,
                            onSelected: (_) => setState(() => _selRow = r),
                          ),
                        ),
                    ],
                    FilledButton(
                      onPressed: selCard == null
                          ? null
                          : () => g.act({
                                'type': 'play',
                                'card': selCard,
                                if (selDef?.type == 'horn') 'row': _selRow,
                              }),
                      child: Text(selDef != null ? '打出【${selDef.name}】' : '打出卡牌'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => g.act({'type': 'pass'}),
                      child: const Text('放弃跟牌 (Pass)'),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 2),
            if (!isSpectator && hand.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 10, right: 10, top: cardW * 0.2, bottom: 4),
                child: OverlapRow(
                  itemWidth: cardW,
                  children: [
                    for (var i = 0; i < hand.length; i++)
                      _buildGwCard(
                        hand[i],
                        cardW,
                        selected: _selIdx == i,
                        onTap: () {
                          if (myMulligan) {
                            g.act({'type': 'mulligan', 'card': hand[i]});
                          } else {
                            setState(() => _selIdx = _selIdx == i ? null : i);
                          }
                        },
                      ),
                  ],
                ),
              )
            else
              const SizedBox(height: 4),
          ]),
          if (phase == 'over')
            Center(child: SingleChildScrollView(child: _buildResultBanner())),
        ]);
      }),
    );
  }

  bool _hasHorn(List? hornsRaw, int s, int r) {
    if (hornsRaw == null || s >= hornsRaw.length) return false;
    final rowList = hornsRaw[s] as List?;
    if (rowList == null || r >= rowList.length) return false;
    return rowList[r] == true;
  }

  int _getRowPower(List? rowPowersRaw, int s, int r) {
    if (rowPowersRaw == null || s >= rowPowersRaw.length) return 0;
    final rowList = rowPowersRaw[s] as List?;
    if (rowList == null || r >= rowList.length) return 0;
    return _int(rowList[r], 0);
  }

  List<Map> _getRowUnits(List? rowUnitsRaw, int s, int r) {
    if (rowUnitsRaw == null || s >= rowUnitsRaw.length) return const [];
    final rowList = rowUnitsRaw[s] as List?;
    if (rowList == null || r >= rowList.length) return const [];
    return (rowList[r] as List?)?.cast<Map>() ?? const [];
  }

  Widget _buildPlayerSummary(
    int s,
    List<int> gems,
    List<int> totalPowers,
    List<int> counts,
    List<bool> passed,
    bool active,
  ) {
    final gCount = s < gems.length ? gems[s] : 2;
    final tot = s < totalPowers.length ? totalPowers[s] : 0;
    final hc = s < counts.length ? counts[s] : 0;
    final isPass = s < passed.length && passed[s];

    return Row(mainAxisSize: MainAxisSize.min, children: [
      g.tag(s, active: active, size: 24, sub: '手牌 $hc'),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFD4AF37),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '总战力 $tot',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
      const SizedBox(width: 6),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 2; i++)
            Icon(
              Icons.diamond,
              size: 16,
              color: i < gCount ? Colors.redAccent : Colors.white24,
            ),
        ],
      ),
      if (isPass) ...[
        const SizedBox(width: 6),
        _pill('已放弃跟牌', Colors.blueGrey),
      ],
    ]);
  }

  Widget _buildBattleRow({
    required int seat,
    required int row,
    required bool isMine,
    required bool weatherOn,
    required bool hornOn,
    required int power,
    required List<Map> units,
    bool selectedForHorn = false,
    VoidCallback? onTap,
  }) {
    final rowIcon = switch (row) {
      0 => '⚔近战',
      1 => '🏹远程',
      _ => '💣攻城',
    };
    final bg = weatherOn
        ? Colors.lightBlue.withValues(alpha: 0.25)
        : (isMine ? Colors.brown.withValues(alpha: 0.25) : Colors.blueGrey.withValues(alpha: 0.25));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selectedForHorn ? Colors.amber : (weatherOn ? Colors.lightBlueAccent : Colors.white24),
            width: selectedForHorn ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$power',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
                Text(rowIcon, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                if (hornOn) ...[
                  const SizedBox(width: 4),
                  _pill('🎺×2', Colors.orange.shade800, fontSize: 9),
                ],
              ]),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: units.isEmpty
                  ? const SizedBox()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final u in units)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: _buildUnitChip(u),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitChip(Map u) {
    final hero = u['hero'] == true;
    final baseP = _int(u['power'], 0);
    final curP = _int(u['currentPower'], baseP);
    final name = '${u['name'] ?? ''}';
    final ability = '${u['ability'] ?? 'none'}';

    final pColor = curP > baseP
        ? Colors.greenAccent
        : (curP < baseP ? Colors.redAccent : (hero ? Colors.amber : Colors.white));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: hero ? const Color(0xFF3E2723) : const Color(0xFF263238),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: hero ? const Color(0xFFFFD700) : Colors.white54, width: hero ? 1.8 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
          child: Text('$curP', style: TextStyle(color: pColor, fontWeight: FontWeight.w900, fontSize: 11)),
        ),
        const SizedBox(width: 4),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        if (ability != 'none') ...[
          const SizedBox(width: 3),
          Text(
            switch (ability) {
              'spy' => '👁',
              'medic' => '✚',
              'bond' => '🤝',
              'muster' => '⚔',
              'scorch' => '🔥',
              _ => '',
            },
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ]),
    );
  }

  Widget _buildGwCard(String code, double w, {bool selected = false, VoidCallback? onTap}) {
    final d = gwDef(code);
    final isUnit = d.type == 'unit';
    final hero = d.hero;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: w,
        height: w * 1.38,
        transform: Matrix4.translationValues(0, selected ? -w * 0.25 : 0, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hero
                ? const [Color(0xFF4E342E), Color(0xFF212121)]
                : (isUnit
                    ? const [Color(0xFFFFF8E1), Color(0xFFFFECB3)]
                    : const [Color(0xFFE3F2FD), Color(0xFFBBDEFB)]),
          ),
          borderRadius: BorderRadius.circular(w * 0.12),
          border: Border.all(
            color: selected ? Colors.amberAccent : (hero ? const Color(0xFFFFD700) : Colors.black45),
            width: selected || hero ? 2.2 : 1,
          ),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))],
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: hero ? const Color(0xFFFFD700) : Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isUnit ? '${d.power}' : '★',
                          style: TextStyle(
                            color: hero ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (d.row >= 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          kGwRowNames[d.row],
                          style: TextStyle(
                            color: hero ? Colors.amberAccent : Colors.black54,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    d.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: hero ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    switch (d.ability) {
                      'spy' => '间谍+2牌',
                      'medic' => '医护复活',
                      'bond' => '同袍翻倍',
                      'muster' => '集结召唤',
                      'scorch' => '灼烧强敌',
                      _ => hero ? '英雄免疫' : (d.type == 'weather' ? '天气' : (d.type == 'horn' ? '号角×2' : '单位')),
                    },
                    style: TextStyle(
                      color: hero ? Colors.amberAccent : Colors.deepPurple,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    final r = v['result'] as Map?;
    final reason = '${r?['reason'] ?? '比赛结束'}';
    final hist = (r?['history'] as List?)?.cast<Map>() ?? const <Map>[];

    return ResultBanner(
      reason,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final h in hist)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '第 ${h['round']} 局：${g.name(0)} ${h['p0']} 点  vs  ${g.name(1)} ${h['p1']} 点',
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ]),
    );
  }
}
