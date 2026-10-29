import 'dart:math';

import 'package:aurora_shared/games/abstract5/tak.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _TakPainter extends CustomPainter {
  final int n;
  final List<List<TakPiece>> board;
  final int selFrom;
  final Set<int> directTargets;
  final int hover;
  final Set<int> lastPath;
  final List<int> winningRoad;
  final Color accent;

  _TakPainter({
    required this.n,
    required this.board,
    required this.selFrom,
    required this.directTargets,
    required this.hover,
    required this.lastPath,
    required this.winningRoad,
    required this.accent,
  });

  static Rect cellRect(Size s, int n, int cell) {
    final cw = s.width / n;
    final x = cell % n, y = cell ~/ n;
    return Rect.fromLTWH(x * cw, y * cw, cw, cw);
  }

  static int hit(Size s, int n, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final cw = s.width / n;
    final x = (o.dx / cw).floor(), y = (o.dy / cw).floor();
    if (x < 0 || x >= n || y < 0 || y >= n) return -1;
    return y * n + x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / n;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.22));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a5Shadow(cw * 0.14, alpha: 0.45));

    // Tavern walnut wood board
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(outer.deflate(cw * 0.05));

    final roadSet = winningRoad.toSet();

    for (var cell = 0; cell < n * n; cell++) {
      final r = cellRect(size, n, cell);
      final row = cell ~/ n, col = cell % n;
      final light = (row + col).isEven;
      final cellColor = light ? const Color(0xFFF3E5AB) : const Color(0xFFC89D66);
      canvas.drawRect(r, Paint()..color = cellColor);

      // Decorative diamond inlay at cell center
      final d = cw * 0.10;
      final diamond = Path()
        ..moveTo(r.center.dx, r.center.dy - d)
        ..lineTo(r.center.dx + d, r.center.dy)
        ..lineTo(r.center.dx, r.center.dy + d)
        ..lineTo(r.center.dx - d, r.center.dy)
        ..close();
      canvas.drawPath(diamond, Paint()..color = const Color(0x224E342E));

      if (roadSet.contains(cell)) {
        canvas.drawRect(r, Paint()..color = const Color(0x77FFD54F));
      } else if (lastPath.contains(cell)) {
        canvas.drawRect(r, Paint()..color = const Color(0x5542A5F5));
      }

      // Coordinate labels
      if (col == 0) {
        a5PaintTextCentered(
          canvas,
          '${n - row}',
          r.topLeft + Offset(cw * 0.14, cw * 0.16),
          cw * 0.17,
          light ? const Color(0x994E342E) : const Color(0xBBFFF8E1),
          weight: FontWeight.w600,
        );
      }
      if (row == n - 1) {
        a5PaintTextCentered(
          canvas,
          String.fromCharCode(65 + col),
          r.bottomRight - Offset(cw * 0.14, cw * 0.15),
          cw * 0.17,
          light ? const Color(0x994E342E) : const Color(0xBBFFF8E1),
          weight: FontWeight.w600,
        );
      }
    }

    // Selected stack border
    if (selFrom >= 0 && selFrom < n * n) {
      final r = cellRect(size, n, selFrom).deflate(cw * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cw * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.2, cw * 0.07)
          ..color = accent,
      );
    }

    // Draw stacks on cells
    for (var cell = 0; cell < n * n; cell++) {
      final stack = board[cell];
      if (stack.isEmpty) continue;
      final r = cellRect(size, n, cell);
      _paintStack(canvas, r, cw, stack);
    }

    // Draw winning road connecting line
    if (winningRoad.length >= 2) {
      final p = Paint()
        ..color = const Color(0xEEFFB300)
        ..strokeWidth = max(2.5, cw * 0.09)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i + 1 < winningRoad.length; i++) {
        final c0 = cellRect(size, n, winningRoad[i]).center;
        final c1 = cellRect(size, n, winningRoad[i + 1]).center;
        canvas.drawLine(c0, c1, p);
      }
    }

    // Draw direct spread targets when a stack is selected
    for (final t in directTargets) {
      final r = cellRect(size, n, t);
      final isHover = t == hover;
      if (isHover) {
        canvas.drawRect(r, Paint()..color = const Color(0x4443A047));
      }
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.19 : 0.14),
        Paint()..color = const Color(0xDD43A047),
      );
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.19 : 0.14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.2, cw * 0.03)
          ..color = Colors.white,
      );
    }

    canvas.restore();
  }

  void _paintStack(Canvas canvas, Rect cellRect, double cw, List<TakPiece> stack) {
    final top = stack.last;
    final h = stack.length;
    final center = h > 1 ? cellRect.center - Offset(0, cw * 0.06) : cellRect.center;

    // Draw buried stack layer indicator bars along bottom of cell when height > 1
    if (h > 1) {
      final barW = cw * 0.62;
      final barH = cw * 0.055;
      final baseBottom = cellRect.bottom - cw * 0.07;
      final visibleLayers = min(h - 1, 5);
      for (var i = 0; i < visibleLayers; i++) {
        final p = stack[stack.length - 2 - i];
        final y = baseBottom - (visibleLayers - 1 - i) * (barH + 1.2);
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cellRect.center.dx, y), width: barW, height: barH),
          Radius.circular(barH * 0.4),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = p.owner == 0 ? const Color(0xFFF5F0E1) : const Color(0xFF263238),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFF5D4037),
        );
      }
    }

    final isWhite = top.owner == 0;
    final fillColors = isWhite
        ? const [Color(0xFFFFFFFF), Color(0xFFF5EFE0), Color(0xFFC8BCA4)]
        : const [Color(0xFF546E7A), Color(0xFF263238), Color(0xFF10181B)];
    final borderColor = isWhite ? const Color(0xFF6D4C41) : const Color(0xFFFFD54F);
    final textColor = isWhite ? const Color(0xFF3E2723) : const Color(0xFFFFF8E1);

    if (top.kind == 'flat') {
      final side = cw * 0.60;
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: side, height: side),
        Radius.circular(cw * 0.12),
      );
      canvas.drawRRect(rr.shift(Offset(cw * 0.02, cw * 0.04)), a5Shadow(cw * 0.07, alpha: 0.4));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: fillColors,
          ).createShader(rr.outerRect),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.4, cw * 0.04)
          ..color = borderColor,
      );
    } else if (top.kind == 'wall') {
      // Standing Stone (Wall): narrow rotated bar / standing slab with '墙'
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-pi / 4);
      final w = cw * 0.66, th = cw * 0.26;
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: th),
        Radius.circular(cw * 0.06),
      );
      canvas.drawRRect(rr.shift(Offset(cw * 0.02, cw * 0.04)), a5Shadow(cw * 0.08, alpha: 0.5));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            colors: fillColors,
          ).createShader(rr.outerRect),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, cw * 0.045)
          ..color = borderColor,
      );
      canvas.restore();
      a5PaintTextCentered(canvas, '墙', center, cw * 0.24, textColor);
    } else {
      // Capstone ('cap'): Royal Crowned Stone
      final rad = cw * 0.34;
      canvas.drawCircle(center + Offset(cw * 0.02, cw * 0.05), rad, a5Shadow(cw * 0.09, alpha: 0.5));
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.35),
            colors: fillColors,
          ).createShader(Rect.fromCircle(center: center, radius: rad)),
      );
      canvas.drawCircle(
        center,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.8, cw * 0.055)
          ..color = const Color(0xFFFFB300),
      );
      canvas.drawCircle(
        center,
        rad * 0.74,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, cw * 0.03)
          ..color = borderColor,
      );
      a5PaintTextCentered(canvas, '顶', center, cw * 0.26, textColor);
    }

    // Stack height badge at top-right if height > 1
    if (h > 1) {
      final badgeCenter = cellRect.topRight + Offset(-cw * 0.16, cw * 0.16);
      final br = cw * 0.13;
      canvas.drawCircle(badgeCenter, br, Paint()..color = const Color(0xDD3E2723));
      a5PaintTextCentered(canvas, '$h', badgeCenter, cw * 0.17, const Color(0xFFFFF8E1));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TakBoardView extends StatefulWidget {
  final GameContext g;
  const TakBoardView(this.g, {super.key});
  @override
  State<TakBoardView> createState() => _TakBoardViewState();
}

class _TakBoardViewState extends State<TakBoardView> {
  String placeKind = 'flat'; // 'flat', 'wall', 'cap'
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  List<Map<String, dynamic>> _legalSpreads(List<List<TakPiece>> board, int n, int seat, int from) {
    final out = <Map<String, dynamic>>[];
    if (from < 0 || from >= n * n) return out;
    final stack = board[from];
    if (stack.isEmpty || stack.last.owner != seat) return out;
    final maxPick = min(n, stack.length);
    final topIsCap = stack.last.kind == 'cap';
    final r0 = from ~/ n, c0 = from % n;

    for (var dir = 0; dir < 4; dir++) {
      final (dr, dc) = takDirs[dir];
      void dfs(int step, int rem, List<int> acc) {
        final r = r0 + dr * step, c = c0 + dc * step;
        if (r < 0 || r >= n || c < 0 || c >= n) return;
        final sq = r * n + c;
        final dest = board[sq];
        if (dest.isNotEmpty) {
          final tk = dest.last.kind;
          if (tk == 'cap') return;
          if (tk == 'wall') {
            if (rem == 1 && topIsCap) {
              out.add({'type': 'spread', 'from': from, 'dir': dir, 'drops': [...acc, 1]});
            }
            return;
          }
        }
        for (var drop = 1; drop <= rem; drop++) {
          final nextAcc = [...acc, drop];
          if (drop == rem) {
            out.add({'type': 'spread', 'from': from, 'dir': dir, 'drops': nextAcc});
          } else {
            dfs(step + 1, rem - drop, nextAcc);
          }
        }
      }

      for (var pick = 1; pick <= maxPick; pick++) {
        dfs(1, pick, const []);
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

    final n = (v['size'] as int?) ?? 5;
    final rawBoard = v['board'] as List;
    final board = [
      for (final s in rawBoard) [for (final p in (s as List)) TakPiece.fromJson(p as Map)],
    ];
    final stones = (v['stones'] as List).cast<int>();
    final caps = (v['caps'] as List).cast<int>();
    final flats = (v['flats'] as List).cast<int>();
    final turn = v['turn'] as int;
    final openingSwap = v['openingSwap'] == true;
    final winningRoad = ((v['winningRoad'] as List?) ?? const []).cast<int>();
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;
    final lastPath = ((last?['path'] as List?) ?? const []).cast<int>().toSet();

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    if (openingSwap && placeKind != 'flat') {
      placeKind = 'flat';
    } else if (!openingSwap && placeKind == 'cap' && caps[turn] <= 0) {
      placeKind = 'flat';
    } else if (!openingSwap && (placeKind == 'flat' || placeKind == 'wall') && stones[turn] <= 0 && caps[turn] > 0) {
      placeKind = 'cap';
    }

    final spreads = (myTurn && !openingSwap && selFrom >= 0)
        ? _legalSpreads(board, n, turn, selFrom)
        : const <Map<String, dynamic>>[];

    // Map target cell -> uniform 1-per-step spread for quick board tapping
    final directSpreadByCell = <int, Map<String, dynamic>>{};
    for (final sp in spreads) {
      final dir = sp['dir'] as int;
      final drops = sp['drops'] as List<int>;
      final (dr, dc) = takDirs[dir];
      final r0 = selFrom ~/ n, c0 = selFrom % n;
      final endR = r0 + dr * drops.length, endC = c0 + dc * drops.length;
      final endCell = endR * n + endC;
      // Prefer [1, 1, ...] or smallest pick for direct cell tap
      if (!directSpreadByCell.containsKey(endCell) || drops.every((d) => d == 1)) {
        directSpreadByCell[endCell] = sp;
      }
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= n * n) return;
      if (openingSwap) {
        if (board[c].isEmpty) {
          g.act({'type': 'place', 'cell': c, 'kind': 'flat'});
        }
        return;
      }

      if (selFrom >= 0 && directSpreadByCell.containsKey(c)) {
        final act = directSpreadByCell[c]!;
        setState(() => selFrom = -1);
        g.act(act);
        return;
      }

      if (board[c].isNotEmpty && board[c].last.owner == turn) {
        setState(() => selFrom = selFrom == c ? -1 : c);
        return;
      }

      if (board[c].isEmpty) {
        setState(() => selFrom = -1);
        g.act({'type': 'place', 'cell': c, 'kind': placeKind});
      }
    }

    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      final sideName = turn == 0 ? '白方' : '黑方';
      if (openingSwap) {
        status = '轮到你（$sideName）开局首手：请点击任意空格放置 1 枚【对手颜色】的平石';
      } else if (selFrom >= 0) {
        status = '已选叠堆 ${takCoord(n, selFrom)}：点击绿点快速分撒，或在下方选择具体分堆方案';
      } else {
        final kName = placeKind == 'flat' ? '平石' : (placeKind == 'wall' ? '立石（墙）' : '顶石');
        status = '轮到你（$sideName）：点击空格放置【$kName】，或点击己方叠堆进行分撒移动';
      }
    } else {
      final sideName = turn == 0 ? '白方' : '黑方';
      status = '等待 ${g.name(turn)}（$sideName）行动';
    }

    final actions = <Widget>[];
    if (myTurn && !openingSwap) {
      if (selFrom < 0) {
        if (stones[turn] > 0) {
          actions.add(a5Button(
            context,
            '平石 (${stones[turn]})',
            Icons.crop_square,
            () => setState(() => placeKind = 'flat'),
            primary: placeKind == 'flat',
          ));
          actions.add(a5Button(
            context,
            '立石/墙 (${stones[turn]})',
            Icons.fence,
            () => setState(() => placeKind = 'wall'),
            primary: placeKind == 'wall',
          ));
        }
        if (caps[turn] > 0) {
          actions.add(a5Button(
            context,
            '顶石 (${caps[turn]})',
            Icons.stars,
            () => setState(() => placeKind = 'cap'),
            primary: placeKind == 'cap',
          ));
        }
      } else {
        for (final sp in spreads.take(6)) {
          final dir = sp['dir'] as int;
          final drops = sp['drops'] as List<int>;
          actions.add(a5Button(
            context,
            '向${takDirNames[dir]} [${drops.join(',')}]',
            Icons.trending_flat,
            () {
              setState(() => selFrom = -1);
              g.act(sp);
            },
          ));
        }
        actions.add(a5Button(
          context,
          '取消选择',
          Icons.clear,
          () => setState(() => selFrom = -1),
        ));
      }
    }

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _TakPainter.hit(bSize, n, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_TakPainter.hit(bSize, n, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _TakPainter(
                n: n,
                board: board,
                selFrom: selFrom,
                directTargets: directSpreadByCell.keys.toSet(),
                hover: hover,
                lastPath: lastPath,
                winningRoad: winningRoad,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sideLabel = s == 0 ? '白方' : '黑方';
      final stateLabel = over
          ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负'))
          : ' · 平石 ${flats[s]} · 储 ${stones[s]}+${caps[s]}顶';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFFF5EFE0) : const Color(0xFF263238),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF6D4C41), width: 1.5),
          ),
        ),
      );
    }

    return A5Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '规则：平石与顶石可连通南北或东西大道即胜；立石（墙）阻挡修路与叠放，顶石单独落于立石上可将其压平！',
      ],
      result: a5Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
