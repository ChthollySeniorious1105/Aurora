import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class PaohuziBoard extends StatefulWidget {
  final GameContext g;
  const PaohuziBoard(this.g, {super.key});

  @override
  State<PaohuziBoard> createState() => _PaohuziBoardState();
}

class _PaohuziBoardState extends State<PaohuziBoard> {
  String? _selectedCard;

  static const List<String> _smallChars = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
  static const List<String> _bigChars = ['壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖', '拾'];

  static String _cardChar(String code) {
    if (code.length < 2) return code;
    final r = int.tryParse(code.substring(1)) ?? 0;
    if (r < 1 || r > 10) return code;
    return code.startsWith('b') ? _bigChars[r - 1] : _smallChars[r - 1];
  }

  static bool _isRed(String code) {
    if (code.length < 2) return false;
    final r = int.tryParse(code.substring(1)) ?? 0;
    return r == 2 || r == 7 || r == 10;
  }

  static bool _isBig(String code) => code.startsWith('b');

  static String _meldTypeLabel(String t) => switch (t) {
        'ti' => '提',
        'pao' => '跑',
        'wei' => '偎',
        'kan' => '坎',
        'peng' => '碰',
        'chi' => '吃',
        'jiang' => '将',
        _ => t,
      };

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 4;
    final minHuxi = (v['minHuxi'] as num?)?.toInt() ?? 15;
    final dealer = (v['dealer'] as num?)?.toInt() ?? 0;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'discard'}';
    final wallCount = (v['wallCount'] as num?)?.toInt() ?? 0;
    final activeCard = v['activeCard'] as String?;
    final activeFrom = (v['activeFrom'] as num?)?.toInt() ?? -1;
    final activeSource = '${v['activeSource'] ?? ''}';
    final status = '${v['status'] ?? ''}';

    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final discardable = ((v['discardable'] as List?)?.map((e) => '$e') ?? const <String>[]).toSet();
    final canHuNow = v['canHuNow'] == true;
    final claimOpts = v['claimOptions'] as Map?;
    final pList = (v['players'] as List?)?.cast<Map>() ?? const [];
    if (pList.isEmpty) return const SizedBox();

    final seats = g.seatsFromMe();
    final mySeat = seats[0];
    final rightSeat = seats.length > 1 ? seats[1] : 1;
    final leftSeat = seats.length > 2 ? seats[2] : 2;

    final myTurnDiscard = !g.spectator && !g.over && phase == 'discard' && turn == mySeat;
    final myClaiming = !g.spectator && !g.over && phase == 'claim' && claimOpts != null;

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              // Top bar: game meta + status
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '第 $round/$totalRounds 局 · 底牌 $wallCount 张 · $minHuxi胡起胡',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBar(
                      status.isNotEmpty ? status : '跑胡子对战中',
                      highlight: myTurnDiscard || myClaiming,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Opponents row (left & right seats)
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPlayerZone(
                        cs,
                        leftSeat,
                        pList.firstWhere((p) => p['seat'] == leftSeat, orElse: () => pList.first),
                        isDealer: dealer == leftSeat,
                        isTurn: !g.over && turn == leftSeat,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildPlayerZone(
                        cs,
                        rightSeat,
                        pList.firstWhere((p) => p['seat'] == rightSeat, orElse: () => pList.first),
                        isDealer: dealer == rightSeat,
                        isTurn: !g.over && turn == rightSeat,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Center table: active card & claim controls / roundEnd settlement
              Expanded(
                flex: 3,
                child: _buildCenterTable(
                  cs,
                  phase: phase,
                  activeCard: activeCard,
                  activeFrom: activeFrom,
                  activeSource: activeSource,
                  claimOpts: claimOpts,
                  roundResult: v['roundResult'] as Map?,
                ),
              ),
              const SizedBox(height: 4),
              // Bottom: My melds + hand cards
              Expanded(
                flex: 5,
                child: _buildMyArea(
                  cs,
                  mySeat,
                  pList.firstWhere((p) => p['seat'] == mySeat, orElse: () => pList.first),
                  hand: hand,
                  discardable: discardable,
                  isDealer: dealer == mySeat,
                  myTurnDiscard: myTurnDiscard,
                  canHuNow: canHuNow,
                ),
              ),
            ],
          ),
          if (g.over) _buildFinalBanner(g, pList, v['roundResult'] as Map?),
        ],
      ),
    );
  }

  Widget _buildPlayerZone(
    ColorScheme cs,
    int seat,
    Map pData, {
    required bool isDealer,
    required bool isTurn,
  }) {
    final handCount = (pData['handCount'] as num?)?.toInt() ?? 0;
    final exposedHuxi = (pData['exposedHuxi'] as num?)?.toInt() ?? 0;
    final score = (pData['score'] as num?)?.toInt() ?? 0;
    final melds = (pData['melds'] as List?)?.cast<Map>() ?? const [];
    final discards = (pData['discards'] as List?)?.map((e) => '$e').toList() ?? const [];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTurn ? cs.primary : cs.outline.withValues(alpha: 0.25), width: isTurn ? 1.8 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.g.tag(
                  seat,
                  active: isTurn,
                  sub: '${isDealer ? "[庄] " : ""}总分 $score · 明胡 $exposedHuxi · 手牌 $handCount',
                  size: 24,
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 4,
                runSpacing: 3,
                children: [
                  for (final m in melds) _buildMeldGroup(cs, m, compact: true),
                  if (discards.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        children: [
                          for (final c in discards) _buildMiniCard(c, width: 16, height: 28),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterTable(
    ColorScheme cs, {
    required String phase,
    required String? activeCard,
    required int activeFrom,
    required String activeSource,
    required Map? claimOpts,
    required Map? roundResult,
  }) {
    if (phase == 'roundEnd' && roundResult != null && !widget.g.over) {
      final text = '${roundResult['text'] ?? '本局结束'}';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 6),
              if (!widget.g.spectator)
                FilledButton.icon(
                  onPressed: () => widget.g.act({'type': 'nextRound'}),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('继续下一局'),
                ),
            ],
          ),
        ),
      );
    }

    final chiList = (claimOpts?['chi'] as List?)?.cast<List>() ?? const [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activeCard != null) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${activeFrom >= 0 ? widget.g.name(activeFrom) : ""} ${activeSource == 'draw' ? '摸出底牌' : '打出'}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 3),
                    _buildZipaiCard(activeCard, width: 36, height: 74, highlight: true),
                  ],
                ),
                const SizedBox(width: 14),
              ] else
                const Text('桌面暂无亮牌', style: TextStyle(fontSize: 13, color: Colors.white70)),
              if (claimOpts != null && !widget.g.spectator)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (claimOpts['hu'] == true)
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => widget.g.act({'type': 'hu'}),
                        child: const Text('胡', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    if (claimOpts['pao'] == true)
                      FilledButton.tonal(
                        onPressed: () => widget.g.act({'type': 'pao'}),
                        child: const Text('跑'),
                      ),
                    if (claimOpts['peng'] == true)
                      FilledButton.tonal(
                        onPressed: () => widget.g.act({'type': 'peng'}),
                        child: const Text('碰'),
                      ),
                    for (final pair in chiList)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: cs.surface.withValues(alpha: 0.85),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: () => widget.g.act({
                          'type': 'chi',
                          'cards': ['${pair[0]}', '${pair[1]}'],
                        }),
                        child: Text('吃 ${_cardChar('${pair[0]}')}${_cardChar('${pair[1]}')}'),
                      ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(backgroundColor: cs.surface.withValues(alpha: 0.7)),
                      onPressed: () => widget.g.act({'type': 'pass'}),
                      child: const Text('过'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyArea(
    ColorScheme cs,
    int mySeat,
    Map myData, {
    required List<String> hand,
    required Set<String> discardable,
    required bool isDealer,
    required bool myTurnDiscard,
    required bool canHuNow,
  }) {
    final exposedHuxi = (myData['exposedHuxi'] as num?)?.toInt() ?? 0;
    final score = (myData['score'] as num?)?.toInt() ?? 0;
    final melds = (myData['melds'] as List?)?.cast<Map>() ?? const [];
    final discards = (myData['discards'] as List?)?.map((e) => '$e').toList() ?? const [];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: myTurnDiscard ? cs.primary : cs.outline.withValues(alpha: 0.3),
          width: myTurnDiscard ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.g.tag(
                  mySeat,
                  active: myTurnDiscard,
                  sub: '${isDealer ? "[庄家] " : ""}总分 $score · 桌面胡息 $exposedHuxi · 手牌 ${hand.length} 张',
                  size: 26,
                ),
                const SizedBox(width: 8),
                if (canHuNow && !widget.g.spectator)
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () => widget.g.act({'type': 'hu'}),
                    child: const Text('天胡 / 自摸胡牌'),
                  ),
                if (myTurnDiscard)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      '点击手牌即可打出（三张相同的坎牌不可拆打）',
                      style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          if (melds.isNotEmpty || discards.isNotEmpty) ...[
            const SizedBox(height: 3),
            SizedBox(
              height: 36,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in melds) ...[
                      _buildMeldGroup(cs, m, compact: true),
                      const SizedBox(width: 4),
                    ],
                    if (discards.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('弃:', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            for (final c in discards) ...[
                              _buildMiniCard(c, width: 16, height: 28),
                              const SizedBox(width: 2),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: hand.isEmpty
                  ? Text(
                      widget.g.spectator ? '观战视角（隐藏手牌）' : '暂无手牌',
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < hand.length; i++)
                            _buildHandCard(
                              hand[i],
                              canDiscard: myTurnDiscard && discardable.contains(hand[i]),
                              dim: myTurnDiscard && !discardable.contains(hand[i]),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandCard(String code, {required bool canDiscard, required bool dim}) {
    final selected = _selectedCard == code;
    return GestureDetector(
      onTap: canDiscard
          ? () {
              setState(() => _selectedCard = code);
              widget.g.act({'type': 'discard', 'card': code});
            }
          : null,
      child: Opacity(
        opacity: dim ? 0.5 : 1.0,
        child: _buildZipaiCard(code, width: 32, height: 68, highlight: selected),
      ),
    );
  }

  Widget _buildMeldGroup(ColorScheme cs, Map m, {bool compact = false}) {
    final type = '${m['type'] ?? ''}';
    final cards = (m['cards'] as List?)?.map((e) => '$e').toList() ?? const [];
    final huxi = (m['huxi'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_meldTypeLabel(type)}${huxi > 0 ? "$huxi" : ""}',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 3),
          for (final c in cards) ...[
            _buildMiniCard(c, width: compact ? 16 : 20, height: compact ? 28 : 36),
            const SizedBox(width: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniCard(String code, {required double width, required double height}) {
    final red = _isRed(code);
    final big = _isBig(code);
    final ch = _cardChar(code);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5E8),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.brown.withValues(alpha: 0.45), width: 0.8),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          ch,
          style: TextStyle(
            fontSize: 13,
            fontWeight: big ? FontWeight.w900 : FontWeight.w700,
            color: red ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildZipaiCard(String code, {required double width, required double height, bool highlight = false}) {
    final red = _isRed(code);
    final big = _isBig(code);
    final ch = _cardChar(code);
    final ink = red ? const Color(0xFFDC2626) : const Color(0xFF1E293B);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5E8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight ? Colors.amber : const Color(0xFF92400E).withValues(alpha: 0.55),
          width: highlight ? 2 : 1.1,
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ch,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                big ? '大写' : '小写',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: ink),
              ),
            ),
            Transform.rotate(
              angle: 3.14159,
              child: Text(
                ch,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink.withValues(alpha: 0.85)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalBanner(GameContext g, List<Map> pList, Map? roundResult) {
    final placings = (g.view['placings'] as List?)?.map((e) => (e as num).toInt()).toList();
    final winners = <String>[];
    if (placings != null) {
      for (var s = 0; s < placings.length; s++) {
        if (placings[s] == 1) winners.add(g.name(s));
      }
    }
    final title = winners.isEmpty ? '跑胡子结束' : '${winners.join("、")} 获胜！';
    return ResultBanner(
      title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (roundResult != null && roundResult['text'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${roundResult['text']}', style: const TextStyle(fontSize: 12)),
            ),
          for (final p in pList)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Text(
                '${g.name((p['seat'] as num).toInt())}：总分 ${p['score']}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
