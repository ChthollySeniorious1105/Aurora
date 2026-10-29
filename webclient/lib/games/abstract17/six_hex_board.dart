import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class SixHexBoard extends StatefulWidget {
  final GameContext g;
  const SixHexBoard(this.g, {super.key});

  @override
  State<SixHexBoard> createState() => _SixHexBoardState();
}

class _SixHexBoardState extends State<SixHexBoard> {
  (int, int)? _selectedFrom;
  (int, int)? _hoveredHex;

  static Offset _axialUnitOffset(int q, int r) {
    final x = sqrt(3) * (q + r * 0.5);
    final y = 1.5 * r;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'place';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final winningShape = v['winningShape'] as String?;
    final reserve =
        (v['reserve'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [18, 18];
    final lastMove = v['lastMove'] as Map?;

    final rawCells = (v['cells'] as List?)?.cast<Map>() ?? const [];
    final tileMap = <(int, int), int>{};
    for (final c in rawCells) {
      final q = (c['q'] as num?)?.toInt() ?? 0;
      final r = (c['r'] as num?)?.toInt() ?? 0;
      final owner = (c['owner'] as num?)?.toInt() ?? 0;
      tileMap[(q, r)] = owner;
    }

    final winningSet = <(int, int)>{};
    final rawWinCells = (v['winningCells'] as List?) ?? const [];
    for (final wc in rawWinCells) {
      if (wc is List && wc.length >= 2) {
        winningSet.add(((wc[0] as num).toInt(), (wc[1] as num).toInt()));
      }
    }

    final isMyTurn = !over && g.seat == turn;

    final legalPlaceSet = <(int, int)>{};
    if (phase == 'place') {
      final rawPlace = (v['legalPlacements'] as List?)?.cast<Map>() ?? const [];
      for (final p in rawPlace) {
        final q = (p['q'] as num?)?.toInt() ?? 0;
        final r = (p['r'] as num?)?.toInt() ?? 0;
        legalPlaceSet.add((q, r));
      }
    }

    final moveTargetsByFrom = <(int, int), Set<(int, int)>>{};
    if (phase == 'move') {
      final rawMoves = (v['legalMoves'] as List?)?.cast<Map>() ?? const [];
      for (final m in rawMoves) {
        final fq = (m['fromQ'] as num?)?.toInt() ?? 0;
        final fr = (m['fromR'] as num?)?.toInt() ?? 0;
        final tq = (m['toQ'] as num?)?.toInt() ?? 0;
        final tr = (m['toR'] as num?)?.toInt() ?? 0;
        moveTargetsByFrom.putIfAbsent((fq, fr), () => <(int, int)>{}).add((tq, tr));
      }
    }

    if (_selectedFrom != null &&
        (!isMyTurn || phase != 'move' || !moveTargetsByFrom.containsKey(_selectedFrom))) {
      _selectedFrom = null;
    }

    final activeMoveTargets =
        _selectedFrom != null ? (moveTargetsByFrom[_selectedFrom] ?? const <(int, int)>{}) : const <(int, int)>{};

    final tileCount0 = tileMap.values.where((o) => o == 0).length;
    final tileCount1 = tileMap.values.where((o) => o == 1).length;

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (phase == 'place') {
      if (isMyTurn) {
        statusText = '【布子阶段】轮到你：点击外围虚线空六角格放置六角砖（凑齐六子直线/圆环/三角即胜）';
      } else {
        statusText = '【布子阶段】等待 ${g.name(turn)} 放置六角砖…';
      }
    } else {
      if (isMyTurn) {
        statusText = _selectedFrom == null
            ? '【移子阶段】轮到你：点击一枚带高亮边框的己方外缘六角砖'
            : '【移子阶段】已选 (${_selectedFrom!.$1}, ${_selectedFrom!.$2})，点击绿色目标空六角格完成移子';
      } else {
        statusText = '【移子阶段】等待 ${g.name(turn)} 移动外缘六角砖…';
      }
    }

    Widget buildPlayerPanel(int s) {
      final isRed = s == 0;
      final res = s < reserve.length ? reserve[s] : 0;
      final onBoard = s == 0 ? tileCount0 : tileCount1;
      final colorLabel = isRed ? '红砖' : '黑砖';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · 储备 $res · 场上 $onBoard',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRed ? const Color(0xFFD32F2F) : const Color(0xFF263238),
            border: Border.all(
              color: isRed ? const Color(0xFFFFCA28) : const Color(0xFF4DD0E1),
              width: 2.0,
            ),
          ),
        ),
      );
    }

    Widget buildShapeLegend() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: Text(
          '获胜六形：━ 六子直线  ·  ⬡ 六子圆环  ·  ▲ 六子三角',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.85)),
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 20 || h <= 20) return const SizedBox.shrink();

          // Collect all hex coordinates to display (occupied + legal targets)
          final allCoords = <(int, int)>{
            ...tileMap.keys,
            ...legalPlaceSet,
            ...activeMoveTargets,
          };
          if (allCoords.isEmpty) allCoords.add((0, 0));

          var minX = double.infinity;
          var maxX = double.negativeInfinity;
          var minY = double.infinity;
          var maxY = double.negativeInfinity;
          for (final (q, r) in allCoords) {
            final u = _axialUnitOffset(q, r);
            if (u.dx < minX) minX = u.dx;
            if (u.dx > maxX) maxX = u.dx;
            if (u.dy < minY) minY = u.dy;
            if (u.dy > maxY) maxY = u.dy;
          }

          final spanX = max(maxX - minX + 2.6, 6.0);
          final spanY = max(maxY - minY + 2.6, 6.0);
          final hexRadius = min(w / spanX, h / spanY).clamp(10.0, 42.0);
          final midU = Offset((minX + maxX) / 2, (minY + maxY) / 2);
          final canvasCenter = Offset(w / 2, h / 2);

          Offset hexToPixel(int q, int r) {
            final u = _axialUnitOffset(q, r);
            return canvasCenter + (u - midU) * hexRadius;
          }

          (int, int)? hitHexAt(Offset pos) {
            (int, int)? best;
            var bestDist = hexRadius * 0.92;
            for (final key in allCoords) {
              final cPos = hexToPixel(key.$1, key.$2);
              final d = (pos - cPos).distance;
              if (d < bestDist) {
                bestDist = d;
                best = key;
              }
            }
            return best;
          }

          return MouseRegion(
            onHover: !isMyTurn
                ? null
                : (e) {
                    final hit = hitHexAt(e.localPosition);
                    if (hit != _hoveredHex) setState(() => _hoveredHex = hit);
                  },
            onExit: (_) {
              if (_hoveredHex != null) setState(() => _hoveredHex = null);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: !isMyTurn
                  ? null
                  : (details) {
                      final hit = hitHexAt(details.localPosition);
                      if (hit == null) return;
                      if (phase == 'place') {
                        if (legalPlaceSet.contains(hit)) {
                          g.act({'type': 'place', 'q': hit.$1, 'r': hit.$2});
                        }
                      } else if (phase == 'move') {
                        if (_selectedFrom != null && activeMoveTargets.contains(hit)) {
                          final (fq, fr) = _selectedFrom!;
                          setState(() => _selectedFrom = null);
                          g.act({
                            'type': 'move',
                            'fromQ': fq,
                            'fromR': fr,
                            'toQ': hit.$1,
                            'toR': hit.$2,
                          });
                        } else if (moveTargetsByFrom.containsKey(hit)) {
                          setState(() => _selectedFrom = hit);
                        } else {
                          setState(() => _selectedFrom = null);
                        }
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _SixHexPainter(
                  tileMap: tileMap,
                  legalPlaceSet: legalPlaceSet,
                  movableSources: moveTargetsByFrom.keys.toSet(),
                  selectedFrom: _selectedFrom,
                  activeMoveTargets: activeMoveTargets,
                  hoveredHex: _hoveredHex,
                  winningSet: winningSet,
                  winningShape: winningShape,
                  lastMove: lastMove,
                  phase: phase,
                  isMyTurn: isMyTurn,
                  hexRadius: hexRadius,
                  midU: midU,
                  canvasCenter: canvasCenter,
                  cs: cs,
                ),
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, outer) {
        final isWide = outer.maxWidth >= 680 && outer.maxWidth > outer.maxHeight * 1.15;

        return Stack(
          children: [
            Container(
              color: g.table,
              padding: const EdgeInsets.all(8),
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: min(250, outer.maxWidth * 0.30),
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
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: buildShapeLegend(),
                                      ),
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: buildShapeLegend(),
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

class _SixHexPainter extends CustomPainter {
  final Map<(int, int), int> tileMap;
  final Set<(int, int)> legalPlaceSet;
  final Set<(int, int)> movableSources;
  final (int, int)? selectedFrom;
  final Set<(int, int)> activeMoveTargets;
  final (int, int)? hoveredHex;
  final Set<(int, int)> winningSet;
  final String? winningShape;
  final Map? lastMove;
  final String phase;
  final bool isMyTurn;
  final double hexRadius;
  final Offset midU;
  final Offset canvasCenter;
  final ColorScheme cs;

  _SixHexPainter({
    required this.tileMap,
    required this.legalPlaceSet,
    required this.movableSources,
    required this.selectedFrom,
    required this.activeMoveTargets,
    required this.hoveredHex,
    required this.winningSet,
    required this.winningShape,
    required this.lastMove,
    required this.phase,
    required this.isMyTurn,
    required this.hexRadius,
    required this.midU,
    required this.canvasCenter,
    required this.cs,
  });

  Offset _hexToPixel(int q, int r) {
    final u = _SixHexBoardState._axialUnitOffset(q, r);
    return canvasCenter + (u - midU) * hexRadius;
  }

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
    final lastQ = (lastMove?['q'] ?? lastMove?['toQ'] as num?)?.toInt();
    final lastR = (lastMove?['r'] ?? lastMove?['toR'] as num?)?.toInt();

    // 1. Draw candidate empty hex slots
    final emptyTargets = phase == 'place' ? legalPlaceSet : activeMoveTargets;
    for (final (q, r) in emptyTargets) {
      final cPos = _hexToPixel(q, r);
      final path = _hexPath(cPos, hexRadius * 0.88);
      final isHovered = hoveredHex == (q, r);
      canvas.drawPath(
        path,
        Paint()
          ..color = isHovered
              ? Colors.greenAccent.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.08),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHovered ? 2.2 : 1.2
          ..color = isHovered
              ? Colors.greenAccent
              : (phase == 'move'
                  ? Colors.greenAccent.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.30)),
      );
      if (isMyTurn) {
        canvas.drawCircle(
          cPos,
          hexRadius * 0.16,
          Paint()
            ..color = isHovered
                ? Colors.greenAccent
                : Colors.greenAccent.withValues(alpha: 0.45),
        );
      }
    }

    // 2. Draw placed hex tiles
    for (final entry in tileMap.entries) {
      final (q, r) = entry.key;
      final owner = entry.value;
      final cPos = _hexToPixel(q, r);
      final outerPath = _hexPath(cPos, hexRadius * 0.93);
      final innerPath = _hexPath(cPos, hexRadius * 0.74);

      // Shadow
      canvas.drawPath(
        _hexPath(cPos + const Offset(1.5, 2.5), hexRadius * 0.93),
        Paint()..color = Colors.black45,
      );

      final isRed = owner == 0;
      final baseColor = isRed ? const Color(0xFFC62828) : const Color(0xFF263238);
      final topColor = isRed ? const Color(0xFFEF5350) : const Color(0xFF455A64);

      canvas.drawPath(outerPath, Paint()..color = baseColor);
      canvas.drawPath(innerPath, Paint()..color = topColor);

      final isWinCell = winningSet.contains((q, r));
      final isLast = lastQ == q && lastR == r;
      final isSelected = selectedFrom == (q, r);
      final isMovable = isMyTurn && phase == 'move' && movableSources.contains((q, r));

      Color borderColor = isRed ? const Color(0xFFFF8A80) : const Color(0xFF90A4AE);
      double strokeW = 1.4;
      if (isWinCell) {
        borderColor = const Color(0xFFFFD740);
        strokeW = 3.2;
      } else if (isSelected) {
        borderColor = Colors.cyanAccent;
        strokeW = 3.0;
      } else if (isMovable) {
        borderColor = Colors.greenAccent;
        strokeW = 2.2;
      } else if (isLast) {
        borderColor = Colors.amberAccent;
        strokeW = 2.4;
      }

      canvas.drawPath(
        outerPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..color = borderColor,
      );

      // Center emblem / coordinate hint
      if (isWinCell) {
        canvas.drawCircle(
          cPos,
          hexRadius * 0.24,
          Paint()..color = const Color(0xFFFFD740),
        );
      } else {
        canvas.drawCircle(
          cPos,
          hexRadius * 0.14,
          Paint()..color = Colors.white.withValues(alpha: isRed ? 0.30 : 0.22),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SixHexPainter oldDelegate) => true;
}
