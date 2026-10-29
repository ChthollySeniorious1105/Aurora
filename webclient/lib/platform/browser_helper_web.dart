import 'dart:js_interop';
import 'package:web/web.dart' as web;

void syncBrowserRoomUrl(String? roomCode) {
  try {
    final loc = web.window.location;
    final u = Uri.parse(loc.href);
    final qp = Map<String, String>.from(u.queryParameters);
    if (roomCode == null || roomCode.trim().isEmpty) {
      if (!qp.containsKey('room')) return;
      qp.remove('room');
    } else {
      final code = roomCode.trim().toUpperCase();
      if (qp['room'] == code) return;
      qp['room'] = code;
    }
    final next = u.replace(queryParameters: qp.isEmpty ? null : qp);
    final pathAndQuery =
        '${next.path.isEmpty ? '/' : next.path}${next.hasQuery ? '?${next.query}' : ''}';
    web.window.history.replaceState(null, '', pathAndQuery);
  } catch (_) {}
}

void setBrowserTitle(String title) {
  try {
    web.document.title = title;
  } catch (_) {}
}

void notifyBrowserInBackground(String title, String body) {
  try {
    if (!web.document.hidden) return;
    if (web.Notification.permission == 'granted') {
      web.Notification(title, web.NotificationOptions(body: body));
    } else if (web.Notification.permission == 'default') {
      web.Notification.requestPermission().toDart.then((perm) {
        if (perm.toDart == 'granted') {
          web.Notification(title, web.NotificationOptions(body: body));
        }
      }).catchError((_) {});
    }
  } catch (_) {}
}
