import 'browser_helper_io.dart'
    if (dart.library.js_interop) 'browser_helper_web.dart' as impl;

/// Updates the browser URL query parameter `?room=<code>` (or removes it when
/// [roomCode] is null/empty) via `history.replaceState` without reloading.
void syncBrowserRoomUrl(String? roomCode) => impl.syncBrowserRoomUrl(roomCode);

/// Sets the browser tab title (`document.title`).
void setBrowserTitle(String title) => impl.setBrowserTitle(title);

/// Sends a browser desktop notification when the tab is in the background.
void notifyBrowserInBackground(String title, String body) =>
    impl.notifyBrowserInBackground(title, body);
