import '../../widgets/common.dart';
import 'match3_battle_board.dart';
import 'shakashaka_board.dart';
import 'yinyang_board.dart';

/// 宝石消消乐对战 / 阴阳连通竞速 / 数间直角三角竞速
final Map<String, BoardBuilder> arcade17Boards = {
  'match3_battle': (g) => Match3BattleBoard(g),
  'yinyang': (g) => YinYangBoard(g),
  'shakashaka': (g) => ShakashakaBoard(g),
};
