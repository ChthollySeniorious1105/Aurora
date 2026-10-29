import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<(int, int)> _hexDirs = [
  (1, 0),
  (1, -1),
  (0, -1),
  (-1, 0),
  (-1, 1),
  (0, 1),
];

int _hexDist(int q1, int r1, [int q2 = 0, int r2 = 0]) {
  final dq = (q1 - q2).abs();
  final dr = (r1 - r2).abs();
  final ds = ((q1 + r1) - (q2 + r2)).abs();
  return max(dq, max(dr, ds));
}

List<(int, int)> _pieceCells(String shape, int q, int r, int rot) {
  final r0 = ((rot % 6) + 6) % 6;
  final d1 = _hexDirs[r0];
  final (int, int) d2;
  switch (shape) {
    case 'straight':
      d2 = _hexDirs[(r0 + 3) % 6];
      break;
    case 'angled':
      d2 = _hexDirs[(r0 + 2) % 6];
      break;
    case 'triangle':
    default:
      d2 = _hexDirs[(r0 + 1) % 6];
      break;
  }
  return [
    (q, r),
    (q + d1.$1, r + d1.$2),
    (q + d2.$1, r + d2.$2),
  ];
}

class PunctBoard extends StatefulWidget {
  final GameContext g;
  const PunctBoard(this.g, {super.key});

  @override
  State<PunctBoard> createState() => _PunctBoardState();
}

class _PunctBoardState extends State<PunctBoard> {
  String _selectedShape = 'straight';
  int _rot = 0;
  int? _selectedPieceId; // non-null = moving an existing board piece
  (int, int)? _previewCell;

  Offset _axialToPixel(int q, int r, double step) {
    final x = step * 1.5 * q;
    final y = step * sqrt(3) * (r + q * 0.5);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final reservesList = (v['reserves'] as List?)?.cast<Map>() ?? const [];
    final totalReserves = (v['totalReserves'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [18, 18];
    final centralControl = (v['centralControl'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final cellsList = (v['cells'] as List?)?.cast<Map>() ?? const [];
    final piecesList = (v['pieces'] as List?)?.cast<Map>() ?? const [];
    final winningChainRaw = (v['winningChain'] as List?) ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final isMyTurn = !over && g.seat == turn;
    final mySeat = g.seat >= 0 && g.seat < 2 ? g.seat : turn;
    final myReserve = mySeat < reservesList.length ? reservesList[mySeat] : const {};

    // Ensure _selectedShape has reserve if possible
    if ((myReserve[_selectedShape] as num? ?? 0) <= 0) {
      for (final s in const ['straight', 'angled', 'triangle']) {
        if ((myReserve[s] as num? ?? 0) > 0) {
          _selectedShape = s;
          break;
        }
      }
    }

    final cellMap = <(int, int), Map>{};
    for (final c in cellsList) {
      cellMap[((c['q'] as num).toInt(), (c['r'] as num).toInt())] = c;
    }

    final pieceMap = <int, Map>{};
    for (final p in piecesList) {
      pieceMap[(p['id'] as num).toInt()] = p;
    }

    if (_selectedPieceId != null) {
      final sp = pieceMap[_selectedPieceId];
      if (sp == null || (sp['owner'] as num).toInt() != turn || sp['topMost'] != true) {
        _selectedPieceId = null;
      }
    }

    bool canDropAt(int q, int r, String shape, int rot) {
      if ((myReserve[shape] as num? ?? 0) <= 0) return false;
      final tri = _pieceCells(shape, q, r, rot);
      for (final (cq, cr) in tri) {
        final c = cellMap[(cq, cr)];
        if (c == null) return false;
        if (c['central'] == true) return false;
        if (((c['height'] as num?)?.toInt() ?? 0) != 0) return false;
      }
      return true;
    }

    bool canMovePieceTo(Map piece, int toQ, int toR, int rot) {
      final fromQ = (piece['q'] as num).toInt();
      final fromR = (piece['r'] as num).toInt();
      final dq = toQ - fromQ;
      final dr = toR - fromR;
      if (dq == 0 && dr == 0) return false;
      var straightLine = false;
      for (final (ux, uy) in _hexDirs) {
        if (ux == 0) {
          if (dq == 0 && dr * uy > 0) straightLine = true;
        } else if (uy == 0) {
          if (dr == 0 && dq * ux > 0) straightLine = true;
        } else {
          if (dq * ux > 0 && dr * uy > 0 && dq.abs() == dr.abs()) straightLine = true;
        }
      }
      if (!straightLine) return false;

      final shape = '${piece['shape']}';
      final targetCells = _pieceCells(shape, toQ, toR, rot);
      for (final (cq, cr) in targetCells) {
        if (!cellMap.containsKey((cq, cr))) return false;
      }

      final oldRaw = (piece['cells'] as List?) ?? const [];
      final oldSet = <(int, int)>{
        for (final item in oldRaw)
          if (item is List && item.length >= 2) ((item[0] as num).toInt(), (item[1] as num).toInt()),
      };

      int effHeight((int, int) pos) {
        final h = (cellMap[pos]?['height'] as num?)?.toInt() ?? 0;
        return oldSet.contains(pos) ? h - 1 : h;
      }

      final h0 = effHeight(targetCells[0]);
      final h1 = effHeight(targetCells[1]);
      final h2 = effHeight(targetCells[2]);
      if (h0 == 0 && h1 == 0 && h2 == 0) return true;
      if (h0 > 0 && h1 > 0 && h2 > 0 && !oldSet.contains(targetCells[0])) {
        final topCol = (cellMap[targetCells[0]]?['topColor'] as num?)?.toInt() ?? -1;
        if (topCol == turn) return true;
      }
      return false;
    }

    final legalMoveTargets = <(int, int)>{};
    if (isMyTurn && _selectedPieceId != null && pieceMap.containsKey(_selectedPieceId)) {
      final sp = pieceMap[_selectedPieceId]!;
      for (final pos in cellMap.keys) {
        if (canMovePieceTo(sp, pos.$1, pos.$2, _rot)) {
          legalMoveTargets.add(pos);
        }
      }
    }

    final winningSet = <(int, int)>{
      for (final item in winningChainRaw)
        if (item is List && item.length >= 2) ((item[0] as num).toInt(), (item[1] as num).toInt()),
    };

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_selectedPieceId != null) {
        statusText = '移动模式（棋子 #$_selectedPieceId）：点击绿圈目标格滑行或叠放，或可先旋转方向';
      } else if (_previewCell != null) {
        statusText = '预览投放 $_previewCell：再次点击该格确认投放，或点击己方顶层棋子改为滑行';
      } else {
        statusText = '轮到你：点击外圈空格预览投放新棋子，或点击己方顶层棋子进行滑行/叠放';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    Widget buildPlayerPanel(int s) {
      final colorLabel = s == 0 ? '白方' : '黑方';
      final rem = s < totalReserves.length ? totalReserves[s] : 0;
      final cc = s < centralControl.length ? centralControl[s] : 0;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · 储备 $rem · 中央 $cc',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s == 0 ? const Color(0xFFFDFBF7) : const Color(0xFF22252A),
            border: Border.all(
              color: s == 0 ? Colors.brown.shade400 : Colors.grey.shade400,
              width: 1.5,
            ),
          ),
        ),
      );
    }

    Widget buildControls() {
      if (!isMyTurn) return const SizedBox.shrink();
      const shapeLabels = {
        'straight': '直线',
        'angled': '折角',
        'triangle': '三角',
      };
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in shapeLabels.entries) ...[
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text('${entry.value}(${myReserve[entry.key] ?? 0})', style: const TextStyle(fontSize: 12)),
                selected: _selectedPieceId == null && _selectedShape == entry.key,
                onSelected: ((myReserve[entry.key] as num? ?? 0) > 0)
                    ? (_) => setState(() {
                          _selectedPieceId = null;
                          _selectedShape = entry.key;
                        })
                    : null,
              ),
              const SizedBox(width: 4),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: () => setState(() => _rot = (_rot + 1) % 6),
              icon: const Icon(Icons.rotate_right, size: 15),
              label: Text('旋转 ${_rot + 1}/6', style: const TextStyle(fontSize: 12)),
            ),
            if (_selectedPieceId != null) ...[
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => setState(() => _selectedPieceId = null),
                child: const Text('取消选子', style: TextStyle(fontSize: 12)),
              ),
            ] else if (_previewCell != null &&
                canDropAt(_previewCell!.$1, _previewCell!.$2, _selectedShape, _rot)) ...[
              const SizedBox(width: 4),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () {
                  final (q, r) = _previewCell!;
                  setState(() => _previewCell = null);
                  g.act({
                    'type': 'drop',
                    'shape': _selectedShape,
                    'rot': _rot,
                    'q': q,
                    'r': r,
                  });
                },
                icon: const Icon(Icons.check, size: 14),
                label: const Text('确认投放', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();
          final hexStep = side / 15.6;
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

          List<(int, int)>? previewTri;
          var previewLegal = false;
          if (isMyTurn && _selectedPieceId == null && _previewCell != null) {
            previewTri = _pieceCells(_selectedShape, _previewCell!.$1, _previewCell!.$2, _rot);
            previewLegal = canDropAt(_previewCell!.$1, _previewCell!.$2, _selectedShape, _rot);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn
                ? null
                : (details) {
                    final tap = details.localPosition - center;
                    (int, int)? hitCell;
                    var bestDist = hexStep * 0.85;
                    for (final pos in cellMap.keys) {
                      final p = _axialToPixel(pos.$1, pos.$2, hexStep);
                      final d = (tap - p).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        hitCell = pos;
                      }
                    }
                    if (hitCell == null) {
                      setState(() {
                        _selectedPieceId = null;
                        _previewCell = null;
                      });
                      return;
                    }

                    final (hq, hr) = hitCell;

                    // If in move mode and tapped a legal move target, execute move
                    if (_selectedPieceId != null && legalMoveTargets.contains(hitCell)) {
                      final pid = _selectedPieceId!;
                      setState(() {
                        _selectedPieceId = null;
                        _previewCell = null;
                      });
                      g.act({
                        'type': 'move',
                        'pieceId': pid,
                        'toQ': hq,
                        'toR': hr,
                        'rot': _rot,
                      });
                      return;
                    }

                    // Check if tapped cell has a top-most own piece -> select it for moving
                    final cellInfo = cellMap[hitCell]!;
                    final topPid = (cellInfo['topPieceId'] as num?)?.toInt();
                    if (topPid != null && pieceMap.containsKey(topPid)) {
                      final pData = pieceMap[topPid]!;
                      if ((pData['owner'] as num).toInt() == turn && pData['topMost'] == true) {
                        if (_selectedPieceId == topPid) {
                          setState(() => _selectedPieceId = null);
                        } else {
                          setState(() {
                            _selectedPieceId = topPid;
                            _rot = (pData['rot'] as num).toInt();
                            _previewCell = null;
                          });
                        }
                        return;
                      }
                    }

                    // Otherwise in drop mode: if tapping same preview cell and legal, drop!
                    if (_selectedPieceId == null) {
                      if (_previewCell == hitCell && canDropAt(hq, hr, _selectedShape, _rot)) {
                        setState(() => _previewCell = null);
                        g.act({
                          'type': 'drop',
                          'shape': _selectedShape,
                          'rot': _rot,
                          'q': hq,
                          'r': hr,
                        });
                      } else {
                        setState(() => _previewCell = hitCell);
                      }
                    } else {
                      setState(() => _selectedPieceId = null);
                    }
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _PunctPainter(
                cellMap: cellMap,
                pieceMap: pieceMap,
                selectedPieceId: _selectedPieceId,
                legalMoveTargets: legalMoveTargets,
                previewTri: previewTri,
                previewLegal: previewLegal,
                winningSet: winningSet,
                lastMove: lastMove,
                turn: turn,
                hexStep: hexStep,
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
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                                      if (isMyTurn) ...[
                                        const SizedBox(height: 6),
                                        buildControls(),
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
                        FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                        if (isMyTurn) ...[
                          const SizedBox(height: 4),
                          buildControls(),
                        ],
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

class _PunctPainter extends CustomPainter {
  final Map<(int, int), Map> cellMap;
  final Map<int, Map> pieceMap;
  final int? selectedPieceId;
  final Set<(int, int)> legalMoveTargets;
  final List<(int, int)>? previewTri;
  final bool previewLegal;
  final Set<(int, int)> winningSet;
  final Map? lastMove;
  final int turn;
  final double hexStep;
  final ColorScheme cs;

  _PunctPainter({
    required this.cellMap,
    required this.pieceMap,
    required this.selectedPieceId,
    required this.legalMoveTargets,
    required this.previewTri,
    required this.previewLegal,
    required this.winningSet,
    required this.lastMove,
    required this.turn,
    required this.hexStep,
    required this.cs,
  });

  Offset _pos(int q, int r, Offset center) {
    final x = hexStep * 1.5 * q;
    final y = hexStep * sqrt(3) * (r + q * 0.5);
    return center + Offset(x, y);
  }

  Path _hexPolygon(Offset c, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final pt = Offset(c.dx + radius * cos(angle), c.dy + radius * sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw outer board background
    final bgRadius = hexStep * 7.4;
    final bgPath = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + pi / 6;
      final pt = Offset(center.dx + bgRadius * cos(a), center.dy + bgRadius * sin(a));
      if (i == 0) {
        bgPath.moveTo(pt.dx, pt.dy);
      } else {
        bgPath.lineTo(pt.dx, pt.dy);
      }
    }
    bgPath.close();

    canvas.drawShadow(bgPath, Colors.black54, 8, false);
    canvas.drawPath(
      bgPath,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF28313E), const Color(0xFF171C24)],
        ).createShader(Rect.fromCircle(center: center, radius: bgRadius)),
    );
    canvas.drawPath(
      bgPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.55),
    );

    // Draw colored side pair indicators along the 6 outer sides
    const pairColors = [
      Color(0xFFFF7043), // Pair 0: q = -4 / q = 4
      Color(0xFF26C6DA), // Pair 1: r = -4 / r = 4
      Color(0xFFAB47BC), // Pair 2: q+r = -4 / q+r = 4
    ];
    final sideSegments = <(int, (int, int), (int, int))>[
      (0, (-4, 0), (-4, 4)),
      (0, (4, -4), (4, 0)),
      (1, (0, -4), (4, -4)),
      (1, (-4, 4), (0, 4)),
      (2, (-4, 0), (0, -4)),
      (2, (0, 4), (4, 0)),
    ];
    for (final (pairIdx, s1, s2) in sideSegments) {
      final p1 = _pos(s1.$1, s1.$2, center);
      final p2 = _pos(s2.$1, s2.$2, center);
      final mid = (p1 + p2) * 0.5;
      final dirOut = (mid - center);
      final normOut = dirOut.distance > 0 ? dirOut / dirOut.distance : Offset.zero;
      final shift = normOut * (hexStep * 0.72);
      canvas.drawLine(
        p1 + shift,
        p2 + shift,
        Paint()
          ..color = pairColors[pairIdx].withValues(alpha: 0.75)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Highlight last move cells
    final lastCells = <(int, int)>{};
    if (lastMove != null) {
      final raw = (lastMove!['cells'] as List?) ?? const [];
      for (final item in raw) {
        if (item is List && item.length >= 2) {
          lastCells.add(((item[0] as num).toInt(), (item[1] as num).toInt()));
        }
      }
    }

    // 1. Draw all 61 hex sockets (distinguishing Central Restricted Zone)
    for (final entry in cellMap.entries) {
      final (q, r) = entry.key;
      final c = entry.value;
      final isCentral = c['central'] == true;
      final p = _pos(q, r, center);
      final hexPath = _hexPolygon(p, hexStep * 0.54);

      canvas.drawPath(
        hexPath,
        Paint()
          ..color = isCentral
              ? const Color(0xFF3E2723).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.06),
      );
      canvas.drawPath(
        hexPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCentral ? 1.6 : 1.0
          ..color = isCentral
              ? const Color(0xFFFFB300).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.18),
      );

      // Socket pinhole
      canvas.drawCircle(
        p,
        hexStep * 0.10,
        Paint()
          ..color = isCentral
              ? const Color(0xFFFFB300).withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.22),
      );
    }

    // 2. Draw connectors between each top-most piece's PÜNCT hex and its 2 satellites
    for (final pData in pieceMap.values) {
      if (pData['topMost'] != true) continue;
      final pid = (pData['id'] as num).toInt();
      final owner = (pData['owner'] as num).toInt();
      final pq = (pData['q'] as num).toInt();
      final pr = (pData['r'] as num).toInt();
      final pCenter = _pos(pq, pr, center);
      final rawCells = (pData['cells'] as List?) ?? const [];
      final isSelected = pid == selectedPieceId;
      for (var i = 1; i < rawCells.length; i++) {
        final item = rawCells[i] as List;
        final sq = (item[0] as num).toInt();
        final sr = (item[1] as num).toInt();
        final sPos = _pos(sq, sr, center);
        canvas.drawLine(
          pCenter,
          sPos,
          Paint()
            ..color = isSelected
                ? Colors.greenAccent
                : (owner == 0 ? const Color(0xFFEAE4D7) : const Color(0xFF3A404A))
            ..strokeWidth = hexStep * 0.34
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // 3. Draw occupied hexes (top piece color, PÜNCT marker, and stack height)
    for (final entry in cellMap.entries) {
      final (q, r) = entry.key;
      final c = entry.value;
      final height = (c['height'] as num?)?.toInt() ?? 0;
      if (height <= 0) continue;

      final topColor = (c['topColor'] as num).toInt();
      final topPid = (c['topPieceId'] as num?)?.toInt();
      final topIsPunct = c['topIsPunct'] == true;
      final isWhite = topColor == 0;
      final isSelected = topPid != null && topPid == selectedPieceId;
      final isWinning = winningSet.contains((q, r));
      final isLast = lastCells.contains((q, r));
      final p = _pos(q, r, center);
      final diskRadius = hexStep * 0.42;

      if (isWinning || isLast || isSelected) {
        canvas.drawCircle(
          p,
          diskRadius + 3.5,
          Paint()
            ..color = isWinning
                ? Colors.amberAccent.withValues(alpha: 0.8)
                : (isSelected
                    ? Colors.greenAccent.withValues(alpha: 0.75)
                    : Colors.orangeAccent.withValues(alpha: 0.45)),
        );
      }

      canvas.drawCircle(
        p + const Offset(1.2, 2.0),
        diskRadius,
        Paint()..color = Colors.black45,
      );

      canvas.drawCircle(
        p,
        diskRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: isWhite
                ? [const Color(0xFFFFFFFF), const Color(0xFFD7D0C2)]
                : [const Color(0xFF4A515C), const Color(0xFF181B20)],
          ).createShader(Rect.fromCircle(center: p, radius: diskRadius)),
      );

      canvas.drawCircle(
        p,
        diskRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.2 : 1.4
          ..color = isSelected
              ? Colors.greenAccent
              : (isWhite ? const Color(0xFFA89F8D) : const Color(0xFF6B7380)),
      );

      // PÜNCT center dot marker
      if (topIsPunct) {
        canvas.drawCircle(
          p,
          diskRadius * 0.36,
          Paint()
            ..color = isWhite ? const Color(0xFFB71C1C) : const Color(0xFFFFCA28),
        );
      }

      // Stack height badge if >= 2
      if (height >= 2) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$height',
            style: TextStyle(
              fontSize: max(9, hexStep * 0.34),
              fontWeight: FontWeight.bold,
              color: isWhite ? Colors.black87 : Colors.white,
              fontFamilyFallback: kFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p + Offset(diskRadius * 0.25, -diskRadius * 0.85));
      }
    }

    // 4. Draw legal move targets when a board piece is selected
    for (final pos in legalMoveTargets) {
      final p = _pos(pos.$1, pos.$2, center);
      canvas.drawCircle(
        p,
        hexStep * 0.32,
        Paint()..color = Colors.greenAccent.withValues(alpha: 0.35),
      );
      canvas.drawCircle(
        p,
        hexStep * 0.36,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = Colors.greenAccent,
      );
    }

    // 5. Draw ghost drop preview
    if (previewTri != null && previewTri!.length == 3) {
      final ghostColor = previewLegal ? Colors.greenAccent : Colors.redAccent;
      final p0 = _pos(previewTri![0].$1, previewTri![0].$2, center);
      for (var i = 1; i < 3; i++) {
        final (cq, cr) = previewTri![i];
        if (_hexDist(cq, cr) <= 4) {
          canvas.drawLine(
            p0,
            _pos(cq, cr, center),
            Paint()
              ..color = ghostColor.withValues(alpha: 0.45)
              ..strokeWidth = hexStep * 0.26
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      for (var i = 0; i < 3; i++) {
        final (cq, cr) = previewTri![i];
        if (_hexDist(cq, cr) > 4) continue;
        final p = _pos(cq, cr, center);
        canvas.drawCircle(
          p,
          hexStep * 0.38,
          Paint()..color = ghostColor.withValues(alpha: 0.28),
        );
        canvas.drawCircle(
          p,
          hexStep * 0.38,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = ghostColor,
        );
        if (i == 0) {
          canvas.drawCircle(p, hexStep * 0.14, Paint()..color = ghostColor);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PunctPainter oldDelegate) => true;
}
