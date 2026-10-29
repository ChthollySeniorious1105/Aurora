import '../../widgets/common.dart';
import 'entropy_board.dart';
import 'konane_board.dart';
import 'pente_board.dart';

export 'entropy_board.dart';
export 'konane_board.dart';
export 'pente_board.dart';

final Map<String, BoardBuilder> abstract9Boards = {
  'pente': PenteBoard.new,
  'entropy': EntropyBoard.new,
  'konane': KonaneBoard.new,
};
