import 'games/riichi/defs.dart';
import 'games/sichuan/defs.dart';
import 'games/poker/defs.dart';
import 'games/uno/defs.dart';
import 'games/chess/defs.dart';
import 'games/military/defs.dart';
import 'games/race/defs.dart';
import 'games/tabletop/defs.dart';
import 'games/social/defs.dart';
import 'games/undercover/defs.dart';
import 'games/classic/defs.dart';
import 'games/pokerplus/defs.dart';
import 'games/teamcards/defs.dart';
import 'games/werewolf/defs.dart';
import 'games/drawguess/defs.dart';
import 'games/mcr/defs.dart';
import 'games/tricks/defs.dart';
import 'games/cncards/defs.dart';
import 'games/shogi/defs.dart';
import 'games/abstract/defs.dart';
import 'games/euro/defs.dart';
import 'games/monopoly/defs.dart';
import 'games/party2/defs.dart';
import 'games/taiwan/defs.dart';
import 'games/hkmj/defs.dart';
import 'games/cards3/defs.dart';
import 'games/onenight/defs.dart';
import 'games/arcade/defs.dart';
import 'games/dice2/defs.dart';
import 'games/mahjong2/defs.dart';
import 'games/cards4/defs.dart';
import 'games/abstract2/defs.dart';
import 'games/euro2/defs.dart';
import 'games/light/defs.dart';
import 'games/party3/defs.dart';
import 'src/engine.dart';
import 'games/party4/defs.dart';
import 'games/arcade2/defs.dart';
import 'games/family/defs.dart';
import 'games/duel2/defs.dart';
import 'games/words/defs.dart';
import 'games/bang/defs.dart';
import 'games/party5/defs.dart';
import 'games/social2/defs.dart';
import 'games/cards5/defs.dart';
import 'games/arcade3/defs.dart';
import 'games/abstract3/defs.dart';
import 'games/euro3/defs.dart';
import 'games/party6/defs.dart';
import 'games/arcade4/defs.dart';
import 'games/euro4/defs.dart';
import 'games/abstract4/defs.dart';
import 'games/cards6/defs.dart';
import 'games/party7/defs.dart';
import 'games/euro5/defs.dart';
import 'games/abstract5/defs.dart';
import 'games/cards7/defs.dart';
import 'games/arcade5/defs.dart';
import 'games/euro6/defs.dart';
import 'games/abstract6/defs.dart';
import 'games/cards8/defs.dart';
import 'games/party8/defs.dart';
import 'games/euro7/defs.dart';
import 'games/cards9/defs.dart';
import 'games/abstract7/defs.dart';
import 'games/arcade6/defs.dart';
import 'games/party9/defs.dart';
import 'games/mahjong3/defs.dart';
import 'games/euro8/defs.dart';
import 'games/party10/defs.dart';
import 'games/cards10/defs.dart';
import 'games/abstract8/defs.dart';
import 'games/arcade7/defs.dart';
import 'games/mahjong4/defs.dart';
import 'games/euro9/defs.dart';
import 'games/party11/defs.dart';
import 'games/cards11/defs.dart';
import 'games/abstract9/defs.dart';
import 'games/arcade8/defs.dart';
import 'games/mahjong5/defs.dart';
import 'games/euro10/defs.dart';
import 'games/party12/defs.dart';
import 'games/cards12/defs.dart';
import 'games/abstract10/defs.dart';
import 'games/arcade9/defs.dart';
import 'games/mahjong6/defs.dart';
import 'games/euro11/defs.dart';
import 'games/party13/defs.dart';
import 'games/cards13/defs.dart';
import 'games/abstract11/defs.dart';
import 'games/arcade10/defs.dart';
import 'games/mahjong7/defs.dart';
import 'games/euro12/defs.dart';
import 'games/party14/defs.dart';
import 'games/cards14/defs.dart';
import 'games/abstract12/defs.dart';
import 'games/arcade11/defs.dart';
import 'games/mahjong8/defs.dart';
import 'games/euro13/defs.dart';
import 'games/party15/defs.dart';
import 'games/cards15/defs.dart';
import 'games/abstract13/defs.dart';
import 'games/arcade12/defs.dart';
import 'games/mahjong9/defs.dart';
import 'games/euro14/defs.dart';
import 'games/party16/defs.dart';
import 'games/cards16/defs.dart';
import 'games/abstract14/defs.dart';
import 'games/arcade13/defs.dart';
import 'games/mahjong10/defs.dart';
import 'games/euro15/defs.dart';
import 'games/party17/defs.dart';
import 'games/cards17/defs.dart';
import 'games/abstract15/defs.dart';
import 'games/arcade14/defs.dart';
import 'games/mahjong11/defs.dart';
import 'games/euro16/defs.dart';
import 'games/party18/defs.dart';
import 'games/cards18/defs.dart';
import 'games/abstract16/defs.dart';
import 'games/arcade15/defs.dart';
import 'games/mahjong12/defs.dart';
import 'games/euro17/defs.dart';
import 'games/party19/defs.dart';
import 'games/cards19/defs.dart';
import 'games/abstract17/defs.dart';
import 'games/arcade16/defs.dart';
import 'games/mahjong13/defs.dart';
import 'games/euro18/defs.dart';
import 'games/party20/defs.dart';
import 'games/cards20/defs.dart';
import 'games/abstract18/defs.dart';
import 'games/arcade17/defs.dart';

/// All game types known to the server and clients. Order = lobby order.
/// Each game package owns its own defs.dart list; add games there, not here.
final List<GameDef> gameRegistry = [
  ...party4Games,
  ...riichiGames,
  ...sichuanGames,
  ...mcrGames,
  ...taiwanGames,
  ...hkmjGames,
  ...pokerGames,
  ...unoGames,
  ...chessGames,
  ...militaryGames,
  ...raceGames,
  ...tabletopGames,
  ...socialGames,
  ...undercoverGames,
  ...classicGames,
  ...pokerplusGames,
  ...teamcardsGames,
  ...werewolfGames,
  ...drawguessGames,
  ...tricksGames,
  ...cncardsGames,
  ...shogiGames,
  ...abstractGames,
  ...euroGames,
  ...monopolyGames,
  ...party2Games,
  ...cards3Games,
  ...onenightGames,
  ...arcadeGames,
  ...dice2Games,
  ...mahjong2Games,
  ...cards4Games,
  ...abstract2Games,
  ...euro2Games,
  ...lightGames,
  ...party3Games,
  ...arcade2Games,
  ...familyGames,
  ...duel2Games,
  ...wordsGames,
  ...bangGames,
  ...party5Games,
  ...social2Games,
  ...cards5Games,
  ...arcade3Games,
  ...abstract3Games,
  ...euro3Games,
  ...party6Games,
  ...arcade4Games,
  ...euro4Games,
  ...abstract4Games,
  ...cards6Games,
  ...party7Games,
  ...euro5Games,
  ...abstract5Games,
  ...cards7Games,
  ...arcade5Games,
  ...euro6Games,
  ...abstract6Games,
  ...cards8Games,
  ...party8Games,
  ...euro7Games,
  ...cards9Games,
  ...abstract7Games,
  ...arcade6Games,
  ...party9Games,
  ...mahjong3Games,
  ...euro8Games,
  ...party10Games,
  ...cards10Games,
  ...abstract8Games,
  ...arcade7Games,
  ...mahjong4Games,
  ...euro9Games,
  ...party11Games,
  ...cards11Games,
  ...abstract9Games,
  ...arcade8Games,
  ...mahjong5Games,
  ...euro10Games,
  ...party12Games,
  ...cards12Games,
  ...abstract10Games,
  ...arcade9Games,
  ...mahjong6Games,
  ...euro11Games,
  ...party13Games,
  ...cards13Games,
  ...abstract11Games,
  ...arcade10Games,
  ...mahjong7Games,
  ...euro12Games,
  ...party14Games,
  ...cards14Games,
  ...abstract12Games,
  ...arcade11Games,
  ...mahjong8Games,
  ...euro13Games,
  ...party15Games,
  ...cards15Games,
  ...abstract13Games,
  ...arcade12Games,
  ...mahjong9Games,
  ...euro14Games,
  ...party16Games,
  ...cards16Games,
  ...abstract14Games,
  ...arcade13Games,
  ...mahjong10Games,
  ...euro15Games,
  ...party17Games,
  ...cards17Games,
  ...abstract15Games,
  ...arcade14Games,
  ...mahjong11Games,
  ...euro16Games,
  ...party18Games,
  ...cards18Games,
  ...abstract16Games,
  ...arcade15Games,
  ...mahjong12Games,
  ...euro17Games,
  ...party19Games,
  ...cards19Games,
  ...abstract17Games,
  ...arcade16Games,
  ...mahjong13Games,
  ...euro18Games,
  ...party20Games,
  ...cards20Games,
  ...abstract18Games,
  ...arcade17Games,
];

GameDef? findGame(String id) {
  for (final g in gameRegistry) {
    if (g.id == id) return g;
  }
  return null;
}
