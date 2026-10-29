import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class CassinoBoard extends StatefulWidget {
  final GameContext g;
  const CassinoBoard(this.g, {super.key});

  @override
  State<CassinoBoard> createState() => _CassinoBoardState();
}

class _CassinoBoardState extends State<CassinoBoard> {
  String? _selectedHandCard;
  final Set<String> _selectedTableCards = {};
  final Set<int> _selectedBuildIndices = {};

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final tableCards = (v['tableCards'] as List?)?.cast<String>() ?? const [];
    final builds = (v['builds'] as List?)?.cast<Map>() ?? const [];
    final hand = (v['hand'] as List?)?.cast<String>() ?? const [];
    final capturedCounts =
        (v['capturedCounts'] as List?)?.cast<num>() ?? const [];
    final spadeCounts = (v['spadeCounts'] as List?)?.cast<num>() ?? const [];
    final sweeps = (v['sweeps'] as List?)?.cast<num>() ?? const [];
    final scores = (v['scores'] as List?)?.cast<num>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    if (_selectedHandCard != null && !hand.contains(_selectedHandCard)) {
      _selectedHandCard = null;
    }
    _selectedTableCards.removeWhere((c) => !tableCards.contains(c));
    _selectedBuildIndices.removeWhere((i) => i < 0 || i >= builds.length);

    final isMyTurn = !g.over && g.seat >= 0 && g.seat == turn;
    final activeHandCard =
        _selectedHandCard ?? (hand.isNotEmpty ? hand.first : null);
    final seats = g.seatsFromMe();
    final opponents = seats.length > 1 ? seats.sublist(1) : const <int>[];

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxHeight < 460 || c.maxWidth < 460;
      final cardW = compact ? 36.0 : 48.0;

      final statusText = g.over
          ? '卡西诺抓牌结束'
          : '第 $round/$totalRounds 局 · 牌库剩余 $deckCount 张 · 轮到 ${g.name(turn)}';

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(children: [
          Column(children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBar(statusText, highlight: isMyTurn),
                if (lastMove != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '上步: ${g.name((lastMove['seat'] as num?)?.toInt() ?? 0)} '
                      '${_modeLabel('${lastMove['mode']}')} ${lastMove['card'] ?? ''}',
                      style: TextStyle(fontSize: compact ? 11 : 12),
                    ),
                  ),
              ],
            ),
            SizedBox(height: compact ? 4 : 8),

            // Opponents row
            if (opponents.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in opponents)
                    _buildPlayerTag(
                      g,
                      s,
                      turn,
                      capturedCounts,
                      spadeCounts,
                      sweeps,
                      scores,
                      compact,
                    ),
                ],
              ),
            SizedBox(height: compact ? 4 : 8),

            // Center table area: Builds + Loose table cards
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(compact ? 8 : 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (builds.isEmpty && tableCards.isEmpty)
                          Text(
                            '桌面已清空（Sweep 清台）！',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: compact ? 12 : 14,
                            ),
                          ),
                        if (builds.isNotEmpty) ...[
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (var i = 0; i < builds.length; i++)
                                _buildPileWidget(
                                  g,
                                  cs,
                                  i,
                                  builds[i],
                                  cardW,
                                  compact,
                                  isMyTurn,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (tableCards.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final tc in tableCards)
                                PlayingCard(
                                  tc,
                                  width: cardW,
                                  selected: _selectedTableCards.contains(tc),
                                  onTap: isMyTurn
                                      ? () => setState(() {
                                            if (!_selectedTableCards.remove(tc)) {
                                              _selectedTableCards.add(tc);
                                            }
                                          })
                                      : null,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Action bar when it's my turn
            if (isMyTurn && activeHandCard != null) ...[
              SizedBox(height: compact ? 4 : 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      g.act({
                        'type': 'play',
                        'mode': 'capture',
                        'card': activeHandCard,
                        if (_selectedTableCards.isNotEmpty)
                          'cards': _selectedTableCards.toList(),
                        if (_selectedBuildIndices.isNotEmpty)
                          'builds': _selectedBuildIndices.toList(),
                      });
                      setState(() {
                        _selectedTableCards.clear();
                        _selectedBuildIndices.clear();
                      });
                    },
                    icon: const Icon(Icons.catching_pokemon, size: 15),
                    label: Text('抓牌 ($activeHandCard)'),
                  ),
                  FilledButton.tonal(
                    onPressed: _selectedTableCards.isEmpty
                        ? null
                        : () {
                            g.act({
                              'type': 'play',
                              'mode': 'build',
                              'card': activeHandCard,
                              'cards': _selectedTableCards.toList(),
                            });
                            setState(() {
                              _selectedTableCards.clear();
                              _selectedBuildIndices.clear();
                            });
                          },
                    child: const Text('建堆 (Build)'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      g.act({
                        'type': 'play',
                        'mode': 'trail',
                        'card': activeHandCard,
                      });
                      setState(() {
                        _selectedTableCards.clear();
                        _selectedBuildIndices.clear();
                      });
                    },
                    child: const Text('放牌 (Trail)'),
                  ),
                ],
              ),
            ],

            if (seats.isNotEmpty) ...[
              SizedBox(height: compact ? 4 : 6),
              _buildPlayerTag(
                g,
                seats.first,
                turn,
                capturedCounts,
                spadeCounts,
                sweeps,
                scores,
                compact,
              ),
            ],
            if (hand.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: compact ? 4 : 6),
                child: OverlapRow(
                  itemWidth: cardW,
                  children: [
                    for (final c in hand)
                      PlayingCard(
                        c,
                        width: cardW,
                        selected: c == activeHandCard,
                        onTap: isMyTurn
                            ? () => setState(() => _selectedHandCard = c)
                            : null,
                      ),
                  ],
                ),
              ),
          ]),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(_buildFinalResultText(g, scores)),
            ),
        ]),
      );
    });
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'capture':
        return '抓牌';
      case 'build':
        return '建堆';
      case 'trail':
        return '放牌';
      default:
        return mode;
    }
  }

  Widget _buildPileWidget(
    GameContext g,
    ColorScheme cs,
    int index,
    Map build,
    double cardW,
    bool compact,
    bool isMyTurn,
  ) {
    final val = (build['value'] as num?)?.toInt() ?? 0;
    final owner = (build['owner'] as num?)?.toInt() ?? 0;
    final cards = (build['cards'] as List?)?.cast<String>() ?? const [];
    final selected = _selectedBuildIndices.contains(index);

    return GestureDetector(
      onTap: isMyTurn
          ? () => setState(() {
                if (!_selectedBuildIndices.remove(index)) {
                  _selectedBuildIndices.add(index);
                }
              })
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.amber : cs.primary,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '建造堆 [$val点] · ${g.name(owner)}',
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                for (final c in cards) PlayingCard(c, width: cardW * 0.8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerTag(
    GameContext g,
    int s,
    int turn,
    List<num> capturedCounts,
    List<num> spadeCounts,
    List<num> sweeps,
    List<num> scores,
    bool compact,
  ) {
    final cc = s < capturedCounts.length ? capturedCounts[s].toInt() : 0;
    final sp = s < spadeCounts.length ? spadeCounts[s].toInt() : 0;
    final sw = s < sweeps.length ? sweeps[s].toInt() : 0;
    final sc = s < scores.length ? scores[s].toInt() : 0;
    return g.tag(
      s,
      active: !g.over && s == turn,
      size: compact ? 28 : 34,
      sub: '牌:$cc · ♠:$sp · 清台:$sw · 分:$sc',
    );
  }

  String _buildFinalResultText(GameContext g, List<num> scores) {
    if (scores.isEmpty) return '对局结束';
    var maxScore = scores.first.toInt();
    for (final s in scores) {
      if (s.toInt() > maxScore) maxScore = s.toInt();
    }
    final winners = [
      for (var i = 0; i < scores.length; i++)
        if (scores[i].toInt() == maxScore) g.name(i),
    ];
    return '${winners.join(" & ")} 获胜！（$maxScore 分）';
  }
}
