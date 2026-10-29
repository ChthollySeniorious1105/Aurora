import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class FogChessBoard extends StatefulWidget {
  final GameContext g;
  const FogChessBoard(this.g, {super.key});

  @override
  State<FogChessBoard> createState() => _FogChessBoardState();
}

class _FogChessBoardState extends State<FogChessBoard> {
  (int, int)? _selected;
  String _promo = 'Q';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static String _pieceIcon(String code) => switch (code) {
        'wK' => '♔',
        'wQ' => '♕',
        'wR' => '♖',
        'wB' => '♗',
        'wN' => '♘',
        'wP' => '♙',
        'bK' => '♚',
        'bQ' => '♛',
        'bR' => '♜',
        'bB' => '♝',
        'bN' => '♞',
        'bP' => '♟',
        _ => '',
      };

  static String _pieceLabel(String code) {
    if (code.length < 2) return '';
    return switch (code.substring(1)) {
      'K' => '王',
      'Q' => '后',
      'R' => '车',
      'B' => '象',
      'N' => '马',
      'P' => '兵',
      _ => '',
    };
  }

  void _onSquareTap(int r, int c) {
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;
    if (over || g.seat != turn) return;

    final board = (v['board'] as List?) ?? const [];
    if (r < 0 || r >= 8 || c < 0 || c >= 8) return;
    final cell = (board[r] as List)[c] as String;
    final myPrefix = g.seat == 0 ? 'w' : 'b';

    final legal = ((v['legalMoves'] as List?) ?? const []).cast<Map>();

    if (_selected != null) {
      final (sr, sc) = _selected!;
      if (sr == r && sc == c) {
        setState(() => _selected = null);
        return;
      }
      final match = legal.where((m) {
        final from = (m['from'] as List).cast<int>();
        final to = (m['to'] as List).cast<int>();
        return from[0] == sr && from[1] == sc && to[0] == r && to[1] == c;
      }).toList();

      if (match.isNotEmpty) {
        setState(() => _selected = null);
        g.act({
          'type': 'move',
          'from': [sr, sc],
          'to': [r, c],
          'promo': _promo,
        });
        return;
      }
    }

    if (cell.startsWith(myPrefix)) {
      setState(() => _selected = (r, c));
    } else {
      setState(() => _selected = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;
    final myTurn = !over && g.seat == turn;
    final seats = g.seatsFromMe();
    final me = seats.first;
    final opp = seats.length > 1 ? seats[1] : 1 - me;
    final visCount = (v['visibleCount'] as int?) ?? 0;

    final statusText = over
        ? ((v['winReason'] as String?) ?? '对局结束')
        : (myTurn ? '你的回合：在迷雾中调兵遣将，擒获敌王' : '等待 ${g.name(turn)} 在迷雾中行动…');

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, c) {
        final isWide = c.maxWidth > c.maxHeight * 1.25;
        final boardWidget = _buildChessGrid(cs);
        final sidePanel = _buildSidePanel(cs, statusText, myTurn, me, opp, visCount);

        return Stack(
          children: [
            if (isWide)
              Row(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.all(8), child: boardWidget)),
                  SizedBox(
                    width: math.min(280, c.maxWidth * 0.38),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                      child: sidePanel,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: _buildCompactHeader(cs, statusText, myTurn, opp, visCount),
                  ),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: boardWidget)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                    child: _buildCompactFooter(cs, myTurn, me),
                  ),
                ],
              ),
            if (over)
              Center(
                child: ResultBanner((v['winReason'] as String?) ?? '对局结束'),
              ),
          ],
        );
      }),
    );
  }

  String _seatSub(int seat) {
    final side = seat == 0 ? '执白' : '执黑';
    final capList = (v['capturedBy'] as List?) ?? const [[], []];
    if (seat < 0 || seat >= capList.length) return side;
    final caps = (capList[seat] as List).cast<String>();
    if (caps.isEmpty) return '$side · 未斩获';
    final icons = caps.take(6).map(_pieceLabel).join('');
    return '$side · 斩获:$icons${caps.length > 6 ? "+${caps.length - 6}" : ""}';
  }

  Widget _buildCompactHeader(ColorScheme cs, String statusText, bool myTurn, int opp, int visCount) {
    final turn = (v['turn'] as int?) ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: myTurn)),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(child: g.tag(opp, active: turn == opp, sub: _seatSub(opp), size: 32)),
            const SizedBox(width: 6),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _buildFogBadge(cs, visCount))),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactFooter(ColorScheme cs, bool myTurn, int me) {
    final turn = (v['turn'] as int?) ?? 0;
    return Row(
      children: [
        Flexible(child: g.tag(me, active: turn == me, sub: _seatSub(me), size: 32)),
        const SizedBox(width: 6),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _buildPromoSelector(cs))),
      ],
    );
  }

  Widget _buildSidePanel(
    ColorScheme cs,
    String statusText,
    bool myTurn,
    int me,
    int opp,
    int visCount,
  ) {
    final turn = (v['turn'] as int?) ?? 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: LayoutBuilder(builder: (context, pc) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: pc.maxHeight > 20 ? pc.maxHeight - 20 : 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatusBar(statusText, highlight: myTurn),
                    const SizedBox(height: 8),
                    g.tag(opp, active: turn == opp, sub: _seatSub(opp), size: 32),
                    const SizedBox(height: 8),
                    Center(child: FittedBox(fit: BoxFit.scaleDown, child: _buildFogBadge(cs, visCount))),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _buildPromoSelector(cs))),
                ),
                g.tag(me, active: turn == me, sub: _seatSub(me), size: 32),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFogBadge(ColorScheme cs, int visCount) {
    final steps = (v['stepCount'] as int?) ?? 0;
    final maxT = (v['maxTurns'] as int?) ?? 160;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility, size: 14, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            '视野 $visCount/64 格 · 步数 $steps/$maxT',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSecondaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoSelector(ColorScheme cs) {
    const promos = [('Q', '升后♕'), ('R', '升车♖'), ('B', '升象♗'), ('N', '升马♘')];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (code, label) in promos)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 11)),
              selected: _promo == code,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _promo = code),
            ),
          ),
      ],
    );
  }

  Widget _buildChessGrid(ColorScheme cs) {
    final board = (v['board'] as List?) ?? const [];
    if (board.length < 8) return const SizedBox();

    final legal = ((v['legalMoves'] as List?) ?? const []).cast<Map>();
    final targetSquares = <(int, int)>{};
    if (_selected != null) {
      for (final m in legal) {
        final from = (m['from'] as List).cast<int>();
        final to = (m['to'] as List).cast<int>();
        if (from[0] == _selected!.$1 && from[1] == _selected!.$2) {
          targetSquares.add((to[0], to[1]));
        }
      }
    }

    final lastMove = v['lastMove'] as Map?;
    final lastFrom = (lastMove?['from'] as List?)?.cast<int>();
    final lastTo = (lastMove?['to'] as List?)?.cast<int>();
    final flip = g.seat == 1;

    return LayoutBuilder(builder: (context, bc) {
      final side = math.min(bc.maxWidth, bc.maxHeight);
      if (side <= 20) return const SizedBox();
      final cellSize = side / 8.0;

      return Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outline.withValues(alpha: 0.45), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var dr = 0; dr < 8; dr++)
                Expanded(
                  child: Row(
                    children: [
                      for (var dc = 0; dc < 8; dc++)
                        Expanded(
                          child: Builder(builder: (context) {
                            final r = flip ? (7 - dr) : dr;
                            final c = flip ? (7 - dc) : dc;
                            final cell = (board[r] as List)[c] as String;
                            final isFog = cell == '?';
                            final isLight = (r + c).isEven;
                            final isSel = _selected == (r, c);
                            final isTarget = targetSquares.contains((r, c));
                            final isLast = (lastFrom != null && lastFrom[0] == r && lastFrom[1] == c) ||
                                (lastTo != null && lastTo[0] == r && lastTo[1] == c);

                            Color bg;
                            if (isFog) {
                              bg = isLight ? const Color(0xFF283040) : const Color(0xFF1D2432);
                            } else {
                              bg = isLight ? const Color(0xFFEBD9B8) : const Color(0xFFB38862);
                            }
                            if (isSel) {
                              bg = Color.lerp(bg, Colors.amber, 0.55)!;
                            } else if (isLast) {
                              bg = Color.lerp(bg, Colors.lightGreenAccent, 0.35)!;
                            }

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onSquareTap(r, c),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: bg,
                                  border: Border.all(
                                    color: isTarget
                                        ? Colors.greenAccent
                                        : Colors.black.withValues(alpha: 0.08),
                                    width: isTarget ? 2.0 : 0.4,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isFog)
                                      Icon(
                                        Icons.cloud,
                                        size: cellSize * 0.42,
                                        color: Colors.blueGrey.withValues(alpha: 0.28),
                                      ),
                                    if (!isFog && cell.isNotEmpty)
                                      _buildChessPiece(cell, cellSize),
                                    if (isTarget)
                                      Container(
                                        width: cell.isNotEmpty && !isFog ? cellSize * 0.82 : cellSize * 0.32,
                                        height: cell.isNotEmpty && !isFog ? cellSize * 0.82 : cellSize * 0.32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: cell.isNotEmpty && !isFog
                                              ? Colors.transparent
                                              : const Color(0xAA1DE9B6),
                                          border: cell.isNotEmpty && !isFog
                                              ? Border.all(color: Colors.redAccent, width: 2.5)
                                              : null,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildChessPiece(String code, double cellSize) {
    final isWhite = code.startsWith('w');
    final bg = isWhite ? const Color(0xFFFFFBF0) : const Color(0xFF21252D);
    final fg = isWhite ? const Color(0xFF2B2218) : const Color(0xFFF3E5AB);
    final borderCol = isWhite ? const Color(0xFF8C6D46) : const Color(0xFFD4AF37);
    final pieceSize = cellSize * 0.80;

    return Container(
      width: pieceSize,
      height: pieceSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: borderCol, width: 1.8),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1.5))],
      ),
      padding: const EdgeInsets.all(2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${_pieceIcon(code)}${_pieceLabel(code)}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: fg,
            fontSize: 16,
            fontFamilyFallback: kFontFallback,
          ),
        ),
      ),
    );
  }
}
