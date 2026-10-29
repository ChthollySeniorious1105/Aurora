import 'package:aurora_shared/games/cards20/zhaopengyou.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class ZhaopengyouBoard extends StatefulWidget {
  final GameContext g;
  const ZhaopengyouBoard(this.g, {super.key});

  @override
  State<ZhaopengyouBoard> createState() => _ZhaopengyouBoardState();
}

class _ZhaopengyouBoardState extends State<ZhaopengyouBoard> {
  final Set<String> _selectedBury = {};
  String _selectedTrump = 'S';
  String _selectedFriend = 'AS';

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final cs = Theme.of(context).colorScheme;
    final v = g.view;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 2;
    final phase = '${v['phase'] ?? 'bid'}';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;

    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final handCounts =
        (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 12);
    final hand = (v['hand'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final legalCards =
        ((v['legalCards'] as List?)?.map((e) => '$e').toList() ?? const <String>[])
            .toSet();

    final currentBid = (v['currentBid'] as num?)?.toInt() ?? 0;
    final declarer = (v['declarer'] as num?)?.toInt() ?? 0;
    final contract = (v['contract'] as num?)?.toInt() ?? 60;
    final defenderTarget = (v['defenderTarget'] as num?)?.toInt() ?? 45;
    final trumpSuit = '${v['trumpSuit'] ?? 'S'}';
    final friendCard = '${v['friendCard'] ?? 'AS'}';
    final friendRevealed = v['friendRevealed'] == true;
    final revealedFriendSeat = (v['revealedFriendSeat'] as num?)?.toInt();
    final amSecretFriend = v['amSecretFriend'] == true;

    final trickNumber = (v['trickNumber'] as num?)?.toInt() ?? 1;
    final currentTrick =
        (v['currentTrick'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastTrick = (v['lastTrick'] as List?)?.cast<Map>() ?? const <Map>[];
    final capturedPoints = (v['capturedPoints'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        List.filled(g.players, 0);
    final actionLog =
        (v['actionLog'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    final isMyTurn = !g.over && g.seat == turn;
    String statusText;
    if (g.over) {
      statusText = '比赛结束';
    } else if (phase == 'bid') {
      statusText = isMyTurn
          ? '轮到你叫分：请选择高于 $currentBid 分的档位（60~100分）或不叫'
          : '等待 ${g.name(turn)} 叫分…';
    } else if (phase == 'setup_declarers') {
      statusText = isMyTurn
          ? '你是庄家！请选 6 张底牌埋底，指定主花色与呼叫的朋友牌'
          : '等待庄家 ${g.name(declarer)} 埋底定主并找朋友…';
    } else {
      statusText = isMyTurn
          ? '轮到你出牌（主花色 ${zpySuitNames[trumpSuit] ?? trumpSuit} · 朋友牌 $friendCard）'
          : '等待 ${g.name(turn)} 出牌…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final compact = h < 460 || w < 460;
      final cardW = compact ? 38.0 : 48.0;

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
                    _chip(
                      cs,
                      '第 $round/$totalRounds 局 · 庄家: ${g.name(declarer)} ($contract分 · 闲家目标$defenderTarget分)',
                    ),
                    if (phase == 'play')
                      _chip(
                        cs,
                        '主花色: ${zpySuitNames[trumpSuit] ?? trumpSuit} · 朋友牌: $friendCard '
                        '(${friendRevealed && revealedFriendSeat != null ? "已亮明:${g.name(revealedFriendSeat)}" : (amSecretFriend ? "你是暗伙伴!" : "身份未亮明")})',
                        highlight: true,
                      ),
                    StatusBar(statusText, highlight: isMyTurn),
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
                        active: !g.over && s == turn,
                        size: compact ? 28 : 34,
                        sub: '${s == declarer ? "[庄] " : (friendRevealed && s == revealedFriendSeat ? "[友] " : "")}'
                            '抓${capturedPoints[s]}分 · 手牌${handCounts[s]} · 总${scores[s]}',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center table area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (phase == 'bid')
                            _buildBiddingPanel(cs, currentBid, isMyTurn, compact),
                          if (phase == 'setup_declarers')
                            _buildSetupDeclarersPanel(
                              cs,
                              hand,
                              isMyTurn,
                              compact,
                            ),
                          if (phase == 'play')
                            _buildTrickTable(
                              cs,
                              trickNumber,
                              currentTrick,
                              lastTrick,
                              actionLog,
                              compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom hand
                if (hand.isNotEmpty) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          phase == 'setup_declarers' && isMyTurn
                              ? '庄家手牌（点击选择 6 张埋底，已选 ${_selectedBury.length}/6 张）：'
                              : '我的手牌（${hand.length}张 · 5=5分, 10=10分, K=10分）：',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        OverlapRow(
                          itemWidth: cardW,
                          maxSpacing: 1.05,
                          children: [
                            for (final c in hand)
                              Builder(builder: (_) {
                                final canPlay =
                                    isMyTurn && phase == 'play' && legalCards.contains(c);
                                final isBurySel = _selectedBury.contains(c);
                                return PlayingCard(
                                  c,
                                  width: cardW,
                                  selected: isBurySel || c == friendCard,
                                  dim: isMyTurn &&
                                      phase == 'play' &&
                                      !legalCards.contains(c),
                                  onTap: (isMyTurn && phase == 'setup_declarers')
                                      ? () {
                                          setState(() {
                                            if (_selectedBury.contains(c)) {
                                              _selectedBury.remove(c);
                                            } else if (_selectedBury.length < 6) {
                                              _selectedBury.add(c);
                                            }
                                          });
                                        }
                                      : (canPlay
                                          ? () => g.act({'type': 'play', 'card': c})
                                          : null),
                                );
                              }),
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

  Widget _buildBiddingPanel(
    ColorScheme cs,
    int currentBid,
    bool isMyTurn,
    bool compact,
  ) {
    final g = widget.g;
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '叫分争庄（当前最高叫分：$currentBid 分）',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          if (isMyTurn)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final b in zpyValidBids)
                  if (b > currentBid)
                    FilledButton(
                      onPressed: () => g.act({'type': 'bid', 'score': b}),
                      child: Text('$b 分'),
                    ),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'pass'}),
                  child: const Text('不叫 (Pass)'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSetupDeclarersPanel(
    ColorScheme cs,
    List<String> hand,
    bool isMyTurn,
    bool compact,
  ) {
    final g = widget.g;
    final defaultBury = _selectedBury.length == 6
        ? _selectedBury.toList()
        : hand.reversed.take(6).toList();

    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '庄家定主与呼叫朋友牌',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          if (isMyTurn) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final s in zpySuits)
                  ChoiceChip(
                    label: Text('主:${zpySuitNames[s]}'),
                    selected: _selectedTrump == s,
                    onSelected: (_) => setState(() => _selectedTrump = s),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final fc in kZpyCandidateFriends.take(8))
                  ChoiceChip(
                    label: Text('找:$fc'),
                    selected: _selectedFriend == fc,
                    onSelected: (_) => setState(() => _selectedFriend = fc),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: hand.length >= 6
                  ? () {
                      final cards = defaultBury;
                      setState(() => _selectedBury.clear());
                      g.act({
                        'type': 'bury',
                        'cards': cards,
                        'trumpSuit': _selectedTrump,
                        'friendCard': _selectedFriend,
                      });
                    }
                  : null,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(
                '确认埋底 (${_selectedBury.length == 6 ? "已选6张" : "自动选末6张"}) · 主${zpySuitNames[_selectedTrump]} · 找$_selectedFriend',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrickTable(
    ColorScheme cs,
    int trickNumber,
    List<Map> currentTrick,
    List<Map> lastTrick,
    List<String> actionLog,
    bool compact,
  ) {
    final g = widget.g;
    final displayTrick = currentTrick.isNotEmpty ? currentTrick : lastTrick;

    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentTrick.isNotEmpty
                ? '第 $trickNumber/12 墩桌面出牌：'
                : '上一墩回顾（第 $trickNumber/12 墩准备领出）：',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (displayTrick.isEmpty)
            const Text(
              '等待庄家领出第一张牌…',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final e in displayTrick)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlayingCard(
                        '${e['card']}',
                        width: compact ? 38 : 46,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        g.name((e['seat'] as num).toInt()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          if (actionLog.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              actionLog.first,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5),
              textAlign: TextAlign.center,
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
