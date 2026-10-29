import 'package:aurora_shared/aurora_shared.dart';

import '../net/transport.dart';
import '../state/app_state.dart';

/// Entry URL friends should open: the one the host typed last time, the
/// server's PUBLIC_WEB_URL, the server's auto-detected LAN URL when the host
/// is on localhost, or the address of this page.
String suggestedWebUrl(AppState app) {
  final saved = app.prefs.getString('inviteWeb:${app.address}') ?? '';
  if (saved.isNotEmpty) return saved;
  if (app.publicWebUrl.isNotEmpty) return app.publicWebUrl;
  final page = defaultWebAddress();
  if (page.isNotEmpty) {
    final u = Uri.tryParse(page);
    if ((u?.host == 'localhost' || u?.host == '127.0.0.1') &&
        app.lanWebUrl.isNotEmpty) {
      return app.lanWebUrl;
    }
    return page;
  }
  if (app.lanWebUrl.isNotEmpty) return app.lanWebUrl;
  // outside the browser (tests): derive the http(s) URL from the ws address
  try {
    final u = Uri.parse(webSocketUrl(app.address));
    return Uri(scheme: u.scheme == 'wss' ? 'https' : 'http', host: u.host, port: u.hasPort ? u.port : null).toString();
  } catch (_) {
    return '';
  }
}

/// `<webUrl>?room=<code>` for the current room, or null when [webUrl] is not a
/// plain http(s) address.
String? roomInvitation(AppState app, String webUrl) {
  final u = Uri.tryParse(webUrl.trim());
  if (u == null ||
      !['http', 'https'].contains(u.scheme) ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty ||
      webUrl.length > 1500) {
    return null;
  }
  final room = app.room?['id'];
  if (room == null) return null;
  final base = Uri(
    scheme: u.scheme,
    host: u.host,
    port: u.hasPort ? u.port : null,
    path: u.path,
  ).toString();
  return AuroraInvitation(base, '$room').url;
}
