import 'package:flutter/material.dart';
import '../../widgets/common.dart';

class NoirKillerBoard extends StatefulWidget {
  final GameContext g;
  const NoirKillerBoard(this.g, {super.key});

  @override
  State<NoirKillerBoard> createState() => _NoirKillerBoardState();
}

class _NoirKillerBoardState extends State<NoirKillerBoard> {
  int? _selectedSuspect;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final rawGrid = (v['grid'] as List?) ?? const [];
    final grid = [
      for (final row in rawGrid)
        [for (final cell in (row as List)) (cell as num).toInt()]
    ];
    final rawStatus = (v['status'] as List?) ?? const [];
    final status = [for (final s in rawStatus) (s as num).toInt()];
    final rawSuspects = (v['suspects'] as List?) ?? const [];
    final suspectMap = <int, Map<String, dynamic>>{
      for (final item in rawSuspects)
        if (item is Map) (item['id'] as num).toInt(): item.cast<String, dynamic>()
    };

    final killerSuspect = (v['killerSuspect'] as num?)?.toInt() ?? -1;
    final inspectorSuspect = (v['inspectorSuspect'] as num?)?.toInt() ?? -1;
    final killerNeighbors = {
      for (final x in (v['killerNeighbors'] as List? ?? const []))
        (x as num).toInt()
    };
    final inspectorNeighbors = {
      for (final x in (v['inspectorNeighbors'] as List? ?? const []))
        (x as num).toInt()
    };

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deadCount = (v['deadCount'] as num?)?.toInt() ?? 0;
    final targetKills = (v['targetKills'] as num?)?.toInt() ?? 11;
    final evidenceCount = (v['evidenceCount'] as num?)?.toInt() ?? 0;
    final lastRadarHit = v['lastRadarHit'] as bool?;
    final lastActionText = (v['lastActionText'] as String?) ?? '';
    final over = v['over'] == true || g.over;
    final winReason = (v['winReason'] as String?) ?? '';

    final myTurn = !over && g.seat == turn;
    final amKiller = g.seat == 0;
    final amInspector = g.seat >= 1;

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720 &&
              constraints.maxWidth > constraints.maxHeight * 1.15;

          final header = _buildHeader(
            g: g,
            cs: cs,
            turn: turn,
            myTurn: myTurn,
            deadCount: deadCount,
            targetKills: targetKills,
            evidenceCount: evidenceCount,
            lastRadarHit: lastRadarHit,
            lastActionText: lastActionText,
          );

          final matrixWidget = _buildMatrixWithShiftControls(
            g: g,
            cs: cs,
            grid: grid,
            status: status,
            suspectMap: suspectMap,
            killerSuspect: killerSuspect,
            inspectorSuspect: inspectorSuspect,
            killerNeighbors: killerNeighbors,
            inspectorNeighbors: inspectorNeighbors,
            myTurn: myTurn,
            amKiller: amKiller,
            amInspector: amInspector,
          );

          final actionPanel = _buildActionPanel(
            g: g,
            cs: cs,
            status: status,
            suspectMap: suspectMap,
            killerSuspect: killerSuspect,
            inspectorSuspect: inspectorSuspect,
            killerNeighbors: killerNeighbors,
            inspectorNeighbors: inspectorNeighbors,
            myTurn: myTurn,
            amKiller: amKiller,
            amInspector: amInspector,
            evidenceCount: evidenceCount,
            over: over,
            winReason: winReason,
          );

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        header,
                        const SizedBox(height: 6),
                        Expanded(
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: matrixWidget,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: actionPanel,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                header,
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: matrixWidget,
                ),
                const SizedBox(height: 8),
                actionPanel,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    required GameContext g,
    required ColorScheme cs,
    required int turn,
    required bool myTurn,
    required int deadCount,
    required int targetKills,
    required int evidenceCount,
    required bool? lastRadarHit,
    required String lastActionText,
  }) {
    final statusStr = g.over
        ? '案件终结'
        : myTurn
            ? '轮到你行动（${g.seat == 0 ? "杀手" : "探长"}）'
            : '等待 ${g.name(turn)}（${turn == 0 ? "杀手" : "探长"}）行动...';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBar(statusStr, highlight: myTurn),
            for (var s = 0; s < g.players; s++)
              g.tag(
                s,
                active: !g.over && turn == s,
                sub: s == 0 ? '🗡️ 杀手' : '🕵️ 探长',
                size: 30,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            _pill(cs, '💀 被害: $deadCount / $targetKills', Colors.redAccent),
            _pill(cs, '🗂️ 证据牌堆: $evidenceCount 张', cs.primary),
            if (lastRadarHit != null)
              _pill(
                cs,
                lastRadarHit ? '🚨 警报：杀手紧邻探长' : '🟢 探长周围安全',
                lastRadarHit ? Colors.deepOrange : Colors.teal,
              ),
          ],
        ),
        if (lastActionText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            lastActionText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
          ),
        ],
      ],
    );
  }

  Widget _pill(ColorScheme cs, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildMatrixWithShiftControls({
    required GameContext g,
    required ColorScheme cs,
    required List<List<int>> grid,
    required List<int> status,
    required Map<int, Map<String, dynamic>> suspectMap,
    required int killerSuspect,
    required int inspectorSuspect,
    required Set<int> killerNeighbors,
    required Set<int> inspectorNeighbors,
    required bool myTurn,
    required bool amKiller,
    required bool amInspector,
  }) {
    if (grid.length < 5) return const SizedBox();

    const cellSize = 68.0;
    const shiftBtnSize = 30.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top column shift UP buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: shiftBtnSize),
            for (var c = 0; c < 5; c++)
              SizedBox(
                width: cellSize,
                height: shiftBtnSize,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '第${c + 1}列上移',
                  icon: const Icon(Icons.keyboard_arrow_up, size: 22),
                  onPressed: myTurn
                      ? () => g.act({'type': 'shift', 'axis': 'col', 'index': c, 'dir': -1})
                      : null,
                ),
              ),
            const SizedBox(width: shiftBtnSize),
          ],
        ),
        for (var r = 0; r < 5; r++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left row shift LEFT button
              SizedBox(
                width: shiftBtnSize,
                height: cellSize,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '第${r + 1}行左移',
                  icon: const Icon(Icons.keyboard_arrow_left, size: 22),
                  onPressed: myTurn
                      ? () => g.act({'type': 'shift', 'axis': 'row', 'index': r, 'dir': -1})
                      : null,
                ),
              ),
              for (var c = 0; c < 5; c++)
                _buildSuspectCell(
                  cs: cs,
                  suspectId: grid[r][c],
                  status: grid[r][c] < status.length ? status[grid[r][c]] : 0,
                  info: suspectMap[grid[r][c]],
                  isKiller: grid[r][c] == killerSuspect,
                  isInspector: grid[r][c] == inspectorSuspect,
                  isTargetable: myTurn &&
                      ((amKiller &&
                              killerNeighbors.contains(grid[r][c]) &&
                              grid[r][c] != killerSuspect &&
                              (grid[r][c] < status.length && status[grid[r][c]] != 2)) ||
                          (amInspector &&
                              inspectorNeighbors.contains(grid[r][c]) &&
                              grid[r][c] != inspectorSuspect &&
                              (grid[r][c] < status.length && status[grid[r][c]] != 2))),
                  selected: _selectedSuspect == grid[r][c],
                  cellSize: cellSize,
                ),
              // Right row shift RIGHT button
              SizedBox(
                width: shiftBtnSize,
                height: cellSize,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '第${r + 1}行右移',
                  icon: const Icon(Icons.keyboard_arrow_right, size: 22),
                  onPressed: myTurn
                      ? () => g.act({'type': 'shift', 'axis': 'row', 'index': r, 'dir': 1})
                      : null,
                ),
              ),
            ],
          ),
        // Bottom column shift DOWN buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: shiftBtnSize),
            for (var c = 0; c < 5; c++)
              SizedBox(
                width: cellSize,
                height: shiftBtnSize,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '第${c + 1}列下移',
                  icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                  onPressed: myTurn
                      ? () => g.act({'type': 'shift', 'axis': 'col', 'index': c, 'dir': 1})
                      : null,
                ),
              ),
            const SizedBox(width: shiftBtnSize),
          ],
        ),
      ],
    );
  }

  Widget _buildSuspectCell({
    required ColorScheme cs,
    required int suspectId,
    required int status,
    required Map<String, dynamic>? info,
    required bool isKiller,
    required bool isInspector,
    required bool isTargetable,
    required bool selected,
    required double cellSize,
  }) {
    final name = (info?['name'] as String?) ?? '#$suspectId';
    final icon = (info?['icon'] as String?) ?? '👤';
    final isDead = status == 2;
    final isExonerated = status == 1;

    Color bgColor = cs.surface.withValues(alpha: 0.88);
    if (isDead) {
      bgColor = Colors.red.shade900.withValues(alpha: 0.45);
    } else if (isExonerated) {
      bgColor = Colors.blueGrey.withValues(alpha: 0.35);
    }
    if (isKiller) {
      bgColor = Colors.redAccent.withValues(alpha: 0.32);
    } else if (isInspector) {
      bgColor = Colors.amber.withValues(alpha: 0.32);
    }

    Color borderColor = cs.outline.withValues(alpha: 0.35);
    double borderWidth = 1.0;
    if (selected) {
      borderColor = cs.primary;
      borderWidth = 2.5;
    } else if (isKiller) {
      borderColor = Colors.redAccent;
      borderWidth = 2.2;
    } else if (isInspector) {
      borderColor = Colors.amber.shade700;
      borderWidth = 2.2;
    } else if (isTargetable) {
      borderColor = Colors.greenAccent.shade400;
      borderWidth = 1.8;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedSuspect = suspectId),
      child: Container(
        width: cellSize - 4,
        height: cellSize - 4,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 18)),
                  if (isKiller)
                    const Text('🗡️', style: TextStyle(fontSize: 13)),
                  if (isInspector)
                    const Text('🕵️', style: TextStyle(fontSize: 13)),
                ],
              ),
              Text(
                name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  decoration: isDead ? TextDecoration.lineThrough : null,
                  color: cs.onSurface,
                ),
              ),
              Text(
                isDead
                    ? '💀被害'
                    : isExonerated
                        ? '✓清白'
                        : '待查',
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDead
                      ? Colors.redAccent
                      : isExonerated
                          ? Colors.teal
                          : cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionPanel({
    required GameContext g,
    required ColorScheme cs,
    required List<int> status,
    required Map<int, Map<String, dynamic>> suspectMap,
    required int killerSuspect,
    required int inspectorSuspect,
    required Set<int> killerNeighbors,
    required Set<int> inspectorNeighbors,
    required bool myTurn,
    required bool amKiller,
    required bool amInspector,
    required int evidenceCount,
    required bool over,
    required String winReason,
  }) {
    final sel = _selectedSuspect;
    final selName = sel != null ? (suspectMap[sel]?['name'] ?? '#$sel') : null;
    final canKillSelected = myTurn &&
        amKiller &&
        sel != null &&
        sel != killerSuspect &&
        killerNeighbors.contains(sel) &&
        (sel < status.length && status[sel] != 2);
    final canAccuseSelected = myTurn &&
        amInspector &&
        sel != null &&
        sel != inspectorSuspect &&
        inspectorNeighbors.contains(sel) &&
        (sel < status.length && status[sel] != 2);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (over) ...[
            ResultBanner(winReason.isNotEmpty ? winReason : '对局结束'),
            const SizedBox(height: 8),
          ],
          if (killerSuspect >= 0)
            _identityCard(
              cs,
              '🗡️ 杀手秘密身份',
              '${suspectMap[killerSuspect]?['icon'] ?? ''} ${suspectMap[killerSuspect]?['name'] ?? killerSuspect}',
              Colors.redAccent,
            ),
          if (inspectorSuspect >= 0) ...[
            const SizedBox(height: 6),
            _identityCard(
              cs,
              '🕵️ 探长秘密位置',
              '${suspectMap[inspectorSuspect]?['icon'] ?? ''} ${suspectMap[inspectorSuspect]?['name'] ?? inspectorSuspect}',
              Colors.amber.shade700,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            selName != null ? '已选中嫌疑人：【$selName】' : '提示：点击网格周围箭头可平移行列，点击相邻嫌疑人可执行暗杀/逮捕',
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (amKiller) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.gps_fixed, size: 16),
                  label: Text(selName != null ? '暗杀 $selName' : '选择相邻目标暗杀'),
                  onPressed: canKillSelected
                      ? () => g.act({'type': 'kill', 'target': sel})
                      : null,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.masks, size: 16),
                  label: Text('伪装换身份 (余$evidenceCount)'),
                  onPressed: myTurn && evidenceCount > 0
                      ? () => g.act({'type': 'disguise'})
                      : null,
                ),
              ],
              if (amInspector) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.gavel, size: 16),
                  label: Text(selName != null ? '逮捕指控 $selName' : '选择相邻目标逮捕'),
                  onPressed: canAccuseSelected
                      ? () => g.act({'type': 'accuse', 'target': sel})
                      : null,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.manage_search, size: 16),
                  label: Text('排查取证 (余$evidenceCount)'),
                  onPressed: myTurn && evidenceCount > 0
                      ? () => g.act({'type': 'exonerate'})
                      : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _identityCard(
    ColorScheme cs,
    String title,
    String person,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
            ),
          ),
          Text(
            person,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
