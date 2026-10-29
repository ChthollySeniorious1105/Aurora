import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common.dart';
import 'a8_common.dart';

class KakuroBoard extends StatefulWidget {
  final GameContext g;
  const KakuroBoard(this.g, {super.key});
  @override
  State<KakuroBoard> createState() => _KakuroBoardState();
}

class _KakuroBoardState extends State<KakuroBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = -1;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _ensureValidSelection(List<bool> isWhite) {
    if (_selectedIdx >= 0 && _selectedIdx < isWhite.length && isWhite[_selectedIdx]) return;
    _selectedIdx = isWhite.indexOf(true);
  }

  void _setDigit(int d, int size, List<bool> isWhite) {
    if (!_canPlay || _selectedIdx < 0 || _selectedIdx >= isWhite.length || !isWhite[_selectedIdx]) {
      return;
    }
    g.act({
      'type': 'set',
      'r': _selectedIdx ~/ size,
      'c': _selectedIdx % size,
      'val': d,
    });
  }

  KeyEventResult _onKeyEvent(
    KeyEvent event,
    int size,
    List<bool> isWhite,
  ) {
    if (event is! KeyDownEvent || !_canPlay) return KeyEventResult.ignored;
    final key = event.logicalKey;

    final digitMap = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.digit1: 1,
      LogicalKeyboardKey.numpad1: 1,
      LogicalKeyboardKey.digit2: 2,
      LogicalKeyboardKey.numpad2: 2,
      LogicalKeyboardKey.digit3: 3,
      LogicalKeyboardKey.numpad3: 3,
      LogicalKeyboardKey.digit4: 4,
      LogicalKeyboardKey.numpad4: 4,
      LogicalKeyboardKey.digit5: 5,
      LogicalKeyboardKey.numpad5: 5,
      LogicalKeyboardKey.digit6: 6,
      LogicalKeyboardKey.numpad6: 6,
      LogicalKeyboardKey.digit7: 7,
      LogicalKeyboardKey.numpad7: 7,
      LogicalKeyboardKey.digit8: 8,
      LogicalKeyboardKey.numpad8: 8,
      LogicalKeyboardKey.digit9: 9,
      LogicalKeyboardKey.numpad9: 9,
      LogicalKeyboardKey.digit0: 0,
      LogicalKeyboardKey.numpad0: 0,
      LogicalKeyboardKey.backspace: 0,
      LogicalKeyboardKey.delete: 0,
    };

    if (digitMap.containsKey(key)) {
      _setDigit(digitMap[key]!, size, isWhite);
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
    final size = math.max(5, aInt(v['size'], 5));
    final left = aInt(v['left'], 0);
    final isWhite = aBools(v['isWhite']);
    final acrossClues = aInts(v['acrossClues']);
    final downClues = aInts(v['downClues']);
    final board = aInts(v['board']);
    final conflicts = aInts(v['conflicts']).toSet();
    final acrossOk = aBools(v['acrossOk']);
    final downOk = aBools(v['downOk']);
    final okRuns = aInt(v['okRuns'], 0);
    final totalRuns = math.max(1, aInt(v['totalRuns'], 8));
    final filledWhite = aInt(v['filledWhite'], 0);
    final totalWhite = math.max(1, aInt(v['totalWhite'], 12));
    final ps = aMaps(v['ps']);

    _ensureValidSelection(isWhite);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '数和填字竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已完成数和填字（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warn = conflicts.isNotEmpty ? ' · ⚠ 存在重复或超额数字' : '';
      status =
          '第 $round/$totalRounds 题（$size×$size）· 区段达标 $okRuns/$totalRuns · 已填 $filledWhite/$totalWhite$warn · ${left}s';
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, e) => _onKeyEvent(e, size, isWhite),
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
          round: round,
          totalRounds: totalRounds,
          isWhite: isWhite,
          acrossClues: acrossClues,
          downClues: downClues,
          board: board,
          conflicts: conflicts,
          acrossOk: acrossOk,
          downOk: downOk,
          okRuns: okRuns,
          totalRuns: totalRuns,
          filledWhite: filledWhite,
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
                      (r) => '${r['score']} 分 · 解出 ${r['solved']}/$totalRounds 题',
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
    final okRuns = aInt(p['okRuns'], 0);
    final totalRuns = math.max(1, aInt(p['totalRuns'], 8));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$okRuns/$totalRuns段', null),
    };
    return A8ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (okRuns / totalRuns),
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
    required List<bool> isWhite,
    required List<int> acrossClues,
    required List<int> downClues,
    required List<int> board,
    required Set<int> conflicts,
    required List<bool> acrossOk,
    required List<bool> downOk,
    required int okRuns,
    required int totalRuns,
    required int filledWhite,
    required int totalWhite,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 52.0 : 45.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141C24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.45), width: 1.8),
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
                    isWhite: isWhite,
                    acrossClues: acrossClues,
                    downClues: downClues,
                    board: board,
                    conflicts: conflicts,
                    acrossOk: acrossOk,
                    downOk: downOk,
                  ),
              ],
            ),
        ],
      ),
    );

    final numpad = Container(
      constraints: BoxConstraints(maxWidth: wide ? 220 : 320),
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
              A8Chip('区段 $okRuns/$totalRuns', cs.primary, size: 11),
              A8Chip(
                conflicts.isNotEmpty ? '⚠ 数字冲突' : '已填 $filledWhite/$totalWhite',
                conflicts.isNotEmpty ? Colors.redAccent : Colors.teal,
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
              for (var d = 1; d <= 9; d++)
                SizedBox(
                  width: 48,
                  height: 38,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _canPlay ? () => _setDigit(d, size, isWhite) : null,
                    child: Text(
                      '$d',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              SizedBox(
                width: 48,
                height: 38,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _canPlay ? () => _setDigit(0, size, isWhite) : null,
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
                label: const Text('清空', style: TextStyle(fontSize: 12)),
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
                numpad,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(height: 8),
                numpad,
              ]),
      ),
    );
  }

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<bool> isWhite,
    required List<int> acrossClues,
    required List<int> downClues,
    required List<int> board,
    required Set<int> conflicts,
    required List<bool> acrossOk,
    required List<bool> downOk,
  }) {
    final idx = r * size + c;
    final white = idx < isWhite.length && isWhite[idx];

    if (!white) {
      final ac = idx < acrossClues.length ? acrossClues[idx] : 0;
      final dn = idx < downClues.length ? downClues[idx] : 0;
      final aOk = idx < acrossOk.length && acrossOk[idx];
      final dOk = idx < downOk.length && downOk[idx];

      return Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1.2),
        child: CustomPaint(
          size: Size(cellPx, cellPx),
          painter: _KakuroClueCellPainter(
            acrossSum: ac,
            downSum: dn,
            acrossOk: aOk,
            downOk: dOk,
          ),
        ),
      );
    }

    final val = idx < board.length ? board[idx] : 0;
    final selected = idx == _selectedIdx;
    final bad = conflicts.contains(idx);
    final sameRowOrCol =
        _selectedIdx >= 0 && (_selectedIdx ~/ size == r || _selectedIdx % size == c);

    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
        setState(() => _selectedIdx = idx);
      },
      onSecondaryTap: _canPlay
          ? () {
              setState(() => _selectedIdx = idx);
              _setDigit(0, size, isWhite);
            }
          : null,
      child: Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          color: bad
              ? const Color(0xFFFFEBEE)
              : (selected
                  ? const Color(0xFFFFF8E1)
                  : (sameRowOrCol ? const Color(0xFFE3F2FD) : const Color(0xFFFAFAFA))),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: bad
                ? const Color(0xFFD32F2F)
                : (selected ? const Color(0xFFFF8F00) : const Color(0xFFB0BEC5)),
            width: selected || bad ? 2.4 : 1.1,
          ),
        ),
        alignment: Alignment.center,
        child: val > 0
            ? Text(
                '$val',
                style: TextStyle(
                  fontSize: cellPx * 0.48,
                  fontWeight: FontWeight.w900,
                  color: bad ? const Color(0xFFC62828) : const Color(0xFF1A237E),
                ),
              )
            : null,
      ),
    );
  }
}

class _KakuroClueCellPainter extends CustomPainter {
  final int acrossSum;
  final int downSum;
  final bool acrossOk;
  final bool downOk;

  _KakuroClueCellPainter({
    required this.acrossSum,
    required this.downSum,
    required this.acrossOk,
    required this.downOk,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF212B36));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF455A64)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    if (acrossSum > 0 || downSum > 0) {
      canvas.drawLine(
        const Offset(2, 2),
        Offset(size.width - 2, size.height - 2),
        Paint()
          ..color = const Color(0xFF78909C)
          ..strokeWidth = 1.4,
      );
    }

    if (acrossSum > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$acrossSum',
          style: TextStyle(
            fontSize: size.width * 0.27,
            fontWeight: FontWeight.w900,
            color: acrossOk ? const Color(0xFF69F0AE) : const Color(0xFFFFD54F),
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 4, 2));
    }

    if (downSum > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$downSum',
          style: TextStyle(
            fontSize: size.width * 0.27,
            fontWeight: FontWeight.w900,
            color: downOk ? const Color(0xFF69F0AE) : const Color(0xFF80DEEA),
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, size.height - tp.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _KakuroClueCellPainter old) =>
      old.acrossSum != acrossSum ||
      old.downSum != downSum ||
      old.acrossOk != acrossOk ||
      old.downOk != downOk;
}
