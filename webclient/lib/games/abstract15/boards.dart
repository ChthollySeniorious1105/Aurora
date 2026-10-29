import '../../widgets/common.dart';
import 'dipole_board.dart';
import 'otrio_board.dart';
import 'slither_board.dart';

/// 三环同心棋 Otrio / 偶极子棋 Dipole / 蜿蜒连边棋 Slither
final Map<String, BoardBuilder> abstract15Boards = {
  'otrio': (g) => OtrioBoard(g),
  'dipole': (g) => DipoleBoard(g),
  'slither': (g) => SlitherBoard(g),
};
