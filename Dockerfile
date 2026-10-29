# Multi-stage Dockerfile for Aurora Standalone Web Server
# Builds both the Flutter Web client (`web/`) and the Dart AOT server (`aurora_server`).
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /src
COPY shared ./shared
COPY server ./server
COPY webclient ./webclient

RUN cd shared && dart pub get
RUN cd server && dart pub get && dart compile exe bin/aurora_server.dart -o /out_server
RUN cd webclient && flutter pub get && flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
# Drop build files browsers never request (same rules and reasoning as
# Optimize-WebRelease in build.ps1): *.symbols debug maps; skwasm/wimp unless a
# build in buildConfig uses the skwasm renderer (or the engine references it);
# canvaskit/webparagraph unless the app config sets preferWebParagraph.
RUN cd webclient/build/web \
 && find . -name '*.symbols' -delete \
 && if ! grep -q '"renderer":"skwasm"' flutter_bootstrap.js && ! grep -q 'skwasm' main.dart.js; then rm -f canvaskit/skwasm* canvaskit/wimp*; fi \
 && if ! grep -Eq 'preferWebParagraph[[:space:]]*:' flutter_bootstrap.js index.html; then rm -rf canvaskit/webparagraph; fi

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /out_server /app/aurora_server
COPY --from=builder /src/webclient/build/web /app/web

EXPOSE 7790
VOLUME ["/app/data", "/app/replays", "/app/words"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:7790/health || exit 1

ENTRYPOINT ["/app/aurora_server", "--port", "7790", "--web-dir", "/app/web", "--data-dir", "/app"]
