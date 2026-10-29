import 'dart:math';

import 'package:aurora_shared/games/abstract7/tzaar.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _TzaarPainter extends CustomPainter {
  final List<int> owner;
  final List<int> pieceType;
  final List<int> height;
  final int selFrom;
  final Set<int> moveTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final String lastKind;
  final Color accent;

  _TzaarPainter({
    required this.owner,
    required this.pieceType,
    required this.height,
    required this.selFrom,
    required this.moveTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastKind,
    required this.accent,
  });

  static double _spacing(Size s) => min(s.width, s.height) / 9.8;

  static Offset cellCenter(Size s, int idx) {
    final (q, r) = tzaarCoords[idx];
    final sp = _spacing(s);
    final cx = s.width / 2 + sp * (q + r * 0.5);
    final cy = s.height / 2 + sp * (r * 0.8660254);
    return Offset(cx, cy);
  }

  static int hit(Size s, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final sp = _spacing(s);
    final maxDist2 = (sp * 0.48) * (sp * 0.48);
    var bestIdx = -1;
    var bestD2 = maxDist2;
    for (var i = 0; i < tzaarCoords.length; i++) {
      final c = cellCenter(s, i);
      final dx = o.dx - c.dx, dy = o.dy - c.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 <= bestD2) {
        bestD2 = d2;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sp = _spacing(size);
    final center = Offset(size.width / 2, size.height / 2);

    // Outer hexagonal board medallion
    final outerPath = Path();
    final outerR = sp * 4.72;
    for (var k = 0; k < 6; k++) {
      final angle = k * pi / 3;
      final pt = center + Offset(outerR * cos(angle), outerR * sin(angle));
      if (k == 0) {
        outerPath.moveTo(pt.dx, pt.dy);
      } else {
        outerPath.lineTo(pt.dx, pt.dy);
      }
    }
    outerPath.close();

    canvas.drawPath(outerPath.shift(Offset(0, sp * 0.08)), a7Shadow(sp * 0.2, alpha: 0.45));
    canvas.drawPath(
      outerPath,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF212B38), Color(0xFF141C26), Color(0xFF0B1017)],
          stops: [0.0, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );
    canvas.drawPath(
      outerPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, sp * 0.08)
        ..color = const Color(0xFF90A4AE).withValues(alpha: 0.55),
    );

    // Central abyssal pit at (0, 0) — pieces cannot enter or cross this pit!
    final pitR = sp * 0.62;
    canvas.drawCircle(
      center,
      pitR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF000000), Color(0xFF090D12), Color(0xFF263238)],
          stops: [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: pitR)),
    );
    canvas.drawCircle(
      center,
      pitR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.4, sp * 0.05)
        ..color = const Color(0xFF546E7A).withValues(alpha: 0.65),
    );
    a7PaintTextCentered(canvas, '✕', center, sp * 0.34, const Color(0x7778909C));

    // Draw grid lines between adjacent non-center cells
    final linePaint = Paint()
      ..color = const Color(0xFF90A4AE).withValues(alpha: 0.34)
      ..strokeWidth = max(1.0, sp * 0.034);
    const halfDirs = [(1, 0), (0, 1), (1, -1)];
    for (var i = 0; i < tzaarCoords.length; i++) {
      final (q, r) = tzaarCoords[i];
      final p0 = cellCenter(size, i);
      for (final (dq, dr) in halfDirs) {
        final j = tzaarIndex(q + dq, r + dr);
        if (j != -1) {
          final p1 = cellCenter(size, j);
          canvas.drawLine(p0, p1, linePaint);
        }
      }
    }

    // Last move line
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < tzaarCoords.length && lastTo < tzaarCoords.length) {
      final p0 = cellCenter(size, lastFrom);
      final p1 = cellCenter(size, lastTo);
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = lastKind == 'capture' ? const Color(0xAAE53935) : const Color(0xAA43A047)
          ..strokeWidth = max(2.0, sp * 0.09)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw intersection sockets & highlights
    for (var i = 0; i < tzaarCoords.length; i++) {
      final c = cellCenter(size, i);
      canvas.drawCircle(c, sp * 0.10, Paint()..color = const Color(0xFF546E7A));
      canvas.drawCircle(c, sp * 0.05, Paint()..color = const Color(0xFFCFD8DC));

      if (i == lastFrom || i == lastTo) {
        canvas.drawCircle(
          c,
          sp * 0.42,
          Paint()..color = lastKind == 'capture' ? const Color(0x44EF5350) : const Color(0x4466BB6A),
        );
      }
    }

    // Draw stacks
    for (var i = 0; i < tzaarCoords.length; i++) {
      final h = height[i];
      if (h <= 0) continue;
      final c = cellCenter(size, i);
      _paintStack(
        canvas,
        c,
        sp,
        seat: owner[i],
        type: pieceType[i],
        h: h,
        selected: i == selFrom,
      );
    }

    // Draw legal target rings (red for capture, green/gold for strengthen!)
    for (final t in moveTargets) {
      final c = cellCenter(size, t);
      final isHover = t == hover;
      final isCap = selFrom >= 0 && owner[t] != owner[selFrom];
      canvas.drawCircle(
        c,
        sp * (isHover ? 0.45 : 0.42),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.2, sp * (isHover ? 0.095 : 0.075))
          ..color = isCap ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
      );
    }
  }

  void _paintStack(
    Canvas canvas,
    Offset c,
    double sp, {
    required int seat,
    required int type,
    required int h,
    required bool selected,
  }) {
    final outerR = sp * 0.38;
    canvas.drawCircle(c + Offset(sp * 0.025, sp * 0.045), outerR, a7Shadow(sp * 0.14, alpha: 0.48));

    final gradColors = seat == 0
        ? const [Color(0xFFFFFFFF), Color(0xFFECEFF1), Color(0xFFB0BEC5)]
        : const [Color(0xFF455A64), Color(0xFF263238), Color(0xFF0D1317)];
    final textColor = seat == 0 ? const Color(0xFF1C262B) : const Color(0xFFF5F7FA);

    // Distinct inner medallion rim per piece type:
    // 0: Tzaar (皇, Gold), 1: Tzarra (骑, Cyan), 2: Tott (兵, Bronze/Amber)
    final Color typeRingColor = type == 0
        ? const Color(0xFFFFB300)
        : (type == 1 ? const Color(0xFF29B6F6) : const Color(0xFFA1887F));

    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: gradColors,
          stops: const [0.0, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: outerR)),
    );

    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.4, sp * (selected ? 0.08 : 0.036))
        ..color = selected ? const Color(0xFFFFD54F) : typeRingColor.withValues(alpha: 0.85),
    );

    canvas.drawCircle(
      c,
      outerR * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.3, sp * (type == 0 ? 0.06 : 0.042))
        ..color = typeRingColor,
    );

    final sym = (type >= 0 && type < tzaarTypeShort.length) ? tzaarTypeShort[type] : '?';
    final label = h > 1 ? '$sym$h' : sym;
    a7PaintTextCentered(
      canvas,
      label,
      c,
      sp * (label.length > 1 ? 0.23 : 0.27),
      textColor,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TzaarBoardView extends StatefulWidget {
  final GameContext g;
  const TzaarBoardView(this.g, {super.key});
  @override
  State<TzaarBoardView> createState() => _TzaarBoardViewState();
}

class _TzaarBoardViewState extends State<TzaarBoardView> {
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  int _countType(List<int> owner, List<int> pieceType, List<int> height, int seat, int t) {
    var cnt = 0;
    for (var i = 0; i < tzaarCoords.length; i++) {
      if (height[i] > 0 && owner[i] == seat && pieceType[i] == t) cnt++;
    }
    return cnt;
  }

  List<int> _legalTargets(
    List<int> owner,
    List<int> pieceType,
    List<int> height,
    bool isOpeningTurn,
    int step,
    int from,
  ) {
    if (from < 0 || from >= tzaarCoords.length || height[from] <= 0) return const [];
    final s = owner[from];
    if (s != 0 && s != 1) return const [];
    final allowStrengthen = step == 2 && !isOpeningTurn;
    final (q0, r0) = tzaarCoords[from];
    final out = <int>[];
    for (final (dq, dr) in tzaarDirs) {
      var cq = q0 + dq, cr = r0 + dr;
      while (true) {
        final idx = tzaarIndex(cq, cr);
        if (idx == -1) break;
        if (height[idx] > 0) {
          if (owner[idx] == 1 - s) {
            if (height[from] >= height[idx]) out.add(idx);
          } else if (allowStrengthen && owner[idx] == s) {
            final tType = pieceType[idx];
            if (pieceType[from] == tType || _countType(owner, pieceType, height, s, tType) > 1) {
              out.add(idx);
            }
          }
          break;
        }
        cq += dq;
        cr += dr;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    if (_lastPlies != v['plies']) {
      _lastPlies = v['plies'];
      selFrom = -1;
    }

    final owner = (v['owner'] as List).cast<int>();
    final pieceType = (v['pieceType'] as List).cast<int>();
    final height = (v['height'] as List).cast<int>();
    final isOpeningTurn = v['isOpeningTurn'] == true;
    final turn = v['turn'] as int;
    final step = (v['step'] as int?) ?? 1;
    final typeCountsRaw = (v['typeCounts'] as List?) ??
        const [
          [6, 9, 15],
          [6, 9, 15],
        ];
    final typeCounts = [
      (typeCountsRaw[0] as List).cast<int>(),
      (typeCountsRaw[1] as List).cast<int>(),
    ];
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastKind = (last?['kind'] as String?) ?? 'capture';

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final moveTargets = <int>{};
    if (myTurn && selFrom >= 0 && selFrom < tzaarCoords.length && owner[selFrom] == turn && height[selFrom] > 0) {
      moveTargets.addAll(_legalTargets(owner, pieceType, height, isOpeningTurn, step, selFrom));
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= tzaarCoords.length) return;
      if (selFrom >= 0 && moveTargets.contains(c)) {
        final f = selFrom;
        setState(() => selFrom = -1);
        g.act({'type': 'move', 'from': f, 'to': c});
        return;
      }
      if (owner[c] == turn && height[c] > 0) {
        setState(() => selFrom = selFrom == c ? -1 : c);
      }
    }

    final sideName = turn == 0 ? '白方' : '黑方';
    final stepBadge = isOpeningTurn ? '首回合(仅1步吃子)' : (step == 1 ? '第1步(强制吃子)' : '第2步(连吃/叠高/跳过)');
    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      if (selFrom < 0) {
        status = '轮到你（$sideName · $stepBadge）：请点选己方棋垛';
      } else {
        status = step == 1 || isOpeningTurn
            ? '已选 ${tzaarCellLabel(selFrom)}（高 ${height[selFrom]}）：点击红圈吃掉不高于你的敌方棋垛'
            : '已选 ${tzaarCellLabel(selFrom)}（高 ${height[selFrom]}）：红圈吃敌子，绿圈叠高己方棋垛，或点跳过';
      }
    } else {
      status = '等待 ${g.name(turn)}（$sideName · $stepBadge）行动';
    }

    final actions = <Widget>[];
    if (myTurn && step == 2 && !isOpeningTurn) {
      actions.add(a7Button(
        context,
        '跳过第 2 步',
        Icons.skip_next,
        () => g.act({'type': 'pass'}),
        primary: true,
      ));
    }
    if (myTurn && selFrom >= 0) {
      actions.add(a7Button(
        context,
        '取消选择',
        Icons.clear,
        () => setState(() => selFrom = -1),
      ));
    }

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _TzaarPainter.hit(bSize, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_TzaarPainter.hit(bSize, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _TzaarPainter(
                owner: owner,
                pieceType: pieceType,
                height: height,
                selFrom: selFrom,
                moveTargets: moveTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastKind: lastKind,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sLabel = s == 0 ? '白方' : '黑方';
      final tc = typeCounts[s];
      final countsLabel = '皇${tc[0]}·骑${tc[1]}·兵${tc[2]}';
      final stateLabel = over
          ? (winner == s ? ' · 胜($countsLabel)' : (winner == 2 ? ' · 和' : ' · 负($countsLabel)'))
          : ' · $countsLabel';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sLabel$stateLabel',
        trailing: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFFECEFF1) : const Color(0xFF263238),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFB300),
              width: 2.2,
            ),
          ),
        ),
      );
    }

    return A7Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '规则：第1步必须吃子（己方高度≥敌方），第2步可再吃、叠高己方或跳过；失去沙皇(皇)/贵族(骑)/卫兵(兵)任一兵种或无子可吃即负！',
      ],
      result: a7Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
