import '../../widgets/common.dart';
import 'cartographers_board.dart';
import 'flip7_board.dart';
import 'noirkiller_board.dart';
import 'shadowhunters_board.dart';

export 'cartographers_board.dart';
export 'flip7_board.dart';
export 'noirkiller_board.dart';
export 'shadowhunters_board.dart';

final Map<String, BoardBuilder> party13Boards = {
  'noirkiller': NoirKillerBoard.new,
  'cartographers': CartographersBoard.new,
  'flip7': Flip7Board.new,
  'shadowhunters': ShadowHuntersBoard.new,
};
