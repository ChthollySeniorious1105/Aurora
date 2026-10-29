import '../../widgets/common.dart';
import 'bloodclock_board.dart';
import 'dixit_board.dart';
import 'insider_board.dart';

/// 血染钟楼·灾祸滋生 / 局内人 / 妙语说书人
final Map<String, BoardBuilder> party6Boards = {
  'bloodclock': (g) => BloodClockBoard(g),
  'insider': (g) => InsiderBoard(g),
  'dixit': (g) => DixitBoard(g),
};
