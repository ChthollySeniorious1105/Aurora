import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class SpicyBoard extends StatefulWidget {
  final GameContext g;
  const SpicyBoard(this.g, {super.key});

  @override
  State<SpicyBoard> createState() => _SpicyBoardState();
}

class _SpicyBoardState extends State<SpicyBoard> {
  int _selectedCardIdx = 0;
  String _claimSpice = 'chili';
  int _claimNum = 1;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final stackCount = (v['stackCount'] as num?)?.toInt() ?? 0;
    final topSpice = v['topClaimSpice'] as String?;
    final topNum = (v['topClaimNum'] as num?)?.toInt();
    final lastPlayer = (v['lastPlayer'] as num?)?.toInt();
    final trophiesLeft = (v['trophiesLeft'] as num?)?.toInt() ?? 3;
    final trophies = (v['trophies'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final wonCards = (v['wonCards'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final myHand = (v['myHand'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final lastChallenge = v['lastChallenge'] as Map<String, dynamic>?;
    final lastActionText = (v['lastActionText'] as String?) ?? '';
    final waiting = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? <int>{};
    final myTurn = waiting.contains(g.seat) && !g.over;
    final canChallenge = !g.over && g.seat >= 0 && stackCount > 0 && lastPlayer != null && lastPlayer != g.seat;

    final legalSpices = (stackCount == 0 || topSpice == null)
        ? const ['chili', 'wasabi', 'pepper']
        : [topSpice];
    final legalNums = (stackCount == 0 || topNum == null || topNum == 10)
        ? const [1, 2, 3]
        : [for (var n = topNum + 1; n <= 10; n++) n];

    final effectiveSpice = legalSpices.contains(_claimSpice) ? _claimSpice : legalSpices.first;
    final effectiveNum = legalNums.contains(_claimNum) ? _claimNum : legalNums.first;

    String statusText;
    if (g.over) {
      statusText = (v['resultText'] as String?) ?? '游戏结束';
    } else if (myTurn) {
      statusText = '轮到你行动：可暗出1张牌并宣称递增点数、摸1张牌，或质疑上家！';
    } else {
      statusText = '轮到 ${g.name(turn)} 行动 · $lastActionText';
    }

    return Container(
      color: g.table,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBar(statusText, highlight: myTurn),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _infoBadge(cs, '🃏 牌库剩余: $deckCount 张'),
                          _infoBadge(cs, '🏆 奖杯剩余: $trophiesLeft / 3'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Players Strip
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        g.tag(
                          s,
                          active: s == turn && !g.over,
                          sub: '手牌${s < handCounts.length ? handCounts[s] : 0} · '
                              '赢牌${s < wonCards.length ? wonCards[s] : 0} · '
                              '🏆×${s < trophies.length ? trophies[s] : 0} · '
                              '${s < scores.length ? scores[s] : 0}分',
                          size: 31,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Central Spice Stack & Challenge Arena
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stackCount == 0 || topSpice == null || topNum == null
                                      ? '🍽️ 中央香料牌堆为空（请以任意香料 1..3 点开牌）'
                                      : '🔥 当前牌堆（共 $stackCount 张）顶牌宣称：【${_spiceLabel(topSpice)} $topNum】',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                if (lastPlayer != null)
                                  Text(
                                    '由 ${g.name(lastPlayer)} 暗置打出 — 质疑时只检定你指定的单一属性！',
                                    style: TextStyle(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.75)),
                                  ),
                              ],
                            ),
                            if (canChallenge)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: () => g.act({'type': 'challenge', 'attr': 'spice'}),
                                    icon: const Icon(Icons.local_fire_department, size: 16),
                                    label: const Text('质疑【香料】'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => g.act({'type': 'challenge', 'attr': 'num'}),
                                    icon: const Icon(Icons.pin, size: 16),
                                    label: const Text('质疑【数字】'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (lastChallenge != null) ...[
                          const Divider(height: 14),
                          Text(
                            '⚡ 最近一次质疑：${g.name((lastChallenge['challenger'] as num).toInt())} 质疑了 '
                            '${g.name((lastChallenge['declarer'] as num).toInt())} 的'
                            '【${lastChallenge['attr'] == 'spice' ? "香料" : "数字"}】 -> '
                            '翻开实牌【${_cardDisplay(lastChallenge['actualCard'] as Map<String, dynamic>)}】，'
                            '${lastChallenge['passed'] == true ? "检定通过（实话）" : "检定失败（吹牛被抓）"}！'
                            '${g.name((lastChallenge['winner'] as num).toInt())} 收走 ${lastChallenge['wonCount']} 张牌！',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: cs.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // My Hand & Play/Draw Controls
                  if (g.seat >= 0 && g.seat < g.players && !g.over)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: myTurn ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '🃏 我的手牌 (${myHand.length} 张) — 选1张暗牌并指定宣称属性：',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (myTurn)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: myHand.isEmpty
                                          ? null
                                          : () {
                                              final idx = _selectedCardIdx.clamp(0, myHand.length - 1);
                                              setState(() => _selectedCardIdx = 0);
                                              g.act({
                                                'type': 'play',
                                                'cardIdx': idx,
                                                'spice': effectiveSpice,
                                                'num': effectiveNum,
                                              });
                                            },
                                      icon: const Icon(Icons.layers, size: 16),
                                      label: Text('暗出并宣称【${_spiceLabel(effectiveSpice)} $effectiveNum】'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => g.act({'type': 'draw'}),
                                      icon: const Icon(Icons.download, size: 16),
                                      label: const Text('摸 1 张牌'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (myHand.isEmpty)
                            const Text('当前手牌已出空！', style: TextStyle(fontSize: 12))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (var i = 0; i < myHand.length; i++)
                                  ChoiceChip(
                                    label: Text(_cardDisplay(myHand[i]), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    selected: _selectedCardIdx == i,
                                    onSelected: (_) => setState(() {
                                      _selectedCardIdx = i;
                                      final sp = myHand[i]['spice'] as String?;
                                      final numVal = (myHand[i]['num'] as num?)?.toInt();
                                      if (sp != null && legalSpices.contains(sp)) {
                                        _claimSpice = sp;
                                      }
                                      if (numVal != null && legalNums.contains(numVal)) {
                                        _claimNum = numVal;
                                      }
                                    }),
                                  ),
                              ],
                            ),
                          if (myTurn) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text('宣称香料：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                for (final sp in legalSpices)
                                  ChoiceChip(
                                    label: Text(_spiceLabel(sp)),
                                    selected: effectiveSpice == sp,
                                    onSelected: (_) => setState(() => _claimSpice = sp),
                                  ),
                                const SizedBox(width: 8),
                                const Text('宣称数字：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                for (final n in legalNums)
                                  ChoiceChip(
                                    label: Text('$n'),
                                    selected: effectiveNum == n,
                                    onSelected: (_) => setState(() => _claimNum = n),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(statusText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _spiceLabel(String s) {
    switch (s) {
      case 'chili':
        return '🌶️ 红椒';
      case 'wasabi':
        return '🟢 芥末';
      case 'pepper':
        return '⚫ 胡椒';
      default:
        return s;
    }
  }

  String _cardDisplay(Map<String, dynamic> c) {
    final t = c['type'] as String? ?? '';
    if (t == 'WILD_SPICE' || c['spice'] == 'WILD_SPICE') return '🌈 百搭香料';
    if (t == 'WILD_NUM' || c['spice'] == 'WILD_NUM') return '🔢 百搭数字';
    return '${_spiceLabel(c['spice'] as String? ?? '')} ${c['num']}';
  }
}
