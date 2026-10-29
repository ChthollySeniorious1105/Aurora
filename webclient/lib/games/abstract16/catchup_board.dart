import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CatchupBoard extends StatefulWidget {
  final GameContext g;
  const CatchupBoard(this.g, {super.key});

  @override
  State<CatchupBoard> createState() => _CatchupBoardState();
}

class _CatchupBoardState extends State<CatchupBoard> {
  static const List<(int, int)> _kHexDirs = [
    (1, 0),
    (0, 1),
    (-1, 1),
  ];

  static Offset _axialToPixel(int q, int r, double hexRadius, Offset center) {
    final x = hexRadius * sqrt(3) * (q + r * 0.5);
    final y = hexRadius * 1.5 * r;
    return Offset(center.dx + x, center.dy + y);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final radius = (v['radius'] as num?)?.toInt() ?? 4;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final quota = (v['quota'] as num?)?.toInt() ?? 2;
    final placedThisTurn = (v['placedThisTurn'] as num?)?.toInt() ?? 0;
    final catchupTriggered = v['catchupTriggered'] == true;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawCells = (v['cells'] as List?)?.cast<Map>() ?? const [];
    final rawGroups = (v['groups'] as List?) ?? const [[], []];
    final lastTurnRaw = (v['lastTurnPlacements'] as List?)?.cast<Map>() ?? const [];
    final currTurnRaw = (v['currentTurnPlacements'] as List?)?.cast<Map>() ?? const [];

    final isMyTurn = !over && g.seat == turn;

    List<int> parseGroupList(int s) {
      if (s < rawGroups.length && rawGroups[s] is List) {
        return (rawGroups[s] as List).map((e) => (e as num).toInt()).toList();
      }
      return const [];
    }

    final g0 = parseGroupList(0);
    final g1 = parseGroupList(1);

    final cellMap = <(int, int), Map>{};
    for (final c in rawCells) {
      final q = (c['q'] as num?)?.toInt() ?? 0;
      final r = (c['r'] as num?)?.toInt() ?? 0;
      cellMap[(q, r)] = c;
    }

    final highlightHexes = <(int, int)>{
      for (final m in lastTurnRaw)
        ((m['q'] as num?)?.toInt() ?? 999, (m['r'] as num?)?.toInt() ?? 999),
      for (final m in currTurnRaw)
        ((m['q'] as num?)?.toInt() ?? 999, (m['r'] as num?)?.toInt() ?? 999),
    };

    final rem = max(0, quota - placedThisTurn);
    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      final triggerTag = catchupTriggered ? '【追赶3子触发！】' : '';
      statusText =
          '$triggerTag轮到你：点击空六角格落子（本回合已放 $placedThisTurn/$quota 子，还可放 $rem 子）';
    } else {
      final triggerTag = catchupTriggered ? '（触发3子追赶配额）' : '';
      statusText = '等待 ${g.name(turn)} 落子（$placedThisTurn/$quota）$triggerTag…';
    }

    Widget buildPlayerPanel(int s) {
      final isFirst = s == 0;
      final grp = s == 0 ? g0 : g1;
      final grpText = grp.isEmpty
          ? '暂无棋群'
          : '群序列 [${grp.take(4).join(',')}${grp.length > 4 ? ',…' : ''}]';
      final colorLabel = isFirst ? '橙方' : '青方';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · $grpText',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFirst ? const Color(0xFFFF7043) : const Color(0xFF26C6DA),
            border: Border.all(
              color: isFirst ? const Color(0xFFFFE082) : const Color(0xFFE0F7FA),
              width: 2.0,
            ),
          ),
        ),
      );
    }

    Widget? buildEndTurnButton() {
      if (!isMyTurn || placedThisTurn < 1 || placedThisTurn >= quota) return null;
      return FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        onPressed: () => g.act({'type': 'end_turn'}),
        icon: const Icon(Icons.check_circle_outline, size: 16),
        label: Text('结束回合 ($placedThisTurn/$quota)'),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 20 || h <= 20) return const SizedBox.shrink();

          final hexRadius = min(
            w / (sqrt(3) * (2 * radius + 1.5)),
            h / (3.0 * radius + 2.6),
          );
          final center = Offset(w / 2, h / 2);

          (int, int)? hitHexAt(Offset pos) {
            (int, int)? best;
            var bestDist = hexRadius * 0.92;
            for (final key in cellMap.keys) {
              final cPos = _axialToPixel(key.$1, key.$2, hexRadius, center);
              final d = (pos - cPos).distance;
              if (d < bestDist) {
                bestDist = d;
                best = key;
              }
            }
            return best;
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn
                ? null
                : (details) {
                    final hit = hitHexAt(details.localPosition);
                    if (hit != null) {
                      final data = cellMap[hit];
                      final owner = (data?['owner'] as num?)?.toInt() ?? -1;
                      if (owner == -1) {
                        g.act({'type': 'place', 'q': hit.$1, 'r': hit.$2});
                      }
                    }
                  },
            child: CustomPaint(
              size: Size(w, h),
              painter: _CatchupPainter(
                cellMap: cellMap,
                highlightHexes: highlightHexes,
                isMyTurn: isMyTurn,
                hexRadius: hexRadius,
                center: center,
                cs: cs,
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, outer) {
        final isWide = outer.maxWidth >= 680 && outer.maxWidth > outer.maxHeight * 1.15;
        final endTurnBtn = buildEndTurnButton();

        return Stack(
          children: [
            Container(
              color: g.table,
              padding: const EdgeInsets.all(8),
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: min(240, outer.maxWidth * 0.28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildPlayerPanel(1),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: StatusBar(statusText, highlight: isMyTurn),
                                      ),
                                      if (endTurnBtn != null) ...[
                                        const SizedBox(height: 6),
                                        FittedBox(fit: BoxFit.scaleDown, child: endTurnBtn),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              buildPlayerPanel(0),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: buildPlayerPanel(0)),
                            const SizedBox(width: 6),
                            Expanded(child: buildPlayerPanel(1)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: StatusBar(statusText, highlight: isMyTurn),
                              ),
                            ),
                            if (endTurnBtn != null) ...[
                              const SizedBox(width: 6),
                              FittedBox(fit: BoxFit.scaleDown, child: endTurnBtn),
                            ],
                          ],
                        ),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    ),
            ),
            if (over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CatchupPainter extends CustomPainter {
  final Map<(int, int), Map> cellMap;
  final Set<(int, int)> highlightHexes;
  final bool isMyTurn;
  final double hexRadius;
  final Offset center;
  final ColorScheme cs;

  _CatchupPainter({
    required this.cellMap,
    required this.highlightHexes,
    required this.isMyTurn,
    required this.hexRadius,
    required this.center,
    required this.cs,
  });

  static Path _hexPath(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * pi / 180.0;
      final px = c.dx + r * cos(angle);
      final py = c.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw hex cells
    for (final entry in cellMap.entries) {
      final (q, r) = entry.key;
      final cPos = _CatchupBoardState._axialToPixel(q, r, hexRadius, center);
      final path = _hexPath(cPos, hexRadius * 0.94);
      final isHighlighted = highlightHexes.contains((q, r));

      Color fill = const Color(0xFF28231E);
      if (isHighlighted) {
        fill = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), fill);
      }
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHighlighted ? 2.0 : 1.0
          ..color = isHighlighted ? Colors.amberAccent : Colors.white.withValues(alpha: 0.16),
      );
    }

    // 2. Draw links between connected same-owner stones
    for (final entry in cellMap.entries) {
      final (q, r) = entry.key;
      final owner = (entry.value['owner'] as num?)?.toInt() ?? -1;
      if (owner < 0) continue;
      final p1 = _CatchupBoardState._axialToPixel(q, r, hexRadius, center);
      final linkColor = owner == 0
          ? const Color(0xFFFF8A65).withValues(alpha: 0.65)
          : const Color(0xFF4DD0E1).withValues(alpha: 0.65);

      for (final (dq, dr) in _CatchupBoardState._kHexDirs) {
        final nh = (q + dq, r + dr);
        final nData = cellMap[nh];
        if (nData != null && ((nData['owner'] as num?)?.toInt() ?? -1) == owner) {
          final p2 = _CatchupBoardState._axialToPixel(nh.$1, nh.$2, hexRadius, center);
          canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = linkColor
              ..strokeWidth = hexRadius * 0.28
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // 3. Draw stones and group size badges
    for (final entry in cellMap.entries) {
      final (q, r) = entry.key;
      final data = entry.value;
      final owner = (data['owner'] as num?)?.toInt() ?? -1;
      final groupSize = (data['groupSize'] as num?)?.toInt() ?? 0;
      final cPos = _CatchupBoardState._axialToPixel(q, r, hexRadius, center);

      if (owner >= 0) {
        final stoneR = hexRadius * 0.56;
        final isP0 = owner == 0;
        canvas.drawCircle(
          cPos + const Offset(1.2, 2.0),
          stoneR,
          Paint()..color = Colors.black54,
        );
        canvas.drawCircle(
          cPos,
          stoneR,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: isP0
                  ? [const Color(0xFFFF8A65), const Color(0xFFD84315)]
                  : [const Color(0xFF4DD0E1), const Color(0xFF00838F)],
            ).createShader(Rect.fromCircle(center: cPos, radius: stoneR)),
        );
        canvas.drawCircle(
          cPos,
          stoneR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = isP0 ? const Color(0xFFFFE082) : const Color(0xFFE0F7FA),
        );

        final tp = TextPainter(
          text: TextSpan(
            text: '$groupSize',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: hexRadius * 0.44,
              fontFamilyFallback: kFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, cPos - Offset(tp.width / 2, tp.height / 2));
      } else if (isMyTurn) {
        canvas.drawCircle(
          cPos,
          hexRadius * 0.16,
          Paint()..color = Colors.greenAccent.withValues(alpha: 0.45),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CatchupPainter oldDelegate) => true;
}
