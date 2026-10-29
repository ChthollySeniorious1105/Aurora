import '../../widgets/common.dart';
import 'five_hundred_board.dart';
import 'schotten_totten_board.dart';
import 'truco_board.dart';

final Map<String, BoardBuilder> cards17Boards = {
  'truco': TrucoBoard.new,
  'five_hundred': FiveHundredBoard.new,
  'schotten_totten': SchottenTottenBoard.new,
};
