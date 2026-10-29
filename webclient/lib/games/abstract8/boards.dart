import '../../widgets/common.dart';
import 'fogchess_board.dart';
import 'stratego_board.dart';
import 'zertz_board.dart';

export 'fogchess_board.dart';
export 'stratego_board.dart';
export 'zertz_board.dart';

final Map<String, BoardBuilder> abstract8Boards = {
  'zertz': ZertzBoard.new,
  'fogchess': FogChessBoard.new,
  'stratego': StrategoBoard.new,
};
