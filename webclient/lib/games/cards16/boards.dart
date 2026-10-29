import '../../widgets/common.dart';
import 'claim_board.dart';
import 'doppelkopf_board.dart';
import 'klaverjassen_board.dart';

final Map<String, BoardBuilder> cards16Boards = {
  'doppelkopf': DoppelkopfBoard.new,
  'klaverjassen': KlaverjassenBoard.new,
  'claim': ClaimBoard.new,
};
