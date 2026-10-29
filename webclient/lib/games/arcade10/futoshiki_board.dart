import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a10_common.dart';

class FutoshikiBoard extends StatefulWidget {
  final GameContext g;
  const FutoshikiBoard(this.g, {super.key});
  @override
  State<FutoshikiBoard> createState() => _FutoshikiBoardState();
}

class _FutoshikiBoardState extends State<FutoshikiBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onCellTap(int r, int c, int size, bool isClue) {
    final idx = r * size + c;
    setState(() => _selectedIdx = idx);
    if (!_canPlay || isClue) return;
    g.act({'type': 'toggle', 'r': r, 'c': c});
  }

  void _onSetDigit(int val, int size, List<int> cluesFlat) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    if (idx < cluesFlat.length && cluesFlat[idx] > 0) return;
    g.act({'type': 'set', 'r': idx ~/ size, 'c': idx % size, 'val': val});
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(4, aInt(v['size'], 4));
    final left = aInt(v['left'], 0);
    final cluesFlat = aInts(v['cluesFlat']);
    final hIneq = aIntGrid(v['hIneq']);
    final vIneq = aIntGrid(v['vIneq']);
    final board = aInts(v['board']);
    final duplicates = aInts(v['duplicates']).toSet();
    final violatedCells = aInts(v['violatedCells']).toSet();
    final violatedH = aInts(v['violatedH']).toSet();
    final violatedV = aInts(v['violatedV']).toSet();
    final satisfiedIneq = aInt(v['satisfiedIneq'], 0);
    final totalIneq = math.max(1, aInt(v['totalIneq'], 1));
    final validLines = aInt(v['validLines'], 0);
    final totalLines = math.max(1, aInt(v['totalLines'], 2 * size));
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '不等号数独竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出不等号数独（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (duplicates.isNotEmpty) '同行/列重复',
        if (violatedCells.isNotEmpty) '不等号违背',
      ];
      final warnStr = warnings.isEmpty ? '无冲突' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 不等号 $satisfiedIneq/$totalIneq · 达标行列 $validLines/$totalLines · $warnStr · ${left}s';
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
        cluesFlat: cluesFlat,
        hIneq: hIneq,
        vIneq: vIneq,
        board: board,
        duplicates: duplicates,
        violatedCells: violatedCells,
        violatedH: violatedH,
        violatedV: violatedV,
        satisfiedIneq: satisfiedIneq,
        totalIneq: totalIneq,
        validLines: validLines,
        totalLines: totalLines,
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
    final filled = aInt(p['filled'], 0);
    final totalCells = math.max(1, aInt(p['totalCells'], 16));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$filled/$totalCells格', null),
    };
    return A10ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (filled / totalCells),
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
    required List<int> cluesFlat,
    required List<List<int>> hIneq,
    required List<List<int>> vIneq,
    required List<int> board,
    required Set<int> duplicates,
    required Set<int> violatedCells,
    required Set<int> violatedH,
    required Set<int> violatedV,
    required int satisfiedIneq,
    required int totalIneq,
    required int validLines,
    required int totalLines,
    required bool wide,
  }) {
    final cellPx = size <= 4 ? 50.0 : 44.0;
    final gapPx = size <= 4 ? 22.0 : 18.0;

    int hSign(int r, int c) =>
        (r < hIneq.length && c < hIneq[r].length) ? hIneq[r][c] : 0;
    int vSign(int r, int c) =>
        (r < vIneq.length && c < vIneq[r].length) ? vIneq[r][c] : 0;

    final gridCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141C26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < size; r++) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < size; c++) ...[
                  _buildCell(
                    r: r,
                    c: c,
                    size: size,
                    cellPx: cellPx,
                    cluesFlat: cluesFlat,
                    board: board,
                    duplicates: duplicates,
                    violatedCells: violatedCells,
                  ),
                  if (c < size - 1)
                    _buildHIneqBadge(
                      r: r,
                      c: c,
                      size: size,
                      gapPx: gapPx,
                      cellPx: cellPx,
                      sign: hSign(r, c),
                      board: board,
                      violated: violatedH.contains(r * (size - 1) + c),
                    ),
                ],
              ],
            ),
            if (r < size - 1)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < size; c++) ...[
                    _buildVIneqBadge(
                      r: r,
                      c: c,
                      size: size,
                      cellPx: cellPx,
                      gapPx: gapPx,
                      sign: vSign(r, c),
                      board: board,
                      violated: violatedV.contains(r * size + c),
                    ),
                    if (c < size - 1) SizedBox(width: gapPx, height: gapPx),
                  ],
                ],
              ),
          ],
        ],
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 230 : 340),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              A10Chip('不等号 $satisfiedIneq/$totalIneq', const Color(0xFF00897B), size: 11),
              A10Chip('行列 $validLines/$totalLines', cs.primary, size: 11),
              A10Chip(
                duplicates.isEmpty && violatedCells.isEmpty ? '✓ 无冲突' : '⚠ 存在冲突',
                duplicates.isEmpty && violatedCells.isEmpty ? Colors.green : Colors.redAccent,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var d = 1; d <= size; d++)
                SizedBox(
                  width: 38,
                  height: 34,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: _canPlay ? () => _onSetDigit(d, size, cluesFlat) : null,
                    child: Text('$d', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              SizedBox(
                width: 44,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetDigit(0, size, cluesFlat) : null,
                  child: const Icon(Icons.backspace_outlined, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _canPlay ? () => g.act({'type': 'clear'}) : null,
                icon: const Icon(Icons.layers_clear, size: 15),
                label: const Text('重置', style: TextStyle(fontSize: 12)),
              ),
              FilledButton.tonalIcon(
                onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
                icon: const Icon(Icons.flag_outlined, size: 15),
                label: const Text('放弃', style: TextStyle(fontSize: 12)),
              ),
            ],
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

  Widget _buildHIneqBadge({
    required int r,
    required int c,
    required int size,
    required double gapPx,
    required double cellPx,
    required int sign,
    required List<int> board,
    required bool violated,
  }) {
    if (sign == 0) {
      return SizedBox(width: gapPx, height: cellPx);
    }
    final idxA = r * size + c, idxB = r * size + (c + 1);
    final a = idxA < board.length ? board[idxA] : 0;
    final b = idxB < board.length ? board[idxB] : 0;
    final satisfied = a > 0 && b > 0 && !violated;
    final symbol = sign < 0 ? '<' : '>';

    return SizedBox(
      width: gapPx,
      height: cellPx,
      child: Center(
        child: Container(
          width: gapPx - 2,
          height: gapPx - 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: violated
                ? const Color(0xFFD32F2F)
                : (satisfied ? const Color(0xFF2E7D32) : const Color(0xFF263238)),
            shape: BoxShape.circle,
          ),
          child: Text(
            symbol,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVIneqBadge({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required double gapPx,
    required int sign,
    required List<int> board,
    required bool violated,
  }) {
    if (sign == 0) {
      return SizedBox(width: cellPx, height: gapPx);
    }
    final idxA = r * size + c, idxB = (r + 1) * size + c;
    final a = idxA < board.length ? board[idxA] : 0;
    final b = idxB < board.length ? board[idxB] : 0;
    final satisfied = a > 0 && b > 0 && !violated;
    final symbol = sign < 0 ? '∧' : '∨';

    return SizedBox(
      width: cellPx,
      height: gapPx,
      child: Center(
        child: Container(
          width: gapPx - 2,
          height: gapPx - 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: violated
                ? const Color(0xFFD32F2F)
                : (satisfied ? const Color(0xFF2E7D32) : const Color(0xFF263238)),
            shape: BoxShape.circle,
          ),
          child: Text(
            symbol,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> cluesFlat,
    required List<int> board,
    required Set<int> duplicates,
    required Set<int> violatedCells,
  }) {
    final idx = r * size + c;
    final isClue = idx < cluesFlat.length && cluesFlat[idx] > 0;
    final val = idx < board.length ? board[idx] : 0;
    final isConflict = duplicates.contains(idx) || violatedCells.contains(idx);
    final isSelected = _selectedIdx == idx;

    Color bgColor;
    Color borderColor;
    Color textColor;
    double borderWidth = isSelected ? 2.4 : 1.4;

    if (isClue) {
      bgColor = isConflict ? const Color(0xFFFFEBEE) : const Color(0xFFE2E8F0);
      borderColor = isConflict
          ? const Color(0xFFD32F2F)
          : (isSelected ? const Color(0xFF0288D1) : const Color(0xFF64748B));
      textColor = isConflict ? const Color(0xFFB71C1C) : const Color(0xFF0F172A);
    } else {
      bgColor = isConflict
          ? const Color(0xFFFFEBEE)
          : (isSelected ? const Color(0xFFE0F7FA) : const Color(0xFFFAFAFA));
      borderColor = isConflict
          ? const Color(0xFFE53935)
          : (isSelected ? const Color(0xFF00ACC1) : const Color(0xFFB0BEC5));
      textColor = isConflict ? const Color(0xFFC62828) : const Color(0xFF0277BD);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size, isClue),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay && !isClue) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': 0});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        alignment: Alignment.center,
        child: val > 0
            ? Text(
                '$val',
                style: TextStyle(
                  fontSize: cellPx * 0.46,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              )
            : null,
      ),
    );
  }
}
