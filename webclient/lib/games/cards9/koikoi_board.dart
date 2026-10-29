import 'package:aurora_shared/games/cards9/koikoi.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class KoiKoiBoard extends StatefulWidget {
  final GameContext g;
  const KoiKoiBoard(this.g, {super.key});

  @override
  State<KoiKoiBoard> createState() => _KoiKoiBoardState();
}

class _KoiKoiBoardState extends State<KoiKoiBoard> {
  int? _selectedHandCard;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  List<int> _intList(Object? raw) =>
      raw is List ? [for (final x in raw) (x as num).toInt()] : const [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 6;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final step = (v['step'] as String?) ?? 'hand';
    final field = _intList(v['field']);
    final stockCount = (v['stockCount'] as num?)?.toInt() ?? 0;
    final drawnCard = (v['drawnCard'] as num?)?.toInt();
    final myHand = _intList(v['myHand']);
    final handCounts = _intList(v['handCounts']);
    final scores = _intList(v['scores']);
    final yakuPoints = _intList(v['yakuPoints']);
    final calledKoiRaw = v['calledKoiKoi'];
    final calledKoi = calledKoiRaw is List
        ? [for (final b in calledKoiRaw) b == true]
        : [false, false];

    final capturedRaw = v['captured'] as List? ?? const [[], []];
    final captured = [
      _intList(capturedRaw.isNotEmpty ? capturedRaw[0] : const []),
      _intList(capturedRaw.length > 1 ? capturedRaw[1] : const []),
    ];

    final yakusRaw = v['yakus'] as List? ?? const [[], []];
    List<Map<String, dynamic>> parseYakus(int s) {
      if (s >= yakusRaw.length || yakusRaw[s] is! List) return const [];
      return [
        for (final item in yakusRaw[s] as List)
          if (item is Map) item.cast<String, dynamic>(),
      ];
    }

    final mySeat = g.seat >= 0 && g.seat < 2 ? g.seat : 0;
    final oppSeat = 1 - mySeat;
    final isMyTurn = !g.spectator && !g.over && turn == g.seat;

    if (_selectedHandCard != null && !myHand.contains(_selectedHandCard)) {
      _selectedHandCard = null;
    }

    // Determine highlighted field cards
    final Set<int> matchingFieldCards = {};
    if (isMyTurn && step == 'stock' && drawnCard != null) {
      final m = hanafudaMonth(drawnCard);
      for (final f in field) {
        if (hanafudaMonth(f) == m) matchingFieldCards.add(f);
      }
    } else if (isMyTurn && step == 'hand' && _selectedHandCard != null) {
      final m = hanafudaMonth(_selectedHandCard!);
      for (final f in field) {
        if (hanafudaMonth(f) == m) matchingFieldCards.add(f);
      }
    }

    String statusText;
    if (g.over) {
      statusText = '对局结束';
    } else if (step == 'koikoi') {
      statusText = isMyTurn
          ? '你达成了新役种！请选择「胜负」立即收分或「来来」冲击翻倍'
          : '等待 ${g.name(turn)} 选择「胜负」或「来来」…';
    } else if (step == 'stock') {
      statusText = isMyTurn
          ? '山牌翻出 ${drawnCard != null ? hanafudaInfo(drawnCard).name : ''}，请点击场上高亮的同月牌配对'
          : '等待 ${g.name(turn)} 选择山牌配对…';
    } else {
      statusText = isMyTurn
          ? (_selectedHandCard != null
              ? '请点击场上高亮的同月花札配对（或再次点击手牌直接打出）'
              : '轮到你出牌：点击手牌配对捕获同月场牌')
          : '轮到 ${g.name(turn)} 出牌';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 460 || w < 440;
          final cardW = compact ? 42.0 : 54.0;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(compact ? 6 : 10),
                child: Column(
                  children: [
                    // Header: StatusBar & Round badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '第 $round / $maxRounds 月 · ${kHanafudaMonthFlowers[(round - 1) % 12]}',
                            style: TextStyle(
                              fontSize: compact ? 11 : 13,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // Opponent Panel
                    _buildPlayerPanel(
                      context,
                      seat: oppSeat,
                      active: !g.over && turn == oppSeat,
                      score: oppSeat < scores.length ? scores[oppSeat] : 0,
                      yakuPts: oppSeat < yakuPoints.length ? yakuPoints[oppSeat] : 0,
                      koi: oppSeat < calledKoi.length && calledKoi[oppSeat],
                      handCount: oppSeat < handCounts.length ? handCounts[oppSeat] : 0,
                      capturedCards: captured[oppSeat],
                      yakus: parseYakus(oppSeat),
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 4 : 8),

                    // Center Field Area + Stock + Koi-Koi Decision Banner
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 6 : 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (step == 'koikoi' && isMyTurn)
                                _buildKoiKoiDecisionCard(
                                  context,
                                  yakus: parseYakus(mySeat),
                                  basePts: mySeat < yakuPoints.length ? yakuPoints[mySeat] : 0,
                                  oppCalledKoi: oppSeat < calledKoi.length && calledKoi[oppSeat],
                                  compact: compact,
                                ),
                              Wrap(
                                spacing: compact ? 6 : 10,
                                runSpacing: compact ? 6 : 10,
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Stock pile
                                  _buildStockWidget(stockCount, drawnCard, cardW),
                                  // Field cards
                                  for (final fCard in field)
                                    HanafudaCardWidget(
                                      cardId: fCard,
                                      width: cardW,
                                      highlight: matchingFieldCards.contains(fCard),
                                      onTap: isMyTurn && matchingFieldCards.contains(fCard)
                                          ? () => _onFieldCardTap(fCard, step)
                                          : null,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 8),

                    // My Captured Panel
                    _buildPlayerPanel(
                      context,
                      seat: mySeat,
                      active: !g.over && turn == mySeat,
                      score: mySeat < scores.length ? scores[mySeat] : 0,
                      yakuPts: mySeat < yakuPoints.length ? yakuPoints[mySeat] : 0,
                      koi: mySeat < calledKoi.length && calledKoi[mySeat],
                      handCount: mySeat < handCounts.length ? handCounts[mySeat] : 0,
                      capturedCards: captured[mySeat],
                      yakus: parseYakus(mySeat),
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 4 : 6),

                    // My Hand Row
                    if (!g.spectator && myHand.isNotEmpty)
                      SizedBox(
                        height: cardW * 1.58,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final c in myHand)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: HanafudaCardWidget(
                                    cardId: c,
                                    width: cardW,
                                    selected: _selectedHandCard == c,
                                    highlight: isMyTurn &&
                                        step == 'hand' &&
                                        field.any((f) => hanafudaMonth(f) == hanafudaMonth(c)),
                                    onTap: isMyTurn && step == 'hand'
                                        ? () => _onHandCardTap(c, field)
                                        : null,
                                  ),
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
                    _buildOverTitle(scores),
                    child: Text(
                      '${g.name(0)}: ${scores.isNotEmpty ? scores[0] : 0} 文   |   '
                      '${g.name(1)}: ${scores.length > 1 ? scores[1] : 0} 文',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _onHandCardTap(int cardId, List<int> field) {
    final m = hanafudaMonth(cardId);
    final matches = field.where((f) => hanafudaMonth(f) == m).toList();
    if (matches.length == 2) {
      if (_selectedHandCard == cardId) {
        g.act({'type': 'play_hand', 'card': cardId, 'match': matches.first});
        setState(() => _selectedHandCard = null);
      } else {
        setState(() => _selectedHandCard = cardId);
      }
      return;
    }
    setState(() => _selectedHandCard = null);
    g.act({
      'type': 'play_hand',
      'card': cardId,
      if (matches.length == 1) 'match': matches.first,
    });
  }

  void _onFieldCardTap(int fieldCard, String step) {
    if (step == 'stock') {
      g.act({'type': 'match_stock', 'match': fieldCard});
      return;
    }
    if (step == 'hand' && _selectedHandCard != null) {
      final hCard = _selectedHandCard!;
      setState(() => _selectedHandCard = null);
      g.act({'type': 'play_hand', 'card': hCard, 'match': fieldCard});
    }
  }

  String _buildOverTitle(List<int> scores) {
    if (scores.length < 2) return '对局结束';
    if (scores[0] > scores[1]) return '${g.name(0)} 获胜！';
    if (scores[1] > scores[0]) return '${g.name(1)} 获胜！';
    return '平局！';
  }

  Widget _buildStockWidget(int stockCount, int? drawnCard, double cardW) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: cardW,
          height: cardW * 1.48,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.shade700, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers, color: Colors.amber, size: 18),
                  const Text('山牌', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Text(
                    '$stockCount',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (drawnCard != null) ...[
          const SizedBox(width: 6),
          HanafudaCardWidget(
            cardId: drawnCard,
            width: cardW,
            selected: true,
            highlight: true,
          ),
        ],
      ],
    );
  }

  Widget _buildKoiKoiDecisionCard(
    BuildContext context, {
    required List<Map<String, dynamic>> yakus,
    required int basePts,
    required bool oppCalledKoi,
    required bool compact,
  }) {
    var finalPts = basePts;
    if (basePts >= 7) finalPts *= 2;
    if (oppCalledKoi) finalPts *= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3E1F14).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '达成役种：${yakus.map((y) => '${y['name']}(${y['points']})').join(' + ')} → 结算可得 $finalPts 文',
            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          FilledButton.icon(
            onPressed: () => g.act({'type': 'shobu'}),
            icon: const Icon(Icons.emoji_events, size: 16),
            label: Text('胜负 (收 $finalPts 文)'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orangeAccent,
              side: const BorderSide(color: Colors.orangeAccent),
            ),
            onPressed: () => g.act({'type': 'koikoi'}),
            icon: const Icon(Icons.local_fire_department, size: 16),
            label: const Text('来来 (Koi-Koi)'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel(
    BuildContext context, {
    required int seat,
    required bool active,
    required int score,
    required int yakuPts,
    required bool koi,
    required int handCount,
    required List<int> capturedCards,
    required List<Map<String, dynamic>> yakus,
    required bool compact,
  }) {
    final brights = capturedCards.where(kBrightCards.contains).toList();
    final animals = capturedCards.where(kAnimalCards.contains).toList();
    final ribbons = capturedCards.where(kRibbonCards.contains).toList();
    final chaffs = capturedCards.where(isChaffOrSakeCup).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: g.tag(
                  seat,
                  active: active,
                  size: compact ? 28 : 34,
                  sub: '总分 $score 文 · 手牌 $handCount',
                ),
              ),
              if (koi) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '来来!',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  alignment: WrapAlignment.end,
                  children: [
                    _catPill('光 ${brights.length}', Colors.amber.shade700),
                    _catPill('种 ${animals.length}', Colors.teal.shade700),
                    _catPill('短 ${ribbons.length}', Colors.pink.shade700),
                    _catPill('粕 ${chaffs.length}', Colors.blueGrey.shade700),
                    if (yakuPts > 0)
                      _catPill('役 $yakuPts文', Colors.redAccent.shade700),
                  ],
                ),
              ),
            ],
          ),
          if (capturedCards.isNotEmpty) ...[
            const SizedBox(height: 3),
            SizedBox(
              height: compact ? 34 : 42,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in capturedCards)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: HanafudaCardWidget(
                          cardId: c,
                          width: compact ? 22 : 27,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _catPill(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Custom-rendered Japanese Hanafuda card widget with seasonal motifs.
class HanafudaCardWidget extends StatelessWidget {
  final int cardId;
  final double width;
  final bool selected;
  final bool highlight;
  final VoidCallback? onTap;

  const HanafudaCardWidget({
    super.key,
    required this.cardId,
    this.width = 48,
    this.selected = false,
    this.highlight = false,
    this.onTap,
  });

  static const List<Color> _monthColors = [
    Color(0xFF2E7D32), // 1月 松 Pine Green
    Color(0xFFC2185B), // 2月 梅 Plum Crimson
    Color(0xFFF06292), // 3月 樱 Cherry Pink
    Color(0xFF7B1FA2), // 4月 藤 Wisteria Purple
    Color(0xFF303F9F), // 5月 菖蒲 Iris Indigo
    Color(0xFFD32F2F), // 6月 牡丹 Peony Red
    Color(0xFFE64A19), // 7月 萩 Bush Clover Orange
    Color(0xFF1565C0), // 8月 芒 Susuki Moon Blue
    Color(0xFFF9A825), // 9月 菊 Chrysanthemum Gold
    Color(0xFFC62828), // 10月 枫 Maple Autumn Red
    Color(0xFF00838F), // 11月 柳 Willow Rain Teal
    Color(0xFF4A148C), // 12月 桐 Paulownia Imperial Violet
  ];

  @override
  Widget build(BuildContext context) {
    final info = hanafudaInfo(cardId);
    final h = width * 1.48;
    final mColor = _monthColors[(info.month - 1) % 12];

    Color catColor;
    String catLabel;
    switch (info.category) {
      case 'bright':
        catColor = const Color(0xFFFFB300);
        catLabel = '光';
        break;
      case 'animal':
        catColor = const Color(0xFF00897B);
        catLabel = cardId == kSakeCupCard ? '盃' : '种';
        break;
      case 'ribbon':
        if (info.ribbonKind == 'red_poetry') {
          catColor = const Color(0xFFD32F2F);
          catLabel = '赤短';
        } else if (info.ribbonKind == 'blue') {
          catColor = const Color(0xFF1976D2);
          catLabel = '青短';
        } else {
          catColor = const Color(0xFFE91E63);
          catLabel = '短';
        }
        break;
      default:
        catColor = const Color(0xFF78909C);
        catLabel = '粕';
    }

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -width * 0.2 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(
          color: selected
              ? Colors.amberAccent
              : (highlight ? Colors.greenAccent : const Color(0xFF212121)),
          width: selected || highlight ? 2.2 : 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? Colors.amber.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: highlight ? 6 : 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.09),
        child: Column(
          children: [
            // Top Month Banner
            Container(
              width: double.infinity,
              color: mColor,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${info.month}月·${info.flower}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            // Center Floral Artwork & Category Badge
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: catColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          catLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        _iconForCard(info),
                        color: mColor,
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.name,
                        style: const TextStyle(
                          color: Color(0xFF212121),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
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

    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }

  IconData _iconForCard(HanafudaCardInfo info) {
    if (info.id == kMoonCard) return Icons.nightlight_round;
    if (info.id == kSakeCupCard) return Icons.wine_bar;
    switch (info.category) {
      case 'bright':
        return Icons.wb_sunny;
      case 'animal':
        return Icons.pets;
      case 'ribbon':
        return Icons.bookmark;
      default:
        return Icons.local_florist;
    }
  }
}
