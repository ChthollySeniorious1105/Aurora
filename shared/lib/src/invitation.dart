/// A room invitation link: `<web entry>?room=ABCDE`. Opening it in a browser
/// connects to that server and offers to join the room.
/// An invitation never contains a room password or a reconnect token.
class AuroraInvitation {
  final String webUrl;
  final String room;
  const AuroraInvitation(this.webUrl, this.room);

  static AuroraInvitation? parse(String text) {
    final candidate = RegExp(
      r'https?://[^\s]+',
    ).firstMatch(text.trim())?.group(0);
    if (candidate == null || candidate.length > 2048) return null;
    final u = Uri.tryParse(candidate);
    if (u == null || u.host.isEmpty || u.userInfo.isNotEmpty) return null;
    final code = (u.queryParameters['room'] ?? '').toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{5}$').hasMatch(code)) return null;
    final base = Uri(
      scheme: u.scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: u.path,
    ).toString();
    return AuroraInvitation(base, code);
  }

  String get url {
    final u = Uri.parse(webUrl);
    return Uri(
      scheme: u.scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: u.path,
      queryParameters: {'room': room},
    ).toString();
  }
}
