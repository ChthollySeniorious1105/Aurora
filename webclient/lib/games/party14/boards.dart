import '../../widgets/common.dart';
import 'notalone_board.dart';
import 'qe_board.dart';
import 'similo_board.dart';
import 'spicy_board.dart';

export 'notalone_board.dart';
export 'qe_board.dart';
export 'similo_board.dart';
export 'spicy_board.dart';

final Map<String, BoardBuilder> party14Boards = {
  'notalone': NotAloneBoard.new,
  'qe': QeBoard.new,
  'similo': SimiloBoard.new,
  'spicy': SpicyBoard.new,
};
