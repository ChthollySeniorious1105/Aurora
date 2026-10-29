import '../../widgets/common.dart';
import 'fox_in_the_forest_board.dart';
import 'schafkopf_board.dart';
import 'wizard_board.dart';

final Map<String, BoardBuilder> cards15Boards = {
  'schafkopf': SchafkopfBoard.new,
  'wizard': WizardBoard.new,
  'fox_in_the_forest': FoxInTheForestBoard.new,
};
