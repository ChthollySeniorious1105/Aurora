import '../../widgets/common.dart';
import 'celestia_board.dart';
import 'cryptid_board.dart';
import 'welcometo_board.dart';

final Map<String, BoardBuilder> party9Boards = {
  'celestia': CelestiaBoard.new,
  'welcometo': WelcomeToBoard.new,
  'cryptid': CryptidBoard.new,
};
