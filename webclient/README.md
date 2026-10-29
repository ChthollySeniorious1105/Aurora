# Aurora 网页前端 (`webclient`)

由 `aurora_server` 在同一端口托管的 Flutter Web 前端（包含 117 款联机与单机小游戏）。

- 构建产物：`flutter build web --release --no-web-resources-cdn --no-wasm-dry-run` 生成 `build/web`，复制到服务端同目录 `web/` 即可。
- 玩家打开服务器网址即自动通过 `/ws` 建立 X25519 + ChaCha20-Poly1305 端到端加密 WebSocket 连接进入大厅。
