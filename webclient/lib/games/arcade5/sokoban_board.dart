import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common.dart';
import 'a5_common.dart';

class SokobanBoard extends StatefulWidget {
  final GameContext g;
  const SokobanBoard(this.g, {super.key});
  @override
  State<SokobanBoard> createState() => _SokobanBoardState();
}

class _SokobanBoardState extends State<SokobanBoard> {
  GameContext get g => widget.g;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _move(int dir) {
    if (!_canPlay) return;
    g.act({'type': 'move', 'dir': dir});
  }

  void _onTapCell(int cellIdx, int w, int worker) {
    if (!_canPlay) return;
    final wr = worker ~/ w, wc = worker % w;
    final tr = cellIdx ~/ w, tc = cellIdx % w;
    final dr = tr - wr, dc = tc - wc;
    if (dr == 0 && dc != 0) {
      _move(dc > 0 ? 1 : 3);
    } else if (dc == 0 && dr != 0) {
      _move(dr > 0 ? 2 : 0);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
      _move(0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      _move(2);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      _move(3);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace || k == LogicalKeyboardKey.keyZ) {
      if (g.view['canUndo'] == true) g.act({'type': 'undo'});
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyR) {
      if (g.view['canReset'] == true) g.act({'type': 'reset'});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final levelName = aStr(v['levelName']);
    final w = math.max(5, aInt(v['w'], 7));
    final h = math.max(5, aInt(v['h'], 7));
    final left = aInt(v['left'], 0);
    final walls = aInts(v['walls']).toSet();
    final goals = aInts(v['goals']).toSet();
    final worker = aInt(v['worker'], 0);
    final boxes = aInts(v['boxes']).toSet();
    final steps = aInt(v['steps'], 0);
    final pushes = aInt(v['pushes'], 0);
    final parSteps = aInt(v['parSteps'], 10);
    final parPushes = aInt(v['parPushes'], 5);
    final boxesOnGoal = aInt(v['boxesOnGoal'], 0);
    final totalBoxes = math.max(1, aInt(v['totalBoxes'], 2));
    final canUndo = v['canUndo'] == true;
    final canReset = v['canReset'] == true;
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '推箱子竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 关「$levelName」· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 关「$levelName」· 已过关（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 关「$levelName」· 已放弃本关，等待其他玩家 · ${left}s';
    } else {
      status = '第 $round/$totalRounds 关「$levelName」· 已推到位 $boxesOnGoal/$totalBoxes 箱 · $steps步/$pushes推 · ${left}s';
    }

    return A5Keys(
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, box) {
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
          round: round,
          totalRounds: totalRounds,
          levelName: levelName,
          w: w,
          h: h,
          walls: walls,
          goals: goals,
          worker: worker,
          boxes: boxes,
          steps: steps,
          pushes: pushes,
          parSteps: parSteps,
          parPushes: parPushes,
          boxesOnGoal: boxesOnGoal,
          totalBoxes: totalBoxes,
          canUndo: canUndo,
          canReset: canReset,
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
                      (r) => '${r['score']} 分 · 通关 ${r['solved']}/$totalRounds · ${r['steps']}步/${r['pushes']}推',
                    ),
                  ),
                ),
            ]),
          ),
        ]);
      }),
    );
  }

  Widget _buildPlayerTile(int s, Map<String, dynamic> p, int totalRounds, double width) {
    final st = aStr(p['status']);
    final score = aInt(p['score'], 0);
    final solved = aInt(p['solved'], 0);
    final doneBoxes = aInt(p['doneBoxes'], 0);
    final totalBoxes = math.max(1, aInt(p['totalBoxes'], 2));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$doneBoxes/$totalBoxes箱', null),
    };
    return A5ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (doneBoxes / totalBoxes),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 通关 $solved/$totalRounds',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int round,
    required int totalRounds,
    required String levelName,
    required int w,
    required int h,
    required Set<int> walls,
    required Set<int> goals,
    required int worker,
    required Set<int> boxes,
    required int steps,
    required int pushes,
    required int parSteps,
    required int parPushes,
    required int boxesOnGoal,
    required int totalBoxes,
    required bool canUndo,
    required bool canReset,
    required bool wide,
  }) {
    const cellPx = 42.0;
    final boardW = w * cellPx;
    final boardH = h * cellPx;

    final warehouseGrid = Container(
      width: boardW,
      height: boardH,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2A26),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final c = (d.localPosition.dx ~/ cellPx).clamp(0, w - 1);
            final r = (d.localPosition.dy ~/ cellPx).clamp(0, h - 1);
            _onTapCell(r * w + c, w, worker);
          },
          child: CustomPaint(
            size: Size(boardW, boardH),
            painter: _SokobanPainter(
              w: w,
              h: h,
              walls: walls,
              goals: goals,
              worker: worker,
              boxes: boxes,
            ),
          ),
        ),
      ),
    );

    final controlPanel = Container(
      width: wide ? 220 : boardW,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          A5Chip('第 $round/$totalRounds 关', cs.primary, size: 12),
          Flexible(
            child: Text(
              levelName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          '当前：$steps 步 / $pushes 推   (最佳：$parSteps 步 / $parPushes 推)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 10),
        A5Dpad(
          enabled: _canPlay,
          onDir: _move,
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: canUndo ? () => g.act({'type': 'undo'}) : null,
            icon: const Icon(Icons.undo, size: 15),
            label: const Text('撤销', style: TextStyle(fontSize: 12)),
          ),
          OutlinedButton.icon(
            onPressed: canReset ? () => g.act({'type': 'reset'}) : null,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('重置', style: TextStyle(fontSize: 12)),
          ),
          FilledButton.tonalIcon(
            onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
            icon: const Icon(Icons.flag_outlined, size: 15),
            label: const Text('放弃', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                warehouseGrid,
                const SizedBox(width: 14),
                controlPanel,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                warehouseGrid,
                const SizedBox(height: 10),
                controlPanel,
              ]),
      ),
    );
  }
}

class _SokobanPainter extends CustomPainter {
  final int w;
  final int h;
  final Set<int> walls;
  final Set<int> goals;
  final int worker;
  final Set<int> boxes;

  _SokobanPainter({
    required this.w,
    required this.h,
    required this.walls,
    required this.goals,
    required this.worker,
    required this.boxes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / w;

    for (var r = 0; r < h; r++) {
      for (var c = 0; c < w; c++) {
        final idx = r * w + c;
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);

        if (walls.contains(idx)) {
          // Brick wall tile
          canvas.drawRect(rect, Paint()..color = const Color(0xFF5D4037));
          canvas.drawRect(
            rect.deflate(2),
            Paint()..color = const Color(0xFF795548),
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color = const Color(0xFF3E2723)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
          continue;
        }

        // Floor tile
        canvas.drawRect(
          rect,
          Paint()..color = (r + c).isOdd ? const Color(0xFFEFEBE4) : const Color(0xFFE5DFD5),
        );

        // Goal marker
        final isGoal = goals.contains(idx);
        if (isGoal) {
          final center = rect.center;
          canvas.drawCircle(
            center,
            cell * 0.24,
            Paint()..color = const Color(0xFF43A047).withValues(alpha: 0.28),
          );
          canvas.drawCircle(
            center,
            cell * 0.14,
            Paint()..color = const Color(0xFF2E7D32),
          );
        }

        // Box crate
        if (boxes.contains(idx)) {
          final boxRect = rect.deflate(cell * 0.11);
          final rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(6));
          final boxCol = isGoal ? const Color(0xFF43A047) : const Color(0xFFD88C32);
          final borderCol = isGoal ? const Color(0xFF1B5E20) : const Color(0xFF7F4610);

          canvas.drawRRect(rrect.shift(const Offset(0, 1.5)), Paint()..color = Colors.black26);
          canvas.drawRRect(rrect, Paint()..color = boxCol);
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = borderCol
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
          // Crate cross planks
          canvas.drawLine(
            boxRect.topLeft + const Offset(4, 4),
            boxRect.bottomRight - const Offset(4, 4),
            Paint()
              ..color = borderCol.withValues(alpha: 0.65)
              ..strokeWidth = 1.6,
          );
          canvas.drawLine(
            boxRect.topRight + const Offset(-4, 4),
            boxRect.bottomLeft + const Offset(4, -4),
            Paint()
              ..color = borderCol.withValues(alpha: 0.65)
              ..strokeWidth = 1.6,
          );
        }

        // Worker
        if (worker == idx) {
          final center = rect.center;
          final radius = cell * 0.34;
          canvas.drawCircle(center + const Offset(0, 1.5), radius, Paint()..color = Colors.black26);
          canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1E88E5));
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
          // Hardhat visor highlight
          canvas.drawCircle(
            center - Offset(0, radius * 0.25),
            radius * 0.45,
            Paint()..color = const Color(0xFFFDD835),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SokobanPainter old) =>
      old.w != w ||
      old.h != h ||
      old.worker != worker ||
      old.boxes != boxes ||
      old.walls != walls ||
      old.goals != goals;
}
