import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/common.dart';
import 'a3_common.dart';

class Math24Board extends StatefulWidget {
  final GameContext g;
  const Math24Board(this.g, {super.key});
  @override
  State<Math24Board> createState() => _Math24BoardState();
}

class _Math24BoardState extends State<Math24Board> {
  GameContext get g => widget.g;
  int _selCard = -1;
  String _selOp = '';
  int _lastRound = -1;
  int _lastLen = -1;

  static const _ops = [
    ('+', '＋', '加'),
    ('-', '－', '减'),
    ('*', '×', '乘'),
    ('/', '÷', '除'),
  ];

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _syncState(int round, int itemLen) {
    if (round != _lastRound || itemLen != _lastLen) {
      _lastRound = round;
      _lastLen = itemLen;
      if (_selCard >= itemLen) _selCard = -1;
      if (itemLen <= 1) {
        _selCard = -1;
        _selOp = '';
      }
    }
  }

  void _onTapCard(int idx, int itemLen) {
    if (!_canPlay || idx < 0 || idx >= itemLen) return;
    if (_selCard == idx) {
      setState(() => _selCard = -1);
      return;
    }
    if (_selCard >= 0 && _selCard < itemLen && _selOp.isNotEmpty) {
      final a = _selCard;
      final op = _selOp;
      setState(() {
        _selCard = -1;
        _selOp = '';
      });
      g.act({'type': 'op', 'a': a, 'b': idx, 'op': op});
      return;
    }
    setState(() => _selCard = idx);
  }

  void _onTapOp(String op, int itemLen) {
    if (!_canPlay || itemLen < 2) return;
    setState(() {
      if (_selCard < 0 && itemLen > 0) _selCard = 0;
      _selOp = _selOp == op ? '' : op;
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final items = aMaps(g.view['items']);
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.digit1) {
      _onTapCard(0, items.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit2) {
      _onTapCard(1, items.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit3) {
      _onTapCard(2, items.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit4) {
      _onTapCard(3, items.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.add || k == LogicalKeyboardKey.equal) {
      _onTapOp('+', items.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      _onTapOp('-', items.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.numpadMultiply || k == LogicalKeyboardKey.keyX) {
      _onTapOp('*', items.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.slash || k == LogicalKeyboardKey.numpadDivide) {
      _onTapOp('/', items.length);
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
    final left = aInt(v['left'], 0);
    final nums = aInts(v['nums']);
    final items = aMaps(v['items']);
    final steps = aStrs(v['steps']);
    final ps = aMaps(v['ps']);
    final canUndo = v['canUndo'] == true;
    final canReset = v['canReset'] == true;
    final sol = aStr(v['sol']);
    final lastRes = aMap(v['lastResult']);

    _syncState(round, items.length);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '游戏结束 · 共 $totalRounds 题';
    } else if (phase == 'reveal') {
      status = '第 $round/$totalRounds 题结算 · 参考解法：${sol.isEmpty ? "见面板" : sol}';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题 · 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 你已算出 24（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'skip') {
      status = '第 $round/$totalRounds 题 · 你已跳过本题，等待其他玩家 · ${left}s';
    } else if (items.length == 1 && aStr(items[0]['txt']) != '24') {
      status = '结果是 ${items[0]['txt']}（不等于 24），请点「撤销」或「重置」！';
    } else if (_selCard >= 0 && _selOp.isEmpty) {
      status = '已选数字 ${items[_selCard]['txt']}，请选择运算符（＋ － × ÷）';
    } else if (_selCard >= 0 && _selOp.isNotEmpty) {
      status = '已选 ${items[_selCard]['txt']} $_selOp ，请点击第二个数字合并！';
    } else {
      status = '第 $round/$totalRounds 题 · 依次选「数字 → 运算符 → 数字」合成 24 · 剩余 ${left}s';
    }

    return A3Keys(
      onKeyEvent: _onKey,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight * 1.15;
        final sideW = wide ? math.min(200.0, box.maxWidth * 0.25) : 0.0;
        final topStripH = wide ? 0.0 : 62.0;

        final playerTiles = Wrap(
          direction: wide ? Axis.vertical : Axis.horizontal,
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final s in g.seatsFromMe())
              if (s < ps.length) _buildPlayerTile(s, ps[s], totalRounds, wide ? sideW - 12 : 142),
          ],
        );

        final workspace = _buildWorkspace(
          context,
          cs: cs,
          round: round,
          totalRounds: totalRounds,
          nums: nums,
          items: items,
          steps: steps,
          canUndo: canUndo,
          canReset: canReset,
          myStatus: myStatus,
          phase: phase,
          sol: sol,
          lastRes: lastRes,
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
          SizedBox(height: 40, child: aStatus(status, highlight: _canPlay)),
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
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts', Colors.green),
      'skip' => ('跳过', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('思考中', null),
    };
    return A3ProgressTile(
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
    required int round,
    required int totalRounds,
    required List<int> nums,
    required List<Map<String, dynamic>> items,
    required List<String> steps,
    required bool canUndo,
    required bool canReset,
    required String myStatus,
    required String phase,
    required String sol,
    required Map<String, dynamic>? lastRes,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35), width: 1.5),
          boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26, offset: Offset(0, 4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header: Round & Initial 4 Numbers
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            A3Chip('第 $round / $totalRounds 题', cs.primary, size: 13),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('本轮初始数字：', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.75))),
              for (final n in nums)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$n', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                ),
            ]),
          ]),
          const SizedBox(height: 14),

          if (phase == 'reveal') ...[
            _buildRevealPanel(cs, sol, lastRes),
          ] else ...[
            // Number Cards in Workspace
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < items.length; i++) _buildNumberCard(cs, i, items[i], items.length),
              ],
            ),
            const SizedBox(height: 14),

            // Operator Buttons
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final (opCode, sym, label) in _ops)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildOpButton(cs, opCode, sym, label, items.length),
                ),
            ]),
            const SizedBox(height: 12),

            // Steps History
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                steps.isEmpty ? '步骤记录：尚无运算步骤（点击两个数字与运算符进行合并）' : '已算步骤：${steps.join("   →   ")}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.85)),
              ),
            ),
            const SizedBox(height: 12),

            // Action Toolbar: Undo, Reset, Skip
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton.icon(
                onPressed: canUndo ? () => g.act({'type': 'undo'}) : null,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('撤销'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: canReset ? () => g.act({'type': 'reset'}) : null,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重置'),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: _canPlay ? () => g.act({'type': 'skip'}) : null,
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('跳过本题'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _buildNumberCard(ColorScheme cs, int i, Map<String, dynamic> item, int totalItems) {
    final txt = aStr(item['txt']);
    final expr = aStr(item['expr']);
    final selected = _selCard == i;
    final isTarget24 = totalItems == 1 && txt == '24';
    final isWrongSingle = totalItems == 1 && txt != '24';

    final borderColor = isTarget24
        ? Colors.green
        : (isWrongSingle ? Colors.redAccent : (selected ? cs.primary : cs.outline.withValues(alpha: 0.35)));

    return GestureDetector(
      onTap: _canPlay ? () => _onTapCard(i, totalItems) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 104,
        height: 126,
        transform: Matrix4.translationValues(0, selected ? -6 : 0, 0),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer
              : (isTarget24 ? Colors.green.shade50 : const Color(0xFFFFFDF7)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected || isTarget24 || isWrongSingle ? 3 : 1.5),
          boxShadow: [
            BoxShadow(
              blurRadius: selected ? 10 : 4,
              color: Colors.black26,
              offset: Offset(0, selected ? 5 : 2),
            ),
          ],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              '#${i + 1}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  txt,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: isTarget24
                        ? Colors.green.shade800
                        : (isWrongSingle ? Colors.red.shade700 : const Color(0xFF263238)),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 18,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                expr,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildOpButton(ColorScheme cs, String opCode, String sym, String label, int itemLen) {
    final selected = _selOp == opCode;
    final enabled = _canPlay && itemLen >= 2;
    return Material(
      color: selected ? cs.primary : cs.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      elevation: selected ? 4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => _onTapOp(opCode, itemLen) : null,
        child: SizedBox(
          width: 68,
          height: 52,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              sym,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: selected ? cs.onPrimary : cs.onSecondaryContainer,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: (selected ? cs.onPrimary : cs.onSecondaryContainer).withValues(alpha: 0.8),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRevealPanel(ColorScheme cs, String sol, Map<String, dynamic>? lastRes) {
    final rows = aMaps(lastRes?['ps']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '参考解法：${sol.isNotEmpty ? sol : aStr(lastRes?['sol'])}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.primary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final r in rows)
              Chip(
                label: Text(
                  '${g.name(aInt(r['s']))}: ${aStr(r['status']) == 'solved' ? '+${r['pts']}分 (${r['expr'] ?? "24"})' : '未解出'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!g.over && g.seat >= 0)
          FilledButton.icon(
            onPressed: () => g.act({'type': 'next'}),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('立即进入下一题'),
          ),
      ]),
    );
  }
}
