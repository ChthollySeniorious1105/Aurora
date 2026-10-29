import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a7_common.dart';

class LaserMazeBoard extends StatefulWidget {
  final GameContext g;
  const LaserMazeBoard(this.g, {super.key});
  @override
  State<LaserMazeBoard> createState() => _LaserMazeBoardState();
}

class _LaserMazeBoardState extends State<LaserMazeBoard> {
  GameContext get g => widget.g;
  int _toolMode = -1; // -1 = 旋转切换, 1 = 放 /, 2 = 放 \, 0 = 清除

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onTapCell(int r, int c, int cellType) {
    if (!_canPlay || cellType != 0) return;
    if (_toolMode < 0) {
      g.act({'type': 'rotate', 'r': r, 'c': c});
    } else {
      g.act({'type': 'place', 'r': r, 'c': c, 'mirror': _toolMode});
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(6, aInt(v['size'], 6));
    final left = aInt(v['left'], 0);
    final grid = aInts(v['grid']);
    final emitterR = aInt(v['emitterR'], 0);
    final emitterC = aInt(v['emitterC'], 0);
    final emitterDir = aInt(v['emitterDir'], 1);
    final targetR = aInt(v['targetR'], 0);
    final targetC = aInt(v['targetC'], 0);
    final targetOpenDir = aInt(v['targetOpenDir'], 0);
    final board = aInts(v['board']);
    final segments = aMaps(v['segments']);
    final litCrystals = aInts(v['litCrystals']).toSet();
    final targetHit = v['targetHit'] == true;
    final litCrystalCount = aInt(v['litCrystalCount'], 0);
    final totalCrystals = math.max(1, aInt(v['totalCrystals'], 1));
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '激光迷宫竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 局（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 局 · 激光已导通（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 局 · 已放弃本局，等待其他玩家 · ${left}s';
    } else {
      final targetStr = targetHit ? '接收器已激活' : '接收器待命中';
      status = '第 $round/$totalRounds 局（$size×$size）· 水晶 $litCrystalCount/$totalCrystals · $targetStr · ${left}s';
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight * 1.12;
      final sideW = wide ? math.min(200.0, box.maxWidth * 0.24) : 0.0;
      final topStripH = wide ? 0.0 : 58.0;

      final playerTiles = Wrap(
        direction: wide ? Axis.vertical : Axis.horizontal,
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final s in g.seatsFromMe())
            if (s < ps.length) _buildPlayerTile(s, ps[s], totalRounds, wide ? sideW - 12 : 140),
        ],
      );

      final workspace = _buildWorkspace(
        context,
        cs: cs,
        size: size,
        round: round,
        totalRounds: totalRounds,
        grid: grid,
        emitterR: emitterR,
        emitterC: emitterC,
        emitterDir: emitterDir,
        targetR: targetR,
        targetC: targetC,
        targetOpenDir: targetOpenDir,
        board: board,
        segments: segments,
        litCrystals: litCrystals,
        targetHit: targetHit,
        litCrystalCount: litCrystalCount,
        totalCrystals: totalCrystals,
        wide: wide,
      );

      Widget body;
      if (wide) {
        body = Row(children: [
          SizedBox(
            width: sideW,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: FittedBox(fit: BoxFit.scaleDown, child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      } else {
        body = Column(children: [
          SizedBox(
            height: topStripH,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      }

      return Column(children: [
        SizedBox(height: 38, child: aStatus(status, highlight: _canPlay)),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: body),
            if (phase == 'over')
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: aRanking(
                    g,
                    aMaps(v['final']),
                    (r) => '${r['score']} 分 · 通关 ${r['solved']}/$totalRounds 局',
                  ),
                ),
              ),
          ]),
        ),
      ]);
    });
  }

  Widget _buildPlayerTile(int s, Map<String, dynamic> p, int totalRounds, double width) {
    final st = aStr(p['status']);
    final score = aInt(p['score'], 0);
    final solved = aInt(p['solved'], 0);
    final goalDone = aInt(p['goalDone'], 0);
    final goalTotal = math.max(1, aInt(p['goalTotal'], 2));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$goalDone/$goalTotal点亮', null),
    };
    return A7ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (goalDone / goalTotal),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 通关 $solved/$totalRounds',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int size,
    required int round,
    required int totalRounds,
    required List<int> grid,
    required int emitterR,
    required int emitterC,
    required int emitterDir,
    required int targetR,
    required int targetC,
    required int targetOpenDir,
    required List<int> board,
    required List<Map<String, dynamic>> segments,
    required Set<int> litCrystals,
    required bool targetHit,
    required int litCrystalCount,
    required int totalCrystals,
    required bool wide,
  }) {
    final cellPx = size <= 6 ? 46.0 : 40.0;
    final sidePx = size * cellPx;

    final mazeCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1621),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF4081).withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final c = (d.localPosition.dx ~/ cellPx).clamp(0, size - 1);
          final r = (d.localPosition.dy ~/ cellPx).clamp(0, size - 1);
          final idx = r * size + c;
          final cellType = idx < grid.length ? grid[idx] : 0;
          _onTapCell(r, c, cellType);
        },
        child: SizedBox(
          width: sidePx,
          height: sidePx,
          child: CustomPaint(
            size: Size(sidePx, sidePx),
            painter: _LaserMazePainter(
              gridSize: size,
              cellPx: cellPx,
              grid: grid,
              emitterR: emitterR,
              emitterC: emitterC,
              emitterDir: emitterDir,
              targetR: targetR,
              targetC: targetC,
              targetOpenDir: targetOpenDir,
              board: board,
              segments: segments,
              litCrystals: litCrystals,
              targetHit: targetHit,
            ),
          ),
        ),
      ),
    );

    final toolbar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        direction: wide ? Axis.vertical : Axis.horizontal,
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          A7Chip('水晶 $litCrystalCount/$totalCrystals', const Color(0xFF00B0FF), size: 11),
          A7Chip(
            targetHit ? '接收器已激活' : '接收器未激活',
            targetHit ? Colors.green : Colors.blueGrey,
            size: 11,
          ),
          ChoiceChip(
            label: const Text('↻ 点击旋转', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == -1,
            onSelected: (_) => setState(() => _toolMode = -1),
          ),
          ChoiceChip(
            label: const Text('╱ 放 / 镜', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 1,
            onSelected: (_) => setState(() => _toolMode = 1),
          ),
          ChoiceChip(
            label: const Text('╲ 放 \\ 镜', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 2,
            onSelected: (_) => setState(() => _toolMode = 2),
          ),
          ChoiceChip(
            label: const Text('⌫ 拆除', style: TextStyle(fontSize: 12)),
            selected: _toolMode == 0,
            onSelected: (_) => setState(() => _toolMode = 0),
          ),
          OutlinedButton.icon(
            onPressed: _canPlay ? () => g.act({'type': 'reset'}) : null,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重置', style: TextStyle(fontSize: 12)),
          ),
          FilledButton.tonalIcon(
            onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: const Text('放弃', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                mazeCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                mazeCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }
}

class _LaserMazePainter extends CustomPainter {
  final int gridSize;
  final double cellPx;
  final List<int> grid;
  final int emitterR;
  final int emitterC;
  final int emitterDir;
  final int targetR;
  final int targetC;
  final int targetOpenDir;
  final List<int> board;
  final List<Map<String, dynamic>> segments;
  final Set<int> litCrystals;
  final bool targetHit;

  _LaserMazePainter({
    required this.gridSize,
    required this.cellPx,
    required this.grid,
    required this.emitterR,
    required this.emitterC,
    required this.emitterDir,
    required this.targetR,
    required this.targetC,
    required this.targetOpenDir,
    required this.board,
    required this.segments,
    required this.litCrystals,
    required this.targetHit,
  });

  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw floor tiles & walls
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final idx = r * gridSize + c;
        final cell = idx < grid.length ? grid[idx] : 0;
        final rect = Rect.fromLTWH(c * cellPx + 1.5, r * cellPx + 1.5, cellPx - 3, cellPx - 3);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

        if (cell == 4) {
          // Fixed Wall
          canvas.drawRRect(rrect, Paint()..color = const Color(0xFF37474F));
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = const Color(0xFF78909C)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        } else {
          canvas.drawRRect(rrect, Paint()..color = const Color(0xFF182432));
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = const Color(0xFF26384C)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        }
      }
    }

    // 2. Draw laser beam segments
    final glowPaint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.42)
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round;
    final corePaint = Paint()
      ..color = const Color(0xFFFF8A80)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    for (final seg in segments) {
      final r1 = aInt(seg['r1']), c1 = aInt(seg['c1']);
      final r2 = aInt(seg['r2']), c2 = aInt(seg['c2']);
      final p1 = Offset((c1 + 0.5) * cellPx, (r1 + 0.5) * cellPx);
      final p2 = Offset((c2 + 0.5) * cellPx, (r2 + 0.5) * cellPx);
      canvas.drawLine(p1, p2, glowPaint);
      canvas.drawLine(p1, p2, corePaint);
    }

    // 3. Draw optical components on top of laser beam
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final idx = r * gridSize + c;
        final cell = idx < grid.length ? grid[idx] : 0;
        final center = Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx);

        if (cell == 1) {
          // Laser Emitter
          canvas.drawCircle(center, cellPx * 0.34, Paint()..color = const Color(0xFFD50000));
          canvas.drawCircle(
            center,
            cellPx * 0.34,
            Paint()
              ..color = const Color(0xFFFF8A80)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
          final nozzle = center + Offset(dc[emitterDir] * cellPx * 0.32, dr[emitterDir] * cellPx * 0.32);
          canvas.drawLine(
            center,
            nozzle,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 4.0
              ..strokeCap = StrokeCap.round,
          );
        } else if (cell == 2) {
          // Target Receiver
          final col = targetHit ? const Color(0xFF00E676) : const Color(0xFF90A4AE);
          canvas.drawCircle(
            center,
            cellPx * 0.36,
            Paint()..color = targetHit ? const Color(0xFF1B5E20) : const Color(0xFF263238),
          );
          canvas.drawCircle(
            center,
            cellPx * 0.36,
            Paint()
              ..color = col
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
          // Draw open port indicator toward targetOpenDir
          final port = center + Offset(dc[targetOpenDir] * cellPx * 0.34, dr[targetOpenDir] * cellPx * 0.34);
          canvas.drawCircle(port, cellPx * 0.12, Paint()..color = const Color(0xFFFFEA00));
        } else if (cell == 3) {
          // Crystal Checkpoint
          final lit = litCrystals.contains(idx);
          final rad = cellPx * 0.28;
          final path = Path()
            ..moveTo(center.dx, center.dy - rad)
            ..lineTo(center.dx + rad, center.dy)
            ..lineTo(center.dx, center.dy + rad)
            ..lineTo(center.dx - rad, center.dy)
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = lit ? const Color(0xFF00E5FF) : const Color(0xFF0277BD).withValues(alpha: 0.6),
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = lit ? Colors.white : const Color(0xFF81D4FA)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
          );
        } else if (cell == 5 || cell == 6) {
          // Fixed Mirror (5 = '/', 6 = '\')
          _drawMirror(canvas, center, cellPx, cell == 5 ? 1 : 2, fixed: true, splitter: false);
        } else if (cell == 7 || cell == 8) {
          // Fixed Beam Splitter (7 = '/', 8 = '\')
          _drawMirror(canvas, center, cellPx, cell == 7 ? 1 : 2, fixed: true, splitter: true);
        } else if (cell == 0) {
          final m = idx < board.length ? board[idx] : 0;
          if (m == 1 || m == 2) {
            _drawMirror(canvas, center, cellPx, m, fixed: false, splitter: false);
          }
        }
      }
    }
  }

  void _drawMirror(
    Canvas canvas,
    Offset center,
    double cellPx,
    int mirrorType, {
    required bool fixed,
    required bool splitter,
  }) {
    final half = cellPx * 0.32;
    // mirrorType 1 = '/' (bottom-left to top-right), 2 = '\' (top-left to bottom-right)
    final p1 = mirrorType == 1 ? center + Offset(-half, half) : center + Offset(-half, -half);
    final p2 = mirrorType == 1 ? center + Offset(half, -half) : center + Offset(half, half);

    if (fixed) {
      canvas.drawCircle(
        center,
        cellPx * 0.16,
        Paint()..color = splitter ? const Color(0xFFCE93D8).withValues(alpha: 0.35) : const Color(0xFFFFB74D).withValues(alpha: 0.3),
      );
    }

    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = splitter
            ? const Color(0xFFE040FB)
            : (fixed ? const Color(0xFFFFCA28) : const Color(0xFF64FFDA))
        ..strokeWidth = splitter ? 3.5 : 4.8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LaserMazePainter old) =>
      old.gridSize != gridSize ||
      old.grid != grid ||
      old.board != board ||
      old.segments != segments ||
      old.targetHit != targetHit;
}
