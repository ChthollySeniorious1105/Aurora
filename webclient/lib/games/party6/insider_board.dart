import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class InsiderBoard extends StatefulWidget {
  final GameContext g;
  const InsiderBoard(this.g, {super.key});

  @override
  State<InsiderBoard> createState() => _InsiderBoardState();
}

class _InsiderBoardState extends State<InsiderBoard> {
  final TextEditingController _inputCtrl = TextEditingController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'qa';
    final accuseStep = (v['accuseStep'] as num?)?.toInt() ?? 1;
    final masterSeat = (v['masterSeat'] as num?)?.toInt() ?? 0;
    final insiderSeat = (v['insiderSeat'] as num?)?.toInt();
    final myRole = (v['myRole'] as String?) ?? 'common';
    final category = (v['category'] as String?) ?? '日常';
    final secretWord = v['secretWord'] as String?;
    final questionsUsed = (v['questionsUsed'] as num?)?.toInt() ?? 0;
    final maxQuestions = (v['maxQuestions'] as num?)?.toInt() ?? 20;
    final currentAsker = (v['currentAsker'] as num?)?.toInt() ?? 0;
    final pendingAsker = (v['pendingAsker'] as num?)?.toInt() ?? -1;
    final pendingQuestion = v['pendingQuestion'] as String?;
    final guesser = (v['guesser'] as num?)?.toInt() ?? -1;
    final suspectSeats = (v['suspectSeats'] as List?)?.cast<int>() ?? const <int>[];
    final qaHistory = (v['qaHistory'] as List?)?.cast<Map>() ?? const <Map>[];
    final candidateWords = (v['candidateWords'] as List?)?.cast<String>() ?? const <String>[];
    final candidateQuestions = (v['candidateQuestions'] as List?)?.cast<Map>() ?? const <Map>[];
    final result = v['result'] as String?;

    final statusText = switch (phase) {
      'qa' => pendingQuestion != null
          ? '等待主持人 ${g.name(masterSeat)} 回答 ${g.name(pendingAsker)} 的问题'
          : '问答阶段（$questionsUsed/$maxQuestions 问）：轮到 ${g.name(currentAsker)} 提问或猜词',
      'accuse' => accuseStep == 1
          ? '指认阶段·第 1 步：公投表决猜中者 ${g.name(guesser)} 是不是局内人！'
          : '指认阶段·第 2 步：在其余嫌疑人中投票抓出真正的局内人！',
      _ => result ?? '游戏结束',
    };

    return Container(
      color: g.table,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 6 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: status + role + secret word pill
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBar(statusText, highlight: phase == 'accuse'),
                          _buildRoleSecretCard(cs, myRole, category, secretWord, questionsUsed, maxQuestions),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Players strip
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var s = 0; s < g.players; s++)
                            g.tag(
                              s,
                              active: (phase == 'qa' && (pendingQuestion != null ? s == masterSeat : s == currentAsker)) ||
                                  (phase == 'accuse' && s == guesser),
                              size: compact ? 28 : 34,
                              sub: [
                                if (s == masterSeat) '👑主持人',
                                if (s == guesser) '🎯猜中者',
                                if (insiderSeat == s) '🕵️局内人',
                              ].join(' '),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Phase-specific Controls
                      if (!g.over && !g.spectator) ...[
                        if (phase == 'qa')
                          _buildQaControls(
                            g: g,
                            cs: cs,
                            masterSeat: masterSeat,
                            pendingAsker: pendingAsker,
                            pendingQuestion: pendingQuestion,
                            candidateQuestions: candidateQuestions,
                            candidateWords: candidateWords,
                            qaHistory: qaHistory,
                            compact: compact,
                          ),
                        if (phase == 'accuse')
                          _buildAccuseControls(
                            g: g,
                            cs: cs,
                            v: v,
                            accuseStep: accuseStep,
                            guesser: guesser,
                            suspectSeats: suspectSeats,
                          ),
                        const SizedBox(height: 8),
                      ],

                      // Q&A Log History
                      _buildQaLog(g, cs, qaHistory, compact),
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

  Widget _buildRoleSecretCard(
    ColorScheme cs,
    String myRole,
    String category,
    String? secretWord,
    int questionsUsed,
    int maxQuestions,
  ) {
    final (roleLabel, color) = switch (myRole) {
      'master' => ('👑 主持人', Colors.amber.shade800),
      'insider' => ('🕵️ 局内人（内鬼）', Colors.deepOrange.shade800),
      'common' => ('🔍 平民', Colors.teal.shade700),
      _ => ('👀 观战', Colors.blueGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('身份：$roleLabel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
          Text('类别：$category', style: const TextStyle(color: Colors.white, fontSize: 12)),
          Text(
            secretWord != null ? '神秘词：【$secretWord】' : '神秘词：【？？？】',
            style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text('提问：$questionsUsed/$maxQuestions', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQaControls({
    required GameContext g,
    required ColorScheme cs,
    required int masterSeat,
    required int pendingAsker,
    required String? pendingQuestion,
    required List<Map> candidateQuestions,
    required List<String> candidateWords,
    required List<Map> qaHistory,
    required bool compact,
  }) {
    if (pendingQuestion != null) {
      return Card(
        color: cs.surface.withValues(alpha: 0.93),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '❓ ${g.name(pendingAsker)} 提问：「$pendingQuestion」',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (g.seat == masterSeat) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                      onPressed: () => g.act({'type': 'answer', 'answer': 'yes'}),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('是 (Yes)'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                      onPressed: () => g.act({'type': 'answer', 'answer': 'no'}),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('否 (No)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => g.act({'type': 'answer', 'answer': 'idk'}),
                      icon: const Icon(Icons.help_outline, size: 16),
                      label: const Text('不知道'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (g.seat == masterSeat) {
      return Card(
        color: cs.surface.withValues(alpha: 0.88),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Text('你是本局主持人，请等待玩家提出是非问题后作答。', style: TextStyle(fontSize: 12.5)),
        ),
      );
    }

    final askedSet = {for (final item in qaHistory) '${item['text']}'};

    return Card(
      color: cs.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '输入是非问题（如：它是动物吗？）或直接输入猜词…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.tonal(
                  onPressed: () {
                    final t = _inputCtrl.text.trim();
                    if (t.isNotEmpty) {
                      g.act({'type': 'ask', 'text': t});
                      _inputCtrl.clear();
                    }
                  },
                  child: const Text('提问'),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: () {
                    final t = _inputCtrl.text.trim();
                    if (t.isNotEmpty) {
                      g.act({'type': 'guess_word', 'text': t});
                      _inputCtrl.clear();
                    }
                  },
                  child: const Text('猜词'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('💡 快捷提问：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final q in candidateQuestions.where((q) => !askedSet.contains('${q['text']}')).take(compact ? 4 : 6))
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${q['text']}', style: const TextStyle(fontSize: 11)),
                    onPressed: () => g.act({'type': 'ask', 'text': '${q['text']}'}),
                  ),
              ],
            ),
            if (candidateWords.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('🎯 候选神秘词（点击直接猜词）：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final w in candidateWords)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.lightbulb_outline, size: 14),
                      label: Text(w, style: const TextStyle(fontSize: 11.5)),
                      onPressed: () => g.act({'type': 'guess_word', 'text': w}),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccuseControls({
    required GameContext g,
    required ColorScheme cs,
    required Map<String, dynamic> v,
    required int accuseStep,
    required int guesser,
    required List<int> suspectSeats,
  }) {
    if (accuseStep == 1) {
      final votes = (v['guesserVotes'] as Map?) ?? const {};
      if (votes.containsKey('${g.seat}')) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Text('你已对猜中者投出审判票，等待其他玩家表决…'),
          ),
        );
      }
      return Card(
        color: cs.surface.withValues(alpha: 0.94),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '⚖️ 第一轮审判：最后猜中神秘词的 ${g.name(guesser)} 是不是局内人？',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: () => g.act({'type': 'vote', 'yes': true}),
                icon: const Icon(Icons.gavel, size: 16),
                label: Text('是，${g.name(guesser)} 就是局内人！'),
              ),
              OutlinedButton.icon(
                onPressed: () => g.act({'type': 'vote', 'yes': false}),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: const Text('不是，局内人另有其人'),
              ),
            ],
          ),
        ),
      );
    }

    final sVotes = (v['suspectVotes'] as Map?) ?? const {};
    if (sVotes.containsKey('${g.seat}')) {
      final t = (sVotes['${g.seat}'] as num?)?.toInt() ?? 0;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text('你已指认 ${g.name(t)}，等待其他玩家完成投票…'),
        ),
      );
    }

    return Card(
      color: cs.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🕵️ 第二轮全员公投：请在其余嫌疑人中指认真正的局内人！',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final s in suspectSeats)
                  FilledButton.tonalIcon(
                    onPressed: () => g.act({'type': 'vote', 'target': s}),
                    icon: const Icon(Icons.person_search, size: 16),
                    label: Text('指认 ${s + 1}号 ${g.name(s)}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQaLog(GameContext g, ColorScheme cs, List<Map> qaHistory, bool compact) {
    if (qaHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('暂无提问记录。平民与局内人可向主持人提出是非问题来缩小神秘词范围。', style: TextStyle(fontSize: 12)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 问答线索记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          for (final item in qaHistory.reversed.take(compact ? 5 : 10))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  _buildAnswerChip('${item['answer']}'),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '#${item['id']} ${g.name((item['asker'] as num?)?.toInt() ?? 0)}：${item['text']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerChip(String ans) {
    final (label, bg) = switch (ans) {
      'yes' => ('是', Colors.green.shade700),
      'no' => ('否', Colors.red.shade700),
      'correct' => ('答对🎉', Colors.amber.shade800),
      _ => ('不知道', Colors.blueGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
    );
  }
}
