import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common.dart';
import 'a5_common.dart';

class RicochetBoard extends StatefulWidget {
  final GameContext g;
  const RicochetBoard(this.g, {super.key});
  @override
  State<RicochetBoard> createState() => _RicochetBoardState();
}

class _RicochetBoardState extends State<RicochetBoard> {
  GameContext get g => widget.g;
  int _selRobot = 0;
  int _lastRound = -1;

  static const _robotColors = [
    Color(0xFFE53935), // 0: 红
    Color(0xFF43A047), // 1: 绿
    Color(0xFF1E88E5), // 2: 蓝
    Color(0xFFFDD835), // 3: 黄
  ];
  static const _robotNames = ['红', '绿', '蓝', '黄'];
  static const _dirArrows = ['↑', '→', '↓', '←'];

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _syncRound(int round, int targetRobot) {
    if (round != _lastRound) {
      _lastRound = round;
      _selRobot = targetRobot.clamp(0, 3);
    }
  }

  void _slide(int dir) {
    if (!_canPlay) return;
    g.act({'type': 'slide', 'robot': _selRobot, 'dir': dir});
  }

  void _onTapCell(int cellIdx, int size, List<int> robots) {
    if (!_canPlay) return;
    final rIdx = robots.indexOf(cellIdx);
    if (rIdx >= 0) {
      setState(() => _selRobot = rIdx);
      return;
    }
    final cur = robots[_selRobot];
    final cr = cur ~/ size, cc = cur % size;
    final tr = cellIdx ~/ size, tc = cellIdx % size;
    if (cr == tr && cc != tc) {
      _slide(tc > cc ? 1 : 3);
    } else if (cc == tc && cr != tr) {
      _slide(tr > cr ? 2 : 0);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.digit1) {
      setState(() => _selRobot = 0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit2) {
      setState(() => _selRobot = 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit3) {
      setState(() => _selRobot = 2);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit4) {
      setState(() => _selRobot = 3);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
      _slide(0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      _slide(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      _slide(2);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      _slide(3);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace) {
      if (g.view['canUndo'] == true) g.act({'type': 'undo'});
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
    final totalRounds = math.max(1, aInt(v['totalRounds'], 5));
    final size = math.max(10, aInt(v['size'], 10));
    final left = aInt(v['left'], 0);
    final walls = aInts(v['walls']);
    final robots = aInts(v['robots']);
    final mainRobots = aInts(v['mainRobots']);
    final targetRobot = aInt(v['targetRobot'], 0).clamp(0, 3);
    final targetCell = aInt(v['targetCell'], 0);
    final parMoves = aInt(v['parMoves'], 3);
    final moves = aMaps(v['moves']);
    final ps = aMaps(v['ps']);
    final canUndo = v['canUndo'] == true;
    final canReset = v['canReset'] == true;

    _syncRound(round, targetRobot);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';
    final targetName = _robotNames[targetRobot];

    String status;
    if (phase == 'over') {
      status = '弹射机器人 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 局 · 目标：将「$targetName机器人」滑入终点格 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 局 · 已锁定解法（${moves.length} 步）！等待其他玩家结算 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 局 · 已放弃本局，等待其他玩家 · ${left}s';
    } else {
      status = '第 $round/$totalRounds 局 · 目标：$targetName机器人 → 靶心格（参考最短 $parMoves 步）· 已走 ${moves.length} 步 · ${left}s';
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
          size: size,
          walls: walls,
          robots: robots.length == 4 ? robots : [0, 1, 2, 3],
          mainRobots: mainRobots.length == 4 ? mainRobots : [0, 1, 2, 3],
          targetRobot: targetRobot,
          targetCell: targetCell,
          parMoves: parMoves,
          moves: moves,
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
                      (r) => '${r['score']} 分 · 解出 ${r['solved']} 局 · 共 ${r['moves']} 步',
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
    final mCount = aInt(p['moves'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('$mCount步锁定', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => (mCount > 0 ? '$mCount步' : '规划中', null),
    };
    return A5ProgressTile(
      g,
      s,
      width: width,
      pct: solved / math.max(1, totalRounds),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 解出 $solved/$totalRounds',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int size,
    required List<int> walls,
    required List<int> robots,
    required List<int> mainRobots,
    required int targetRobot,
    required int targetCell,
    required int parMoves,
    required List<Map<String, dynamic>> moves,
    required bool canUndo,
    required bool canReset,
    required bool wide,
  }) {
    const boardPx = 380.0;
    final cellPx = boardPx / size;

    final gridWidget = Container(
      width: boardPx,
      height: boardPx,
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFE6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final c = (d.localPosition.dx ~/ cellPx).clamp(0, size - 1);
            final r = (d.localPosition.dy ~/ cellPx).clamp(0, size - 1);
            _onTapCell(r * size + c, size, robots);
          },
          child: CustomPaint(
            size: const Size(boardPx, boardPx),
            painter: _RicochetPainter(
              size: size,
              walls: walls,
              robots: robots,
              mainRobots: mainRobots,
              targetRobot: targetRobot,
              targetCell: targetCell,
              selRobot: _selRobot,
            ),
          ),
        ),
      ),
    );

    final controls = Container(
      width: wide ? 230 : 380,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Target banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _robotColors[targetRobot].withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _robotColors[targetRobot], width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.ads_click, size: 18, color: _robotColors[targetRobot]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '目标：${_robotNames[targetRobot]}色机器人 (最短 $parMoves 步)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),

        // Robot selector pills (1..4)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var r = 0; r < 4; r++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selRobot = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selRobot == r ? _robotColors[r] : _robotColors[r].withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _robotColors[r],
                        width: _selRobot == r ? 2.5 : 1,
                      ),
                    ),
                    child: Text(
                      '${r + 1}${_robotNames[r]}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selRobot == r ? (r == 3 ? Colors.black87 : Colors.white) : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),

        // D-pad
        A5Dpad(
          enabled: _canPlay,
          onDir: _slide,
          accentColor: _robotColors[_selRobot],
        ),
        const SizedBox(height: 8),

        // Move trail
        Text(
          moves.isEmpty
              ? '点击棋盘机器人或按 1~4 切换，方向键弹射'
              : '路线(${moves.length}步)：${moves.map((m) => "${_robotNames[aInt(m['robot']).clamp(0, 3)]}${_dirArrows[aInt(m['dir']).clamp(0, 3)]}").join(" ")}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 8),

        // Action buttons
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
                gridWidget,
                const SizedBox(width: 14),
                controls,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                gridWidget,
                const SizedBox(height: 10),
                controls,
              ]),
      ),
    );
  }
}

class _RicochetPainter extends CustomPainter {
  final int size;
  final List<int> walls;
  final List<int> robots;
  final List<int> mainRobots;
  final int targetRobot;
  final int targetCell;
  final int selRobot;

  _RicochetPainter({
    required this.size,
    required this.walls,
    required this.robots,
    required this.mainRobots,
    required this.targetRobot,
    required this.targetCell,
    required this.selRobot,
  });

  static const _robotColors = [
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFFFBC02D),
  ];
  static const _robotLabels = ['红', '绿', '蓝', '黄'];

  @override
  void paint(Canvas canvas, Size s) {
    final cell = s.width / size;
    final gridPaint = Paint()
      ..color = const Color(0xFFD7CFC2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Alternating subtle tile tint
    final altPaint = Paint()..color = const Color(0xFFEDE7DA);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        if ((r + c).isOdd) {
          canvas.drawRect(rect, altPaint);
        }
        canvas.drawRect(rect, gridPaint);
      }
    }

    // Draw Target Cell
    if (targetCell >= 0 && targetCell < size * size) {
      final tr = targetCell ~/ size, tc = targetCell % size;
      final tCol = _robotColors[targetRobot];
      final rect = Rect.fromLTWH(tc * cell + 3, tr * cell + 3, cell - 6, cell - 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = tCol.withValues(alpha: 0.28),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = tCol
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke,
      );
      final center = Offset((tc + 0.5) * cell, (tr + 0.5) * cell);
      canvas.drawCircle(center, cell * 0.16, Paint()..color = tCol);
    }

    // Draw ghost markers for initial robot positions
    for (var r = 0; r < 4 && r < mainRobots.length; r++) {
      final idx = mainRobots[r];
      if (idx < 0 || idx >= size * size) continue;
      final rr = idx ~/ size, cc = idx % size;
      final center = Offset((cc + 0.5) * cell, (rr + 0.5) * cell);
      canvas.drawCircle(
        center,
        cell * 0.2,
        Paint()
          ..color = _robotColors[r].withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Draw Walls
    final wallPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < walls.length && i < size * size; i++) {
      final w = walls[i];
      if (w == 0) continue;
      final r = i ~/ size, c = i % size;
      final x0 = c * cell, y0 = r * cell, x1 = (c + 1) * cell, y1 = (r + 1) * cell;
      if ((w & 1) != 0) canvas.drawLine(Offset(x0, y0), Offset(x1, y0), wallPaint);
      if ((w & 2) != 0) canvas.drawLine(Offset(x1, y0), Offset(x1, y1), wallPaint);
      if ((w & 4) != 0) canvas.drawLine(Offset(x0, y1), Offset(x1, y1), wallPaint);
      if ((w & 8) != 0) canvas.drawLine(Offset(x0, y0), Offset(x0, y1), wallPaint);
    }

    // Draw 4 Robots
    for (var r = 0; r < 4 && r < robots.length; r++) {
      final idx = robots[r];
      if (idx < 0 || idx >= size * size) continue;
      final rr = idx ~/ size, cc = idx % size;
      final center = Offset((cc + 0.5) * cell, (rr + 0.5) * cell);
      final radius = cell * 0.36;
      final col = _robotColors[r];

      if (r == selRobot) {
        canvas.drawCircle(
          center,
          radius + 3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          radius + 4,
          Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }

      canvas.drawCircle(center + const Offset(0, 1.5), radius, Paint()..color = Colors.black26);
      canvas.drawCircle(center, radius, Paint()..color = col);

      final tp = TextPainter(
        text: TextSpan(
          text: _robotLabels[r],
          style: TextStyle(
            fontSize: cell * 0.36,
            fontWeight: FontWeight.w900,
            color: r == 3 ? Colors.black87 : Colors.white,
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RicochetPainter old) =>
      old.size != size ||
      old.targetRobot != targetRobot ||
      old.targetCell != targetCell ||
      old.selRobot != selRobot ||
      old.robots != robots ||
      old.walls != walls;
}
