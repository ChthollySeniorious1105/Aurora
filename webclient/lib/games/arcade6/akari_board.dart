import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a6_common.dart';

class AkariBoard extends StatefulWidget {
  final GameContext g;
  const AkariBoard(this.g, {super.key});
  @override
  State<AkariBoard> createState() => _AkariBoardState();
}

class _AkariBoardState extends State<AkariBoard> {
  GameContext get g => widget.g;
  int _toolMode = 1; // 1 = 灯泡 💡, 2 = 标记点 ·, 0 = 循环切换

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onTapCell(int r, int c) {
    if (!_canPlay) return;
    if (_toolMode == 0) {
      g.act({'type': 'toggle', 'r': r, 'c': c});
    } else {
      g.act({'type': 'toggle', 'r': r, 'c': c, 'mode': _toolMode});
    }
  }

  void _onSecondaryTapCell(int r, int c) {
    if (!_canPlay) return;
    g.act({'type': 'toggle', 'r': r, 'c': c, 'mode': 2});
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
    final board = aInts(v['board']);
    final lit = aBools(v['lit']);
    final conflicts = aInts(v['conflicts']).toSet();
    final wallOk = aBools(v['wallOk']);
    final litWhite = aInt(v['litWhite'], 0);
    final totalWhite = math.max(1, aInt(v['totalWhite'], 20));
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '美术馆照明竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已点亮美术馆（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final confWarn = conflicts.isNotEmpty ? ' · ⚠ 灯泡直射冲突' : '';
      status = '第 $round/$totalRounds 题（$size×$size）· 已照亮 $litWhite/$totalWhite 格$confWarn · 剩余 ${left}s';
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
        board: board,
        lit: lit,
        conflicts: conflicts,
        wallOk: wallOk,
        litWhite: litWhite,
        totalWhite: totalWhite,
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
                    (r) => '${r['score']} 分 · 点亮 ${r['solved']}/$totalRounds 题',
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
    final litWhite = aInt(p['litWhite'], 0);
    final totalWhite = math.max(1, aInt(p['totalWhite'], 20));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$litWhite/$totalWhite亮', null),
    };
    return A6ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (litWhite / totalWhite),
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
    required int round,
    required int totalRounds,
    required List<int> grid,
    required List<int> board,
    required List<bool> lit,
    required Set<int> conflicts,
    required List<bool> wallOk,
    required int litWhite,
    required int totalWhite,
    required bool wide,
  }) {
    final cellPx = size <= 6 ? 46.0 : 38.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E242B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < size; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < size; c++)
                  _buildCell(
                    cs: cs,
                    r: r,
                    c: c,
                    size: size,
                    cellPx: cellPx,
                    grid: grid,
                    board: board,
                    lit: lit,
                    conflicts: conflicts,
                    wallOk: wallOk,
                  ),
              ],
            ),
        ],
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
          A6Chip('第 $round/$totalRounds 题 · $litWhite/$totalWhite 亮', cs.primary, size: 11),
          ChoiceChip(
            label: const Text('💡 放灯泡', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 1,
            onSelected: (_) => setState(() => _toolMode = 1),
          ),
          ChoiceChip(
            label: const Text('· 标记点', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 2,
            onSelected: (_) => setState(() => _toolMode = 2),
          ),
          ChoiceChip(
            label: const Text('↻ 循环', style: TextStyle(fontSize: 12)),
            selected: _toolMode == 0,
            onSelected: (_) => setState(() => _toolMode = 0),
          ),
          OutlinedButton.icon(
            onPressed: _canPlay ? () => g.act({'type': 'clear'}) : null,
            icon: const Icon(Icons.layers_clear, size: 16),
            label: const Text('清空', style: TextStyle(fontSize: 12)),
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
                gridCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }

  Widget _buildCell({
    required ColorScheme cs,
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> grid,
    required List<int> board,
    required List<bool> lit,
    required Set<int> conflicts,
    required List<bool> wallOk,
  }) {
    final idx = r * size + c;
    final cellType = idx < grid.length ? grid[idx] : -2;

    if (cellType >= -1) {
      // Black wall (unnumbered -1 or numbered 0..4)
      final ok = idx < wallOk.length && wallOk[idx];
      return Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: const Color(0xFF101418),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: cellType >= 0
                ? (ok ? const Color(0xFF69F0AE) : const Color(0xFF90A4AE))
                : const Color(0xFF37474F),
            width: cellType >= 0 ? 1.6 : 1.0,
          ),
        ),
        child: cellType >= 0
            ? Center(
                child: Text(
                  '$cellType',
                  style: TextStyle(
                    fontSize: cellPx * 0.48,
                    fontWeight: FontWeight.w900,
                    color: ok ? const Color(0xFF69F0AE) : Colors.white,
                  ),
                ),
              )
            : null,
      );
    }

    // White corridor cell
    final val = idx < board.length ? board[idx] : 0;
    final isLit = idx < lit.length && lit[idx];
    final isConflict = conflicts.contains(idx);

    Widget? child;
    if (val == 1) {
      child = Center(
        child: Icon(
          Icons.lightbulb,
          size: cellPx * 0.64,
          color: isConflict ? const Color(0xFFD50000) : const Color(0xFFF57F17),
        ),
      );
    } else if (val == 2) {
      child = Center(
        child: Container(
          width: cellPx * 0.22,
          height: cellPx * 0.22,
          decoration: const BoxDecoration(
            color: Color(0xFF546E7A),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _canPlay ? () => _onTapCell(r, c) : null,
      onSecondaryTap: _canPlay ? () => _onSecondaryTapCell(r, c) : null,
      child: Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isConflict
              ? const Color(0xFFFFCDD2)
              : (isLit ? const Color(0xFFFFF59D) : const Color(0xFFF5F5F0)),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isConflict
                ? const Color(0xFFE53935)
                : (isLit ? const Color(0xFFFBC02D) : const Color(0xFFB0BEC5)),
            width: (val == 1 || isConflict) ? 1.8 : 1.0,
          ),
        ),
        child: child,
      ),
    );
  }
}
