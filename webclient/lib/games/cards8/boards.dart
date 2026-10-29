import '../../widgets/common.dart';
import 'red7_board.dart';
import 'scopa_board.dart';
import 'sixtysix_board.dart';

final Map<String, BoardBuilder> cards8Boards = {
  'sixtysix': SixtySixBoard.new,
  'scopa': ScopaBoard.new,
  'red7': Red7Board.new,
};
