import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class ScoutBoard extends StatefulWidget {
  final GameContext g;
  const ScoutBoard(this.g, {super.key});

  @override
  State<ScoutBoard> createState() => _ScoutBoardState();
}

class _ScoutBoardState extends State<ScoutBoard> {
  int? _selStart;
  int? _selEnd;
  String _scoutSide = 'left';
  bool _scoutFlip = false;
  int _scoutInsertAt = 0;

  static const List<Color> _numColors = [
    Color(0xFF546E7A), // 0 unused
    Color(0xFFE53935), // 1 Red
    Color(0xFFD81B60), // 2 Pink
    Color(0xFF8E24AA), // 3 Purple
    Color(0xFF3949AB), // 4 Indigo
    Color(0xFF1E88E5), // 5 Blue
    Color(0xFF00897B), // 6 Teal
    Color(0xFF43A047), // 7 Green
    Color(0xFFFDD835), // 8 Yellow
    Color(0xFFFB8C00), // 9 Orange
    Color(0xFF6D4C41), // 10 Brown
  ];

  static Color _colorFor(int n) =>
      (n >= 1 && n < _numColors.length) ? _numColors[n] : _numColors[0];

  void _onCardTap(int idx, int handLen) {
    setState(() {
      if (_selStart == null || _selEnd == null) {
        _selStart = idx;
        _selEnd = idx;
      } else if (idx == _selStart && idx == _selEnd) {
        _selStart = null;
        _selEnd = null;
      } else if (idx < _selStart!) {
        _selStart = idx;
      } else {
        _selEnd = idx;
      }
      _scoutInsertAt = (idx + 1).clamp(0, handLen);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final phase = '${v['phase'] ?? 'flip'}';
    final subPhase = '${v['subPhase'] ?? ''}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final myOriented = v['myOriented'] == true;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final capturedCount = (v['capturedCount'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players, 0);
    final scoutTokens =
        (v['scoutTokens'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final scoutAndShowUsed =
        (v['scoutAndShowUsed'] as List?)?.map((e) => e == true).toList() ??
            List.filled(g.players, false);
    final handCounts =
        (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);

    final rawHand = (v['hand'] as List?) ?? const [];
    final hand = <List<int>>[
      for (final c in rawHand)
        if (c is List && c.length >= 2)
          [(c[0] as num).toInt(), (c[1] as num).toInt()],
    ];

    final rawStage = (v['stageCards'] as List?) ?? const [];
    final stageCards = <List<int>>[
      for (final c in rawStage)
        if (c is List && c.length >= 2)
          [(c[0] as num).toInt(), (c[1] as num).toInt()],
    ];
    final stageOwner = (v['stageOwner'] as num?)?.toInt() ?? -1;
    final stageComboType = '${v['stageComboType'] ?? ''}';
    final legalShows =
        (v['legalShows'] as List?)?.cast<Map>() ?? const <Map>[];

    // Clamp local selections to current hand length
    final sStart = (_selStart != null && _selStart! < hand.length) ? _selStart : null;
    final sEnd = (_selEnd != null && sStart != null && _selEnd! >= sStart && _selEnd! < hand.length)
        ? _selEnd
        : sStart;
    final insIdx = _scoutInsertAt.clamp(0, hand.length);

    final canSelShow = sStart != null &&
        sEnd != null &&
        legalShows.any((m) =>
            (m['start'] as num?)?.toInt() == sStart &&
            (m['end'] as num?)?.toInt() == sEnd);

    final isMyFlip = !g.over && phase == 'flip' && !g.spectator && !myOriented;
    final isMyTurn = !g.over && phase == 'play' && g.seat == turn;
    final myUsedSaS = (g.seat >= 0 && g.seat < scoutAndShowUsed.length)
        ? scoutAndShowUsed[g.seat]
        : true;

    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'flip') {
      statusText = isMyFlip
          ? '请确认手牌朝向：保持当前方向，或整副手牌上下颠倒翻转（严禁重排顺序！）'
          : '等待全员确认手牌正反方向…';
    } else if (subPhase == 'must_show') {
      statusText = isMyTurn
          ? '已执行「挖角连演」挖角步骤！请选择连续手牌立即演出压牌 (Show)'
          : '等待 ${g.name(turn)} 完成挖角连演…';
    } else {
      statusText = isMyTurn
          ? '轮到你行动：选择连续手牌「演出压牌(Show)」，或从舞台两端「星探挖角(Scout)」'
          : '等待 ${g.name(turn)} 行动…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 40.0 : 52.0;

      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 6 : 10),
        child: Stack(
          children: [
            Column(
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(cs, '第 $round/$totalRounds 局 · 马戏星探 SCOUT'),
                    _chip(
                      cs,
                      '铁律：手牌顺序锁定不可重排 · 同点组(Set) > 顺子(Run)',
                      highlight: true,
                    ),
                    StatusBar(statusText, highlight: isMyFlip || isMyTurn),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Players row
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      g.tag(
                        s,
                        active: !g.over &&
                            ((phase == 'play' && s == turn) ||
                                (phase == 'flip' && s == g.seat && !myOriented)),
                        size: compact ? 28 : 34,
                        sub: '总${scores[s]} · 捕获${capturedCount[s]}+筹码${scoutTokens[s]} · 手牌${handCounts[s]}张'
                            '${!scoutAndShowUsed[s] ? " [连演★]" : ""}',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center stage & action controls
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (phase == 'flip')
                            _buildFlipPanel(cs, hand, isMyFlip, compact)
                          else ...[
                            _buildStageArea(
                              cs,
                              stageCards,
                              stageOwner,
                              stageComboType,
                              cardW,
                              compact,
                            ),
                            if (isMyTurn) ...[
                              SizedBox(height: compact ? 6 : 8),
                              _buildActionPanel(
                                cs,
                                hand,
                                stageCards,
                                legalShows,
                                sStart,
                                sEnd,
                                canSelShow,
                                insIdx,
                                subPhase,
                                myUsedSaS,
                                compact,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom non-rearrangeable dual-number hand
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '我的手牌（共 ${hand.length} 张 · 顺序不可重排 · 上方大字为当前生效点数）：',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        OverlapRow(
                          itemWidth: cardW,
                          maxSpacing: 1.08,
                          children: [
                            for (var i = 0; i < hand.length; i++)
                              _buildDualCard(
                                hand[i],
                                width: cardW,
                                indexBadge: i,
                                selected: sStart != null &&
                                    sEnd != null &&
                                    i >= sStart &&
                                    i <= sEnd,
                                onTap: isMyTurn
                                    ? () => _onCardTap(i, hand.length)
                                    : null,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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

  Widget _chip(ColorScheme cs, String label, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? cs.primaryContainer.withValues(alpha: 0.92)
            : cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? cs.primary : cs.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: highlight ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildDualCard(
    List<int> card, {
    required double width,
    int? indexBadge,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final top = card[0];
    final bottom = card[1];
    final h = width * 1.42;
    final topColor = _colorFor(top);
    final botColor = _colorFor(bottom);

    final widgetCard = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.25 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(
          color: selected ? Colors.amber : topColor,
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.12),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: topColor.withValues(alpha: 0.16),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '$top',
                      style: TextStyle(
                        fontSize: width * 0.48,
                        fontWeight: FontWeight.w900,
                        color: topColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(height: 1, color: Colors.black12),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.04),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (indexBadge != null)
                        Text(
                          '#${indexBadge + 1}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black45,
                          ),
                        ),
                      const SizedBox(width: 2),
                      Text(
                        '↕$bottom',
                        style: TextStyle(
                          fontSize: width * 0.26,
                          fontWeight: FontWeight.bold,
                          color: botColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return widgetCard;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: widgetCard),
    );
  }

  Widget _buildFlipPanel(
    ColorScheme cs,
    List<List<int>> hand,
    bool isMyFlip,
    bool compact,
  ) {
    final normalPreview = hand.map((c) => '${c[0]}').join(' - ');
    final flippedPreview =
        hand.reversed.map((c) => '${c[1]}').join(' - ');

    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: EdgeInsets.all(compact ? 8 : 14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🎪 开局手牌正反方向抉择 (Flip Phase)',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 4),
          if (hand.isNotEmpty) ...[
            Text(
              '当前正面序列: [$normalPreview]',
              style: TextStyle(fontSize: 11.5, color: cs.onSurface),
            ),
            Text(
              '整副翻转序列: [$flippedPreview]',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: cs.secondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (isMyFlip)
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      widget.g.act({'type': 'orient', 'flip': false}),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('保持当前方向 (不翻转)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      widget.g.act({'type': 'orient', 'flip': true}),
                  icon: const Icon(Icons.flip_camera_android, size: 16),
                  label: const Text('上下颠倒翻转整副手牌'),
                ),
              ],
            )
          else
            Text(
              '已确认方向，等待其他玩家确认…',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStageArea(
    ColorScheme cs,
    List<List<int>> stageCards,
    int stageOwner,
    String stageComboType,
    double cardW,
    bool compact,
  ) {
    final comboLabel = stageComboType == 'set'
        ? (stageCards.length <= 1 ? '单张演出' : '${stageCards.length}张同点组 (Set)')
        : (stageComboType == 'run' ? '${stageCards.length}张顺子 (Run)' : '');

    return Container(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 580),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stageCards.isEmpty
                ? '🎪 马戏中央舞台（当前为空，可打出任意连续同点组或顺子）'
                : '🎪 中央舞台：${widget.g.name(stageOwner)} 的 $comboLabel',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          if (stageCards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '等待首位玩家登台演出 (Show)…',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < stageCards.length; i++)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildDualCard(stageCards[i], width: cardW),
                      if (i == 0 || i == stageCards.length - 1)
                        Positioned(
                          top: -5,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                i == 0 && i == stageCards.length - 1
                                    ? '可挖'
                                    : (i == 0 ? '左端' : '右端'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(
    ColorScheme cs,
    List<List<int>> hand,
    List<List<int>> stageCards,
    List<Map> legalShows,
    int? sStart,
    int? sEnd,
    bool canSelShow,
    int insIdx,
    String subPhase,
    bool myUsedSaS,
    bool compact,
  ) {
    final g = widget.g;
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show controls
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (canSelShow)
                FilledButton.icon(
                  onPressed: () {
                    g.act({'type': 'show', 'start': sStart, 'end': sEnd});
                    setState(() {
                      _selStart = null;
                      _selEnd = null;
                    });
                  },
                  icon: const Icon(Icons.theater_comedy, size: 16),
                  label: Text('演出所选牌 (#${sStart! + 1}~#${sEnd! + 1})'),
                ),
              for (final m in legalShows.take(4))
                Builder(builder: (_) {
                  final st = (m['start'] as num).toInt();
                  final ed = (m['end'] as num).toInt();
                  final cards = (m['cards'] as List?) ?? const [];
                  final label = cards
                      .map((c) => c is List && c.isNotEmpty ? '${c[0]}' : '?')
                      .join('-');
                  return ActionChip(
                    label: Text('演出 [$label] (#${st + 1}${st == ed ? "" : "-#${ed + 1}"})'),
                    onPressed: () =>
                        g.act({'type': 'show', 'start': st, 'end': ed}),
                  );
                }),
            ],
          ),

          // Scout & Scout+Show controls (when stage is non-empty and not in must_show)
          if (stageCards.isNotEmpty && subPhase != 'must_show') ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (stageCards.length > 1)
                  ChoiceChip(
                    label: Text(_scoutSide == 'left'
                        ? '挖左端 (${stageCards.first[0]}/${stageCards.first[1]})'
                        : '挖右端 (${stageCards.last[0]}/${stageCards.last[1]})'),
                    selected: true,
                    onSelected: (_) => setState(() {
                      _scoutSide = _scoutSide == 'left' ? 'right' : 'left';
                    }),
                  ),
                FilterChip(
                  label: Text(_scoutFlip ? '已翻转挖角牌' : '不翻转挖角牌'),
                  selected: _scoutFlip,
                  onSelected: (v) => setState(() => _scoutFlip = v),
                ),
                ActionChip(
                  label: Text('插入位置: 缝隙 $insIdx/${hand.length}'),
                  onPressed: () => setState(() {
                    _scoutInsertAt = (_scoutInsertAt + 1) % (hand.length + 1);
                  }),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => g.act({
                    'type': 'scout',
                    'endSide': _scoutSide,
                    'flip': _scoutFlip,
                    'insertAt': insIdx,
                  }),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('星探挖角 (Scout)'),
                ),
                if (!myUsedSaS)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => g.act({
                      'type': 'scout_and_show',
                      'endSide': _scoutSide,
                      'flip': _scoutFlip,
                      'insertAt': insIdx,
                    }),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('挖角连演 (每局限1次)'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildResultText(List<int> scores) {
    final g = widget.g;
    return '比赛结束！${[
      for (var s = 0; s < g.players; s++) '${g.name(s)}: ${scores[s]}分'
    ].join(' · ')}';
  }
}
