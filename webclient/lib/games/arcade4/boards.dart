import '../../widgets/common.dart';
import 'paohuzi_board.dart';
import 'pentago_board.dart';
import 'puyobattle_board.dart';

final Map<String, BoardBuilder> arcade4Boards = {
  'puyobattle': PuyoBattleBoard.new,
  'pentago': PentagoBoard.new,
  'paohuzi': PaohuziBoard.new,
};
