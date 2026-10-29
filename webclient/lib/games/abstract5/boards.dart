import '../../widgets/common.dart';
import 'fanorona_board.dart';
import 'hnefatafl_board.dart';
import 'tak_board.dart';

/// 维京棋 / 塔克棋 / 马达加斯加棋
final Map<String, BoardBuilder> abstract5Boards = {
  'hnefatafl': (g) => HnefataflBoardView(g),
  'tak': (g) => TakBoardView(g),
  'fanorona': (g) => FanoronaBoardView(g),
};
