import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a7_common.dart';

class NurikabeBoard extends StatefulWidget {
  final GameContext g;
  const NurikabeBoard(this.g, {super.key});
  @override
  State<NurikabeBoard> createState() => _NurikabeBoardState();
}

class _NurikabeBoardState extends State<NurikabeBoard> {
  GameContext get g => widget.g;
  int _toolMode = 0; // 0 = 循环切换, 1 = 涂黑海, 2 = 标白岛

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
    final size = math.max(5, aInt(v['size'], 5));
    final left = aInt(v['left'], 0);
    final clues = aInts(v['clues']);
    final board = aInts(v['board']);
    final twoByTwo = aInts(v['twoByTwo']).toSet();
    final seaConnected = v['seaConnected'] == true;
    final seaComponents = aInt(v['seaComponents'], 0);
    final clueOk = aBools(v['clueOk']);
    final clueIslandSizes = aInts(v['clueIslandSizes']);
    final okClues = aInt(v['okClues'], 0);
    final totalClues = math.max(1, aInt(v['totalClues'], 4));
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '数墙竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已完成数墙划分（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warn = twoByTwo.isNotEmpty
          ? ' · ⚠ 存在 2×2 黑海块'
          : (seaConnected ? ' · 黑海已连通' : (seaComponents > 1 ? ' · 黑海分成了 $seaComponents 块' : ''));
      status = '第 $round/$totalRounds 题（$size×$size）· 岛屿达标 $okClues/$totalClues$warn · 剩余 ${left}s';
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
        clues: clues,
        board: board,
        twoByTwo: twoByTwo,
        seaConnected: seaConnected,
        clueOk: clueOk,
        clueIslandSizes: clueIslandSizes,
        okClues: okClues,
        totalClues: totalClues,
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
                    (r) => '${r['score']} 分 · 解出 ${r['solved']}/$totalRounds 题',
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
    final okClues = aInt(p['okClues'], 0);
    final totalClues = math.max(1, aInt(p['totalClues'], 4));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$okClues/$totalClues岛', null),
    };
    return A7ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (okClues / totalClues),
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
    required List<int> clues,
    required List<int> board,
    required Set<int> twoByTwo,
    required bool seaConnected,
    required List<bool> clueOk,
    required List<int> clueIslandSizes,
    required int okClues,
    required int totalClues,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 52.0 : 40.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF10202E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4FC3F7).withValues(alpha: 0.45), width: 1.8),
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
                    r: r,
                    c: c,
                    size: size,
                    cellPx: cellPx,
                    clues: clues,
                    board: board,
                    twoByTwo: twoByTwo,
                    clueOk: clueOk,
                    clueIslandSizes: clueIslandSizes,
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
          A7Chip('第 $round/$totalRounds 题 · 岛屿 $okClues/$totalClues', cs.primary, size: 11),
          A7Chip(
            twoByTwo.isNotEmpty ? '⚠ 2×2 黑块!' : (seaConnected ? '黑海已连通' : '黑海待连通'),
            twoByTwo.isNotEmpty ? Colors.redAccent : (seaConnected ? Colors.teal : Colors.blueGrey),
            size: 11,
          ),
          ChoiceChip(
            label: const Text('↻ 循环', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 0,
            onSelected: (_) => setState(() => _toolMode = 0),
          ),
          ChoiceChip(
            label: const Text('🌊 涂黑海', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 1,
            onSelected: (_) => setState(() => _toolMode = 1),
          ),
          ChoiceChip(
            label: const Text('· 标白岛', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 2,
            onSelected: (_) => setState(() => _toolMode = 2),
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
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> clues,
    required List<int> board,
    required Set<int> twoByTwo,
    required List<bool> clueOk,
    required List<int> clueIslandSizes,
  }) {
    final idx = r * size + c;
    final clue = idx < clues.length ? clues[idx] : 0;

    if (clue > 0) {
      final ok = idx < clueOk.length && clueOk[idx];
      final curSize = idx < clueIslandSizes.length ? clueIslandSizes[idx] : 0;
      return Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ok ? const Color(0xFF2E7D32) : const Color(0xFFFF8F00),
            width: 2.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$clue',
              style: TextStyle(
                fontSize: cellPx * 0.46,
                fontWeight: FontWeight.w900,
                color: ok ? const Color(0xFF1B5E20) : const Color(0xFF263238),
              ),
            ),
            if (curSize > 0)
              Positioned(
                right: 2,
                bottom: 1,
                child: Text(
                  '$curSize',
                  style: TextStyle(
                    fontSize: cellPx * 0.2,
                    fontWeight: FontWeight.bold,
                    color: ok ? const Color(0xFF2E7D32) : const Color(0xFF78909C),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final val = idx < board.length ? board[idx] : 0;
    final isBad2x2 = twoByTwo.contains(idx);

    Widget? child;
    if (val == 1) {
      child = Center(
        child: Icon(
          isBad2x2 ? Icons.warning_amber_rounded : Icons.waves,
          size: cellPx * 0.42,
          color: isBad2x2
              ? const Color(0xFFFF8A80)
              : const Color(0xFF4FC3F7).withValues(alpha: 0.55),
        ),
      );
    } else if (val == 2) {
      child = Center(
        child: Container(
          width: cellPx * 0.24,
          height: cellPx * 0.24,
          decoration: const BoxDecoration(
            color: Color(0xFF2E7D32),
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
        margin: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          color: val == 1
              ? (isBad2x2 ? const Color(0xFF4E141C) : const Color(0xFF15293B))
              : const Color(0xFFF5F5F0),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isBad2x2
                ? const Color(0xFFFF5252)
                : (val == 1 ? const Color(0xFF0288D1) : const Color(0xFFB0BEC5)),
            width: isBad2x2 ? 2.2 : 1.1,
          ),
        ),
        child: child,
      ),
    );
  }
}
