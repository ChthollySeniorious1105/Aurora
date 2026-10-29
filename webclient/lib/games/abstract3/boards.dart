import '../../widgets/common.dart';
import 'abalone_board.dart';
import 'santorini_board.dart';

/// 圣托里尼 / 大力士棋
final Map<String, BoardBuilder> abstract3Boards = {
  'santorini': (g) => SantoriniBoardView(g),
  'abalone': (g) => AbaloneBoardView(g),
};
