import 'package:aurora_shared/games/cards12/tichu.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class TichuBoard extends StatefulWidget {
  final GameContext g;
  const TichuBoard(this.g, {super.key});

  @override
  State<TichuBoard> createState() => _TichuBoardState();
}

class _TichuBoardState extends State<TichuBoard> {
  final Set<String> _selected = {};
  int _selectedWish = 14; // Default wish rank A(14) when playing MJ

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  List<int> _intList(Object? raw) =>
      raw is List ? [for (final x in raw) (x as num).toInt()] : const [];

  List<String> _strList(Object? raw) =>
      raw is List ? [for (final x in raw) '$x'] : const [];

  List<bool> _boolList(Object? raw) =>
      raw is List ? [for (final x in raw) x == true] : const [];

  static const Map<String, String> _comboTypeNames = {
    'single': '单张',
    'pair': '对子',
    'pair_steps': '连对',
    'triple': '三条',
    'full_house': '葫芦',
    'straight': '顺子',
    'four_bomb': '四条炸弹',
    'sf_bomb': '同花顺炸弹',
    'dog': '犬(传搭档)',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 300;
    final phase = (v['phase'] as String?) ?? 'play';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final lastPlaySeat = (v['lastPlaySeat'] as num?)?.toInt();
    final trickPoints = (v['trickPoints'] as num?)?.toInt() ?? 0;
    final activeWish = (v['activeWish'] as num?)?.toInt();
    final mustFulfillWish = v['mustFulfillWish'] == true;
    final canCallTichu = v['canCallTichu'] == true;

    final handCounts = _intList(v['handCounts']);
    final capturedPoints = _intList(v['capturedPoints']);
    final tichuCalled = _boolList(v['tichuCalled']);
    final finishOrder = _intList(v['finishOrder']);
    final teamScores = _intList(v['teamScores']);
    final myHand = _strList(v['myHand']);

    _selected.removeWhere((c) => !myHand.contains(c));

    TichuCombo? tableCombo;
    final rawCombo = v['currentCombo'];
    if (rawCombo is Map) {
      tableCombo = TichuCombo(
        type: '${rawCombo['type'] ?? 'single'}',
        length: (rawCombo['length'] as num?)?.toInt() ?? 1,
        rank: (rawCombo['rank'] as num?)?.toDouble() ?? 0,
        cards: _strList(rawCombo['cards']),
      );
    }

    final playsRaw = v['currentTrickPlays'] as List? ?? const [];
    final currentTrickPlays = [
      for (final e in playsRaw)
        if (e is Map) e.cast<String, dynamic>(),
    ];

    final summaryRaw = v['lastHandSummary'];
    final summary =
        summaryRaw is Map ? summaryRaw.cast<String, dynamic>() : null;

    final seats = g.seatsFromMe();
    final mySeat = seats.first;
    final oppSeats = seats.sublist(1);
    final isMyTurn = !g.spectator && !g.over && turn == g.seat;

    final lastSingle =
        (tableCombo != null && tableCombo.type == 'single')
            ? tableCombo.rank
            : null;
    final selectedList = myHand.where(_selected.contains).toList();
    final candidateCombo =
        evaluateTichuCombo(selectedList, lastSingleRank: lastSingle);
    final canPlaySelected = isMyTurn &&
        phase == 'play' &&
        candidateCombo != null &&
        canBeatTichuCombo(candidateCombo, tableCombo) &&
        !(selectedList.contains('DOG') && tableCombo != null) &&
        (!mustFulfillWish ||
            selectedList.any((c) => tichuCardRank(c) == activeWish));

    String statusText;
    if (g.over) {
      statusText = '整场对局已结束';
    } else if (phase == 'give_dragon') {
      statusText = isMyTurn
          ? '你用龙（DRG）赢下本墩！请选择将本墩赠送给哪位对手'
          : '等待 ${g.name(turn)} 选择将龙墩赠送给哪位对手…';
    } else if (mustFulfillWish) {
      statusText = '轮到你出牌（必须打出含雀牌许愿点数 ${kTichuRankLabels[activeWish]} 的牌型！）';
    } else {
      statusText = isMyTurn
          ? (tableCombo == null ? '轮到你领出任意牌型' : '轮到你跟牌或过牌')
          : '轮到 ${g.name(turn)} 行动';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 450 || w < 440;
          final cardW = compact ? 36.0 : 46.0;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(compact ? 4 : 8),
                child: Column(
                  children: [
                    // Top status bar
                    Row(
                      children: [
                        Flexible(
                          flex: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '局$round · 蓝${teamScores.isNotEmpty ? teamScores[0] : 0}:'
                              '${teamScores.length > 1 ? teamScores[1] : 0}红',
                              style: TextStyle(
                                fontSize: compact ? 10 : 12,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 3 : 6),

                    // Opponents / Partner row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final s in oppSeats)
                          _buildSeatChip(
                            s: s,
                            mySeat: mySeat,
                            active: !g.over && turn == s,
                            cards: s < handCounts.length ? handCounts[s] : 0,
                            pts: s < capturedPoints.length
                                ? capturedPoints[s]
                                : 0,
                            tichu: s < tichuCalled.length && tichuCalled[s],
                            finishRank: finishOrder.indexOf(s) + 1,
                            compact: compact,
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 3 : 6),

                    // Center table area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 6 : 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: _buildCenterContent(
                              phase: phase,
                              isMyTurn: isMyTurn,
                              mySeat: mySeat,
                              tableCombo: tableCombo,
                              lastPlaySeat: lastPlaySeat,
                              trickPoints: trickPoints,
                              targetScore: targetScore,
                              activeWish: activeWish,
                              mustFulfillWish: mustFulfillWish,
                              canCallTichu: canCallTichu,
                              currentTrickPlays: currentTrickPlays,
                              summary: summary,
                              selectedList: selectedList,
                              candidateCombo: candidateCombo,
                              canPlaySelected: canPlaySelected,
                              cardW: cardW,
                              compact: compact,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 3 : 6),

                    // My player bar
                    _buildSeatChip(
                      s: mySeat,
                      mySeat: mySeat,
                      active: !g.over && turn == mySeat,
                      cards:
                          mySeat < handCounts.length ? handCounts[mySeat] : 0,
                      pts: mySeat < capturedPoints.length
                          ? capturedPoints[mySeat]
                          : 0,
                      tichu: mySeat < tichuCalled.length && tichuCalled[mySeat],
                      finishRank: finishOrder.indexOf(mySeat) + 1,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 3 : 6),

                    // My hand
                    if (!g.spectator && myHand.isNotEmpty)
                      SizedBox(
                        height: cardW * 1.5,
                        child: Center(
                          child: OverlapRow(
                            itemWidth: cardW,
                            children: [
                              for (final c in myHand)
                                _buildTichuCard(
                                  c,
                                  width: cardW,
                                  selected: _selected.contains(c),
                                  onTap: !g.over
                                      ? () {
                                          setState(() {
                                            if (_selected.contains(c)) {
                                              _selected.remove(c);
                                            } else {
                                              _selected.add(c);
                                            }
                                          });
                                        }
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (g.over)
                Center(
                  child: ResultBanner(
                    _buildWinnerTitle(teamScores),
                    child: Text(
                      '蓝队 (${g.name(0)} & ${g.name(2)}): ${teamScores.isNotEmpty ? teamScores[0] : 0} 分  |  '
                      '红队 (${g.name(1)} & ${g.name(3)}): ${teamScores.length > 1 ? teamScores[1] : 0} 分',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _buildWinnerTitle(List<int> teamScores) {
    if (teamScores.length < 2) return '对局结束';
    if (teamScores[0] >= teamScores[1]) {
      return '蓝队 (${g.name(0)} & ${g.name(2)}) 获胜！';
    }
    return '红队 (${g.name(1)} & ${g.name(3)}) 获胜！';
  }

  Widget _buildSeatChip({
    required int s,
    required int mySeat,
    required bool active,
    required int cards,
    required int pts,
    required bool tichu,
    required int finishRank,
    required bool compact,
  }) {
    final isPartner = s != mySeat && (s % 2 == mySeat % 2);
    final teamLabel = (s % 2 == 0) ? '蓝队' : '红队';
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            g.tag(
              s,
              active: active,
              size: compact ? 24 : 30,
              sub: '手牌 $cards · 抓分 $pts',
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: s % 2 == 0 ? Colors.blue.shade800 : Colors.red.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPartner ? '$teamLabel·搭档' : teamLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (tichu) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TICHU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (finishRank > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '第$finishRank名',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenterContent({
    required String phase,
    required bool isMyTurn,
    required int mySeat,
    required TichuCombo? tableCombo,
    required int? lastPlaySeat,
    required int trickPoints,
    required int targetScore,
    required int? activeWish,
    required bool mustFulfillWish,
    required bool canCallTichu,
    required List<Map<String, dynamic>> currentTrickPlays,
    required Map<String, dynamic>? summary,
    required List<String> selectedList,
    required TichuCombo? candidateCombo,
    required bool canPlaySelected,
    required double cardW,
    required bool compact,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Info badges
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            _badge('桌面累计: $trickPoints分 · 目标$targetScore分', Colors.teal.shade800),
            if (activeWish != null)
              _badge(
                '雀牌许愿: ${kTichuRankLabels[activeWish]}${mustFulfillWish ? ' (你必须满足!)' : ''}',
                mustFulfillWish
                    ? Colors.deepOrange.shade800
                    : Colors.purple.shade800,
              ),
            if (canCallTichu)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => g.act({'type': 'call_tichu'}),
                icon: const Icon(Icons.campaign, size: 15),
                label: const Text('叫地主 Tichu (±100)'),
              ),
          ],
        ),
        const SizedBox(height: 6),

        if (phase == 'give_dragon') ...[
          const Text(
            '龙（DRG +25分）赢下本墩，必须将此墩赠送给一名对手：',
            style: TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          if (isMyTurn)
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final opp in [(mySeat + 1) % 4, (mySeat + 3) % 4])
                  FilledButton.icon(
                    onPressed: () =>
                        g.act({'type': 'give_dragon', 'target': opp}),
                    icon: const Icon(Icons.card_giftcard, size: 16),
                    label: Text('赠予对手 ${g.name(opp)}'),
                  ),
              ],
            ),
        ] else ...[
          // Current table combination
          if (tableCombo != null && lastPlaySeat != null) ...[
            Text(
              '${g.name(lastPlaySeat)} 打出「${_comboTypeNames[tableCombo.type] ?? tableCombo.type}」',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final c in tableCombo.cards)
                  _buildTichuCard(c, width: cardW * 0.92),
              ],
            ),
          ] else if (currentTrickPlays.isNotEmpty &&
              currentTrickPlays.last['type'] == 'dog')
            Text(
              '${g.name((currentTrickPlays.last['seat'] as num?)?.toInt() ?? 0)} 打出犬（DOG），传球给搭档！',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
            )
          else
            const Text(
              '空桌面领出：可出单张、对子、连对、三条、葫芦、顺子、犬或炸弹',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),

          if (isMyTurn) ...[
            const SizedBox(height: 6),
            // If MJ is selected, allow picking wish rank 2..14
            if (selectedList.contains('MJ'))
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    '雀牌许愿:',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                  ),
                  for (final r in [14, 13, 12, 11, 10, 9, 8, 5, 2])
                    ChoiceChip(
                      label: Text(
                        kTichuRankLabels[r] ?? '$r',
                        style: const TextStyle(fontSize: 10),
                      ),
                      selected: _selectedWish == r,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _selectedWish = r),
                    ),
                ],
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: canPlaySelected
                      ? () {
                          final cards = List<String>.of(selectedList);
                          setState(() => _selected.clear());
                          g.act({
                            'type': 'play',
                            'cards': cards,
                            if (cards.contains('MJ')) 'wish': _selectedWish,
                          });
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(
                    candidateCombo != null
                        ? '出牌 (${_comboTypeNames[candidateCombo.type] ?? candidateCombo.type})'
                        : '出牌 (${selectedList.length}张)',
                  ),
                ),
                if (tableCombo != null)
                  OutlinedButton(
                    onPressed: !mustFulfillWish
                        ? () {
                            setState(() => _selected.clear());
                            g.act({'type': 'pass'});
                          }
                        : null,
                    child: const Text('过牌 (Pass)'),
                  ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: const Text('清空重选'),
                  ),
              ],
            ),
          ],
        ],

        if (summary != null) ...[
          const SizedBox(height: 6),
          _buildSummaryBanner(summary),
        ],
      ],
    );
  }

  Widget _buildSummaryBanner(Map<String, dynamic> s) {
    final dv = s['doubleVictory'] == true;
    final delta = _intList(s['roundDelta']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '上局结算：${dv ? '双关 200:0！' : ''}蓝队 ${delta.isNotEmpty ? delta[0] : 0} 分 / '
        '红队 ${delta.length > 1 ? delta[1] : 0} 分',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Widget _buildTichuCard(
    String code, {
    required double width,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    const specials = {
      'MJ': ('雀', '1', Color(0xFF2E7D32), Icons.auto_awesome),
      'DOG': ('犬', '传搭档', Color(0xFF5D4037), Icons.pets),
      'PHX': ('凤', '-25分', Color(0xFFE65100), Icons.local_fire_department),
      'DRG': ('龙', '+25分', Color(0xFFB71C1C), Icons.whatshot),
    };
    final sp = specials[code];
    if (sp == null) {
      return PlayingCard(code, width: width, selected: selected, onTap: onTap);
    }

    final h = width * 1.4;
    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.3 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(
          color: selected ? Colors.amber : sp.$3,
          width: selected ? 2.2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sp.$1,
                style: TextStyle(
                  fontSize: width * 0.36,
                  fontWeight: FontWeight.bold,
                  color: sp.$3,
                ),
              ),
              Icon(sp.$4, size: width * 0.44, color: sp.$3),
              Text(
                sp.$2,
                style: TextStyle(
                  fontSize: width * 0.22,
                  fontWeight: FontWeight.bold,
                  color: sp.$3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }

  Widget _badge(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
