import 'dart:math';

import 'package:aurora_shared/games/abstract4/kamisado.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

const List<Color> _kamiColors = [
  Color(0xFFF57C00), // 0: Orange 橙
  Color(0xFF1976D2), // 1: Blue 蓝
  Color(0xFF7B1FA2), // 2: Purple 紫
  Color(0xFFEC407A), // 3: Pink 粉
  Color(0xFFFBC02D), // 4: Yellow 黄
  Color(0xFFD32F2F), // 5: Red 红
  Color(0xFF388E3C), // 6: Green 绿
  Color(0xFF5D4037), // 7: Brown 棕
];

class _KamisadoPainter extends CustomPainter {
  final List<List<int>> towers;
  final int turn;
  final int requiredColor;
  final int effColor;
  final Set<int> moveTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;

  _KamisadoPainter({
    required this.towers,
    required this.turn,
    required this.requiredColor,
    required this.effColor,
    required this.moveTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
  });

  static Rect cellRect(Size s, int cell) {
    final cw = s.width / 8;
    final x = cell % 8, y = cell ~/ 8;
    return Rect.fromLTWH(x * cw, y * cw, cw, cw);
  }

  static int hit(Size s, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final cw = s.width / 8;
    final x = (o.dx / cw).floor(), y = (o.dy / cw).floor();
    if (x < 0 || x >= 8 || y < 0 || y >= 8) return -1;
    return y * 8 + x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / 8;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.22));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a4Shadow(cw * 0.14, alpha: 0.5));

    // Obsidian lacquer frame
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2320), Color(0xFF14100E)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(outer.deflate(cw * 0.05));

    for (var c = 0; c < 64; c++) {
      final r = cellRect(size, c);
      final sqColorIdx = kamisadoCellColors[c];
      final baseColor = _kamiColors[sqColorIdx];

      canvas.drawRect(r, Paint()..color = const Color(0xFF1E1916));
      final inner = r.deflate(cw * 0.035);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(cw * 0.1)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(baseColor, Colors.white, 0.16)!,
              baseColor,
              Color.lerp(baseColor, Colors.black, 0.22)!,
            ],
          ).createShader(inner),
      );

      // Subtle color name label in top-left of each square (colorblind friendly)
      a4PaintTextCentered(
        canvas,
        kamisadoColorNames[sqColorIdx],
        inner.topLeft + Offset(cw * 0.15, cw * 0.14),
        cw * 0.16,
        Colors.white.withValues(alpha: 0.62),
        weight: FontWeight.w600,
      );

      // Last move highlight
      if (c == lastFrom || c == lastTo) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(inner, Radius.circular(cw * 0.1)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.0, cw * 0.06)
            ..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }

    // Draw last move trajectory line
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < 64 && lastTo < 64) {
      canvas.drawLine(
        cellRect(size, lastFrom).center,
        cellRect(size, lastTo).center,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.65)
          ..strokeWidth = max(1.8, cw * 0.055)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Highlight active/selected Dragon Tower cell
    if (effColor >= 0 && effColor < 8) {
      final activeCell = towers[turn][effColor];
      final r = cellRect(size, activeCell).deflate(cw * 0.02);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cw * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.5, cw * 0.08)
          ..color = const Color(0xFFFFEE58),
      );
    }

    // Draw legal target overlays
    for (final t in moveTargets) {
      final r = cellRect(size, t);
      final isHover = t == hover;
      final row = t ~/ 8;
      final isGoal = row == (turn == 0 ? 0 : 7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(cw * 0.06), Radius.circular(cw * 0.12)),
        Paint()..color = (isGoal ? const Color(0xFFFFD54F) : Colors.white).withValues(alpha: isHover ? 0.45 : 0.22),
      );
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.22 : 0.16),
        Paint()..color = isGoal ? const Color(0xFFFFB300) : const Color(0xDDFFFFFF),
      );
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.22 : 0.16),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, cw * 0.04)
          ..color = const Color(0xCC212121),
      );
      if (isGoal) {
        a4PaintTextCentered(canvas, '胜', r.center, cw * 0.21, const Color(0xFF3E2723));
      }
    }

    // Draw all 16 Dragon Towers
    for (var s = 0; s < 2; s++) {
      for (var colIdx = 0; colIdx < 8; colIdx++) {
        final cell = towers[s][colIdx];
        if (cell < 0 || cell >= 64) continue;
        final isSelected = s == turn && colIdx == effColor;
        _paintTower(canvas, cellRect(size, cell).center, cw, s, colIdx, isSelected);
      }
    }

    canvas.restore();
  }

  void _paintTower(Canvas canvas, Offset c, double cw, int seat, int towerColorIdx, bool selected) {
    final r = cw * (selected ? 0.40 : 0.37);
    canvas.drawCircle(c + Offset(r * 0.1, r * 0.18), r, a4Shadow(r * 0.22, alpha: 0.55));

    // Outer casing: Seat 0 = Ivory/Gold Dragon, Seat 1 = Obsidian/Silver Dragon
    final isGold = seat == 0;
    final outerColors = isGold
        ? const [Color(0xFFFFFFFF), Color(0xFFFFF3E0), Color(0xFFD7CCC8)]
        : const [Color(0xFF455A64), Color(0xFF212121), Color(0xFF0B0E10)];

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: outerColors,
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, r * (selected ? 0.18 : 0.12))
        ..color = selected
            ? const Color(0xFFFFEE58)
            : (isGold ? const Color(0xFFFFB300) : const Color(0xFF90A4AE)),
    );

    // Inner colored dragon crest
    final innerR = r * 0.66;
    final crestColor = _kamiColors[towerColorIdx];
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            Color.lerp(crestColor, Colors.white, 0.32)!,
            crestColor,
            Color.lerp(crestColor, Colors.black, 0.28)!,
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: innerR)),
    );
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, r * 0.07)
        ..color = Colors.white.withValues(alpha: 0.75),
    );

    // Direction chevron + color character
    final textColor = towerColorIdx == 4 ? const Color(0xFF212121) : Colors.white;
    a4PaintTextCentered(
      canvas,
      kamisadoColorNames[towerColorIdx],
      c + Offset(0, isGold ? r * 0.06 : -r * 0.06),
      innerR * 0.92,
      textColor,
    );
    a4PaintTextCentered(
      canvas,
      isGold ? '▲' : '▼',
      c + Offset(0, isGold ? -r * 0.78 : r * 0.78),
      r * 0.34,
      isGold ? const Color(0xFFE65100) : const Color(0xFFFFD54F),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class KamisadoBoardView extends StatefulWidget {
  final GameContext g;
  const KamisadoBoardView(this.g, {super.key});
  @override
  State<KamisadoBoardView> createState() => _KamisadoBoardViewState();
}

class _KamisadoBoardViewState extends State<KamisadoBoardView> {
  int selColor = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    if (_lastPlies != v['plies']) {
      _lastPlies = v['plies'];
      selColor = -1;
    }

    final towers = [for (final t in v['towers'] as List) (t as List).cast<int>()];
    final scores = (v['scores'] as List).cast<int>();
    final targetScore = (v['targetScore'] as int?) ?? 1;
    final round = (v['round'] as int?) ?? 1;
    final turn = v['turn'] as int;
    final requiredColor = v['requiredColor'] as int;
    final canPass = v['canPass'] == true;
    final legalMoves = [
      for (final m in v['legalMoves'] as List) ((m[0] as int), (m[1] as int), (m[2] as int))
    ];
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? (last?['cell'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final effColor = requiredColor >= 0 ? requiredColor : selColor;

    final moveTargets = <int>{};
    if (myTurn && effColor >= 0) {
      for (final (col, _, to) in legalMoves) {
        if (col == effColor) {
          moveTargets.add(to);
        }
      }
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= 64) return;
      if (canPass && requiredColor >= 0 && towers[turn][requiredColor] == c) {
        g.act({'type': 'pass'});
        return;
      }
      if (effColor >= 0 && moveTargets.contains(c)) {
        final from = towers[turn][effColor];
        setState(() => selColor = -1);
        g.act({'type': 'move', 'color': effColor, 'from': from, 'to': c});
        return;
      }
      if (requiredColor < 0) {
        final idx = towers[turn].indexOf(c);
        if (idx >= 0) {
          setState(() => selColor = selColor == idx ? -1 : idx);
        }
      }
    }

    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      if (canPass) {
        status = '你的【${kamisadoColorNames[requiredColor]}塔】前方三路均被阻挡，请点击“跳过回合”';
      } else if (requiredColor >= 0) {
        status = '颜色锁生效：请将你的【${kamisadoColorNames[requiredColor]}塔】向前或斜前方移动（冲抵对方底线即胜）';
      } else if (selColor < 0) {
        status = '本局首步：请点选你底线任意 1 座龙塔进行移动';
      } else {
        status = '已选【${kamisadoColorNames[selColor]}塔】：请点选前方圆点目标格';
      }
    } else {
      final lockText = requiredColor >= 0 ? '移动【${kamisadoColorNames[requiredColor]}塔】' : '选择首步龙塔';
      status = '等待 ${g.name(turn)} $lockText';
    }

    final actions = <Widget>[];
    if (myTurn && canPass) {
      actions.add(a4Button(
        context,
        '跳过回合（${kamisadoColorNames[requiredColor]}塔被阻挡）',
        Icons.skip_next,
        () => g.act({'type': 'pass'}),
        primary: true,
      ));
    }

    // Color lock status pill tray
    Widget? tray;
    if (requiredColor >= 0) {
      final lockColor = _kamiColors[requiredColor];
      tray = A4Panel(
        highlight: myTurn,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: lockColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '当前颜色锁：【${kamisadoColorNames[requiredColor]}色】— ${g.name(turn)} 本回合必须操控【${kamisadoColorNames[requiredColor]}塔】',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      );
    }

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _KamisadoPainter.hit(bSize, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_KamisadoPainter.hit(bSize, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _KamisadoPainter(
                towers: towers,
                turn: turn,
                requiredColor: requiredColor,
                effColor: effColor,
                moveTargets: moveTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sideLabel = s == 0 ? '金塔（▲北上）' : '黑塔（▼南下）';
      final scoreLabel = targetScore > 1 ? ' · 积分 ${scores[s]}/$targetScore' : '';
      final stateLabel = over ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负')) : '';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideLabel$scoreLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFFFFF3E0) : const Color(0xFF212121),
            shape: BoxShape.circle,
            border: Border.all(
              color: s == 0 ? const Color(0xFFFFB300) : const Color(0xFF90A4AE),
              width: 1.8,
            ),
          ),
        ),
      );
    }

    return A4Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      tray: tray,
      trayFraction: 0.10,
      trayLandscapeHeight: 48,
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '第 $round 局（目标 $targetScore 分）· 龙塔仅可向正前/左前/右前移动，落点格颜色指定对手下一步龙塔！',
      ],
      result: a4Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
