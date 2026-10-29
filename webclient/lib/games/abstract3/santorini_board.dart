import 'dart:math';

import 'package:aurora_shared/games/abstract3/santorini.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

const List<Color> _seatColors = [
  Color(0xFFE53935), // P0: Coral Red
  Color(0xFF00ACC1), // P1: Aegean Teal/Cyan
  Color(0xFFFB8C00), // P2: Amber Gold
];
const List<String> _seatColorNames = ['红', '青', '橙'];

Color _playerColor(int seat) => _seatColors[seat.clamp(0, _seatColors.length - 1)];

class _SantoriniPainter extends CustomPainter {
  final List<int> heights;
  final List<List<int>> workers;
  final List<bool> eliminated;
  final int selWorker;
  final Set<int> moveTargets;
  final Set<int> buildTargets;
  final Set<int> winTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final int lastBuild;
  final Color accent;

  _SantoriniPainter({
    required this.heights,
    required this.workers,
    required this.eliminated,
    required this.selWorker,
    required this.moveTargets,
    required this.buildTargets,
    required this.winTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastBuild,
    required this.accent,
  });

  static Rect cellRect(Size s, int cell) {
    final cw = s.width / 5;
    final x = cell % 5, y = cell ~/ 5;
    return Rect.fromLTWH(x * cw, y * cw, cw, cw);
  }

  static int hit(Size s, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final cw = s.width / 5;
    final x = (o.dx / cw).floor(), y = (o.dy / cw).floor();
    if (x < 0 || x > 4 || y < 0 || y > 4) return -1;
    return y * 5 + x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / 5;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.18));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.05)), a3Shadow(cw * 0.12, alpha: 0.45));

    // Aegean island board background
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBCE3C5), Color(0xFF8CC099), Color(0xFF75AD84)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(outer);

    for (var c = 0; c < 25; c++) {
      final r = cellRect(size, c).deflate(cw * 0.045);
      final even = ((c % 5) + (c ~/ 5)) % 2 == 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cw * 0.1)),
        Paint()..color = even ? const Color(0x24FFFFFF) : const Color(0x14000000),
      );

      // Highlight last action cells
      if (c == lastFrom || c == lastTo) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(cw * 0.1)),
          Paint()..color = const Color(0x44FFD54F),
        );
      }
      if (c == lastBuild) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(cw * 0.1)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.5, cw * 0.04)
            ..color = const Color(0xCC29B6F6),
        );
      }

      // Coordinate label in top-left corner
      a3PaintTextCentered(
        canvas,
        santoriniCoord(c),
        r.topLeft + Offset(cw * 0.13, cw * 0.11),
        cw * 0.14,
        const Color(0x661B3B24),
        weight: FontWeight.w600,
      );

      final h = heights[c];
      _paintBuilding(canvas, r.center, cw, h);
    }

    canvas.restore();

    // Selected worker ring
    if (selWorker >= 0 && selWorker < 25) {
      final r = cellRect(size, selWorker).deflate(cw * 0.04);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cw * 0.12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.0, cw * 0.065)
          ..color = accent,
      );
    }

    // Draw workers
    for (var s = 0; s < workers.length; s++) {
      if (s < eliminated.length && eliminated[s]) continue;
      for (final c in workers[s]) {
        if (c < 0 || c >= 25) continue;
        final center = cellRect(size, c).center;
        final h = heights[c];
        // Lift worker slightly when standing on higher towers
        final lift = Offset(0, -h * cw * 0.025);
        _paintWorker(canvas, center + lift, cw, _playerColor(s), s);
      }
    }

    // Draw move & build target overlays
    for (final t in moveTargets) {
      final r = cellRect(size, t);
      final isWin = winTargets.contains(t);
      final isHover = t == hover;
      final color = isWin ? const Color(0xFFFFB300) : const Color(0xFF43A047);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(cw * 0.07), Radius.circular(cw * 0.12)),
        Paint()..color = color.withValues(alpha: isHover ? 0.42 : 0.24),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(cw * 0.07), Radius.circular(cw * 0.12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, cw * 0.05)
          ..color = color,
      );
      if (isWin) {
        a3PaintTextCentered(canvas, '胜', r.center, cw * 0.24, const Color(0xFF4E342E));
      } else {
        canvas.drawCircle(r.center, cw * (isHover ? 0.17 : 0.12), Paint()..color = color.withValues(alpha: 0.9));
      }
    }

    for (final b in buildTargets) {
      final r = cellRect(size, b);
      final isHover = b == hover;
      const color = Color(0xFFFB8C00);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(cw * 0.07), Radius.circular(cw * 0.12)),
        Paint()..color = color.withValues(alpha: isHover ? 0.45 : 0.26),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(cw * 0.07), Radius.circular(cw * 0.12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, cw * 0.05)
          ..color = color,
      );
      a3PaintTextCentered(canvas, '建', r.center, cw * 0.22, Colors.white);
    }
  }

  void _paintBuilding(Canvas canvas, Offset c, double cw, int h) {
    if (h <= 0) return;

    void tier(double frac, double shiftY, Color topColor, Color sideColor) {
      final w = cw * frac;
      final rect = Rect.fromCenter(center: c + Offset(0, shiftY), width: w, height: w);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cw * 0.08));
      canvas.drawRRect(rr.shift(Offset(cw * 0.02, cw * 0.035)), Paint()..color = sideColor);
      canvas.drawRRect(rr, Paint()..color = topColor);
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, cw * 0.015)
          ..color = const Color(0x33000000),
      );
    }

    // Level 1 base
    if (h >= 1) {
      tier(0.80, 0, const Color(0xFFFDFBF7), const Color(0xFFD7CCC8));
    }
    // Level 2 middle
    if (h >= 2) {
      tier(0.64, -cw * 0.02, const Color(0xFFF5F0E6), const Color(0xFFBCAAA4));
    }
    // Level 3 top tower (with golden rim)
    if (h >= 3) {
      tier(0.48, -cw * 0.04, const Color(0xFFFFF8E1), const Color(0xFFA1887F));
      final r3 = Rect.fromCenter(center: c + Offset(0, -cw * 0.04), width: cw * 0.44, height: cw * 0.44);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r3, Radius.circular(cw * 0.06)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, cw * 0.022)
          ..color = const Color(0xFFFFB300),
      );
    }
    // Level 4 Aegean blue dome
    if (h >= 4) {
      final domeCenter = c + Offset(0, -cw * 0.05);
      final r = cw * 0.24;
      canvas.drawCircle(domeCenter + Offset(r * 0.1, r * 0.16), r, a3Shadow(r * 0.18, alpha: 0.45));
      canvas.drawCircle(
        domeCenter,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [Color(0xFF64B5F6), Color(0xFF1976D2), Color(0xFF0D47A1)],
            stops: [0.0, 0.65, 1.0],
          ).createShader(Rect.fromCircle(center: domeCenter, radius: r)),
      );
    }

    // Height badge at bottom-right of cell
    final badgeCenter = c + Offset(cw * 0.31, cw * 0.31);
    final badgeColor = h == 4
        ? const Color(0xFF0D47A1)
        : (h == 3 ? const Color(0xFFE65100) : const Color(0xFF455A64));
    canvas.drawCircle(badgeCenter, cw * 0.12, Paint()..color = badgeColor);
    a3PaintTextCentered(canvas, h == 4 ? '穹' : '$h', badgeCenter, cw * 0.14, Colors.white);
  }

  void _paintWorker(Canvas canvas, Offset c, double cw, Color color, int seat) {
    final r = cw * 0.21;
    canvas.drawCircle(c + Offset(r * 0.12, r * 0.22), r, a3Shadow(r * 0.2, alpha: 0.5));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.42)!],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, r * 0.1)
        ..color = Colors.white.withValues(alpha: 0.65),
    );
    a3PaintTextCentered(canvas, '${seat + 1}', c, r * 0.95, Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SantoriniBoardView extends StatefulWidget {
  final GameContext g;
  const SantoriniBoardView(this.g, {super.key});
  @override
  State<SantoriniBoardView> createState() => _SantoriniBoardViewState();
}

class _SantoriniBoardViewState extends State<SantoriniBoardView> {
  int selWorker = -1;
  int hover = -1;
  bool prebuildMode = false; // Prometheus pre-build toggle
  bool domeMode = false; // Atlas dome toggle
  bool doubleMode = false; // Hephaestus double build toggle
  Object? _lastPlies;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    if (_lastPlies != v['plies']) {
      _lastPlies = v['plies'];
      selWorker = -1;
      prebuildMode = false;
      domeMode = false;
      doubleMode = false;
    }

    final heights = (v['heights'] as List).cast<int>();
    final workers = [for (final w in v['workers'] as List) (w as List).cast<int>()];
    final gods = (v['gods'] as List).cast<String>();
    final godEnabled = v['godEnabled'] == true;
    final eliminated = (v['eliminated'] as List).cast<bool>();
    final phase = v['phase'] as String;
    final turn = v['turn'] as int;
    final step = v['step'] as String;
    final activeCell = v['activeCell'] as int;
    final athenaLocked = v['athenaLocked'] == true;
    final legalMoves = [for (final m in v['legalMoves'] as List) ((m[0] as int), (m[1] as int))];
    final legalPrebuilds = [for (final m in v['legalPrebuilds'] as List) ((m[0] as int), (m[1] as int))];
    final legalBuilds = (v['legalBuilds'] as List).cast<int>();
    final canDome = v['canDome'] == true;
    final doubleCells = (v['doubleCells'] as List).cast<int>().toSet();
    final canPass = v['canPass'] == true;
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;
    final myGod = (turn >= 0 && turn < gods.length) ? gods[turn] : 'none';

    final lastFrom = (last?['from'] as int?) ?? (last?['cell'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastBuild = (last?['build2'] as int?) ?? (last?['build'] as int?) ?? -1;

    // Determine effective selected worker and target sets
    var effWorker = selWorker;
    if (step == 'post_prebuild' || step == 'build' || step == 'build2') {
      effWorker = activeCell;
    } else if (myTurn && phase == 'play' && step == 'move' && effWorker < 0 && workers[turn].length == 1) {
      effWorker = workers[turn].first;
    }

    final moveTargets = <int>{};
    final buildTargets = <int>{};
    final winTargets = <int>{};

    if (myTurn) {
      if (phase == 'place') {
        for (var c = 0; c < 25; c++) {
          final occupied = workers.any((ws) => ws.contains(c));
          if (!occupied) moveTargets.add(c);
        }
      } else if (step == 'move' || step == 'post_prebuild') {
        if (effWorker >= 0) {
          if (prebuildMode && step == 'move') {
            for (final (f, b) in legalPrebuilds) {
              if (f == effWorker) buildTargets.add(b);
            }
          } else {
            for (final (f, t) in legalMoves) {
              if (f == effWorker) {
                moveTargets.add(t);
                if ((heights[t] == 3 && heights[t] > heights[f]) ||
                    (myGod == 'pan' && heights[f] - heights[t] >= 2) ||
                    (myGod == 'artemis' && !santoriniAdj(f).contains(t) && heights[t] == 3)) {
                  winTargets.add(t);
                }
              }
            }
          }
        }
      } else if (step == 'build' || step == 'build2') {
        for (final b in legalBuilds) {
          if (doubleMode && !doubleCells.contains(b)) continue;
          buildTargets.add(b);
        }
      }
    }

    void tapCell(int c) {
      if (!myTurn || c < 0) return;
      if (phase == 'place') {
        if (moveTargets.contains(c)) {
          g.act({'type': 'place', 'cell': c});
        }
        return;
      }
      if (step == 'move') {
        if (effWorker >= 0 && prebuildMode && buildTargets.contains(c)) {
          g.act({'type': 'prebuild', 'from': effWorker, 'cell': c});
          return;
        }
        if (effWorker >= 0 && moveTargets.contains(c)) {
          g.act({'type': 'move', 'from': effWorker, 'to': c});
          return;
        }
        if (workers[turn].contains(c)) {
          setState(() {
            selWorker = selWorker == c ? -1 : c;
          });
        }
        return;
      }
      if (step == 'post_prebuild') {
        if (moveTargets.contains(c)) {
          g.act({'type': 'move', 'from': activeCell, 'to': c});
        }
        return;
      }
      if (step == 'build' || step == 'build2') {
        if (buildTargets.contains(c)) {
          g.act({
            'type': 'build',
            'cell': c,
            if (step == 'build' && domeMode && canDome) 'dome': true,
            if (step == 'build' && doubleMode && doubleCells.contains(c)) 'double': true,
          });
        }
      }
    }

    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      if (phase == 'place') {
        status = '请点选棋盘空格放置第 ${workers[turn].length + 1}/2 名工人';
      } else if (step == 'move') {
        if (effWorker < 0) {
          status = '轮到你：请点选你的 1 名工人（${_seatColorNames[turn]}色）';
        } else if (prebuildMode) {
          status = '普罗米修斯：点橙色格先建造（随后该工人移动不能攀爬）';
        } else {
          status = '点绿色格移动工人（或点另一名己方工人切换）';
        }
      } else if (step == 'post_prebuild') {
        status = '普罗米修斯：请移动刚才建造的工人（本回合不能向上攀爬）';
      } else if (step == 'build') {
        if (domeMode) {
          status = '阿特拉斯：点橙色格直接加盖蓝色穹顶（4层）';
        } else if (doubleMode) {
          status = '赫菲斯托斯：点橙色格连续加盖 2 层';
        } else {
          status = '点选相邻橙色格建造建筑（+1层）';
        }
      } else {
        status = '德墨忒尔：可点橙色格建造第 2 次，或点“结束建造”';
      }
    } else {
      final stepLabel = phase == 'place' ? '放置工人' : (step.startsWith('build') ? '建造' : '移动');
      status = '等待 ${g.name(turn)}（${_seatColorNames[turn]}方）$stepLabel';
    }

    // Action buttons for god abilities
    final actions = <Widget>[];
    if (myTurn && phase == 'play') {
      if (step == 'move' && legalPrebuilds.isNotEmpty) {
        final hasForSelected = effWorker < 0 || legalPrebuilds.any((p) => p.$1 == effWorker);
        if (hasForSelected) {
          actions.add(a3Button(
            context,
            prebuildMode ? '取消先建' : '先建后移（普罗米修斯）',
            Icons.foundation,
            () => setState(() {
              prebuildMode = !prebuildMode;
              if (prebuildMode && effWorker < 0) {
                selWorker = legalPrebuilds.first.$1;
              }
            }),
            primary: prebuildMode,
          ));
        }
      }
      if (step == 'build' && canDome) {
        actions.add(a3Button(
          context,
          domeMode ? '改为普通建造(+1)' : '直接建穹顶（阿特拉斯）',
          Icons.roofing,
          () => setState(() => domeMode = !domeMode),
          primary: domeMode,
        ));
      }
      if (step == 'build' && doubleCells.isNotEmpty) {
        actions.add(a3Button(
          context,
          doubleMode ? '改为建 1 层' : '连建 2 层（赫菲斯托斯）',
          Icons.layers,
          () => setState(() => doubleMode = !doubleMode),
          primary: doubleMode,
        ));
      }
      if (step == 'build2' && canPass) {
        actions.add(a3Button(
          context,
          '结束建造',
          Icons.check_circle_outline,
          () => g.act({'type': 'pass'}),
          primary: true,
        ));
      }
    }

    // Optional God cards tray when godMode is enabled
    Widget? tray;
    if (godEnabled) {
      tray = A3Panel(
        highlight: myTurn,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var s = 0; s < g.players; s++)
                Builder(builder: (context) {
                  final god = santoriniGodById(gods[s]);
                  if (god == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4, right: 6),
                        decoration: BoxDecoration(color: _playerColor(s), shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Text(
                          '${g.name(s)}【${god.name}·${god.title}】：${god.desc}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: s == turn ? FontWeight.w700 : FontWeight.normal,
                            color: eliminated[s] ? cs.onSurface.withValues(alpha: 0.45) : cs.onSurface,
                          ),
                        ),
                      ),
                    ]),
                  );
                }),
            ],
          ),
        ),
      );
    }

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _SantoriniPainter.hit(bSize, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_SantoriniPainter.hit(bSize, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _SantoriniPainter(
                heights: heights,
                workers: workers,
                eliminated: eliminated,
                selWorker: effWorker,
                moveTargets: moveTargets,
                buildTargets: buildTargets,
                winTargets: winTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastBuild: lastBuild,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final god = santoriniGodById(gods[s]);
      final godLabel = god != null ? ' · ${god.name}' : '';
      final stateLabel = eliminated[s]
          ? ' · 已出局'
          : (over ? (winner == s ? ' · 胜' : (winner == g.players ? ' · 和' : ' · 负')) : '');
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '${_seatColorNames[s]}方$godLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: _playerColor(s), shape: BoxShape.circle),
        ),
      );
    }

    return A3Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      tray: tray,
      trayFraction: 0.18,
      trayLandscapeHeight: 110,
      actions: actions,
      info: [
        if (athenaLocked) '【雅典娜禁令生效中】本轮其他玩家的工人不能向上攀爬！',
        if (note.isNotEmpty) '上一步：$note',
        '规则：移动 1 名工人（最多向上爬 1 层）→ 在相邻空格建造（+1层，4层为穹顶），踏上第 3 层即胜！',
      ],
      result: a3Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
