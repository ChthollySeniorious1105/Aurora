import '../../widgets/common.dart';
import 'archaeology_board.dart';
import 'deadmansdraw_board.dart';
import 'goodcopbadcop_board.dart';
import 'manila_board.dart';

export 'archaeology_board.dart';
export 'deadmansdraw_board.dart';
export 'goodcopbadcop_board.dart';
export 'manila_board.dart';

final Map<String, BoardBuilder> party15Boards = {
  'deadmansdraw': DeadMansDrawBoard.new,
  'archaeology': ArchaeologyBoard.new,
  'goodcopbadcop': GoodCopBadCopBoard.new,
  'manila': ManilaBoard.new,
};
