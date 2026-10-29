import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a5_common.dart';

class NonogramBoard extends StatefulWidget {
  final GameContext g;
  const NonogramBoard(this.g, {super.key});
  @override
  State<NonogramBoard> createState() => _NonogramBoardState();
}

class _NonogramBoardState extends State<NonogramBoard> {
  GameContext get g => widget.g;
  int _toolMode = 1; // 1 = 涂黑, 2 = 标记 X, 0 = 循环切换

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
    final size = math.max(5, aInt(v['size'], 7));
    final left = aInt(v['left'], 0);
    final rowClues = aIntLists(v['rowClues']);
    final colClues = aIntLists(v['colClues']);
    final board = aInts(v['board']);
    final rowOk = aBools(v['rowOk']);
    final colOk = aBools(v['colOk']);
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';
    final okCount = rowOk.where((x) => x).length + colOk.where((x) => x).length;
    final totalLines = size * 2;

    String status;
    if (phase == 'over') {
      status = '数织竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      status = '第 $round/$totalRounds 题（$size×$size）· 已满足 $okCount/$totalLines 条行列线索 · 剩余 ${left}s';
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
        rowClues: rowClues,
        colClues: colClues,
        board: board,
        rowOk: rowOk,
        colOk: colOk,
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
    final linesOk = aInt(p['linesOk'], 0);
    final totalLines = math.max(1, aInt(p['totalLines'], 10));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$linesOk/$totalLines行', null),
    };
    return A5ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (linesOk / totalLines),
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
    required List<List<int>> rowClues,
    required List<List<int>> colClues,
    required List<int> board,
    required List<bool> rowOk,
    required List<bool> colOk,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 46.0 : (size <= 7 ? 38.0 : 32.0);
    const clueW = 74.0;
    const clueH = 66.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35), width: 1.5),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26, offset: Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Top row: corner label + column clues
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: clueW,
            height: clueH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$size×$size\n第$round/$totalRounds题',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 4),
          for (var c = 0; c < size; c++)
            Container(
              width: cellPx,
              height: clueH,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: (c < colOk.length && colOk[c])
                    ? Colors.green.withValues(alpha: 0.22)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (c < colOk.length && colOk[c]) ? Colors.green : cs.outline.withValues(alpha: 0.25),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (final n in (c < colClues.length ? colClues[c] : const [0]))
                      Text(
                        '$n',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: (c < colOk.length && colOk[c]) ? Colors.green.shade800 : cs.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ]),
        const SizedBox(height: 4),

        // Rows: row clue + cells
        for (var r = 0; r < size; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: clueW,
                height: cellPx,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  color: (r < rowOk.length && rowOk[r])
                      ? Colors.green.withValues(alpha: 0.22)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (r < rowOk.length && rowOk[r]) ? Colors.green : cs.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    (r < rowClues.length ? rowClues[r] : const [0]).join('  '),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: (r < rowOk.length && rowOk[r]) ? Colors.green.shade800 : cs.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              for (var c = 0; c < size; c++) _buildCell(cs, r, c, size, board, cellPx),
            ]),
          ),
      ]),
    );

    final toolbar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
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
          ChoiceChip(
            label: const Text('■ 涂黑', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 1,
            onSelected: (_) => setState(() => _toolMode = 1),
          ),
          ChoiceChip(
            label: const Text('✕ 标记X', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _buildCell(ColorScheme cs, int r, int c, int size, List<int> board, double cellPx) {
    final idx = r * size + c;
    final val = idx < board.length ? board[idx] : 0;
    final filled = val == 1;
    final markedX = val == 2;

    return GestureDetector(
      onTap: _canPlay ? () => _onTapCell(r, c) : null,
      onSecondaryTap: _canPlay ? () => _onSecondaryTapCell(r, c) : null,
      child: Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF263238) : const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: filled ? const Color(0xFF1E88E5) : cs.outline.withValues(alpha: 0.4),
            width: filled ? 1.8 : 1.0,
          ),
        ),
        child: markedX
            ? Center(
                child: Icon(
                  Icons.close,
                  size: cellPx * 0.62,
                  color: Colors.redAccent.shade200,
                ),
              )
            : null,
      ),
    );
  }
}
