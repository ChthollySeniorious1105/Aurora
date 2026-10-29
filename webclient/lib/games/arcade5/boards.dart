import '../../widgets/common.dart';
import 'nonogram_board.dart';
import 'ricochet_board.dart';
import 'sokoban_board.dart';

/// 弹射机器人 / 数织竞速 / 推箱子竞速
final Map<String, BoardBuilder> arcade5Boards = {
  'ricochet': (g) => RicochetBoard(g),
  'nonogram': (g) => NonogramBoard(g),
  'sokoban': (g) => SokobanBoard(g),
};
