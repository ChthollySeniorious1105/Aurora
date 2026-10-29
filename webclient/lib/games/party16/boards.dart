import '../../widgets/common.dart';
import 'downforce_board.dart';
import 'jamaica_board.dart';
import 'mysterium_park_board.dart';
import 'vegas_showdown_board.dart';

export 'downforce_board.dart';
export 'jamaica_board.dart';
export 'mysterium_park_board.dart';
export 'vegas_showdown_board.dart';

final Map<String, BoardBuilder> party16Boards = {
  'mysterium_park': MysteriumParkBoard.new,
  'vegas_showdown': VegasShowdownBoard.new,
  'jamaica': JamaicaBoard.new,
  'downforce': DownforceBoard.new,
};
