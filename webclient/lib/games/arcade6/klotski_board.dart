import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common.dart';
import 'a6_common.dart';

class KlotskiBoard extends StatefulWidget {
  final GameContext g;
  const KlotskiBoard(this.g, {super.key});
  @override
  State<KlotskiBoard> createState() => _KlotskiBoardState();
}

class _KlotskiBoardState extends State<KlotskiBoard> {
  GameContext get g => widget.g;
  int _selectedPiece = 0;
  Offset? _dragStart;
  int? _dragPiece;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _slide(int pieceId, int dir) {
    if (!_canPlay) return;
    setState(() => _selectedPiece = pieceId);
    g.act({'type': 'slide', 'piece': pieceId, 'dir': dir});
  }

  static const _dr = [-1, 0, 1, 0];
  static const _dc = [0, 1, 0, -1];

  bool _canPieceSlide(List<Map<String, dynamic>> pieces, int pieceId, int dir, int boardW, int boardH) {
    final p = pieces.where((x) => aInt(x['id']) == pieceId).firstOrNull;
    if (p == null) return false;
    final r = aInt(p['r']), c = aInt(p['c']), w = aInt(p['w'], 1), h = aInt(p['h'], 1);
    final nr = r + _dr[dir], nc = c + _dc[dir];
    if (nr < 0 || nc < 0 || nr + h > boardH || nc + w > boardW) return false;
    for (final q in pieces) {
      if (aInt(q['id']) == pieceId) continue;
      final qr = aInt(q['r']), qc = aInt(q['c']), qw = aInt(q['w'], 1), qh = aInt(q['h'], 1);
      if (nr < qr + qh && nr + h > qr && nc < qc + qw && nc + w > qc) return false;
    }
    return true;
  }

  bool _cellCoveredBy(Map<String, dynamic> p, int r, int c) {
    final pr = aInt(p['r']), pc = aInt(p['c']), pw = aInt(p['w'], 1), ph = aInt(p['h'], 1);
    return r >= pr && r < pr + ph && c >= pc && c < pc + pw;
  }

  void _onTapCell(int r, int c, List<Map<String, dynamic>> pieces, int w, int h) {
    for (final p in pieces) {
      if (_cellCoveredBy(p, r, c)) {
        setState(() => _selectedPiece = aInt(p['id'], 0));
        return;
      }
    }
    if (!_canPlay) return;
    // Empty cell tapped: first check if currently selected piece can slide onto (r, c)
    for (var dir = 0; dir < 4; dir++) {
      if (_canPieceSlide(pieces, _selectedPiece, dir, w, h)) {
        final p = pieces.firstWhere((x) => aInt(x['id']) == _selectedPiece);
        final nr = aInt(p['r']) + _dr[dir], nc = aInt(p['c']) + _dc[dir];
        final pw = aInt(p['w'], 1), ph = aInt(p['h'], 1);
        if (r >= nr && r < nr + ph && c >= nc && c < nc + pw) {
          _slide(_selectedPiece, dir);
          return;
        }
      }
    }
    // Otherwise check if any piece can slide onto (r, c)
    for (final p in pieces) {
      final pid = aInt(p['id']);
      for (var dir = 0; dir < 4; dir++) {
        if (_canPieceSlide(pieces, pid, dir, w, h)) {
          final nr = aInt(p['r']) + _dr[dir], nc = aInt(p['c']) + _dc[dir];
          final pw = aInt(p['w'], 1), ph = aInt(p['h'], 1);
          if (r >= nr && r < nr + ph && c >= nc && c < nc + pw) {
            _slide(pid, dir);
            return;
          }
        }
      }
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
      _slide(_selectedPiece, 0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
      _slide(_selectedPiece, 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
      _slide(_selectedPiece, 2);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
      _slide(_selectedPiece, 3);
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
    final w = math.max(4, aInt(v['w'], 4));
    final h = math.max(5, aInt(v['h'], 5));
    final left = aInt(v['left'], 0);
    final pieces = aMaps(v['pieces']);
    final steps = aInt(v['steps'], 0);
    final parSteps = aInt(v['parSteps'], 10);
    final canUndo = v['canUndo'] == true;
    final canReset = v['canReset'] == true;
    final ps = aMaps(v['ps']);

    if (pieces.isNotEmpty && !pieces.any((p) => aInt(p['id']) == _selectedPiece)) {
      _selectedPiece = aInt(pieces.first['id'], 0);
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '华容道竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 局「$levelName」· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 局「$levelName」· 已突围（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 局「$levelName」· 已放弃本局，等待其他玩家 · ${left}s';
    } else {
      status = '第 $round/$totalRounds 局「$levelName」· 已走 $steps 步（最优 $parSteps 步）· 剩余 ${left}s';
    }

    return A6Keys(
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
          pieces: pieces,
          steps: steps,
          parSteps: parSteps,
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
                      (r) => '${r['score']} 分 · 突围 ${r['solved']}/$totalRounds · 共 ${r['steps']} 步',
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
    final steps = aInt(p['steps'], 0);
    final pct = aDouble(p['pct'], 0.0);
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$steps步', null),
    };
    return A6ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : pct,
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 突围 $solved/$totalRounds',
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
    required List<Map<String, dynamic>> pieces,
    required int steps,
    required int parSteps,
    required bool canUndo,
    required bool canReset,
    required bool wide,
  }) {
    const cellPx = 62.0;
    final boardW = w * cellPx;
    final boardH = h * cellPx;

    final boardWidget = Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF4E342E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7CCC8), width: 2),
        boxShadow: const [BoxShadow(blurRadius: 14, color: Colors.black38, offset: Offset(0, 5))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final c = (d.localPosition.dx ~/ cellPx).clamp(0, w - 1);
            final r = (d.localPosition.dy ~/ cellPx).clamp(0, h - 1);
            _onTapCell(r, c, pieces, w, h);
          },
          onPanStart: (d) {
            final c = (d.localPosition.dx ~/ cellPx).clamp(0, w - 1);
            final r = (d.localPosition.dy ~/ cellPx).clamp(0, h - 1);
            _dragStart = d.localPosition;
            _dragPiece = null;
            for (final p in pieces) {
              if (_cellCoveredBy(p, r, c)) {
                final pid = aInt(p['id'], 0);
                setState(() => _selectedPiece = pid);
                _dragPiece = pid;
                break;
              }
            }
          },
          onPanEnd: (d) {
            if (_dragStart == null || _dragPiece == null) return;
            final v = d.velocity.pixelsPerSecond;
            if (v.distance > 120) {
              final dir = v.dx.abs() > v.dy.abs()
                  ? (v.dx > 0 ? 1 : 3)
                  : (v.dy > 0 ? 2 : 0);
              _slide(_dragPiece!, dir);
            }
            _dragStart = null;
            _dragPiece = null;
          },
          onPanUpdate: (d) {
            if (_dragStart == null || _dragPiece == null) return;
            final delta = d.localPosition - _dragStart!;
            if (delta.distance >= 24) {
              final dir = delta.dx.abs() > delta.dy.abs()
                  ? (delta.dx > 0 ? 1 : 3)
                  : (delta.dy > 0 ? 2 : 0);
              final pid = _dragPiece!;
              _dragStart = null;
              _dragPiece = null;
              _slide(pid, dir);
            }
          },
          child: SizedBox(
            width: boardW,
            height: boardH,
            child: CustomPaint(
              size: Size(boardW, boardH),
              painter: _KlotskiPainter(
                w: w,
                h: h,
                pieces: pieces,
                selectedPiece: _selectedPiece,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: cellPx * 2,
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFCA28), width: 1.5),
          ),
          child: const Text(
            '▼ 华容道出口 (曹操 2×2) ▼',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFFECB3)),
          ),
        ),
      ]),
    );

    final controlPanel = Container(
      width: wide ? 236 : boardW + 20,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          A6Chip('第 $round/$totalRounds 局', cs.primary, size: 12),
          Flexible(
            child: Text(
              levelName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          '当前：$steps 步  ·  最优：$parSteps 步',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final p in pieces)
              () {
                final pid = aInt(p['id']);
                final pName = aStr(p['name']);
                final sel = pid == _selectedPiece;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _selectedPiece = pid),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: sel ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sel ? cs.onPrimary : cs.onSurface,
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
        const SizedBox(height: 10),
        A6Dpad(
          enabled: _canPlay,
          onDir: (dir) => _slide(_selectedPiece, dir),
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
                boardWidget,
                const SizedBox(width: 14),
                controlPanel,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                boardWidget,
                const SizedBox(height: 10),
                controlPanel,
              ]),
      ),
    );
  }
}

class _KlotskiPainter extends CustomPainter {
  final int w;
  final int h;
  final List<Map<String, dynamic>> pieces;
  final int selectedPiece;

  _KlotskiPainter({
    required this.w,
    required this.h,
    required this.pieces,
    required this.selectedPiece,
  });

  static (Color, Color) _pieceColors(int id) => switch (id) {
        0 => (const Color(0xFFC62828), const Color(0xFFFFD54F)), // 曹操 (crimson + gold)
        1 => (const Color(0xFF2E7D32), const Color(0xFFA5D6A7)), // 关羽 (jade green)
        2 => (const Color(0xFF1565C0), const Color(0xFF90CAF9)), // 张飞 (sapphire blue)
        3 => (const Color(0xFF00838F), const Color(0xFF80DEEA)), // 赵云 (cyan teal)
        4 => (const Color(0xFF6A1B9A), const Color(0xFFCE93D8)), // 马超 (royal purple)
        5 => (const Color(0xFFEF6C00), const Color(0xFFFFCC80)), // 黄忠 (amber orange)
        _ => (const Color(0xFF6D4C41), const Color(0xFFD7CCC8)), // 兵卒 (bronze wood)
      };

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / w;
    final cellH = size.height / h;

    // Background recess
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFF2B1B17),
    );

    // Subtle grid slots
    for (var r = 0; r < h; r++) {
      for (var c = 0; c < w; c++) {
        final slot = Rect.fromLTWH(c * cellW + 2, r * cellH + 2, cellW - 4, cellH - 4);
        final isExitZone = (r == 3 || r == 4) && (c == 1 || c == 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(slot, const Radius.circular(6)),
          Paint()
            ..color = isExitZone
                ? const Color(0xFFFFB300).withValues(alpha: 0.14)
                : const Color(0xFF3E2723),
        );
      }
    }

    // Draw pieces
    for (final p in pieces) {
      final id = aInt(p['id'], 0);
      final name = aStr(p['name']);
      final r = aInt(p['r'], 0);
      final c = aInt(p['c'], 0);
      final pw = aInt(p['w'], 1);
      final ph = aInt(p['h'], 1);
      final selected = id == selectedPiece;

      final rect = Rect.fromLTWH(
        c * cellW + 3,
        r * cellH + 3,
        pw * cellW - 6,
        ph * cellH - 6,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      final (fillCol, borderCol) = _pieceColors(id);

      // Drop shadow
      canvas.drawRRect(rrect.shift(const Offset(0, 2.5)), Paint()..color = Colors.black45);
      // Block body
      canvas.drawRRect(rrect, Paint()..color = fillCol);
      // Inner bevel highlight
      canvas.drawRRect(
        rrect.deflate(3),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Border (brighter & thicker when selected)
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = selected ? const Color(0xFFFFEA00) : borderCol
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3.2 : 1.8,
      );

      // Piece label
      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontSize: id == 0 ? 22 : (pw * ph > 1 ? 16 : 13),
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontFamilyFallback: kFontFallback,
            shadows: const [Shadow(blurRadius: 3, color: Colors.black54, offset: Offset(0, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _KlotskiPainter old) =>
      old.w != w ||
      old.h != h ||
      old.selectedPiece != selectedPiece ||
      old.pieces != pieces;
}
