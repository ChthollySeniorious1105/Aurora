import '../../widgets/common.dart';
import 'clobber_board.dart';
import 'lyngk_board.dart';
import 'shobu_board.dart';

final Map<String, BoardBuilder> abstract12Boards = {
  'lyngk': (g) => LyngkBoard(g),
  'shobu': (g) => ShobuBoard(g),
  'clobber': (g) => ClobberBoard(g),
};
