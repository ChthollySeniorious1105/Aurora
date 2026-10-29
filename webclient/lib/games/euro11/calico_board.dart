import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _patchColors = [
  Color(0xFF2E5EAA), // 0 靛蓝
  Color(0xFFF2B134), // 1 琥珀
  Color(0xFFE05A47), // 2 珊瑚
  Color(0xFF3FA77A), // 3 薄荷
  Color(0xFF8856A7), // 4 紫藤
  Color(0xFFE67FA8), // 5 樱粉
];
const List<String> _colorNames = ['靛蓝', '琥珀', '珊瑚', '薄荷', '紫藤', '樱粉'];
const List<String> _patternNames = ['条纹', '波点', '碎花', '格纹', '藤蔓', '星芒'];
const List<String> _patternIcons = ['▤', '⁙', '✿', '❖', '❦', '✦'];

int _asInt(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
List<T> _asList<T>(Object? v) => v is List ? v.cast<T>() : <T>[];
Map<String, dynamic> _asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

class CalicoPatchWidget extends StatelessWidget {
  final int color;
  final int pattern;
  final double size;
  final bool selected;
  final bool borderTile;
  final VoidCallback? onTap;

  const CalicoPatchWidget({
    super.key,
    required this.color,
    required this.pattern,
    this.size = 44,
    this.selected = false,
    this.borderTile = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = _patchColors[color.clamp(0, 5)];
    final pat = pattern.clamp(0, 5);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(size * 0.24),
          border: Border.all(
            color: selected ? Colors.white : (borderTile ? Colors.white54 : Colors.black45),
            width: selected ? 2.5 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: selected ? 6 : 2,
              color: selected ? Colors.amberAccent : Colors.black26,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _PatternPainter(pat),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  '${_patternIcons[pat]}\n${_colorNames[color.clamp(0, 5)][0]}${_patternNames[pat][0]}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    height: 1.05,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 2, color: Colors.black87)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final int pattern;
  const _PatternPainter(this.pattern);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final w = size.width;
    switch (pattern) {
      case 0: // Stripes
        for (var i = 1; i <= 3; i++) {
          final y = w * i / 4;
          canvas.drawLine(Offset(4, y), Offset(w - 4, y), p);
        }
      case 1: // Dots
        final fill = Paint()..color = Colors.white.withValues(alpha: 0.22);
        for (final pt in [Offset(w * 0.28, w * 0.28), Offset(w * 0.72, w * 0.28), Offset(w * 0.28, w * 0.72), Offset(w * 0.72, w * 0.72)]) {
          canvas.drawCircle(pt, w * 0.08, fill);
        }
      case 2: // Flower circle
        canvas.drawCircle(Offset(w / 2, w / 2), w * 0.34, p);
      case 3: // Plaid
        canvas.drawRect(Rect.fromLTWH(w * 0.2, w * 0.2, w * 0.6, w * 0.6), p);
      case 4: // Vines
        canvas.drawArc(Rect.fromLTWH(w * 0.15, w * 0.15, w * 0.7, w * 0.7), 0, pi, false, p);
      default: // Star
        canvas.drawLine(Offset(w * 0.2, w * 0.2), Offset(w * 0.8, w * 0.8), p);
        canvas.drawLine(Offset(w * 0.8, w * 0.2), Offset(w * 0.2, w * 0.8), p);
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) => oldDelegate.pattern != pattern;
}

class CalicoBoard extends StatefulWidget {
  final GameContext g;
  const CalicoBoard(this.g, {super.key});

  @override
  State<CalicoBoard> createState() => _CalicoBoardState();
}

class _CalicoBoardState extends State<CalicoBoard> {
  int selHandIdx = 0;
  int selMarketIdx = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final over = v['phase'] == 'over';
    final turn = _asInt(v['turn']);
    final round = _asInt(v['round'], 1);
    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final cats = _asList<dynamic>(v['cats']).map(_asMap).toList();
    final market = _asList<dynamic>(v['market']).map(_asMap).toList();
    final hand = _asList<dynamic>(v['hand']).map(_asMap).toList();
    final ps = _asList<dynamic>(v['players']).map(_asMap).toList();

    if (selHandIdx >= hand.length) selHandIdx = 0;
    if (selMarketIdx >= market.length) selMarketIdx = 0;

    final status = over
        ? '猫咪与花被 · 终局计分'
        : myTurn
            ? '第 $round 轮 · 轮到你：1.选手牌与市场布片 → 2.点击花被空白格缝制'
            : '第 $round 轮 · 等待 ${g.name(turn)} 缝制花被';

    Widget catsAndMarketPanel() {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final c in cats)
                  Builder(builder: (_) {
                    final pats = _asList<dynamic>(c['patterns']).map(_asInt).toList();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🐱 ${c['name']} (≥${c['minSize']}连 +${c['vp']}分): '
                        '${pats.map((p) => '${_patternIcons[p]}${_patternNames[p]}').join('/')}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('中央市场 (袋余 ${_asInt(v['bagCount'])}): ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    for (var m = 0; m < market.length; m++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: CalicoPatchWidget(
                          color: _asInt(market[m]['color']),
                          pattern: _asInt(market[m]['pattern']),
                          size: 40,
                          selected: myTurn && selMarketIdx == m,
                          onTap: myTurn ? () => setState(() => selMarketIdx = m) : null,
                        ),
                      ),
                  ],
                ),
                if (hand.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('我的手牌: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      for (var h = 0; h < hand.length; h++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: CalicoPatchWidget(
                            color: _asInt(hand[h]['color']),
                            pattern: _asInt(hand[h]['pattern']),
                            size: 42,
                            selected: myTurn && selHandIdx == h,
                            onTap: myTurn ? () => setState(() => selHandIdx = h) : null,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildQuiltBoard(int s, double cellSize, {bool interactive = false}) {
      final p = ps[s];
      final quilt = _asList<dynamic>(p['quilt']).map((row) => _asList<dynamic>(row)).toList();
      final bd = _asMap(p['breakdown']);
      final goals = _asList<dynamic>(bd['goals']).map(_asMap).toList();
      final goalMap = <(int, int), Map<String, dynamic>>{
        for (final gm in goals) (_asInt(gm['r']), _asInt(gm['c'])): gm,
      };
      final active = !over && turn == s;
      final sub = '总分 ${_asInt(p['score'])} (目标${_asInt(bd['goalVp'])} · 纽扣${_asInt(bd['buttonVp'])}${bd['rainbow'] == true ? '🌈' : ''} · 猫咪${_asInt(bd['catVp'])})';

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? cs.primary : cs.outline.withValues(alpha: 0.3), width: active ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            g.tag(s, active: active, sub: sub, size: max(22, min(32, cellSize * 0.72))),
            const SizedBox(height: 6),
            for (var r = 0; r < 5; r++)
              Padding(
                padding: EdgeInsets.only(left: r.isOdd ? cellSize * 0.45 : 0, bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var c = 0; c < 5; c++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Builder(builder: (_) {
                          final rawCell = r < quilt.length && c < quilt[r].length ? quilt[r][c] : null;
                          if (rawCell == null) {
                            final canTap = interactive && myTurn;
                            return GestureDetector(
                              onTap: canTap
                                  ? () => g.act({
                                        'type': 'place',
                                        'handIdx': selHandIdx,
                                        'r': r,
                                        'c': c,
                                        'marketIdx': selMarketIdx,
                                      })
                                  : null,
                              child: Container(
                                width: cellSize,
                                height: cellSize,
                                decoration: BoxDecoration(
                                  color: canTap ? cs.primary.withValues(alpha: 0.18) : Colors.black12,
                                  borderRadius: BorderRadius.circular(cellSize * 0.24),
                                  border: Border.all(
                                    color: canTap ? cs.primary : Colors.white38,
                                    width: canTap ? 1.8 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    canTap ? '+缝制\n($r,$c)' : '$r,$c',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: canTap ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          final cell = _asMap(rawCell);
                          if (cell['goal'] != null) {
                            final gInfo = goalMap[(r, c)];
                            final vp = _asInt(gInfo?['vp']);
                            return Container(
                              width: cellSize,
                              height: cellSize,
                              decoration: BoxDecoration(
                                color: vp == 11
                                    ? const Color(0xFFD99B26)
                                    : (vp == 7 ? const Color(0xFF2B6CB0) : const Color(0xFF3A3F54)),
                                borderRadius: BorderRadius.circular(cellSize * 0.24),
                                border: Border.all(color: Colors.amberAccent, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '🎯\n${cell['goal']}\n${vp > 0 ? '+$vp分' : '7/11分'}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }
                          return CalicoPatchWidget(
                            color: _asInt(cell['color']),
                            pattern: _asInt(cell['pattern']),
                            size: cellSize,
                            borderTile: cell['border'] == true,
                          );
                        }),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    Widget? banner;
    if (over) {
      final pl = _asList<dynamic>(v['placings']).map(_asInt).toList();
      final winners = [for (var s = 0; s < pl.length; s++) if (pl[s] == 1) g.name(s)];
      banner = ResultBanner(
        '${winners.join('、')} 获胜！',
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DataTable(
            headingRowHeight: 28,
            dataRowMinHeight: 26,
            dataRowMaxHeight: 30,
            columns: const [
              DataColumn(label: Text('玩家')),
              DataColumn(label: Text('设计目标')),
              DataColumn(label: Text('纽扣')),
              DataColumn(label: Text('猫咪')),
              DataColumn(label: Text('总分')),
            ],
            rows: [
              for (final p in ps)
                DataRow(cells: [
                  DataCell(Text(g.name(_asInt(p['seat'])), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('${_asInt(_asMap(p['breakdown'])['goalVp'])}')),
                  DataCell(Text('${_asInt(_asMap(p['breakdown'])['buttonVp'])}${_asMap(p['breakdown'])['rainbow'] == true ? '🌈' : ''}')),
                  DataCell(Text('${_asInt(_asMap(p['breakdown'])['catVp'])}')),
                  DataCell(Text('${_asInt(p['score'])}', style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
            ],
          ),
        ),
      );
    }

    final order = g.seatsFromMe();
    final primarySeat = me >= 0 ? me : 0;
    final others = order.where((s) => s != primarySeat).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > constraints.maxHeight * 1.15;
      final myCell = wide
          ? min(44.0, max(26.0, (constraints.maxHeight - 130) / 6.5))
          : min(44.0, max(28.0, (constraints.maxWidth - 40) / 6.2));
      final otherCell = max(22.0, myCell * 0.65);

      return Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(6),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBar(status, highlight: myTurn),
                  const SizedBox(height: 6),
                  catsAndMarketPanel(),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      if (ps.isNotEmpty)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: buildQuiltBoard(primarySeat, myCell, interactive: me >= 0),
                        ),
                      for (final s in others)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: buildQuiltBoard(s, otherCell),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (banner != null) Align(alignment: Alignment.topCenter, child: banner),
        ],
      );
    });
  }
}
