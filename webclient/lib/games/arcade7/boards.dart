import '../../widgets/common.dart';
import 'lasermaze_board.dart';
import 'nurikabe_board.dart';
import 'slitherlink_board.dart';

/// 数墙竞速 / 数圈竞速 / 激光迷宫竞速
final Map<String, BoardBuilder> arcade7Boards = {
  'nurikabe': (g) => NurikabeBoard(g),
  'slitherlink': (g) => SlitherlinkBoard(g),
  'lasermaze': (g) => LaserMazeBoard(g),
};
