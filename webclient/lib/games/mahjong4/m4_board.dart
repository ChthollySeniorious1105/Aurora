import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/mahjong_table.dart';
import '../../widgets/pieces.dart';

const suitLabels = ['万', '筒', '条'];
const honorLabels = ['东', '南', '西', '北', '白', '发', '中'];
const windLabels = ['东', '南', '西', '北'];

List<String> codesOf(Object? l) => l is List ? [for (final e in l) '$e'] : <String>[];

int codeSuit(String c) => c.length == 2 ? 'mps'.indexOf(c[1]) : -1;

int codeOrder(String c, {String? specialFirst}) {
  if (specialFirst != null && c == specialFirst) return -10;
  if (c.length != 2) return 999;
  final n = int.tryParse(c[0]) ?? 0;
  return switch (c[1]) {
    'm' => n,
    'p' => 10 + n,
    's' => 20 + n,
    'z' => 30 + n,
    _ => 999,
  };
}

List<String> sortCodes(Iterable<String> codes, {String? specialFirst}) =>
    codes.toList()..sort((a, b) => codeOrder(a, specialFirst: specialFirst).compareTo(codeOrder(b, specialFirst: specialFirst)));

String tileLabel(String c) {
  if (c.length != 2) return '?';
  final n = (int.tryParse(c[0]) ?? 1).clamp(1, 9);
  return switch (c[1]) {
    'm' || 'p' || 's' => '${'一二三四五六七八九'[n - 1]}${suitLabels['mps'.indexOf(c[1])]}',
    'z' => honorLabels[(n - 1).clamp(0, 6)],
    _ => '?',
  };
}

Widget m4Meld(Map m, double tw) {
  final kind = m['kind'] as String? ?? 'peng';
  final tiles = codesOf(m['tiles']);
  final fallbackTile = m['tile'] as String? ?? 'back';
  final list = tiles.isNotEmpty ? tiles : List.filled(kind == 'peng' || kind == 'pon' ? 3 : 4, fallbackTile);
  final claimed = m['claimed'] as String?;
  var claimedIdx = -1;
  if (claimed != null && kind != 'agang' && kind != 'ankan') {
    claimedIdx = kind == 'chi' ? list.indexOf(claimed) : 1;
  }
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: tw * 0.1),
    child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < list.length; i++)
        MahjongTile(
          list[i],
          width: tw,
          faceDown: list[i] == 'back' || ((kind == 'agang' || kind == 'ankan') && (i == 0 || i == 3)),
          sideways: i == claimedIdx,
        ),
    ]),
  );
}

/// Shared board for `guizhoumj`, `harbinmj`, and `fujianmj`.
class M4Board extends StatefulWidget {
  final GameContext g;
  const M4Board(this.g, {super.key});
  @override
  State<M4Board> createState() => _M4BoardState();
}

class _M4BoardState extends State<M4Board> {
  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  bool _hideSettle = false;
  int _settleHand = -1;

  Map<String, dynamic> seatV(int s) => ((v['seats'] as List)[s] as Map).cast<String, dynamic>();
  String get phase => v['phase'] as String? ?? 'act';
  String get rule => v['rule'] as String? ?? 'guizhoumj';

  String get title => switch (rule) {
        'guizhoumj' => '贵阳捉鸡麻将',
        'harbinmj' => '哈尔滨麻将',
        'fujianmj' => '福建游金麻将',
        _ => '麻将',
      };

  @override
  Widget build(BuildContext context) {
    if (v['seats'] == null) return const Center(child: CircularProgressIndicator());
    final settle = v['settle'] as Map?;
    final sh = settle == null ? -1 : (settle['hand'] as num).toInt();
    if (sh != _settleHand) {
      _settleHand = sh;
      _hideSettle = false;
    }
    final n = (v['seats'] as List).length;
    final base = g.seat < 0 ? 0 : g.seat;
    final pos = <int, int>{for (var i = 0; i < n; i++) (base + i) % n: i};
    final ev = (v['event'] as Map?)?.cast<String, dynamic>();
    final callText = mjEventLabel(ev?['t']);
    final callSeat = (ev?['seat'] as num?)?.toInt() ?? -1;
    final callAlign = callSeat < 0
        ? Alignment.center
        : switch (pos[callSeat] ?? 0) {
            0 => const Alignment(0, 0.45),
            1 => const Alignment(0.6, 0),
            2 => const Alignment(0, -0.55),
            _ => const Alignment(-0.6, 0),
          };
    final showSettle = settle != null && (phase == 'settle' || phase == 'over');

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final handTile = [w / 19.0, h * 0.072, 50.0].reduce(math.min);
      final barH = handTile * 4 / 3 + handTile * 0.5 + 62;
      final tableH = math.max(150.0, h - barH - 36);
      final sq = math.min(w, tableH);
      return MjTableBackground(
        felt: g.table,
        child: Stack(children: [
          Column(children: [
            SizedBox(height: 34, child: Center(child: _status())),
            SizedBox(
              height: tableH,
              child: Stack(children: [
                Center(
                  child: SizedBox(
                    width: sq,
                    height: sq,
                    child: Stack(children: [
                      Center(child: _centerPanel(sq, pos)),
                      for (var s = 0; s < n; s++)
                        Positioned.fill(
                          child: RotatedBox(quarterTurns: const [0, 3, 2, 1][pos[s]!], child: _side(s, pos[s]!, sq)),
                        ),
                    ]),
                  ),
                ),
                for (var s = 0; s < n; s++) _tagFor(s, pos[s]!, w),
              ]),
            ),
          ]),
          _toggles(w, tableH, sq),
          Positioned.fill(child: M4HandBar(g: g, v: v, tileW: handTile)),
          Positioned.fill(child: MjCallBanner(text: callText, eventKey: ev?['seq'], alignment: callAlign)),
          if (showSettle && !_hideSettle) ...[
            Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.45))),
            Positioned.fill(
              child: MjResultEntrance(
                key: ValueKey('settle$sh$phase'),
                child: Center(child: M4SettlePanel(g: g, view: v, onHide: () => setState(() => _hideSettle = true))),
              ),
            ),
          ],
          if (showSettle && _hideSettle)
            Positioned(
              top: 40,
              right: 8,
              child: FilledButton.icon(
                onPressed: () => setState(() => _hideSettle = false),
                icon: const Icon(Icons.receipt_long),
                label: Text(phase == 'over' ? '最终结算' : '本局结算'),
              ),
            ),
        ]),
      );
    });
  }

  Widget _toggles(double w, double tableH, double sq) {
    if (g.seat < 0) return const SizedBox.shrink();
    final side = (w - sq) / 2;
    if (side >= 110) return Positioned(left: 8, top: 34 + tableH / 2 - 48, child: const MjAutoToggles());
    final free = (tableH - sq) / 2 - 46;
    if (free < 40) return const SizedBox.shrink();
    return Positioned(
      left: 8,
      top: 34 + (tableH + sq) / 2 + 2,
      height: free,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topLeft, child: const MjAutoToggles()),
    );
  }

  Widget _status() {
    final me = (v['me'] as Map?)?.cast<String, dynamic>();
    final seat = g.seat;
    var text = '${v['last'] ?? ''}';
    var hi = false;
    switch (phase) {
      case 'act':
        if (seat >= 0 && v['turn'] == seat) {
          hi = true;
          final sv = seatV(seat);
          if (sv['ting'] == true) {
            text = '已报听：可摸宝/自摸或摸切打出';
          } else if (((sv['swimState'] as num?)?.toInt() ?? 0) > 0) {
            final st = (sv['swimState'] as num).toInt();
            text = '游金中（${const ['', '单游', '双游', '三游'][st.clamp(0, 3)]}）：自摸任意牌即赢！';
          } else {
            text = '轮到你出牌 · ${mjDiscardHint()}';
          }
        } else {
          text = '轮到 ${g.name((v['turn'] as num).toInt())} · $text';
        }
      case 'claim':
        if (me?['claim'] != null) {
          hi = true;
          final tile = v['claimTile'] as String? ?? '1m';
          final from = (v['claimFrom'] as num?)?.toInt() ?? 0;
          text = '${g.name(from)} 打出 ${tileLabel(tile)}';
        }
      case 'settle':
        text = '本局结束';
      case 'over':
        text = '对局结束';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FittedBox(fit: BoxFit.scaleDown, child: StatusBar('$title · $text', highlight: hi)),
    );
  }

  static String _fmtScore(Object? raw) {
    final v = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    return '$v';
  }

  Widget _centerPanel(double sq, Map<int, int> pos) {
    final dw = (sq * 0.05).clamp(11.0, 30.0);
    final cp = dw * 6.3;
    final dealer = (v['dealer'] as num).toInt();
    final turn = (v['turn'] as num).toInt();
    final edges = List.generate(4, (_) => (wind: '', score: '', dealer: false, active: false, present: false));
    for (final e in pos.entries) {
      final sv = seatV(e.key);
      edges[e.value] = (
        wind: windLabels[(e.key - dealer + 4) % 4],
        score: _fmtScore(sv['score']),
        dealer: e.key == dealer,
        active: turn == e.key && phase == 'act',
        present: true,
      );
    }

    String sub;
    Widget? extra;
    if (rule == 'guizhoumj') {
      sub = '共${v['hands']}局 · 通行豆捉鸡';
      final ind = v['chickenIndicator'] as String?;
      final lc = v['luckyChicken'] as String?;
      final golden = v['goldenChicken'] == true;
      if (ind != null && lc != null) {
        extra = Row(mainAxisSize: MainAxisSize.min, children: [
          MahjongTile(ind, width: 16, badge: '翻'),
          const SizedBox(width: 4),
          MahjongTile(lc, width: 16, highlight: true, badge: golden ? '金' : '鸡'),
        ]);
      } else {
        extra = Row(mainAxisSize: MainAxisSize.min, children: [
          const MahjongTile('1s', width: 16, highlight: true, badge: '鸡'),
        ]);
      }
    } else if (rule == 'harbinmj') {
      final bao = v['baoTile'] as String?;
      sub = '共${v['hands']}局 · ${bao != null ? '宝牌已亮' : '报听看宝'}';
      extra = Row(mainAxisSize: MainAxisSize.min, children: [
        MahjongTile(
          bao ?? 'back',
          width: 16,
          faceDown: bao == null,
          highlight: bao != null,
          badge: '宝',
        ),
      ]);
    } else {
      final gold = v['goldTile'] as String? ?? '1m';
      sub = '共${v['hands']}局 · 开金游金';
      extra = Row(mainAxisSize: MainAxisSize.min, children: [
        MahjongTile(gold, width: 16, highlight: true, badge: '金'),
      ]);
    }

    return MjCenterPanel(
      size: cp,
      title: '第${v['hand']}局',
      subtitle: sub,
      wall: (v['wall'] as num).toInt(),
      edges: edges,
      extra: extra,
    );
  }

  Widget _side(int s, int rel, double sq) {
    final sv = seatV(s);
    final dw = (sq * 0.05).clamp(11.0, 30.0);
    final cp = dw * 6.3;
    final ds = (sv['discards'] as List).cast<Map>();
    final ev = v['event'] as Map?;
    final newestLive = ds.isNotEmpty && ds.last['taken'] != true;
    final fly = ev != null && ev['t'] == 'discard' && ev['seat'] == s && newestLive;
    final lastHi = v['lastDiscard'] == s && newestLive && (phase == 'act' || phase == 'claim');
    final children = <Widget>[
      Positioned(
        left: sq / 2 - cp / 2,
        top: sq / 2 + cp / 2 + dw * 0.15,
        child: _river(ds, dw, lastHi, fly ? ev['seq'] : null),
      ),
    ];
    if (rel != 0 || g.seat < 0) {
      final ot = (sq / 26).clamp(9.0, 24.0);
      final hand = sv['hand'];
      final count = (sv['count'] as num).toInt();
      final gold = v['goldTile'] as String?;
      final bao = v['baoTile'] as String?;
      final special = gold ?? bao;
      final tiles = <Widget>[];
      if (hand is List) {
        for (final cd in sortCodes(codesOf(hand), specialFirst: special)) {
          final isGold = gold != null && cd == gold;
          final isBao = bao != null && cd == bao;
          tiles.add(MahjongTile(
            cd,
            width: ot,
            highlight: isGold || isBao,
            badge: isGold ? '金' : (isBao ? '宝' : null),
          ));
        }
      } else {
        for (var i = 0; i < count; i++) {
          if (i == count - 1 && sv['drawn'] == true) tiles.add(SizedBox(width: ot * 0.3));
          tiles.add(MahjongTile('back', width: ot, faceDown: true));
        }
      }
      children.add(Positioned(
        left: 0,
        right: 0,
        bottom: 2,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              ...tiles,
              ...mjMelds(s, [for (final m in sv['melds'] as List) m4Meld(m as Map, ot)], gap: ot * 0.2),
            ]),
          ),
        ),
      ));
    }
    return SizedBox(width: sq, height: sq, child: Stack(clipBehavior: Clip.none, children: children));
  }

  Widget _river(List<Map> ds, double dw, bool lastHi, Object? flyKey) {
    final rows = <List<Widget>>[];
    for (var i = 0; i < ds.length; i++) {
      if (i % 6 == 0) rows.add([]);
      final last = i == ds.length - 1;
      final isCf = ds[i]['cf'] == true;
      Widget t = MahjongTile(
        ds[i]['t'] as String,
        width: dw,
        dim: ds[i]['taken'] == true,
        highlight: (lastHi && last) || isCf,
        sideways: ds[i]['riichi'] == true,
        badge: isCf ? '冲' : null,
      );
      t = mjGiri(t, ds[i], dw);
      if (flyKey != null && last) t = MjDiscardFly(key: ValueKey(flyKey), highlight: false, child: t);
      rows.last.add(t);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in rows)
        Padding(padding: EdgeInsets.only(bottom: dw * 0.04), child: Row(mainAxisSize: MainAxisSize.min, children: r)),
    ]);
  }

  Widget _tagFor(int s, int rel, double w) {
    final sv = seatV(s);
    final active = phase == 'act' && v['turn'] == s;
    final waiting = (v['waiting'] as List).contains(s);
    final small = w < 600;
    final beans = (sv['beans'] as num?)?.toInt() ?? 0;
    final chongfeng = sv['chongfeng'] == true;
    final kaimen = sv['kaimen'] == true;
    final ting = sv['ting'] == true;
    final guaDaFeng = sv['guaDaFeng'] == true;
    final swim = (sv['swimState'] as num?)?.toInt() ?? 0;

    String? status;
    if (phase == 'claim' && waiting) status = '思考中';

    final chips = <Widget>[
      if (v['dealer'] == s) _chip('庄', Colors.deepOrange),
      if (rule == 'guizhoumj' && beans > 0) _chip('豆×$beans', Colors.teal),
      if (rule == 'guizhoumj' && chongfeng) _chip('冲锋鸡', MjColors.riichi),
      if (rule == 'harbinmj' && kaimen && !ting) _chip('开门', Colors.teal),
      if (rule == 'harbinmj' && ting) _chip('报听', MjColors.riichi),
      if (rule == 'harbinmj' && guaDaFeng) _chip('大风', MjColors.kan),
      if (rule == 'fujianmj' && swim > 0)
        _chip(const ['', '单游×2', '双游×4', '三游×8'][swim.clamp(0, 3)], MjColors.riichi),
    ];

    final tag = MjTurnGlow(
      active: active,
      child: g.tag(
        s,
        active: active,
        size: small ? 24 : 32,
        sub: '${sv['score']}${status == null ? '' : ' · $status'}',
        trailing: chips.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: chips),
      ),
    );
    final align = switch (rel) {
      0 => Alignment.bottomRight,
      1 => Alignment.topRight,
      2 => Alignment.topLeft,
      _ => Alignment.bottomLeft,
    };
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: small ? 155 : 230), child: tag),
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        margin: const EdgeInsets.only(left: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

class M4HandBar extends StatefulWidget {
  final GameContext g;
  final Map<String, dynamic> v;
  final double tileW;
  const M4HandBar({super.key, required this.g, required this.v, required this.tileW});
  @override
  State<M4HandBar> createState() => _M4HandBarState();
}

class _M4HandBarState extends State<M4HandBar> {
  final _auto = MjAutoRunner();

  GameContext get g => widget.g;
  Map<String, dynamic> get v => widget.v;
  String get rule => v['rule'] as String? ?? 'guizhoumj';

  @override
  void initState() {
    super.initState();
    for (final n in [MjAutoState.autoWin, MjAutoState.noCall, MjAutoState.tsumogiri]) {
      n.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    for (final n in [MjAutoState.autoWin, MjAutoState.noCall, MjAutoState.tsumogiri]) {
      n.removeListener(_rebuild);
    }
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  static String _code(Object id) => (id as String).split('#').first;

  List<(String, String)> _tiles(Map sv, Map me) {
    final hand = codesOf(sv['hand']);
    final special = (v['goldTile'] ?? v['baoTile']) as String?;
    final drawn = me['drawn'] as String?;
    var hasDrawn = false;
    if (drawn != null && hand.contains(drawn)) {
      hand.remove(drawn);
      hasDrawn = true;
    }
    final seen = <String, int>{};
    final out = <(String, String)>[
      for (final c in sortCodes(hand, specialFirst: special)) ('$c#${seen[c] = (seen[c] ?? 0) + 1}', c),
    ];
    if (hasDrawn) out.add(('$drawn#d', drawn!));
    return out;
  }

  void _autoPlay(Map me, bool myTurn, String? drawnId, Set<String>? discardable) {
    if (g.replay) return;
    final key = '${v['hand']}|${v['phase']}|${v['turn']}|${v['event']?['seq']}|$drawnId';
    final claim = codesOf(me['claim']);
    if (MjAutoState.autoWin.value) {
      if (myTurn && me['canSanJinDao'] == true) {
        return _auto.run('$key|sjd', () => g.act({'type': 'sanjindao'}));
      }
      if (myTurn && me['canMoBao'] == true) {
        return _auto.run('$key|mb', () => g.act({'type': 'mobao'}));
      }
      if (myTurn && me['canHu'] == true) {
        return _auto.run('$key|zimo', () => g.act({'type': 'hu'}));
      }
      if (claim.contains('hu')) {
        return _auto.run('$key|hu', () => g.act({'type': 'hu'}));
      }
    }
    if (claim.isNotEmpty && !claim.contains('hu') && MjAutoState.noCall.value) {
      return _auto.run('$key|pass', () => g.act({'type': 'pass'}), delayMs: 250);
    }
    if (myTurn && MjAutoState.tsumogiri.value && drawnId != null && me['canHu'] != true) {
      final c = _code(drawnId);
      if (discardable == null || discardable.contains(c)) {
        _auto.run('$key|giri', () => g.act({'type': 'discard', 'tile': c}), delayMs: 600);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = (v['me'] as Map?)?.cast<String, dynamic>();
    if (me == null || g.seat < 0) {
      return const Align(
        alignment: Alignment.bottomCenter,
        child: Padding(padding: EdgeInsets.only(bottom: 8), child: Text('观战中', style: TextStyle(color: Colors.white70))),
      );
    }
    final phase = v['phase'] as String? ?? 'act';
    final sv = ((v['seats'] as List)[g.seat] as Map).cast<String, dynamic>();
    final gold = v['goldTile'] as String?;
    final bao = v['baoTile'] as String?;
    final myTurn = phase == 'act' && v['turn'] == g.seat;
    final tiles = _tiles(sv, me);
    final discardable = me['discardable'] == null ? null : codesOf(me['discardable']).toSet();
    final drawnId = tiles.isNotEmpty && tiles.last.$1.endsWith('#d') ? tiles.last.$1 : null;
    _autoPlay(me, myTurn, drawnId, discardable);
    final tw = widget.tileW;
    final locked = sv['ting'] == true;

    final hand = MjHand(
      tileWidth: tw,
      active: myTurn,
      onDiscard: (id) => g.act({'type': 'discard', 'tile': _code(id)}),
      tiles: [
        for (final (id, c) in tiles)
          MjHandTile(
            id: id,
            drawn: id.endsWith('#d'),
            enabled: !myTurn || discardable == null || discardable.contains(c),
            marked: (gold != null && c == gold) || (bao != null && c == bao),
            tile: (w, {dim = false}) {
              final isGold = gold != null && c == gold;
              final isBao = bao != null && c == bao;
              final isChicken = rule == 'guizhoumj' && c == '1s';
              return MahjongTile(
                c,
                width: w,
                dim: dim || (locked && !id.endsWith('#d')),
                highlight: isGold || isBao,
                badge: isGold ? '金' : (isBao ? '宝' : (isChicken ? '鸡' : null)),
              );
            },
          ),
      ],
      trailing: [
        ...mjMelds('me', [for (final m in sv['melds'] as List) m4Meld(m as Map, tw * 0.78)], gap: tw * 0.18),
      ],
    );

    final actions = _actions(me, phase, myTurn);
    final waits = codesOf(me['waits']);
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (actions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6, right: 12, left: 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: MjActionBar(actions: actions, scale: (tw / 44).clamp(0.75, 1.2)),
            ),
          ),
        ),
      if (waits.isNotEmpty && !myTurn)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  waits.length >= 34 ? '游金听全牌（34种）' : '听：',
                  style: const TextStyle(color: MjColors.winGlow, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if (waits.length < 34)
                  for (final w in waits.take(9)) Padding(padding: const EdgeInsets.all(1), child: MahjongTile(w, width: 14)),
              ]),
            ),
          ),
        ),
      Padding(padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4), child: hand),
    ]);
  }

  List<MjAction> _actions(Map me, String phase, bool myTurn) {
    final out = <MjAction>[];
    Widget preview(List<String> cs, [String? hi]) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (final c in cs) MahjongTile(c, width: 18, highlight: c == hi),
        ]);

    if (myTurn) {
      if (me['canSanJinDao'] == true) {
        out.add(MjAction.win('三金倒', () => g.act({'type': 'sanjindao'})));
      }
      if (me['canMoBao'] == true) {
        out.add(MjAction.win('摸宝', () => g.act({'type': 'mobao'})));
      }
      if (me['canHu'] == true) {
        out.add(MjAction.win('自摸', () => g.act({'type': 'hu'})));
      }
      if (rule == 'fujianmj' && me['canSwim'] == true) {
        final sts = codesOf(me['swimTiles']);
        final lbl = me['nextSwimLabel'] as String? ?? '游金';
        if (sts.isNotEmpty) {
          out.add(MjAction(
            lbl,
            MjColors.riichi,
            () => g.act({'type': 'swim', 'tile': sts.first}),
            preview: preview([sts.first]),
            primary: true,
          ));
        }
      }
      if (rule == 'harbinmj' && me['canTing'] == true) {
        final tts = codesOf(me['tingTiles']);
        if (tts.isNotEmpty) {
          out.add(MjAction(
            '报听',
            MjColors.riichi,
            () => g.act({'type': 'ting', 'tile': tts.first}),
            preview: preview([tts.first]),
          ));
        }
      }
      for (final k in codesOf(me['kongs'])) {
        out.add(MjAction.kan('杠', () => g.act({'type': 'gang', 'tile': k}), preview: preview([k])));
      }
      return out;
    }

    final claim = codesOf(me['claim']);
    if (phase == 'claim' && claim.isNotEmpty) {
      final tile = v['claimTile'] as String? ?? '1m';
      final chis = [for (final c in (me['chis'] as List? ?? const [])) codesOf(c)];
      if (claim.contains('hu')) {
        out.add(MjAction.win('胡', () => g.act({'type': 'hu'})));
      }
      if (claim.contains('gang')) {
        out.add(MjAction.kan('杠', () => g.act({'type': 'gang'}), preview: preview([tile])));
      }
      if (claim.contains('peng')) {
        out.add(MjAction.call('碰', () => g.act({'type': 'peng'}), preview: preview([tile])));
      }
      if (claim.contains('chi')) {
        for (final c in chis) {
          out.add(MjAction.call('吃', () => g.act({'type': 'chi', 'tile': c.first}), preview: preview(c, tile)));
        }
      }
      out.add(MjAction.skip(() => g.act({'type': 'pass'}), '过'));
    }
    return out;
  }
}

class M4SettlePanel extends StatelessWidget {
  final GameContext g;
  final Map<String, dynamic> view;
  final VoidCallback onHide;
  const M4SettlePanel({super.key, required this.g, required this.view, required this.onHide});

  String get rule => view['rule'] as String? ?? 'guizhoumj';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = (view['settle'] as Map).cast<String, dynamic>();
    final over = view['phase'] == 'over';
    final seats = (view['seats'] as List).cast<Map>();
    final delta = [for (final d in st['delta'] as List) (d as num).toInt()];
    final events = (st['events'] as List? ?? const []).cast<Map>();
    final cj = (st['chajiao'] as List? ?? const []).cast<Map>();
    final n = seats.length;
    final waiting = (view['waiting'] as List).contains(g.seat);
    final small = TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8));
    final order = over && view['ranking'] != null
        ? [for (final r in view['ranking'] as List) (r as num).toInt()]
        : List.generate(n, (i) => i);

    Widget chip(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
          child: Text(t, style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
        );

    final body = <Widget>[];
    if (rule == 'guizhoumj' && st['luckyChicken'] != null) {
      final ind = st['chickenIndicator'] as String? ?? '1s';
      final lc = st['luckyChicken'] as String? ?? '2s';
      final golden = st['goldenChicken'] == true;
      body.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(golden ? '翻出金鸡：' : '本局翻鸡：', style: small),
          MahjongTile(ind, width: 18, badge: '翻'),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 14)),
          MahjongTile(lc, width: 18, highlight: true, badge: golden ? '金' : '鸡'),
        ]),
      ));
    } else if (rule == 'harbinmj' && st['baoTile'] != null) {
      body.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text('本局宝牌：', style: small),
          MahjongTile(st['baoTile'] as String, width: 18, highlight: true, badge: '宝'),
        ]),
      ));
    } else if (rule == 'fujianmj' && st['goldTile'] != null) {
      body.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text('本局金牌：', style: small),
          MahjongTile(st['goldTile'] as String, width: 18, highlight: true, badge: '金'),
        ]),
      ));
    }

    final huEvents = [for (final e in events) if (e['kind'] == 'hu') e];
    for (final e in huEvents) {
      final s = (e['seat'] as num).toInt();
      final from = (e['from'] as num).toInt();
      final zimo = e['zimo'] == true;
      final items = [
        for (final it in (e['items'] as List? ?? const []).cast<List>()) '${it[0]} +${it[1]}',
      ];
      final summary = e['mult'] != null && (e['mult'] as num) > 1
          ? '番数 ${e['fan']} · 游金 ×${e['mult']} · +${e['total']} 分'
          : '番分 ${e['fan']} · +${e['total']} 分';
      body.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            MahjongTile(e['tile'] as String? ?? '1m', width: 22, highlight: true),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                zimo ? '${g.name(s)} 自摸' : '${g.name(s)} 胡 ${g.name(from)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(summary, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
              ),
            ),
          ]),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [for (final t in items) chip(t)]),
          ],
        ]),
      ));
    }

    if (cj.isNotEmpty) {
      body.add(const Divider(height: 10));
      for (final c in cj.take(6)) {
        body.add(Text(
          '${c['why']}：${g.name((c['from'] as num).toInt())} → ${g.name((c['to'] as num).toInt())}  +${c['amount']}',
          style: small,
        ));
      }
    }

    if (huEvents.isEmpty && cj.isEmpty) {
      body.add(Text('牌山摸完，流局', style: small));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade600, width: 2),
          boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black54)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Text(
                  over ? '终局排名' : '第 ${st['hand']} 局结算',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.primary),
                ),
              ),
              IconButton(onPressed: onHide, icon: const Icon(Icons.visibility), tooltip: '查看牌桌'),
            ]),
            Flexible(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ...body,
                  const Divider(height: 14),
                  for (var i = 0; i < order.length; i++)
                    _scoreRow(context, order[i], over ? i + 1 : 0, delta[order[i]], (seats[order[i]]['score'] as num).toInt()),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            if (!over)
              FilledButton(
                onPressed: waiting ? () => g.act({'type': 'next'}) : null,
                child: Text(waiting ? '下一局' : '等待其他玩家…'),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _scoreRow(BuildContext context, int s, int rank, int d, int total) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        if (rank > 0)
          SizedBox(
            width: 28,
            child: Text('$rank',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: rank == 1 ? Colors.amber : cs.onSurface)),
          ),
        Avatar(g.avatar(s), size: 26, bot: g.bot(s)),
        const SizedBox(width: 6),
        Expanded(child: Text(g.name(s), overflow: TextOverflow.ellipsis)),
        SizedBox(
          width: 76,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(fit: BoxFit.scaleDown, child: MjScoreDelta(d, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 76,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text('$total', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}
