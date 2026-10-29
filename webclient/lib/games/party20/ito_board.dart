import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ItoBoard extends StatefulWidget {
  final GameContext g;
  const ItoBoard(this.g, {super.key});

  @override
  State<ItoBoard> createState() => _ItoBoardState();
}

class _ItoBoardState extends State<ItoBoard> {
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

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 3;
    final lives = (v['lives'] as num?)?.toInt() ?? 3;
    final maxLives = (v['maxLives'] as num?)?.toInt() ?? 3;
    final phase = v['phase'] as String? ?? 'clue';
    final theme = v['theme'] as String? ?? '';
    final lowLabel = v['lowLabel'] as String? ?? '1=最小';
    final highLabel = v['highLabel'] as String? ?? '100=最大';
    final scale = (v['scale'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final mySecretNumber = (v['mySecretNumber'] as num?)?.toInt() ?? -1;
    final secretNumbers = (v['secretNumbers'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, -1);
    final cardPlayed = (v['cardPlayed'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(g.players, false);
    final clues = (v['clues'] as Map?) ?? const {};
    final playedCards = (v['playedCards'] as List?) ?? const [];
    final nominatedSeat = (v['nominatedSeat'] as num?)?.toInt() ?? -1;
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final teamScore = (v['teamScore'] as num?)?.toInt() ?? 0;
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canClue = v['canClue'] == true && !g.over;
    final canPlay = v['canPlay'] == true && !g.over;

    final hearts = '${'❤️' * lives}${'🖤' * (maxLives - lives).clamp(0, 10)}';

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '糸：数字共鸣 — 终局结算（团队 $teamScore 分）'
                          : '第 $round/$totalRounds 轮 · $hearts · ${phase == "clue" ? "💬比喻线索阶段" : "🃏升序共鸣亮牌 (1→100)"}',
                      highlight: canClue || canPlay,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.9)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Theme Spectrum Card + Secret Number Badge
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '🎯 本轮共鸣主题：【$theme】',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            if (mySecretNumber > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '🔒 你的秘密数字: $mySecretNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text('⬅️ 最小端：$lowLabel', style: const TextStyle(fontSize: 11)),
                            Text('➡️ 最大端：$highLabel', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        if (scale.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (var i = 0; i < scale.length; i++)
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: canClue
                                      ? () => g.act({'type': 'clue', 'text': '标准的${scale[i]}'})
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${i * 10 + 1}~${(i + 1) * 10}: ${scale[i]}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Phase 1: Clue Input Panel
                  if (canClue)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _clueCtrl,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '输入比喻线索（严禁含数字0-9）',
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          FilledButton(
                            onPressed: () {
                              final txt = _clueCtrl.text.trim();
                              if (txt.isNotEmpty) {
                                g.act({'type': 'clue', 'text': txt});
                                _clueCtrl.clear();
                              }
                            },
                            child: const Text('💬 提交共鸣线索', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  // Phase 2: Ascending Play & Nomination Controls
                  if (canPlay)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: () => g.act({'type': 'play_card'}),
                            child: Text(
                              '🃏 亮出我的数字牌 ($mySecretNumber)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          for (var s = 0; s < g.players; s++)
                            if (s != g.seat && s < cardPlayed.length && !cardPlayed[s])
                              FilledButton.tonal(
                                onPressed: () => g.act({'type': 'nominate', 'target': s}),
                                child: Text(
                                  '👉 提议 ${g.name(s)} 先亮牌',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // All Players' Clues & Card Status
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🧶 全员比喻线索与亮牌状态（升序已亮 ${playedCards.length}/${g.players} 张）',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var s = 0; s < g.players; s++)
                              Builder(builder: (context) {
                                final clueTxt = clues['$s'] as String?;
                                final played = s < cardPlayed.length && cardPlayed[s];
                                final secNum = s < secretNumbers.length ? secretNumbers[s] : -1;
                                final isNominated = phase == 'play' && nominatedSeat == s && !played;

                                return Container(
                                  width: 150,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: played
                                        ? cs.primaryContainer.withValues(alpha: 0.65)
                                        : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isNominated
                                          ? cs.primary
                                          : cs.outline.withValues(alpha: 0.3),
                                      width: isNominated ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${g.name(s)}${isNominated ? " 👈推荐" : ""}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        clueTxt != null ? '「$clueTxt」' : '⏳ 思考线索中…',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: cs.primary),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        played
                                            ? '🔓 已亮出: $secNum'
                                            : (secNum > 0 ? '🔒 秘密数字: $secNum' : '🔒 未亮牌'),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: !g.over &&
                              ((phase == 'clue' && !clues.containsKey('$s')) ||
                                  (phase == 'play' && nominatedSeat == s)),
                          sub: '⭐${s < scores.length ? scores[s] : 0}分',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '糸：数字共鸣结束'),
            ),
        ],
      ),
    );
  }
}
