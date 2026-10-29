import '../../widgets/common.dart';
import 'amazons_board.dart';
import 'kamisado_board.dart';
import 'linesofaction_board.dart';

/// 亚马逊棋 / 行动线棋 / 神道棋
final Map<String, BoardBuilder> abstract4Boards = {
  'amazons': (g) => AmazonsBoardView(g),
  'linesofaction': (g) => LinesOfActionBoardView(g),
  'kamisado': (g) => KamisadoBoardView(g),
};
