import '../../widgets/common.dart';
import 'cribbage_board.dart';
import 'durak_board.dart';
import 'ohhell_board.dart';

/// 克里比奇 / 猜墩牌 / 杜拉克
final Map<String, BoardBuilder> cards6Boards = {
  'cribbage': (g) => CribbageBoard(g),
  'ohhell': (g) => OhHellBoard(g),
  'durak': (g) => DurakBoard(g),
};
