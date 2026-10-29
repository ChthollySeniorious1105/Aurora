import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class DeceptionBoard extends StatefulWidget {
  final GameContext g;
  const DeceptionBoard(this.g, {super.key});

  @override
  State<DeceptionBoard> createState() => _DeceptionBoardState();
}

class _DeceptionBoardState extends State<DeceptionBoard> {
  String? _selectedNightMeans;
  String? _selectedNightClue;

  List<int> _draftBullets = [0, 0, 0, 0, 0, 0];
  int _replaceTileIdx = 2;
  int _replaceOptIdx = 0;

  int? _solveSuspect;
  String? _solveMeans;
  String? _solveClue;

  static const Map<String, (String, Color)> _roleInfo = {
    'forensic': ('法医', Color(0xFF0288D1)),
    'murderer': ('凶手', Color(0xFFD32F2F)),
    'accomplice': ('帮凶', Color(0xFFE64A19)),
    'witness': ('目击者', Color(0xFF7B1FA2)),
    'investigator': ('刑警', Color(0xFF2E7D32)),
    'spectator': ('观众', Color(0xFF616161)),
  };

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'night';
    final round = (v['round'] as int?) ?? 1;
    final forensicSeat = (v['forensicSeat'] as int?) ?? 0;
    final myRole = (v['myRole'] as String?) ?? 'spectator';
    final murdererSeat = v['murdererSeat'] as int?;
    final accompliceSeat = v['accompliceSeat'] as int?;
    final witnessSeat = v['witnessSeat'] as int?;
    final witnessSuspects = (v['witnessSuspects'] as List?)?.cast<int>();
    final keyMeans = v['keyMeans'] as String?;
    final keyClue = v['keyClue'] as String?;
    final currentInv = (v['currentInvestigator'] as int?) ?? -1;
    final waiting = (v['waitingFor'] as List?)?.cast<int>() ?? const <int>[];
    final isMyTurn = g.seat >= 0 && waiting.contains(g.seat);

    final meansAll = [
      for (final l in (v['means'] as List? ?? const []))
        (l as List).cast<String>(),
    ];
    final cluesAll = [
      for (final l in (v['clues'] as List? ?? const []))
        (l as List).cast<String>(),
    ];
    final tiles = (v['tiles'] as List? ?? const []).cast<Map<String, dynamic>>();
    final pendingNewTile = v['pendingNewTile'] as Map<String, dynamic>?;
    final badge = (v['badge'] as List? ?? const []).cast<bool>();
    final solveHistory = (v['solveHistory'] as List? ?? const []).cast<Map<String, dynamic>>();
    final winnerTeam = v['winnerTeam'] as String?;

    String statusText;
    if (g.over) {
      statusText = winnerTeam == 'investigators' ? '游戏结束：刑警与法医阵营获胜！' : '游戏结束：凶手阵营获胜！';
    } else if (phase == 'night') {
      statusText = isMyTurn ? '夜晚阶段：请秘密选择 1 张凶器与 1 张核心物证' : '夜晚阶段：等待凶手选择作案凶器与核心物证…';
    } else if (phase == 'forensic') {
      statusText = isMyTurn
          ? (round == 1 ? '第 1 轮：请法医在 6 个现场板块上放置子弹标记' : '第 $round 轮：请法医替换 1 块现场板块并放置子弹标记')
          : '第 $round 轮：等待法医 ${g.name(forensicSeat)} 放置现场子弹线索…';
    } else if (phase == 'investigate') {
      statusText = isMyTurn
          ? '第 $round 轮调查：轮到你发言或消耗警徽破案'
          : '第 $round 轮调查：等待 ${g.name(currentInv)} 发言或破案…';
    } else {
      statusText = isMyTurn ? '刑警已破案！请凶手选择 1 名调查员暗杀目击者！' : '等待凶手暗杀目击者…';
    }

    final roleMeta = _roleInfo[myRole] ?? ('未知', cs.primary);

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(statusText, highlight: isMyTurn),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleMeta.$2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '身份：${roleMeta.$1} · 第$round/3轮',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (murdererSeat != null && keyMeans != null && keyClue != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '真相：${g.name(murdererSeat)}${accompliceSeat != null ? '(帮凶:${g.name(accompliceSeat)})' : ''} · 凶器【$keyMeans】+ 物证【$keyClue】',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    else if (witnessSuspects != null && witnessSuspects.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade800.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '目击对象：${witnessSuspects.map(g.name).join(' / ')}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildActionPanel(
                        cs: cs,
                        phase: phase,
                        round: round,
                        isMyTurn: isMyTurn,
                        forensicSeat: forensicSeat,
                        murdererSeat: murdererSeat,
                        accompliceSeat: accompliceSeat,
                        meansAll: meansAll,
                        cluesAll: cluesAll,
                        tiles: tiles,
                        pendingNewTile: pendingNewTile,
                        badge: badge,
                      ),
                      const SizedBox(height: 6),
                      _buildSceneTilesSection(cs, tiles, phase, round, isMyTurn),
                      const SizedBox(height: 8),
                      _buildSuspectsSection(
                        cs: cs,
                        forensicSeat: forensicSeat,
                        currentInv: currentInv,
                        meansAll: meansAll,
                        cluesAll: cluesAll,
                        badge: badge,
                        keyMeans: keyMeans,
                        keyClue: keyClue,
                        murdererSeat: murdererSeat,
                        isMyTurn: isMyTurn,
                        phase: phase,
                      ),
                      if (solveHistory.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildSolveHistory(cs, solveHistory),
                      ],
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
                winnerTeam == 'investigators' ? '刑警与法医破案获胜！' : '凶手成功逍遥法外！',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (murdererSeat != null)
                      Text(
                        '真凶：${g.name(murdererSeat)}  |  凶器：${keyMeans ?? '?'}  |  核心物证：${keyClue ?? '?'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    if (accompliceSeat != null || witnessSeat != null)
                      Text(
                        '${accompliceSeat != null ? '帮凶：${g.name(accompliceSeat)}  ' : ''}${witnessSeat != null ? '目击者：${g.name(witnessSeat)}' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionPanel({
    required ColorScheme cs,
    required String phase,
    required int round,
    required bool isMyTurn,
    required int forensicSeat,
    required int? murdererSeat,
    required int? accompliceSeat,
    required List<List<String>> meansAll,
    required List<List<String>> cluesAll,
    required List<Map<String, dynamic>> tiles,
    required Map<String, dynamic>? pendingNewTile,
    required List<bool> badge,
  }) {
    final g = widget.g;
    if (!isMyTurn || g.over) return const SizedBox.shrink();

    if (phase == 'night' && g.seat < meansAll.length) {
      final myMeans = meansAll[g.seat];
      final myClues = cluesAll[g.seat];
      final selM = _selectedNightMeans ?? (myMeans.isNotEmpty ? myMeans.first : '');
      final selC = _selectedNightClue ?? (myClues.isNotEmpty ? myClues.first : '');
      return Card(
        color: cs.surface.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('凶手作案：请从你的 4 张凶器与 4 张物证中各选 1 张', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final m in myMeans)
                    ChoiceChip(
                      label: Text('凶器: $m', style: const TextStyle(fontSize: 12)),
                      selected: selM == m,
                      onSelected: (_) => setState(() => _selectedNightMeans = m),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final c in myClues)
                    ChoiceChip(
                      label: Text('物证: $c', style: const TextStyle(fontSize: 12)),
                      selected: selC == c,
                      onSelected: (_) => setState(() => _selectedNightClue = c),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () => g.act({'type': 'commit', 'means': selM, 'clue': selC}),
                icon: const Icon(Icons.check, size: 16),
                label: Text('确认作案组合：【$selM】+【$selC】'),
              ),
            ],
          ),
        ),
      );
    }

    if (phase == 'forensic') {
      if (round == 1) {
        return Card(
          color: cs.surface.withValues(alpha: 0.92),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '法医取证：点击下方 6 个现场板块中的词条设定子弹位置，然后点击公布',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => g.act({'type': 'forensic', 'bullets': _draftBullets}),
                  icon: const Icon(Icons.adjust, size: 16),
                  label: const Text('公布子弹线索'),
                ),
              ],
            ),
          ),
        );
      } else {
        final newTitle = (pendingNewTile?['title'] as String?) ?? '新现场板块';
        final newOpts = (pendingNewTile?['options'] as List?)?.cast<String>() ?? const <String>[];
        return Card(
          color: cs.surface.withValues(alpha: 0.92),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('第 $round 轮新抽到板块：【$newTitle】，请选择要替换的旧板块(2..5)及子弹标记：',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var t = 2; t < tiles.length; t++)
                      ChoiceChip(
                        label: Text('替换: ${tiles[t]['title']}', style: const TextStyle(fontSize: 12)),
                        selected: _replaceTileIdx == t,
                        onSelected: (_) => setState(() => _replaceTileIdx = t),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var o = 0; o < newOpts.length; o++)
                      ChoiceChip(
                        label: Text('🎯 ${newOpts[o]}', style: const TextStyle(fontSize: 12)),
                        selected: _replaceOptIdx == o,
                        onSelected: (_) => setState(() => _replaceOptIdx = o),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: () => g.act({
                    'type': 'forensic',
                    'replace': _replaceTileIdx,
                    'option': _replaceOptIdx,
                  }),
                  child: const Text('确认替换板块并放置子弹'),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (phase == 'investigate') {
      final hasBadge = g.seat < badge.length && badge[g.seat];
      return Card(
        color: cs.surface.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => g.act({'type': 'pass'}),
                icon: const Icon(Icons.skip_next, size: 16),
                label: const Text('结束发言 (保留警徽)'),
              ),
              if (hasBadge) ...[
                Text(
                  _solveSuspect != null && _solveMeans != null && _solveClue != null
                      ? '指认：${g.name(_solveSuspect!)} 【$_solveMeans】+【$_solveClue】'
                      : '点击下方任意嫌疑人的 1 张凶器与 1 张物证可发起破案',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                FilledButton.icon(
                  onPressed: (_solveSuspect != null && _solveMeans != null && _solveClue != null)
                      ? () => g.act({
                            'type': 'solve',
                            'suspect': _solveSuspect,
                            'means': _solveMeans,
                            'clue': _solveClue,
                          })
                      : null,
                  icon: const Icon(Icons.local_police, size: 16),
                  label: const Text('消耗警徽破案'),
                ),
              ] else
                const Text('你的警徽已消耗，本轮只能跳过', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (phase == 'assassinate_witness') {
      final targets = [
        for (var s = 0; s < g.players; s++)
          if (s != forensicSeat && s != murdererSeat && s != accompliceSeat) s
      ];
      return Card(
        color: cs.surface.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('凶手最后反扑——点击暗杀怀疑是【目击者】的玩家：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              for (final t in targets)
                FilledButton.tonal(
                  onPressed: () => g.act({'type': 'assassinate', 'target': t}),
                  child: Text('暗杀 ${g.name(t)}'),
                ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSceneTilesSection(
    ColorScheme cs,
    List<Map<String, dynamic>> tiles,
    String phase,
    int round,
    bool isMyTurn,
  ) {
    final canEditRound1 = phase == 'forensic' && round == 1 && isMyTurn;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < tiles.length; i++)
          _buildSceneTileCard(cs, i, tiles[i], canEditRound1),
      ],
    );
  }

  Widget _buildSceneTileCard(
    ColorScheme cs,
    int idx,
    Map<String, dynamic> tile,
    bool canEditRound1,
  ) {
    final title = (tile['title'] as String?) ?? '';
    final type = (tile['type'] as String?) ?? 'scene';
    final options = (tile['options'] as List? ?? const []).cast<String>();
    final selected = canEditRound1 ? _draftBullets[idx] : ((tile['selected'] as int?) ?? -1);

    final headerColor = type == 'cause'
        ? const Color(0xFFB71C1C)
        : (type == 'location' ? const Color(0xFF1B5E20) : const Color(0xFF5D4037));

    return Container(
      width: 182,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: headerColor.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var o = 0; o < options.length; o++)
                InkWell(
                  onTap: canEditRound1
                      ? () => setState(() {
                            _draftBullets = List.of(_draftBullets);
                            _draftBullets[idx] = o;
                          })
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected == o ? Colors.amber.shade700 : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      selected == o ? '🎯 ${options[o]}' : options[o],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected == o ? FontWeight.bold : FontWeight.normal,
                        color: selected == o ? Colors.black : cs.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuspectsSection({
    required ColorScheme cs,
    required int forensicSeat,
    required int currentInv,
    required List<List<String>> meansAll,
    required List<List<String>> cluesAll,
    required List<bool> badge,
    required String? keyMeans,
    required String? keyClue,
    required int? murdererSeat,
    required bool isMyTurn,
    required String phase,
  }) {
    final g = widget.g;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var s = 0; s < g.players; s++)
          if (s != forensicSeat)
            _buildSuspectCard(
              cs: cs,
              seat: s,
              active: s == currentInv,
              means: s < meansAll.length ? meansAll[s] : const [],
              clues: s < cluesAll.length ? cluesAll[s] : const [],
              hasBadge: s < badge.length && badge[s],
              keyMeans: murdererSeat == s ? keyMeans : null,
              keyClue: murdererSeat == s ? keyClue : null,
              selectableForSolve: phase == 'investigate' && isMyTurn && g.seat < badge.length && badge[g.seat],
            ),
      ],
    );
  }

  Widget _buildSuspectCard({
    required ColorScheme cs,
    required int seat,
    required bool active,
    required List<String> means,
    required List<String> clues,
    required bool hasBadge,
    required String? keyMeans,
    required String? keyClue,
    required bool selectableForSolve,
  }) {
    final g = widget.g;
    final selectedThisSuspect = _solveSuspect == seat;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? cs.primary : (selectedThisSuspect ? Colors.amber : cs.outline.withValues(alpha: 0.35)),
          width: active || selectedThisSuspect ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            seat,
            active: active,
            size: 28,
            sub: hasBadge ? '🛡️ 警徽可用' : '警徽已耗尽',
          ),
          const SizedBox(height: 6),
          const Text('凶器 (Means)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final m in means)
                InkWell(
                  onTap: selectableForSolve
                      ? () => setState(() {
                            if (_solveSuspect != seat) {
                              _solveSuspect = seat;
                              _solveClue = clues.isNotEmpty ? clues.first : null;
                            }
                            _solveMeans = m;
                          })
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: (selectedThisSuspect && _solveMeans == m)
                          ? Colors.red.shade700
                          : (keyMeans == m ? Colors.red.shade900 : Colors.red.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (selectedThisSuspect && _solveMeans == m) || keyMeans == m
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (selectedThisSuspect && _solveMeans == m) || keyMeans == m
                            ? Colors.white
                            : cs.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('核心物证 (Clues)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final c in clues)
                InkWell(
                  onTap: selectableForSolve
                      ? () => setState(() {
                            if (_solveSuspect != seat) {
                              _solveSuspect = seat;
                              _solveMeans = means.isNotEmpty ? means.first : null;
                            }
                            _solveClue = c;
                          })
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: (selectedThisSuspect && _solveClue == c)
                          ? Colors.blue.shade700
                          : (keyClue == c ? Colors.blue.shade900 : Colors.blue.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (selectedThisSuspect && _solveClue == c) || keyClue == c
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (selectedThisSuspect && _solveClue == c) || keyClue == c
                            ? Colors.white
                            : cs.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSolveHistory(ColorScheme cs, List<Map<String, dynamic>> solveHistory) {
    final g = widget.g;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('破案记录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          for (final h in solveHistory)
            Text(
              '第${h['round']}轮 ${g.name((h['seat'] as int?) ?? 0)} 指认 ${g.name((h['suspect'] as int?) ?? 0)}：【${h['means']}】+【${h['clue']}】 → ${h['correct'] == true ? '✅ 正确' : '❌ 错误'}',
              style: const TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
