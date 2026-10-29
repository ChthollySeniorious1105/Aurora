{{flutter_js}}
{{flutter_build_config}}

// Aurora loading page: real download progress for main.dart.js, stage texts,
// and a friendly retry message when something fails or stalls.
//
// Progress: main.dart.js is prefetched with fetch() and a stream reader. The
// Aurora server sends it `Cache-Control: no-cache` + a weak ETag, so the
// <script> tag flutter.js injects afterwards revalidates and gets a cheap 304
// and reuses the cached body (same URL, same credentials mode, same
// Accept-Encoding → same HTTP cache entry). Generic static servers usually
// send Last-Modified/ETag too (heuristic freshness or 304), so this still works
// there; the progress total falls back from X-Raw-Length to Content-Length
// (only when the body is not content-encoded) or to an indeterminate bar.
(function () {
  'use strict';

  var STALL_MS = 45000; // no download progress / no stage change for this long → error
  var el = function (id) { return document.getElementById(id); };
  var overlay = el('aurora-loading');
  var bar = el('aurora-bar');
  var fill = el('aurora-fill');
  var sub = el('aurora-sub');
  var pct = el('aurora-pct');
  var retry = el('aurora-retry');
  var finished = false;
  var failed = false;
  var watchdog = 0;

  function setText(node, text) {
    if (node) node.textContent = text;
  }

  // fraction in [0, 1], or null for the indeterminate animation
  function setProgress(fraction) {
    if (!bar || !fill) return;
    if (fraction == null) {
      bar.classList.add('indeterminate');
      setText(pct, '');
      return;
    }
    var p = Math.max(0, Math.min(fraction, 1));
    bar.classList.remove('indeterminate');
    fill.style.width = (p * 100).toFixed(1) + '%';
    setText(pct, Math.floor(p * 100) + '%');
  }

  function stage(text) {
    setText(sub, text);
    setProgress(null);
  }

  function fail(message, error) {
    if (error) console.error('[Aurora] ' + message, error);
    if (finished || failed) return;
    failed = true;
    clearTimeout(watchdog);
    if (overlay) overlay.classList.add('failed');
    setText(sub, message);
    setText(pct, '请检查网络连接后点击重新加载。');
    if (retry) retry.hidden = false;
  }

  function arm(ms, message) {
    clearTimeout(watchdog);
    watchdog = setTimeout(function () { fail(message); }, ms);
  }

  // Also called after a stall message: if the app does come up late, show it.
  function done() {
    finished = true;
    clearTimeout(watchdog);
    if (overlay) overlay.remove();
  }

  // (the retry button reloads via its inline onclick, which also works when
  // this script itself failed to load)

  // The entrypoint flutter.js will load: only predictable with a single dart2js build.
  var builds = (window._flutter && _flutter.buildConfig && _flutter.buildConfig.builds) || [];
  var mainJsUrl = builds.length === 1 && builds[0].compileTarget !== 'dart2wasm'
    ? new URL(builds[0].mainJsPath || 'main.dart.js', document.baseURI).toString()
    : null;

  // A failed <script> load fires a non-bubbling error event; catch it in the capture phase.
  window.addEventListener('error', function (e) {
    var t = e.target;
    if (mainJsUrl && t && t.tagName === 'SCRIPT' && t.src === mainJsUrl) {
      fail('加载失败：无法下载游戏主程序。');
    }
  }, true);

  // Resolves with the download duration in ms (0 when skipped).
  async function prefetchMain() {
    if (!mainJsUrl || !window.fetch) return 0;
    var started = Date.now();
    var stallMsg = '下载超时：游戏资源长时间没有进展。';
    arm(STALL_MS, stallMsg);
    var res = await fetch(mainJsUrl, { credentials: 'same-origin' });
    if (!res.ok) throw new Error('HTTP ' + res.status + ' for ' + mainJsUrl);
    var raw = parseInt(res.headers.get('X-Raw-Length') || '', 10);
    var len = parseInt(res.headers.get('Content-Length') || '', 10);
    var enc = (res.headers.get('Content-Encoding') || 'identity').toLowerCase();
    // Content-Length counts encoded bytes; the reader yields decoded ones.
    var total = raw > 0 ? raw : (len > 0 && enc === 'identity' ? len : 0);
    if (!res.body || !res.body.getReader) {
      await res.arrayBuffer(); // no streams support: indeterminate bar
      return Date.now() - started;
    }
    setProgress(total ? 0 : null);
    var reader = res.body.getReader();
    var received = 0;
    for (;;) {
      var chunk = await reader.read();
      if (chunk.done) break;
      received += chunk.value.byteLength;
      arm(STALL_MS, stallMsg);
      if (total) setProgress(Math.min(received / total, 0.99)); // 100% only once complete
    }
    setProgress(1);
    return Date.now() - started;
  }

  function startEngine(downloadMs) {
    stage('正在初始化渲染引擎…');
    // This stage still downloads CanvasKit (smaller than main.dart.js: ~2–3 MB
    // gzip vs ~5.5 MB), so allow at least as long as main.dart.js took.
    arm(STALL_MS + (mainJsUrl ? downloadMs : 2 * STALL_MS), '初始化超时：渲染引擎长时间没有响应。');
    return _flutter.loader.load({
      config: {
        // CJK / emoji fallback fonts are fetched on demand; fonts.gstatic.com is
        // unreachable on many networks in mainland China, the .cn mirror works everywhere.
        fontFallbackBaseUrl: 'https://fonts.gstatic.cn/s/',
      },
      onEntrypointLoaded: async function (engineInitializer) {
        try {
          const appRunner = await engineInitializer.initializeEngine();
          stage('正在启动…');
          arm(STALL_MS, '启动超时：应用长时间没有响应。');
          await appRunner.runApp();
          done();
        } catch (e) {
          fail('启动失败：渲染引擎初始化出错。', e);
        }
      },
    });
  }

  (async function () {
    var downloadMs;
    try {
      downloadMs = await prefetchMain();
    } catch (e) {
      fail('加载失败：无法下载游戏主程序。', e);
      return;
    }
    try {
      await startEngine(downloadMs);
    } catch (e) {
      fail('启动失败：无法加载游戏引擎。', e);
    }
  })();
})();
