import '../../widgets/common.dart';
import 'bezique_board.dart';
import 'scout_board.dart';
import 'tute_board.dart';

final Map<String, BoardBuilder> cards18Boards = {
  'tute': TuteBoard.new,
  'bezique': BeziqueBoard.new,
  'scout': ScoutBoard.new,
};
