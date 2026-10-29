import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class SlitherBoard extends StatefulWidget {
  final GameContext g;
  const SlitherBoard(this.g, {super.key});

  @override
  State<SlitherBoard> createState() => _SlitherBoardState();
}

class _SlitherBoardState extends State<SlitherBoard> {
  (int, int)? _slideFrom;
  (int, int)? _slideTo;

  static bool _checkNoDiagonalTouch(List<List<int>> grid, int size, int color) {
    for (var r = 0; r < size - 1; r++) {
      final row0 = grid[r];
      final row1 = grid[r + 1];
      for (var c = 0; c < size; c++) {
        if (row0[c] != color) continue;
        if (c + 1 < size && row1[c + 1] == color) {
          if (row0[c + 1] != color && row1[c] != color) return false;
        }
        if (c - 1 >= 0 && row1[c - 1] == color) {
          if (row0[c - 1] != color && row1[c] != color) return false;
        }
      }
    }
    return true;
  }

  static bool _isTurnLegalOn(
    List<List<int>> board,
    int size,
    int color,
    int fromR,
    int fromC,
    int toR,
    int toC,
    int placeR,
    int placeC,
  ) {
    if (placeR < 0 || placeR >= size || placeC < 0 || placeC >= size) return false;
    final work = [for (final row in board) List<int>.of(row)];
    if (fromR != -1) {
      if (fromR < 0 || fromR >= size || fromC < 0 || fromC >= size) return false;
      if (toR < 0 || toR >= size || toC < 0 || toC >= size) return false;
      if (work[fromR][fromC] != color || work[toR][toC] != 0) return false;
      if (max((toR - fromR).abs(), (toC - fromC).abs()) != 1) return false;
      work[fromR][fromC] = 0;
      work[toR][toC] = color;
    }
    if (work[placeR][placeC] != 0) return false;
    work[placeR][placeC] = color;
    return _checkNoDiagonalTouch(work, size, color);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final boardSize = (v['boardSize'] as num?)?.toInt() ?? 7;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawBoard = (v['board'] as List?) ?? const [];
    final stones = (v['stones'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final winChainRaw = (v['winChain'] as List?)?.cast<Map>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final board = List.generate(boardSize, (r) {
      if (r < rawBoard.length && rawBoard[r] is List) {
        final row = rawBoard[r] as List;
        return List.generate(boardSize, (c) => c < row.length ? (row[c] as num).toInt() : 0);
      }
      return List<int>.filled(boardSize, 0);
    });

    final isMyTurn = !over && g.seat == turn;
    final myColor = turn + 1;

    if (!isMyTurn) {
      _slideFrom = null;
      _slideTo = null;
    } else if (_slideFrom != null) {
      final (fr, fc) = _slideFrom!;
      if (fr < 0 || fr >= boardSize || fc < 0 || fc >= boardSize || board[fr][fc] != myColor) {
        _slideFrom = null;
        _slideTo = null;
      } else if (_slideTo != null) {
        final (tr, tc) = _slideTo!;
        if (tr < 0 || tr >= boardSize || tc < 0 || tc >= boardSize || board[tr][tc] != 0) {
          _slideTo = null;
        }
      }
    }

    final slideDestCandidates = <(int, int)>{};
    final legalPlaceCells = <(int, int)>{};

    if (isMyTurn) {
      if (_slideFrom == null) {
        for (var r = 0; r < boardSize; r++) {
          for (var c = 0; c < boardSize; c++) {
            if (_isTurnLegalOn(board, boardSize, myColor, -1, -1, -1, -1, r, c)) {
              legalPlaceCells.add((r, c));
            }
          }
        }
      } else if (_slideTo == null) {
        final (fr, fc) = _slideFrom!;
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final tr = fr + dr;
            final tc = fc + dc;
            if (tr < 0 || tr >= boardSize || tc < 0 || tc >= boardSize) continue;
            if (board[tr][tc] != 0) continue;
            var hasAnyPlace = false;
            for (var pr = 0; pr < boardSize && !hasAnyPlace; pr++) {
              for (var pc = 0; pc < boardSize && !hasAnyPlace; pc++) {
                if (pr == fr && pc == fc) continue;
                if (_isTurnLegalOn(board, boardSize, myColor, fr, fc, tr, tc, pr, pc)) {
                  hasAnyPlace = true;
                }
              }
            }
            if (hasAnyPlace) {
              slideDestCandidates.add((tr, tc));
            }
          }
        }
      } else {
        final (fr, fc) = _slideFrom!;
        final (tr, tc) = _slideTo!;
        for (var pr = 0; pr < boardSize; pr++) {
          for (var pc = 0; pc < boardSize; pc++) {
            if (_isTurnLegalOn(board, boardSize, myColor, fr, fc, tr, tc, pr, pc)) {
              legalPlaceCells.add((pr, pc));
            }
          }
        }
      }
    }

    final winCells = <(int, int)>{
      for (final m in winChainRaw)
        ((m['r'] as num?)?.toInt() ?? -1, (m['c'] as num?)?.toInt() ?? -1),
    };

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_slideFrom == null) {
        statusText = '轮到你：直接点击绿点空格落子，或先点击 1 枚己方棋子滑移 1 格后再落子';
      } else if (_slideTo == null) {
        statusText = '已选滑移棋子 (${_slideFrom!.$1 + 1},${_slideFrom!.$2 + 1})：请点击相邻青色高亮格滑移（再点原棋子取消）';
      } else {
        statusText = '滑移预览就绪：请点击绿色高亮空格放置本回合的新棋子（点击原棋子取消滑移）';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 滑移并落子…';
    }

    Widget buildPlayerPanel(int s) {
      final isWhite = s == 0;
      final goalDesc = isWhite ? '白方 (↕ 上下连边)' : '黑方 (↔ 左右连边)';
      final st = s < stones.length ? stones[s] : 0;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$goalDesc · 棋子 $st',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF263238),
            border: Border.all(
              color: isWhite ? const Color(0xFFFFB300) : const Color(0xFF00E5FF),
              width: 2.0,
            ),
          ),
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();
          final cellSize = side / (boardSize + 1.1);
          final boardPx = cellSize * boardSize;
          final origin = Offset(
            (constraints.maxWidth - boardPx) / 2,
            (constraints.maxHeight - boardPx) / 2,
          );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn
                ? null
                : (details) {
                    final local = details.localPosition - origin;
                    final c = (local.dx / cellSize).floor();
                    final r = (local.dy / cellSize).floor();
                    if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) {
                      setState(() {
                        _slideFrom = null;
                        _slideTo = null;
                      });
                      return;
                    }

                    final hit = (r, c);

                    if (_slideFrom == null) {
                      if (board[r][c] == myColor) {
                        setState(() {
                          _slideFrom = hit;
                          _slideTo = null;
                        });
                        return;
                      }
                      if (legalPlaceCells.contains(hit)) {
                        g.act({
                          'type': 'turn',
                          'fromR': -1,
                          'fromC': -1,
                          'toR': -1,
                          'toC': -1,
                          'placeR': r,
                          'placeC': c,
                        });
                      }
                      return;
                    }

                    if (_slideTo == null) {
                      if (hit == _slideFrom) {
                        setState(() => _slideFrom = null);
                        return;
                      }
                      if (slideDestCandidates.contains(hit)) {
                        setState(() => _slideTo = hit);
                        return;
                      }
                      if (board[r][c] == myColor) {
                        setState(() => _slideFrom = hit);
                        return;
                      }
                      setState(() => _slideFrom = null);
                      return;
                    }

                    // _slideFrom != null && _slideTo != null
                    if (hit == _slideFrom || hit == _slideTo) {
                      setState(() {
                        _slideFrom = null;
                        _slideTo = null;
                      });
                      return;
                    }
                    if (legalPlaceCells.contains(hit)) {
                      final (fr, fc) = _slideFrom!;
                      final (tr, tc) = _slideTo!;
                      setState(() {
                        _slideFrom = null;
                        _slideTo = null;
                      });
                      g.act({
                        'type': 'turn',
                        'fromR': fr,
                        'fromC': fc,
                        'toR': tr,
                        'toC': tc,
                        'placeR': r,
                        'placeC': c,
                      });
                      return;
                    }
                    setState(() {
                      _slideFrom = null;
                      _slideTo = null;
                    });
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SlitherPainter(
                board: board,
                boardSize: boardSize,
                myColor: myColor,
                slideFrom: _slideFrom,
                slideTo: _slideTo,
                slideDestCandidates: slideDestCandidates,
                legalPlaceCells: legalPlaceCells,
                winCells: winCells,
                lastMove: lastMove,
                cellSize: cellSize,
                origin: origin,
                cs: cs,
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, outer) {
        final isWide = outer.maxWidth >= 680 && outer.maxWidth > outer.maxHeight * 1.15;

        return Stack(
          children: [
            Container(
              color: g.table,
              padding: const EdgeInsets.all(8),
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: min(240, outer.maxWidth * 0.28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildPlayerPanel(1),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: StatusBar(statusText, highlight: isMyTurn),
                                  ),
                                ),
                              ),
                              buildPlayerPanel(0),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: buildPlayerPanel(0)),
                            const SizedBox(width: 6),
                            Expanded(child: buildPlayerPanel(1)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    ),
            ),
            if (over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SlitherPainter extends CustomPainter {
  final List<List<int>> board;
  final int boardSize;
  final int myColor;
  final (int, int)? slideFrom;
  final (int, int)? slideTo;
  final Set<(int, int)> slideDestCandidates;
  final Set<(int, int)> legalPlaceCells;
  final Set<(int, int)> winCells;
  final Map? lastMove;
  final double cellSize;
  final Offset origin;
  final ColorScheme cs;

  _SlitherPainter({
    required this.board,
    required this.boardSize,
    required this.myColor,
    required this.slideFrom,
    required this.slideTo,
    required this.slideDestCandidates,
    required this.legalPlaceCells,
    required this.winCells,
    required this.lastMove,
    required this.cellSize,
    required this.origin,
    required this.cs,
  });

  Offset _center(int r, int c) => Offset(
        origin.dx + (c + 0.5) * cellSize,
        origin.dy + (r + 0.5) * cellSize,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final boardPx = cellSize * boardSize;
    final pad = cellSize * 0.30;
    final outerRect = Rect.fromLTWH(
      origin.dx - pad,
      origin.dy - pad,
      boardPx + pad * 2,
      boardPx + pad * 2,
    );
    final rrect = RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.28));
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black54, 8, false);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B241E), Color(0xFF1A1612)],
        ).createShader(outerRect),
    );

    // Goal border bars: Top & Bottom for White (Player 0), Left & Right for Black (Player 1)
    final barThickness = cellSize * 0.14;
    final whiteBorderPaint = Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.85);
    final blackBorderPaint = Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.85);

    // Top & Bottom bars
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy - barThickness - 2, boardPx, barThickness),
        const Radius.circular(4),
      ),
      whiteBorderPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy + boardPx + 2, boardPx, barThickness),
        const Radius.circular(4),
      ),
      whiteBorderPaint,
    );

    // Left & Right bars
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx - barThickness - 2, origin.dy, barThickness, boardPx),
        const Radius.circular(4),
      ),
      blackBorderPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + boardPx + 2, origin.dy, barThickness, boardPx),
        const Radius.circular(4),
      ),
      blackBorderPaint,
    );

    final lastPlaceR = (lastMove?['placeR'] as num?)?.toInt();
    final lastPlaceC = (lastMove?['placeC'] as num?)?.toInt();
    final lastToR = (lastMove?['toR'] as num?)?.toInt();
    final lastToC = (lastMove?['toC'] as num?)?.toInt();

    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        );
        final isAlt = (r + c).isOdd;
        Color sqColor = isAlt ? const Color(0xFF3E342B) : const Color(0xFF4B3F34);
        if ((r == lastPlaceR && c == lastPlaceC) || (r == lastToR && c == lastToC)) {
          sqColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), sqColor);
        }
        if (slideFrom == (r, c)) {
          sqColor = Color.alphaBlend(Colors.cyanAccent.withValues(alpha: 0.30), sqColor);
        }
        canvas.drawRect(rect, Paint()..color = sqColor);
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = Colors.white.withValues(alpha: 0.12),
        );
      }
    }

    // Effective board with previewed slide if any
    int cellValue(int r, int c) {
      if (slideFrom != null && slideTo != null) {
        if (slideFrom == (r, c)) return 0;
        if (slideTo == (r, c)) return myColor;
      }
      return board[r][c];
    }

    // Draw orthogonal chain links between same-color stones
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final v = cellValue(r, c);
        if (v == 0) continue;
        final linkColor = v == 1
            ? const Color(0xFFFFE082).withValues(alpha: 0.65)
            : const Color(0xFF4DD0E1).withValues(alpha: 0.65);
        final p1 = _center(r, c);
        if (r + 1 < boardSize && cellValue(r + 1, c) == v) {
          canvas.drawLine(
            p1,
            _center(r + 1, c),
            Paint()
              ..color = linkColor
              ..strokeWidth = cellSize * 0.16
              ..strokeCap = StrokeCap.round,
          );
        }
        if (c + 1 < boardSize && cellValue(r, c + 1) == v) {
          canvas.drawLine(
            p1,
            _center(r, c + 1),
            Paint()
              ..color = linkColor
              ..strokeWidth = cellSize * 0.16
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // Draw stones and placement/slide hints
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        final p = _center(r, c);
        final v = cellValue(r, c);
        final isGhostSlide = slideTo == (r, c);
        final isWinCell = winCells.contains((r, c));

        if (v != 0) {
          final isWhite = v == 1;
          final radius = cellSize * 0.36;

          if (isWinCell || slideFrom == (r, c) || isGhostSlide) {
            canvas.drawCircle(
              p,
              radius + 3.5,
              Paint()
                ..color = isWinCell
                    ? Colors.amberAccent.withValues(alpha: 0.9)
                    : Colors.cyanAccent.withValues(alpha: 0.8),
            );
          }

          canvas.drawCircle(
            p + const Offset(1.2, 2.0),
            radius,
            Paint()..color = Colors.black54,
          );
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: isWhite
                    ? [const Color(0xFFFFFFFF), const Color(0xFFCFD8DC)]
                    : [const Color(0xFF37474F), const Color(0xFF10181D)],
              ).createShader(Rect.fromCircle(center: p, radius: radius)),
          );
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8
              ..color = isWhite ? const Color(0xFFFFB300) : const Color(0xFF00E5FF),
          );
        } else {
          if (slideDestCandidates.contains((r, c))) {
            canvas.drawCircle(
              p,
              cellSize * 0.24,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.4
                ..color = Colors.cyanAccent,
            );
          }
          if (legalPlaceCells.contains((r, c))) {
            canvas.drawCircle(
              p,
              cellSize * 0.14,
              Paint()..color = Colors.greenAccent.withValues(alpha: 0.78),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SlitherPainter oldDelegate) => true;
}
