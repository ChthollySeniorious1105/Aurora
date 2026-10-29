import '../../widgets/common.dart';
import 'epaminondas_board.dart';
import 'neutreeko_board.dart';
import 'twixt_board.dart';

export 'epaminondas_board.dart';
export 'neutreeko_board.dart';
export 'twixt_board.dart';

final Map<String, BoardBuilder> abstract10Boards = {
  'twixt': TwixtBoard.new,
  'epaminondas': EpaminondasBoard.new,
  'neutreeko': NeutreekoBoard.new,
};
