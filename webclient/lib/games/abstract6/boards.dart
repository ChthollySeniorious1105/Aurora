import '../../widgets/common.dart';
import 'breakthrough_board.dart';
import 'quixo_board.dart';
import 'yinsh_board.dart';

/// 星盘棋 YINSH / 奇索棋 Quixo / 突破棋 Breakthrough
final Map<String, BoardBuilder> abstract6Boards = {
  'yinsh': (g) => YinshBoardView(g),
  'quixo': (g) => QuixoBoardView(g),
  'breakthrough': (g) => BreakthroughBoardView(g),
};
