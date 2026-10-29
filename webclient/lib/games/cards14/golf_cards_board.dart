import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class GolfCardsBoard extends StatefulWidget {
  final GameContext g;
  const GolfCardsBoard(this.g, {super.key});

  @override
  State<GolfCardsBoard> createState() => _GolfCardsBoardState();
}

class _GolfCardsBoardState extends State<GolfCardsBoard> {
  String _actMode = 'swap'; // 'swap' | 'discard_flip'

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final hole = (v['hole'] as num?)?.toInt() ?? 1;
    final totalHoles = (v['totalHoles'] as num?)?.toInt() ?? 3;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'draw'}';
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;
    final discardTop = v['discardTop'] as String?;
    final drawnCard = v['drawnCard'] as String?;
    final firstOutSeat = (v['firstOutSeat'] as num?)?.toInt() ?? -1;

    final rawGrids = (v['grid'] as List?) ?? const [];
    final grids = <List<String>>[
      for (var s = 0; s < g.players; s++)
        s < rawGrids.length
            ? (rawGrids[s] as List).map((e) => '$e').toList()
            : List.filled(9, '??'),
    ];
    final rawRev = (v['revealed'] as List?) ?? const [];
    final revealed = <List<bool>>[
      for (var s = 0; s < g.players; s++)
        s < rawRev.length
            ? (rawRev[s] as List).map((e) => e == true).toList()
            : List.filled(9, false),
    ];
    final visibleScores = (v['visibleScores'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players, 0);
    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final rawCancelled = (v['cancelledCols'] as List?) ?? const [];
    final cancelledCols = <List<bool>>[
      for (var s = 0; s < g.players; s++)
        s < rawCancelled.length
            ? (rawCancelled[s] as List).map((e) => e == true).toList()
            : [false, false, false],
    ];

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '全部球洞结束！总分最低者获胜';
    } else if (phase == 'draw') {
      statusText = isMyTurn
          ? '轮到你：点击「摸牌堆」抽牌，或直接点击你的九宫格拿「弃牌顶牌」替换'
          : '等待 ${g.name(turn)} 摸牌或拿取弃牌…';
    } else {
      statusText = isMyTurn
          ? (_actMode == 'swap'
              ? '已抽牌：点击九宫格任意位置进行【替换】'
              : '已抽牌：点击九宫格未翻开的暗牌进行【弃牌翻面】')
          : '等待 ${g.name(turn)} 处理抽到的牌…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 470 || w < 460;
      final myCardW = compact ? 34.0 : 44.0;
      final oppCardW = compact ? 24.0 : 30.0;

      final seats = g.seatsFromMe();
      final mySeat = seats.isNotEmpty ? seats.first : 0;
      final oppSeats = seats.length > 1 ? seats.sublist(1) : const <int>[];

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _pill(cs, '第 $hole/$totalHoles 洞 · K=0 A=1 2=-2 王=-5 同列三消=0'),
                    if (firstOutSeat >= 0)
                      _pill(cs, '${g.name(firstOutSeat)} 已全翻开 · 最后一轮！', highlight: true),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),

                // Main scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Opponents' 3x3 grids
                        if (oppSeats.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final s in oppSeats)
                                _buildPlayerGridCard(
                                  cs: cs,
                                  seat: s,
                                  grid: grids[s],
                                  rev: revealed[s],
                                  cancelled: cancelledCols[s],
                                  visScore: visibleScores[s],
                                  totalScore: scores[s],
                                  active: !g.over && s == turn,
                                  isMe: false,
                                  isMyTurn: false,
                                  phase: phase,
                                  cardW: oppCardW,
                                  compact: compact,
                                ),
                            ],
                          ),
                        SizedBox(height: compact ? 6 : 10),

                        // Center Stock & Discard & My 3x3 Grid
                        Wrap(
                          spacing: 14,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildDeckArea(
                              cs: cs,
                              stockCount: stockCount,
                              discardTop: discardTop,
                              drawnCard: drawnCard,
                              isMyTurn: isMyTurn,
                              phase: phase,
                              cardW: myCardW,
                              compact: compact,
                            ),
                            _buildPlayerGridCard(
                              cs: cs,
                              seat: mySeat,
                              grid: grids[mySeat],
                              rev: revealed[mySeat],
                              cancelled: cancelledCols[mySeat],
                              visScore: visibleScores[mySeat],
                              totalScore: scores[mySeat],
                              active: !g.over && mySeat == turn,
                              isMe: !g.spectator,
                              isMyTurn: isMyTurn && mySeat == g.seat,
                              phase: phase,
                              cardW: myCardW,
                              compact: compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(_buildResultText(scores)),
              ),
          ],
        ),
      );
    });
  }

  Widget _pill(ColorScheme cs, String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? cs.primaryContainer.withValues(alpha: 0.92)
            : cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: highlight ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildDeckArea({
    required ColorScheme cs,
    required int stockCount,
    required String? discardTop,
    required String? drawnCard,
    required bool isMyTurn,
    required String phase,
    required double cardW,
    required bool compact,
  }) {
    final canDrawStock = isMyTurn && phase == 'draw';
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stock pile
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayingCard(
                    '??',
                    width: cardW,
                    faceDown: true,
                    selected: canDrawStock,
                    onTap: canDrawStock ? () => g.act({'type': 'draw_stock'}) : null,
                  ),
                  const SizedBox(height: 4),
                  Text('摸牌堆 ($stockCount)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  if (canDrawStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                        onPressed: () => g.act({'type': 'draw_stock'}),
                        child: const Text('抽牌', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Discard pile
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (discardTop != null)
                    PlayingCard(discardTop, width: cardW)
                  else
                    SizedBox(width: cardW, height: cardW * 1.4),
                  const SizedBox(height: 4),
                  const Text('弃牌顶牌', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              // Drawn card if in 'act' phase
              if (drawnCard != null) ...[
                const SizedBox(width: 14),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayingCard(
                      drawnCard,
                      width: cardW,
                      faceDown: drawnCard == '??',
                      selected: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '手头抽牌',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (isMyTurn && phase == 'act') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('替换九宫格 (Swap)', style: TextStyle(fontSize: 11)),
                  selected: _actMode == 'swap',
                  onSelected: (_) => setState(() => _actMode = 'swap'),
                ),
                ChoiceChip(
                  label: const Text('弃牌并翻暗牌 (Flip)', style: TextStyle(fontSize: 11)),
                  selected: _actMode == 'discard_flip',
                  onSelected: (_) => setState(() => _actMode = 'discard_flip'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerGridCard({
    required ColorScheme cs,
    required int seat,
    required List<String> grid,
    required List<bool> rev,
    required List<bool> cancelled,
    required int visScore,
    required int totalScore,
    required bool active,
    required bool isMe,
    required bool isMyTurn,
    required String phase,
    required double cardW,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isMe ? 0.9 : 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? cs.primary : cs.outline.withValues(alpha: 0.3),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            seat,
            active: active,
            size: compact ? 26 : 32,
            sub: '当前可见 $visScore 杆 · 累计 $totalScore 杆',
          ),
          SizedBox(height: compact ? 4 : 6),
          // Column headers (showing 0pt cancellation badge when cancelled)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var col = 0; col < 3; col++)
                Container(
                  width: cardW + 6,
                  alignment: Alignment.center,
                  child: cancelled[col]
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '三消0分',
                              style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      : Text(
                          '第${col + 1}列',
                          style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // 3x3 Grid
          for (var row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var col = 0; col < 3; col++)
                    Builder(builder: (context) {
                      final slot = row * 3 + col;
                      final isRev = rev[slot];
                      final code = grid[slot];
                      VoidCallback? onTap;
                      if (isMyTurn) {
                        if (phase == 'draw') {
                          onTap = () => g.act({'type': 'take_discard', 'slot': slot});
                        } else if (phase == 'act') {
                          if (_actMode == 'swap') {
                            onTap = () => g.act({'type': 'swap', 'slot': slot});
                          } else if (!isRev) {
                            onTap = () => g.act({'type': 'discard_flip', 'slot': slot});
                          }
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: PlayingCard(
                          code,
                          width: cardW,
                          faceDown: !isRev || code == '??',
                          dim: isMyTurn && phase == 'act' && _actMode == 'discard_flip' && isRev,
                          onTap: onTap,
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _buildResultText(List<int> scores) {
    final parts = [for (var i = 0; i < scores.length; i++) '${g.name(i)}: ${scores[i]}杆'];
    return '比赛结束（杆数越低越优）！${parts.join(" · ")}';
  }
}
