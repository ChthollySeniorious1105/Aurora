import '../../widgets/common.dart';
import 'biblios_board.dart';
import 'lasvegas_board.dart';
import 'portroyal_board.dart';

final Map<String, BoardBuilder> euro5Boards = {
  'portroyal': PortRoyalBoard.new,
  'lasvegas': LasVegasBoard.new,
  'biblios': BibliosBoard.new,
};
