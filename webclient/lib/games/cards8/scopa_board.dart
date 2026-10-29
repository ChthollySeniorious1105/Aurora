import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class ScopaBoard extends StatefulWidget {
  final GameContext g;
  const ScopaBoard(this.g, {super.key});

  @override
  State<ScopaBoard> createState() => _ScopaBoardState();
}

class _ScopaBoardState extends State<ScopaBoard> {
  String? _selectedCard;
  final List<String> _selectedTable = [];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final seats = g.seatsFromMe();
    final me = seats.first;
    final opponents = seats.skip(1).toList();

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 11;
    final scores = (v['scores'] as List?)?.cast<num>() ?? const [];
    final capturedCounts =
        (v['capturedCounts'] as List?)?.cast<num>() ?? const [];
    final coinCounts = (v['coinCounts'] as List?)?.cast<num>() ?? const [];
    final hasSettebello =
        (v['hasSettebello'] as List?)?.cast<bool>() ?? const [];
    final scopas = (v['scopas'] as List?)?.cast<num>() ?? const [];
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final table = (v['table'] as List?)?.cast<String>() ?? const <String>[];
    final hand = (v['hand'] as List?)?.cast<String>() ?? const <String>[];
    final rawLegal = v['legalCaptures'] as Map?;
    final lastMove = v['lastMove'] as Map?;
    final lastHandSummary = v['lastHandSummary'] as Map?;
    final myTurn = !g.over && g.seat == turn;

    if (_selectedCard != null && !hand.contains(_selectedCard)) {
      _selectedCard = null;
      _selectedTable.clear();
    }

    List<List<String>> legalFor(String c) {
      final list = rawLegal?[c];
      if (list is! List) return const [];
      return [
        for (final sub in list)
          if (sub is List) [for (final x in sub) '$x'],
      ];
    }

    final currentLegals =
        _selectedCard != null ? legalFor(_selectedCard!) : const <List<String>>[];

    String subFor(int s) {
      final sc = s < scores.length ? scores[s] : 0;
      final cap = s < capturedCounts.length ? capturedCounts[s] : 0;
      final coins = s < coinCounts.length ? coinCounts[s] : 0;
      final sp = s < scopas.length ? scopas[s] : 0;
      final sb = (s < hasSettebello.length && hasSettebello[s]) ? ' · ♦7' : '';
      return '$sc/$targetScore分 · 吃$cap张(♦$coins) · 清台$sp$sb';
    }

    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (myTurn) {
      if (_selectedCard == null) {
        statusText = '轮到你：点击手牌出牌或吃牌';
      } else if (currentLegals.isEmpty) {
        statusText = '所选手牌无可吃桌面牌，点击确认留在桌面';
      } else {
        statusText = '请选择要吃掉的桌面牌组合';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 出牌…';
    }

    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxHeight < 460 || c.maxWidth < 460;
      final cardW = compact ? 40.0 : 50.0;

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(
          children: [
            Column(
              children: [
                // Opponents row + status
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final s in opponents)
                      g.tag(
                        s,
                        active: !g.over && turn == s,
                        sub: subFor(s),
                        size: compact ? 26 : 32,
                      ),
                    StatusBar(statusText, highlight: myTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),

                // Center Table Area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  '牌库剩余: $deckCount 张',
                                  style: TextStyle(fontSize: compact ? 11 : 12),
                                ),
                              ),
                              if (lastMove != null)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(
                                    _formatLastMove(g, lastMove),
                                    style:
                                        TextStyle(fontSize: compact ? 11 : 12),
                                  ),
                                ),
                              if (lastHandSummary != null)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: cs.secondaryContainer,
                                  label: Text(
                                    '上局得分: ${lastHandSummary['gained']}',
                                    style: TextStyle(
                                      fontSize: compact ? 11 : 12,
                                      color: cs.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: compact ? 6 : 10),

                          // Table cards container
                          Container(
                            constraints: const BoxConstraints(minWidth: 220),
                            padding: EdgeInsets.all(compact ? 8 : 14),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: table.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text(
                                      '桌面已空 (Scopa!)',
                                      style: TextStyle(
                                        fontSize: compact ? 12 : 14,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    ),
                                  )
                                : Wrap(
                                    spacing: compact ? 6 : 10,
                                    runSpacing: compact ? 6 : 10,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      for (final tc in table)
                                        PlayingCard(
                                          tc,
                                          width: cardW,
                                          selected: _selectedTable.contains(tc) ||
                                              (currentLegals.length == 1 &&
                                                  currentLegals.first
                                                      .contains(tc)),
                                          onTap: myTurn &&
                                                  _selectedCard != null &&
                                                  currentLegals.isNotEmpty
                                              ? () {
                                                  setState(() {
                                                    if (_selectedTable
                                                        .contains(tc)) {
                                                      _selectedTable.remove(tc);
                                                    } else {
                                                      _selectedTable.add(tc);
                                                    }
                                                  });
                                                }
                                              : null,
                                        ),
                                    ],
                                  ),
                          ),

                          // Capture action choices when a hand card is selected
                          if (myTurn && _selectedCard != null) ...[
                            SizedBox(height: compact ? 6 : 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: [
                                if (currentLegals.isEmpty)
                                  FilledButton.icon(
                                    onPressed: () {
                                      final c = _selectedCard!;
                                      setState(() {
                                        _selectedCard = null;
                                        _selectedTable.clear();
                                      });
                                      g.act({
                                        'type': 'play',
                                        'card': c,
                                        'capture': <String>[],
                                      });
                                    },
                                    icon: const Icon(Icons.south, size: 16),
                                    label: Text('打出 $_selectedCard 留在桌面'),
                                  )
                                else ...[
                                  for (final opt in currentLegals)
                                    FilledButton.tonal(
                                      onPressed: () {
                                        final c = _selectedCard!;
                                        setState(() {
                                          _selectedCard = null;
                                          _selectedTable.clear();
                                        });
                                        g.act({
                                          'type': 'play',
                                          'card': c,
                                          'capture': opt,
                                        });
                                      },
                                      child: Text(
                                        '用 $_selectedCard 吃 [${opt.join(' + ')}]',
                                        style: TextStyle(
                                          fontSize: compact ? 11 : 12,
                                        ),
                                      ),
                                    ),
                                  if (_selectedTable.isNotEmpty)
                                    FilledButton(
                                      onPressed: () {
                                        final c = _selectedCard!;
                                        final cap =
                                            List<String>.of(_selectedTable);
                                        setState(() {
                                          _selectedCard = null;
                                          _selectedTable.clear();
                                        });
                                        g.act({
                                          'type': 'play',
                                          'card': c,
                                          'capture': cap,
                                        });
                                      },
                                      child: Text(
                                        '确认吃所选 (${_selectedTable.join('+')})',
                                        style: TextStyle(
                                          fontSize: compact ? 11 : 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom area: my tag + hand
                g.tag(
                  me,
                  active: !g.over && turn == me,
                  sub: subFor(me),
                  size: compact ? 26 : 32,
                ),
                SizedBox(height: compact ? 4 : 6),
                if (hand.isNotEmpty)
                  SizedBox(
                    height: cardW * 1.45,
                    child: Center(
                      child: OverlapRow(
                        itemWidth: cardW,
                        children: [
                          for (final c in hand)
                            PlayingCard(
                              c,
                              width: cardW,
                              selected: _selectedCard == c,
                              onTap: myTurn
                                  ? () {
                                      final legals = legalFor(c);
                                      if (_selectedCard == c &&
                                          legals.length <= 1) {
                                        // Double tap quick play when unambiguous
                                        final cap = legals.isEmpty
                                            ? <String>[]
                                            : legals.first;
                                        setState(() {
                                          _selectedCard = null;
                                          _selectedTable.clear();
                                        });
                                        g.act({
                                          'type': 'play',
                                          'card': c,
                                          'capture': cap,
                                        });
                                      } else {
                                        setState(() {
                                          _selectedCard = c;
                                          _selectedTable.clear();
                                        });
                                      }
                                    }
                                  : null,
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
                child: ResultBanner(
                  _resultTitle(g, v),
                  child: Text(
                    '总分：${[
                      for (var s = 0; s < g.players; s++)
                        '${g.name(s)} ${s < scores.length ? scores[s] : 0}分',
                    ].join(' · ')}',
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  String _formatLastMove(GameContext g, Map m) {
    final s = (m['seat'] as num?)?.toInt() ?? 0;
    final card = '${m['card'] ?? ''}';
    final cap = (m['captured'] as List?)?.cast<String>() ?? const [];
    final scopa = m['scopa'] == true;
    if (cap.isEmpty) return '${g.name(s)} 打出 $card';
    return '${g.name(s)} 用 $card 吃 [${cap.join('+')}]${scopa ? " (Scopa!)" : ""}';
  }

  String _resultTitle(GameContext g, Map<String, dynamic> v) {
    final res = v['result'] as Map?;
    final winners = (res?['winners'] as List?)?.cast<num>() ?? const [];
    if (winners.isNotEmpty) {
      return '${winners.map((w) => g.name(w.toInt())).join('、')} 获胜！';
    }
    return '比赛结束';
  }
}
