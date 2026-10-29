import '../../widgets/common.dart';
import 'broom_service_board.dart';
import 'burgle_bros_board.dart';
import 'mahe_board.dart';
import 'stockpile_board.dart';

export 'broom_service_board.dart';
export 'burgle_bros_board.dart';
export 'mahe_board.dart';
export 'stockpile_board.dart';

final Map<String, BoardBuilder> party17Boards = {
  'burgle_bros': BurgleBrosBoard.new,
  'broom_service': BroomServiceBoard.new,
  'mahe': MaheBoard.new,
  'stockpile': StockpileBoard.new,
};
