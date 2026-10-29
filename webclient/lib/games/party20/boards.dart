import '../../widgets/common.dart';
import 'bomb_busters_board.dart';
import 'criminal_dance_board.dart';
import 'ito_board.dart';
import 'taco_cat_board.dart';

export 'bomb_busters_board.dart';
export 'criminal_dance_board.dart';
export 'ito_board.dart';
export 'taco_cat_board.dart';

final Map<String, BoardBuilder> party20Boards = {
  'ito': ItoBoard.new,
  'criminal_dance': CriminalDanceBoard.new,
  'bomb_busters': BombBustersBoard.new,
  'taco_cat': TacoCatBoard.new,
};
