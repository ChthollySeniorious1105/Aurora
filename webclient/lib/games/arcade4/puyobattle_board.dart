import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class PuyoBattleBoard extends StatefulWidget {
  final GameContext g;
  const PuyoBattleBoard(this.g, {super.key});

  @override
  State<PuyoBattleBoard> createState() => _PuyoBattleBoardState();
}

class _PuyoBattleBoardState extends State<PuyoBattleBoard> {
  int _col = 2;
  int _rot = 0;
  int _lastWave = -1;

  static const List<Color> _puyoColors = [
    Colors.transparent,
    Color(0xFFEF4444), // 1 Red
    Color(0xFF22C55E), // 2 Green
    Color(0xFF3B82F6), // 3 Blue
    Color(0xFFEAB308), // 4 Yellow
    Color(0xFF94A3B8), // 5 Garbage
  ];

  int _clampCol(int c, int r) {
    final rot = r & 3;
    var col = c.clamp(0, 5);
    if (rot == 1 && col >= 5) col = 4;
    if (rot == 3 && col <= 0) col = 1;
    return col;
  }

  void _rotate(int dir) {
    setState(() {
      _rot = (_rot + (dir >= 0 ? 1 : 3)) & 3;
      _col = _clampCol(_col, _rot);
    });
  }

  void _move(int dir) {
    setState(() {
      _col = _clampCol(_col + dir, _rot);
    });
  }

  void _drop([int? targetCol]) {
    final c = targetCol != null ? _clampCol(targetCol, _rot) : _clampCol(_col, _rot);
    setState(() => _col = c);
    widget.g.act({'type': 'drop', 'col': c, 'rot': _rot});
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final wave = (v['wave'] as num?)?.toInt() ?? 1;
    if (wave != _lastWave) {
      _lastWave = wave;
      _col = 2;
      _rot = 0;
    }

    final pList = (v['players'] as List?)?.cast<Map>() ?? const [];
    if (pList.isEmpty) return const SizedBox();

    final seats = g.seatsFromMe();
    final mySeat = seats.first;
    final oppSeats = seats.sublist(1);

    Map myData = pList.firstWhere((p) => p['seat'] == mySeat, orElse: () => pList.first);
    final myAlive = myData['alive'] == true;
    final myActed = myData['acted'] == true;
    final canAct = !g.spectator && !g.over && myAlive && !myActed;

    final statusMsg = g.over
        ? '魔法气泡对战结束！'
        : (canAct
            ? '第 $wave 轮：调整方向并点击列或【落下】放置气泡'
            : (myAlive ? '第 $wave 轮：已落子，等待其他玩家...' : '你已淘汰，正在观战第 $wave 轮'));

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: StatusBar(statusMsg, highlight: canAct),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 620;
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildMySection(context, cs, mySeat, myData, canAct),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: _buildOpponentsSection(context, cs, oppSeats, pList),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          if (oppSeats.isNotEmpty)
                            Expanded(
                              flex: 3,
                              child: _buildOpponentsSection(context, cs, oppSeats, pList),
                            ),
                          const SizedBox(height: 4),
                          Expanded(
                            flex: 7,
                            child: _buildMySection(context, cs, mySeat, myData, canAct),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          if (g.over) _buildResultOverlay(g, pList),
        ],
      ),
    );
  }

  Widget _buildMySection(BuildContext context, ColorScheme cs, int seat, Map data, bool canAct) {
    final grid = (data['grid'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(72, 0);
    final curPair = (data['curPair'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 2];
    final next1 = (data['next1'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [2, 3];
    final next2 = (data['next2'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [3, 4];
    final score = (data['score'] as num?)?.toInt() ?? 0;
    final maxChain = (data['maxChain'] as num?)?.toInt() ?? 0;
    final pending = (data['pendingGarbage'] as num?)?.toInt() ?? 0;
    final lastEvent = '${data['lastEvent'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: canAct ? cs.primary : cs.outline.withValues(alpha: 0.3), width: canAct ? 2 : 1),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.g.tag(
                  seat,
                  active: canAct,
                  sub: '得分 $score · 最高 $maxChain 连锁',
                  size: 30,
                ),
                if (pending > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Text(
                      '预警障碍: $pending',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 6 / 13.6,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          return GestureDetector(
                            onTapUp: canAct
                                ? (details) {
                                    final c = ((details.localPosition.dx / box.maxWidth) * 6).floor().clamp(0, 5);
                                    _drop(c);
                                  }
                                : null,
                            child: CustomPaint(
                              size: Size(box.maxWidth, box.maxHeight),
                              painter: _PuyoGridPainter(
                                grid: grid,
                                curPair: curPair,
                                col: _clampCol(_col, _rot),
                                rot: _rot,
                                showActive: canAct,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 136,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('下一组预告', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildPairPreview('NEXT', next1),
                              _buildPairPreview('2ND', next2),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ctrlBtn(Icons.arrow_back, '左移', canAct ? () => _move(-1) : null),
                              _ctrlBtn(Icons.arrow_forward, '右移', canAct ? () => _move(1) : null),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _ctrlBtn(Icons.rotate_left, '逆旋', canAct ? () => _rotate(-1) : null),
                              _ctrlBtn(Icons.rotate_right, '顺旋', canAct ? () => _rotate(1) : null),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: canAct ? () => _drop() : null,
                              icon: const Icon(Icons.vertical_align_bottom, size: 16),
                              label: Text('第 ${_clampCol(_col, _rot) + 1} 列落下'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (lastEvent.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(lastEvent, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, String label, VoidCallback? onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(56, 32),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildPairPreview(String title, List<int> pair) {
    final cMain = _puyoColors[pair[0].clamp(0, 5)];
    final cSub = _puyoColors[pair[1].clamp(0, 5)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, color: Colors.white70)),
          const SizedBox(height: 2),
          _miniDot(cSub, 16),
          const SizedBox(height: 2),
          _miniDot(cMain, 16),
        ],
      ),
    );
  }

  Widget _miniDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white54, width: 1),
      ),
    );
  }

  Widget _buildOpponentsSection(BuildContext context, ColorScheme cs, List<int> oppSeats, List<Map> pList) {
    return Row(
      children: [
        for (var i = 0; i < oppSeats.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _buildOpponentCard(
              cs,
              oppSeats[i],
              pList.firstWhere((p) => p['seat'] == oppSeats[i], orElse: () => pList.first),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOpponentCard(ColorScheme cs, int seat, Map data) {
    final grid = (data['grid'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(72, 0);
    final alive = data['alive'] == true;
    final score = (data['score'] as num?)?.toInt() ?? 0;
    final maxChain = (data['maxChain'] as num?)?.toInt() ?? 0;
    final pending = (data['pendingGarbage'] as num?)?.toInt() ?? 0;
    final lastEvent = '${data['lastEvent'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: alive ? 0.72 : 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: widget.g.tag(
              seat,
              active: alive && data['acted'] != true,
              sub: '${alive ? "存活" : "淘汰"} · $score分 · $maxChain连${pending > 0 ? " · 障$pending" : ""}',
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 6 / 12,
                child: CustomPaint(
                  painter: _PuyoGridPainter(
                    grid: grid,
                    curPair: const [1, 1],
                    col: 2,
                    rot: 0,
                    showActive: false,
                  ),
                ),
              ),
            ),
          ),
          if (lastEvent.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                lastEvent,
                style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultOverlay(GameContext g, List<Map> pList) {
    final placings = (g.view['placings'] as List?)?.map((e) => (e as num).toInt()).toList();
    final winners = <String>[];
    if (placings != null) {
      for (var s = 0; s < placings.length; s++) {
        if (placings[s] == 1) winners.add(g.name(s));
      }
    }
    final title = winners.isEmpty ? '对战结束' : '${winners.join("、")} 获胜！';
    return ResultBanner(
      title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in pList)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${g.name((p['seat'] as num).toInt())}：${p['score']} 分（最高 ${p['maxChain']} 连锁）',
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _PuyoGridPainter extends CustomPainter {
  final List<int> grid;
  final List<int> curPair;
  final int col;
  final int rot;
  final bool showActive;

  _PuyoGridPainter({
    required this.grid,
    required this.curPair,
    required this.col,
    required this.rot,
    required this.showActive,
  });

  static const List<Color> _colors = [
    Colors.transparent,
    Color(0xFFEF4444), // Red
    Color(0xFF22C55E), // Green
    Color(0xFF3B82F6), // Blue
    Color(0xFFEAB308), // Yellow
    Color(0xFF94A3B8), // Garbage
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final topRows = showActive ? 1.6 : 0.0;
    final totalRows = 12.0 + topRows;
    final cellW = size.width / 6.0;
    final cellH = size.height / totalRows;
    final boardTop = topRows * cellH;

    // Board background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, boardTop, size.width, size.height - boardTop),
      const Radius.circular(8),
    );
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF0F172A));

    // Grid lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var c = 1; c < 6; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, boardTop), Offset(x, size.height), linePaint);
    }
    for (var r = 1; r < 12; r++) {
      final y = boardTop + r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Spawn point X marker at (row 0, col 2)
    final spawnCenter = Offset(2.5 * cellW, boardTop + 0.5 * cellH);
    final xRadius = min(cellW, cellH) * 0.25;
    final xPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.55)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(spawnCenter + Offset(-xRadius, -xRadius), spawnCenter + Offset(xRadius, xRadius), xPaint);
    canvas.drawLine(spawnCenter + Offset(xRadius, -xRadius), spawnCenter + Offset(-xRadius, xRadius), xPaint);

    // Draw active pair & column highlight if showActive
    if (showActive && curPair.length >= 2) {
      final subCol = rot == 1 ? col + 1 : (rot == 3 ? col - 1 : col);
      final hiPaint = Paint()..color = Colors.white.withValues(alpha: 0.07);
      canvas.drawRect(Rect.fromLTWH(col * cellW, boardTop, cellW, size.height - boardTop), hiPaint);
      if (subCol != col && subCol >= 0 && subCol < 6) {
        canvas.drawRect(Rect.fromLTWH(subCol * cellW, boardTop, cellW, size.height - boardTop), hiPaint);
      }

      // Active pair in top preview zone
      final mainY = boardTop - cellH * (rot == 2 ? 1.15 : 0.45);
      final subY = rot == 0
          ? boardTop - cellH * 1.15
          : (rot == 2 ? boardTop - cellH * 0.45 : mainY);
      _drawPuyo(canvas, Offset((col + 0.5) * cellW, mainY), min(cellW, cellH) * 0.43, curPair[0]);
      _drawPuyo(canvas, Offset((subCol + 0.5) * cellW, subY), min(cellW, cellH) * 0.43, curPair[1]);
    }

    // Draw grid puyos & connections
    final radius = min(cellW, cellH) * 0.43;
    for (var r = 0; r < 12; r++) {
      for (var c = 0; c < 6; c++) {
        final v = grid[r * 6 + c];
        if (v <= 0 || v > 5) continue;
        final center = Offset((c + 0.5) * cellW, boardTop + (r + 0.5) * cellH);
        if (v >= 1 && v <= 4) {
          final color = _colors[v];
          if (c < 5 && grid[r * 6 + c + 1] == v) {
            canvas.drawRect(
              Rect.fromCenter(center: center + Offset(cellW * 0.5, 0), width: cellW, height: radius * 1.3),
              Paint()..color = color,
            );
          }
          if (r < 11 && grid[(r + 1) * 6 + c] == v) {
            canvas.drawRect(
              Rect.fromCenter(center: center + Offset(0, cellH * 0.5), width: radius * 1.3, height: cellH),
              Paint()..color = color,
            );
          }
        }
        _drawPuyo(canvas, center, radius, v);
      }
    }

    // Border around board
    canvas.drawRRect(
      bgRect,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawPuyo(Canvas canvas, Offset center, double radius, int colorIdx) {
    final c = _colors[colorIdx.clamp(0, 5)];
    canvas.drawCircle(center, radius, Paint()..color = c);
    // Gloss highlight
    canvas.drawCircle(
      center + Offset(-radius * 0.28, -radius * 0.28),
      radius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    if (colorIdx >= 1 && colorIdx <= 4 && radius >= 6) {
      // Cute eyes for colored Puyos
      final eyePaint = Paint()..color = Colors.white;
      final pupilPaint = Paint()..color = Colors.black87;
      final e1 = center + Offset(-radius * 0.22, -radius * 0.05);
      final e2 = center + Offset(radius * 0.22, -radius * 0.05);
      canvas.drawCircle(e1, radius * 0.18, eyePaint);
      canvas.drawCircle(e2, radius * 0.18, eyePaint);
      canvas.drawCircle(e1, radius * 0.09, pupilPaint);
      canvas.drawCircle(e2, radius * 0.09, pupilPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PuyoGridPainter oldDelegate) => true;
}
