import 'dart:math';

import 'package:aurora_shared/games/party6/defs.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class DixitBoard extends StatefulWidget {
  final GameContext g;
  const DixitBoard(this.g, {super.key});

  @override
  State<DixitBoard> createState() => _DixitBoardState();
}

class _DixitBoardState extends State<DixitBoard> {
  int _selectedCard = -1;
  final TextEditingController _clueCtrl = TextEditingController();

  @override
  void dispose() {
    _clueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'story';
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final storyteller = (v['storyteller'] as num?)?.toInt() ?? 0;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 30;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final clue = (v['clue'] as String?) ?? '';
    final hand = (v['hand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final mySubmitted = (v['mySubmitted'] as num?)?.toInt();
    final myVote = (v['myVote'] as num?)?.toInt();
    final pool = (v['pool'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final lastRound = v['lastRound'] as Map?;
    final result = v['result'] as String?;

    final isStoryteller = g.seat == storyteller;
    final statusText = switch (phase) {
      'story' => isStoryteller ? '第 $round 轮：你是本轮说书人！请选一张画牌并输入诗意提示语' : '第 $round 轮：等待说书人 ${g.name(storyteller)} 挑选画牌并给出提示语…',
      'submit' => isStoryteller
          ? '提示语「$clue」已公布，等待其他玩家交出混淆画牌…'
          : (mySubmitted != null ? '你已交出画牌，等待其他玩家…' : '说书人妙语：「$clue」——请从手牌挑选一张最契合的画牌交出'),
      'vote' => isStoryteller
          ? '全员画牌已展示，等待其他玩家投票猜哪张是你的画牌…'
          : (myVote != null ? '你已投票，等待其他玩家…' : '说书人妙语：「$clue」——请点击桌上画牌投票找出说书人的牌！'),
      _ => result ?? '游戏结束',
    };

    return Container(
      color: g.table,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
            final cardW = compact ? 92.0 : 120.0;
            final cardH = compact ? 132.0 : 168.0;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 6 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: status + target & deck info
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBar(statusText, highlight: (phase == 'story' && isStoryteller) || (phase != 'story' && !isStoryteller)),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('第 $round 轮 · 目标 $targetScore 分 · 牌库余 $deckCount 张', style: const TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Scoreboard
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var s = 0; s < g.players; s++)
                            g.tag(
                              s,
                              active: s == storyteller,
                              size: compact ? 28 : 32,
                              sub: '${s == storyteller ? "📖说书人 · " : ""}${s < scores.length ? scores[s] : 0} 分',
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Clue Banner + Table Pool (when in submit / vote)
                      if (clue.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '✨ 本轮说书人（${g.name(storyteller)}）的妙语：「$clue」',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 13 : 15, color: cs.onPrimaryContainer),
                          ),
                        ),

                      if (pool.isNotEmpty) ...[
                        Text(
                          phase == 'vote' && !isStoryteller && myVote == null
                              ? '🃏 展示区的梦境画牌（点击一张非自己的画牌进行投票）：'
                              : '🃏 展示区的梦境画牌：',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final cId in pool)
                              _DixitDreamCardWidget(
                                cardId: cId,
                                width: cardW,
                                height: cardH,
                                selected: myVote == cId,
                                badge: mySubmitted == cId ? '我的牌' : (myVote == cId ? '已投✓' : null),
                                dim: mySubmitted == cId && phase == 'vote',
                                onTap: (!g.over && !g.spectator && phase == 'vote' && !isStoryteller && myVote == null && mySubmitted != cId)
                                    ? () => g.act({'type': 'vote', 'card': cId})
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Storyteller input or Non-storyteller submit button
                      if (!g.over && !g.spectator) ...[
                        if (phase == 'story' && isStoryteller)
                          _buildStorytellerPanel(g, cs, hand, compact),
                        if (phase == 'submit' && !isStoryteller && mySubmitted == null)
                          _buildSubmitPanel(g, cs, hand),
                      ],

                      // My Hand of 6 Dream Cards
                      if (hand.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '🎨 我的手牌（共 ${hand.length} 张）：',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final cId in hand)
                              _DixitDreamCardWidget(
                                cardId: cId,
                                width: cardW,
                                height: cardH,
                                selected: _selectedCard == cId,
                                onTap: () => setState(() {
                                  _selectedCard = _selectedCard == cId ? -1 : cId;
                                  if (phase == 'story' && isStoryteller && _selectedCard >= 0 && _clueCtrl.text.trim().isEmpty) {
                                    _clueCtrl.text = kDixitCards[_selectedCard].clues.first;
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],

                      // Last Round Settlement Summary
                      if (lastRound != null) ...[
                        const SizedBox(height: 8),
                        _buildLastRoundSummary(g, cs, lastRound),
                      ],
                    ],
                  ),
                ),
                if (g.over && result != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ResultBanner(result),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStorytellerPanel(GameContext g, ColorScheme cs, List<int> hand, bool compact) {
    final activeCard = hand.contains(_selectedCard) ? _selectedCard : (hand.isNotEmpty ? hand.first : -1);
    final presetClues = activeCard >= 0 ? kDixitCards[activeCard].clues : const <String>[];

    return Card(
      color: cs.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeCard >= 0
                  ? '📖 已选画牌：《${kDixitCards[activeCard].title}》——请输入一句诗意提示语：'
                  : '📖 请先从下方手牌点击选择一张画牌：',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _clueCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '输入诗意提示语（如：银河里的漂流者）…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: activeCard >= 0
                      ? () {
                          final txt = _clueCtrl.text.trim().isNotEmpty
                              ? _clueCtrl.text.trim()
                              : kDixitCards[activeCard].clues.first;
                          g.act({'type': 'story', 'card': activeCard, 'clue': txt});
                          _clueCtrl.clear();
                          setState(() => _selectedCard = -1);
                        }
                      : null,
                  icon: const Icon(Icons.auto_stories, size: 16),
                  label: const Text('出牌并公布妙语'),
                ),
              ],
            ),
            if (presetClues.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Text('灵感推荐：', style: TextStyle(fontSize: 11.5)),
                  for (final cl in presetClues)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(cl, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _clueCtrl.text = cl),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitPanel(GameContext g, ColorScheme cs, List<int> hand) {
    final activeCard = hand.contains(_selectedCard) ? _selectedCard : -1;
    return Card(
      color: cs.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              activeCard >= 0
                  ? '已选中《${kDixitCards[activeCard].title}》作为本轮混淆画牌'
                  : '请从下方手牌点击选中一张最契合提示语的画牌交出',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            FilledButton.icon(
              onPressed: activeCard >= 0
                  ? () {
                      g.act({'type': 'submit', 'card': activeCard});
                      setState(() => _selectedCard = -1);
                    }
                  : null,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('交出选中画牌'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastRoundSummary(GameContext g, ColorScheme cs, Map lastRound) {
    final rNum = (lastRound['round'] as num?)?.toInt() ?? 1;
    final st = (lastRound['storyteller'] as num?)?.toInt() ?? 0;
    final stCard = (lastRound['storyCard'] as num?)?.toInt() ?? 0;
    final cl = (lastRound['clue'] as String?) ?? '';
    final summary = (lastRound['summary'] as String?) ?? '';
    final delta = (lastRound['delta'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];

    final deltaStr = [
      for (var s = 0; s < g.players && s < delta.length; s++)
        if (delta[s] > 0) '${g.name(s)} +${delta[s]}',
    ].join('，');

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '📜 第 $rNum 轮回顾：说书人 ${g.name(st)} 的「$cl」对应真牌《${kDixitCards[stCard % 72].title}》——$summary（得分：$deltaStr）',
        style: const TextStyle(fontSize: 11.5),
      ),
    );
  }
}

class _DixitDreamCardWidget extends StatelessWidget {
  final int cardId;
  final double width;
  final double height;
  final bool selected;
  final bool dim;
  final String? badge;
  final VoidCallback? onTap;

  const _DixitDreamCardWidget({
    required this.cardId,
    required this.width,
    required this.height,
    this.selected = false,
    this.dim = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = kDixitCards[cardId % kDixitCards.length];
    final cs = Theme.of(context).colorScheme;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.amberAccent : Colors.white54,
          width: selected ? 3 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: selected ? Colors.amber.withValues(alpha: 0.45) : Colors.black26,
            blurRadius: selected ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _DixitDreamCardPainter(card),
            ),
            // Card Title & Tags overlay at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.tags.take(3).join(' · '),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Card ID number top-left
            Positioned(
              left: 5,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${card.id + 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(color: cs.onPrimary, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (dim) {
      content = Opacity(opacity: 0.55, child: content);
    }
    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

class _DixitDreamCardPainter extends CustomPainter {
  final DixitCard card;
  const _DixitDreamCardPainter(this.card);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(card.colorA), Color(card.colorB)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Draw stars / sparkles deterministically from card.id
    final rng = Random(card.id * 97 + 13);
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (var i = 0; i < 14; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * (size.height * 0.72);
      final sr = 0.8 + rng.nextDouble() * 1.8;
      canvas.drawCircle(Offset(sx, sy), sr, starPaint);
    }

    final cx = size.width * 0.5;
    final cy = size.height * 0.42;
    final r = min(size.width, size.height) * 0.28;

    // Soft glowing aura behind central motif
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(cx, cy), r * 1.25, glowPaint);

    final fg = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fill = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;

    switch (card.motif) {
      case 'moon_boat':
        canvas.drawCircle(Offset(cx, cy - r * 0.2), r * 0.65, fill);
        final boat = Path()
          ..moveTo(cx - r * 0.8, cy + r * 0.35)
          ..quadraticBezierTo(cx, cy + r * 0.9, cx + r * 0.8, cy + r * 0.35)
          ..close();
        canvas.drawPath(boat, fg..style = PaintingStyle.fill);
        break;
      case 'hourglass':
        final path = Path()
          ..moveTo(cx - r * 0.6, cy - r * 0.8)
          ..lineTo(cx + r * 0.6, cy - r * 0.8)
          ..lineTo(cx - r * 0.6, cy + r * 0.8)
          ..lineTo(cx + r * 0.6, cy + r * 0.8)
          ..close();
        canvas.drawPath(path, fg);
        canvas.drawCircle(Offset(cx, cy), 3, fill);
        break;
      case 'sky_stairs':
        for (var i = 0; i < 5; i++) {
          final sx = cx - r * 0.7 + i * (r * 0.28);
          final sy = cy + r * 0.6 - i * (r * 0.26);
          canvas.drawRect(Rect.fromLTWH(sx, sy, r * 0.45, 4), fill);
        }
        break;
      case 'forest_lantern':
        canvas.drawLine(Offset(cx, cy - r * 0.9), Offset(cx, cy - r * 0.3), fg);
        canvas.drawCircle(Offset(cx, cy), r * 0.42, fill);
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: r * 0.7, height: r * 0.9), fg);
        break;
      case 'whale_stars':
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: r * 1.5, height: r * 0.75), fill);
        canvas.drawCircle(Offset(cx - r * 0.4, cy - r * 0.05), 2.5, Paint()..color = Colors.black87);
        break;
      case 'mask_mirror':
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: r * 1.1, height: r * 1.4), fg);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx - r * 0.25, cy - r * 0.1), width: r * 0.3, height: r * 0.18), fill);
        canvas.drawOval(Rect.fromCenter(center: Offset(cx + r * 0.25, cy - r * 0.1), width: r * 0.3, height: r * 0.18), fill);
        break;
      case 'rose_key':
        for (var i = 0; i < 6; i++) {
          final ang = i * pi / 3;
          canvas.drawCircle(Offset(cx + cos(ang) * r * 0.35, cy + sin(ang) * r * 0.35), r * 0.32, fg);
        }
        canvas.drawCircle(Offset(cx, cy), r * 0.28, fill);
        break;
      case 'clock_tower':
        canvas.drawCircle(Offset(cx, cy), r * 0.8, fg);
        canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r * 0.55), fg);
        canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.4, cy + r * 0.15), fg);
        break;
      case 'lighthouse':
        final tower = Path()
          ..moveTo(cx - r * 0.25, cy - r * 0.6)
          ..lineTo(cx + r * 0.25, cy - r * 0.6)
          ..lineTo(cx + r * 0.45, cy + r * 0.8)
          ..lineTo(cx - r * 0.45, cy + r * 0.8)
          ..close();
        canvas.drawPath(tower, fg);
        canvas.drawCircle(Offset(cx, cy - r * 0.7), r * 0.25, fill);
        break;
      default:
        canvas.drawCircle(Offset(cx, cy), r * 0.65, fill);
        canvas.drawCircle(Offset(cx, cy), r * 0.85, fg);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DixitDreamCardPainter oldDelegate) => oldDelegate.card.id != card.id;
}
