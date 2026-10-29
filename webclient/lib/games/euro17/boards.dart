import '../../widgets/common.dart';
import 'guild_explorers_board.dart';
import 'little_town_board.dart';
import 'santa_monica_board.dart';
import 'verdant_board.dart';

final Map<String, BoardBuilder> euro17Boards = {
  'verdant': (g) => VerdantBoard(g),
  'santa_monica': (g) => SantaMonicaBoard(g),
  'guild_explorers': (g) => GuildExplorersBoard(g),
  'little_town': (g) => LittleTownBoard(g),
};
