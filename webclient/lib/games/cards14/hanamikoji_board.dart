import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class HanamikojiBoard extends StatefulWidget {
  final GameContext g;
  const HanamikojiBoard(this.g, {super.key});

  @override
  State<HanamikojiBoard> createState() => _HanamikojiBoardState();
}

class _HanamikojiBoardState extends State<HanamikojiBoard> {
  int _selectedAction = 0; // 0: secret, 1: discard, 2: gift, 3: compete
  final List<int> _selectedIndices = [];

  GameContext get g => widget.g;

  static const List<Color> _geishaColors = [
    Color(0xFFC62828), // 0: 红扇 (2)
    Color(0xFFAD1457), // 1: 画卷 (2)
    Color(0xFF6A1B9A), // 2: 纸伞 (2)
    Color(0xFF2E7D32), // 3: 茶道 (3)
    Color(0xFF00838F), // 4: 折笛 (3)
    Color(0xFFEF6C00), // 5: 三味线 (4)
    Color(0xFF283593), // 6: 花冠 (5)
  ];

  static const List<String> _actionShortNames = [
    '密约 (暗1)',
    '取舍 (弃2)',
    '赠予 (3选1)',
    '竞争 (2对选1)',
  ];

  static const List<int> _actionNeedCards = [1, 2, 3, 4];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 4;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'action'}';
    final offerFrom = (v['offerFrom'] as num?)?.toInt() ?? -1;

    final favor =
        (v['favor'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(7, -1);
    final charms =
        (v['geishaCharms'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const [2, 2, 2, 3, 3, 4, 5];
    final items = (v['geishaItems'] as List?)?.map((e) => '$e').toList() ??
        const ['折扇', '画卷', '纸伞', '茶碗', '横笛', '三味线', '花冠'];

    final rawPlayed = (v['played'] as List?) ?? const [];
    final played = <List<int>>[
      for (var s = 0; s < 2; s++)
        s < rawPlayed.length
            ? (rawPlayed[s] as List).map((e) => (e as num).toInt()).toList()
            : List.filled(7, 0),
    ];

    final rawActs = (v['actionsLeft'] as List?) ?? const [];
    final actionsLeft = <List<bool>>[
      for (var s = 0; s < 2; s++)
        s < rawActs.length
            ? (rawActs[s] as List).map((e) => e == true).toList()
            : [true, true, true, true],
    ];

    final hand =
        (v['hand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? <int>[];
    final mySecret = (v['mySecret'] as num?)?.toInt();
    final giftOffer =
        (v['giftOffer'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            <int>[];
    final rawPairs = (v['competePairs'] as List?) ?? const [];
    final competePairs = <List<int>>[
      for (final p in rawPairs)
        (p as List).map((e) => (e as num).toInt()).toList(),
    ];
    final charmPoints =
        (v['charmPoints'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [0, 0];
    final geishaCounts =
        (v['geishaCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            [0, 0];

    final mySeat = g.seat >= 0 && g.seat < 2 ? g.seat : 0;
    final oppSeat = 1 - mySeat;
    final isMyTurn = !g.over && g.seat == turn;

    // Ensure _selectedAction points to an available action for mySeat
    if (!actionsLeft[mySeat][_selectedAction]) {
      final avail = actionsLeft[mySeat].indexOf(true);
      if (avail >= 0) _selectedAction = avail;
    }
    _selectedIndices.removeWhere((idx) => idx < 0 || idx >= hand.length);

    String statusText;
    if (g.over) {
      final wSeat = (v['winner'] as num?)?.toInt() ?? 0;
      statusText = '${g.name(wSeat)} 获胜（${v['winReason'] ?? ''}）';
    } else if (phase == 'pick_gift') {
      statusText = isMyTurn
          ? '${g.name(offerFrom)} 发起「赠予」：请从 3 张礼物牌中挑选 1 张归入己方'
          : '等待 ${g.name(turn)} 从「赠予」的 3 张牌中挑选 1 张…';
    } else if (phase == 'pick_pair') {
      statusText = isMyTurn
          ? '${g.name(offerFrom)} 发起「竞争」：请从两对礼物牌中挑选 1 对归入己方'
          : '等待 ${g.name(turn)} 从「竞争」的两对牌中挑选 1 对…';
    } else {
      statusText = isMyTurn
          ? '轮到你行动：选择 1 个行动标记并点选对应数量的手牌'
          : '等待 ${g.name(turn)} 选择行动…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 470 || w < 460;

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
                    _badge(cs, '第 $round/$maxRounds 回合 · 获胜条件：≥4 位艺伎 或 ≥11 点魅力'),
                    StatusBar(statusText, highlight: isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 8),

                // Main scrollable table
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Opponent strip
                        _buildPlayerStrip(
                          cs: cs,
                          seat: oppSeat,
                          active: !g.over && turn == oppSeat,
                          geishas: geishaCounts[oppSeat],
                          charm: charmPoints[oppSeat],
                          acts: actionsLeft[oppSeat],
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 6 : 10),

                        // 7 Geishas Center Row
                        _buildGeishaRow(
                          cs: cs,
                          mySeat: mySeat,
                          oppSeat: oppSeat,
                          favor: favor,
                          charms: charms,
                          items: items,
                          played: played,
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 6 : 10),

                        // Offer response panel (Gift or Compete)
                        if (phase == 'pick_gift' && giftOffer.isNotEmpty)
                          _buildGiftPicker(cs, giftOffer, charms, items, isMyTurn, compact)
                        else if (phase == 'pick_pair' && competePairs.length == 2)
                          _buildCompetePicker(cs, competePairs, charms, items, isMyTurn, compact),

                        // My strip
                        _buildPlayerStrip(
                          cs: cs,
                          seat: mySeat,
                          active: !g.over && turn == mySeat,
                          geishas: geishaCounts[mySeat],
                          charm: charmPoints[mySeat],
                          acts: actionsLeft[mySeat],
                          mySecret: mySecret,
                          items: items,
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 6 : 10),

                        // My Hand & Action Execution Panel
                        if (!g.spectator && hand.isNotEmpty)
                          _buildHandAndActionPanel(
                            cs: cs,
                            hand: hand,
                            acts: actionsLeft[mySeat],
                            charms: charms,
                            items: items,
                            isMyTurn: isMyTurn && phase == 'action',
                            compact: compact,
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
                  '${g.name((v['winner'] as num?)?.toInt() ?? 0)} 获胜！\n'
                  '${v['winReason'] ?? ''}\n'
                  '${g.name(0)}: ${geishaCounts[0]}艺伎/${charmPoints[0]}魅力 · '
                  '${g.name(1)}: ${geishaCounts[1]}艺伎/${charmPoints[1]}魅力',
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _badge(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface),
      ),
    );
  }

  Widget _buildPlayerStrip({
    required ColorScheme cs,
    required int seat,
    required bool active,
    required int geishas,
    required int charm,
    required List<bool> acts,
    int? mySecret,
    List<String>? items,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          g.tag(
            seat,
            active: active,
            size: compact ? 26 : 32,
            sub: '青睐 $geishas/4 位 · 魅力 $charm/11 点',
          ),
          for (var a = 0; a < 4; a++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: acts[a]
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _actionShortNames[a],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  decoration: acts[a] ? null : TextDecoration.lineThrough,
                  color: acts[a]
                      ? cs.onPrimaryContainer
                      : cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          if (mySecret != null && items != null && mySecret >= 0 && mySecret < items.length)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '我的密约：${items[mySecret]}',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGeishaRow({
    required ColorScheme cs,
    required int mySeat,
    required int oppSeat,
    required List<int> favor,
    required List<int> charms,
    required List<String> items,
    required List<List<int>> played,
    required bool compact,
  }) {
    final cardW = compact ? 72.0 : 94.0;
    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: compact ? 6 : 8,
      alignment: WrapAlignment.center,
      children: [
        for (var idx = 0; idx < 7; idx++)
          Container(
            width: cardW,
            padding: EdgeInsets.all(compact ? 5 : 7),
            decoration: BoxDecoration(
              color: _geishaColors[idx].withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: favor[idx] == mySeat
                    ? Colors.amberAccent
                    : (favor[idx] == oppSeat ? Colors.cyanAccent : Colors.white30),
                width: favor[idx] == -1 ? 1 : 2.5,
              ),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Opponent played count + favor indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '对手:${played[oppSeat][idx]} ${favor[idx] == oppSeat ? "★青睐" : ""}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: favor[idx] == oppSeat ? Colors.cyanAccent : Colors.white70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Charm value circle
                CircleAvatar(
                  radius: compact ? 13 : 16,
                  backgroundColor: Colors.white,
                  child: Text(
                    '${charms[idx]}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 13 : 15,
                      color: _geishaColors[idx],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    items[idx],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (favor[idx] == -1)
                  const Text(
                    '中立',
                    style: TextStyle(color: Colors.white60, fontSize: 9),
                  ),
                const SizedBox(height: 4),
                // My played count + favor indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '我方:${played[mySeat][idx]} ${favor[idx] == mySeat ? "★青睐" : ""}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: favor[idx] == mySeat ? Colors.amberAccent : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGiftPicker(
    ColorScheme cs,
    List<int> giftOffer,
    List<int> charms,
    List<String> items,
    bool isMyTurn,
    bool compact,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMyTurn ? '「赠予」：请点击挑选 1 张礼物牌（其余 2 张归对方）' : '等待对方从「赠予」中挑选 1 张…',
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < giftOffer.length; i++)
                _buildItemCardWidget(
                  geishaId: giftOffer[i],
                  charms: charms,
                  items: items,
                  selected: isMyTurn,
                  compact: compact,
                  onTap: isMyTurn
                      ? () => g.act({'type': 'pick_gift', 'index': i})
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompetePicker(
    ColorScheme cs,
    List<List<int>> competePairs,
    List<int> charms,
    List<String> items,
    bool isMyTurn,
    bool compact,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMyTurn ? '「竞争」：请挑选其中 1 对礼物牌（另 1 对归对方）' : '等待对方从「竞争」中挑选 1 对…',
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var p = 0; p < 2; p++)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: isMyTurn ? () => g.act({'type': 'pick_pair', 'pair': p}) : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.primary),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('第 ${p + 1} 对', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final c in competePairs[p])
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: _buildItemCardWidget(
                                  geishaId: c,
                                  charms: charms,
                                  items: items,
                                  compact: compact,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHandAndActionPanel({
    required ColorScheme cs,
    required List<int> hand,
    required List<bool> acts,
    required List<int> charms,
    required List<String> items,
    required bool isMyTurn,
    required bool compact,
  }) {
    final needed = _actionNeedCards[_selectedAction];
    final canSubmit = isMyTurn &&
        acts[_selectedAction] &&
        _selectedIndices.length == needed;

    return Container(
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMyTurn) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var a = 0; a < 4; a++)
                  if (acts[a])
                    ChoiceChip(
                      label: Text(_actionShortNames[a], style: const TextStyle(fontSize: 11)),
                      selected: _selectedAction == a,
                      onSelected: (_) => setState(() {
                        _selectedAction = a;
                        _selectedIndices.clear();
                      }),
                    ),
                FilledButton.icon(
                  onPressed: canSubmit ? _submitAction : null,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(
                    '执行 (${_selectedIndices.length}/$needed张)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < hand.length; i++)
                _buildItemCardWidget(
                  geishaId: hand[i],
                  charms: charms,
                  items: items,
                  selected: _selectedIndices.contains(i),
                  badge: _badgeForIndex(i),
                  compact: compact,
                  onTap: isMyTurn
                      ? () => setState(() {
                            if (_selectedIndices.contains(i)) {
                              _selectedIndices.remove(i);
                            } else if (_selectedIndices.length < needed) {
                              _selectedIndices.add(i);
                            }
                          })
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _badgeForIndex(int idx) {
    final pos = _selectedIndices.indexOf(idx);
    if (pos < 0) return null;
    if (_selectedAction == 3) {
      return pos < 2 ? 'A对' : 'B对';
    }
    return '${pos + 1}';
  }

  void _submitAction() {
    final idx = List<int>.of(_selectedIndices);
    _selectedIndices.clear();
    switch (_selectedAction) {
      case 0:
        g.act({'type': 'secret', 'cardIdx': idx[0]});
      case 1:
        g.act({'type': 'discard', 'cards': [idx[0], idx[1]]});
      case 2:
        g.act({'type': 'gift', 'cards': [idx[0], idx[1], idx[2]]});
      case 3:
        g.act({
          'type': 'compete',
          'pairA': [idx[0], idx[1]],
          'pairB': [idx[2], idx[3]],
        });
    }
  }

  Widget _buildItemCardWidget({
    required int geishaId,
    required List<int> charms,
    required List<String> items,
    bool selected = false,
    String? badge,
    required bool compact,
    VoidCallback? onTap,
  }) {
    final gid = geishaId.clamp(0, 6);
    final color = _geishaColors[gid];
    final w = compact ? 52.0 : 64.0;
    final h = w * 1.35;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: w,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -6 : 0, 0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? Colors.amberAccent : Colors.white54,
          width: selected ? 2.5 : 1,
        ),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Text(
                        '${charms[gid]}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[gid],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
