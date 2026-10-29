import '../../widgets/common.dart';
import 'blooms_board.dart';
import 'cannon_board.dart';
import 'latrunculi_board.dart';

/// 大炮棋 Cannon / 双色花围棋 Blooms / 古罗马夹击棋 Latrunculi
final Map<String, BoardBuilder> abstract14Boards = {
  'cannon': (g) => CannonBoard(g),
  'blooms': (g) => BloomsBoard(g),
  'latrunculi': (g) => LatrunculiBoard(g),
};
