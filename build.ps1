# Builds and packages the standalone Aurora web server component:
#   - aurora_server.exe (single-port HTTP + /ws WebSocket server)
#   - web\              (Flutter web client served at / on the same port)
#   - *.bat             (One-click start scripts)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File build.ps1 [-Version 1.0.0] [-SkipTests]
param([string]$Version = "1.0.0", [switch]$SkipTests)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

$flutterBin = if (Test-Path "c:\ART\.tools\flutter\bin\flutter.bat") { "c:\ART\.tools\flutter\bin" } elseif (Test-Path "D:\Tools\flutter\bin\flutter.bat") { "D:\Tools\flutter\bin" } else { "c:\ART\.tools\flutter\bin" }
$dartBin = if (Test-Path "c:\ART\.tools\dart-sdk\bin\dart.exe") { "c:\ART\.tools\dart-sdk\bin" } elseif (Test-Path "D:\Tools\flutter\bin\cache\dart-sdk\bin\dart.exe") { "D:\Tools\flutter\bin\cache\dart-sdk\bin" } else { "c:\ART\.tools\dart-sdk\bin" }
$cleanPath = (($env:PATH -replace '"','') -split ';' | Where-Object { $_ -ne '' } | Select-Object -Unique) -join ';'
$env:PATH = if (Test-Path (Join-Path $flutterBin "flutter.bat")) { "$flutterBin;$cleanPath" } else { $cleanPath }
$flutter = if (Test-Path (Join-Path $flutterBin "flutter.bat")) { Join-Path $flutterBin "flutter.bat" } else { "flutter" }
$dart = if (Test-Path (Join-Path $dartBin "dart.exe")) { Join-Path $dartBin "dart.exe" } else { "dart" }

# Strips files from the copied Flutter web output that browsers never request.
#  * *.symbols: wasm symbol maps for symbolizing native stack traces offline;
#    nothing at runtime fetches them (~8.5 MB).
#  * canvaskit\skwasm*, canvaskit\wimp*: flutter.js only imports these from its
#    skwasm branch, which runs only when the selected buildConfig.builds entry
#    has renderer "skwasm" (dart2wasm builds). Our build is dart2js + canvaskit
#    (`flutter build web` without --wasm; --no-wasm-dry-run), and the dart2js
#    engine in main.dart.js never references skwasm. Both are verified below
#    before deleting.
#  * canvaskit\webparagraph\: flutter.js (and the engine's own fallback loader)
#    only picks it when the app config sets `preferWebParagraph: true` (and the
#    browser has TextCluster); our flutter_bootstrap.js doesn't set it.
#  Kept: canvaskit\canvaskit.* (full variant: Firefox/Safari, or browsers
#  without Intl.v8BreakIterator/ImageDecoder) and canvaskit\chromium\* (default
#  for Chrome/Edge: hasChromiumBreakIterators && hasImageCodecs).
function Optimize-WebRelease([string]$webDir) {
  $symbols = Get-ChildItem $webDir -Recurse -File -Filter "*.symbols"
  $symbols | Remove-Item -Force
  Write-Host "  removed $($symbols.Count) *.symbols files"

  $bootstrap = Get-Content (Join-Path $webDir "flutter_bootstrap.js") -Raw
  $index = Get-Content (Join-Path $webDir "index.html") -Raw
  $m = [regex]::Match($bootstrap, '_flutter\.buildConfig\s*=\s*(\{.*?\});\s*$', 'Multiline')
  if (-not $m.Success) { Write-Warning "buildConfig not found in flutter_bootstrap.js; keeping all renderer variants"; return }
  $builds = @(($m.Groups[1].Value | ConvertFrom-Json).builds)
  $canvaskitOnly = $builds.Count -gt 0 -and -not ($builds | Where-Object { $_.renderer -ne "canvaskit" -or $_.compileTarget -ne "dart2js" })
  $mainJs = Join-Path $webDir "main.dart.js"
  $engineMentionsSkwasm = (Test-Path $mainJs) -and [bool](Select-String -Path $mainJs -Pattern "skwasm" -SimpleMatch -List)
  $canvaskitDir = Join-Path $webDir "canvaskit"
  if ($canvaskitOnly -and -not $engineMentionsSkwasm) {
    Get-ChildItem $canvaskitDir -File | Where-Object { $_.Name -like "skwasm*" -or $_.Name -like "wimp*" } | Remove-Item -Force
    Write-Host "  removed skwasm/skwasm_heavy/wimp (builds: dart2js/canvaskit only)"
  } else {
    Write-Host "  keeping skwasm/wimp variants (buildConfig is not dart2js/canvaskit-only)"
  }
  if (-not ([regex]::IsMatch($bootstrap + $index, 'preferWebParagraph\s*:'))) {
    $wp = Join-Path $canvaskitDir "webparagraph"
    if (Test-Path $wp) { Remove-Item $wp -Recurse -Force; Write-Host "  removed canvaskit\webparagraph (preferWebParagraph not set)" }
  }
}

$out = Join-Path $root "dist"
$stage = Join-Path $out "Aurora-WebServer"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

Write-Host "== 1/3 Aurora Shared & Server ==" -ForegroundColor Cyan
Push-Location (Join-Path $root "shared")
try {
  & $dart pub get
  if ($LASTEXITCODE -ne 0) { throw "aurora_shared pub get failed" }
  if (-not $SkipTests) {
    & $dart test
    if ($LASTEXITCODE -ne 0) { throw "aurora_shared tests failed" }
  }
} finally {
  Pop-Location
}

Push-Location (Join-Path $root "server")
try {
  & $dart pub get
  if ($LASTEXITCODE -ne 0) { throw "aurora_server pub get failed" }
  if (-not $SkipTests) {
    & $dart test
    if ($LASTEXITCODE -ne 0) { throw "aurora_server tests failed" }
  }
  & $dart compile exe bin\aurora_server.dart -o (Join-Path $stage "aurora_server.exe")
  if ($LASTEXITCODE -ne 0) { throw "aurora_server compile failed" }
  Copy-Item "*.bat" $stage
} finally {
  Pop-Location
}

Write-Host "== 2/3 Aurora Web Client ==" -ForegroundColor Cyan
Push-Location (Join-Path $root "webclient")
try {
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "aurora_client pub get failed" }
  if (-not $SkipTests) {
    & $flutter test
    if ($LASTEXITCODE -ne 0) { throw "aurora_client tests failed" }
  }
  & $flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
  if ($LASTEXITCODE -ne 0) { throw "Aurora web client build failed" }
  Copy-Item "build\web" (Join-Path $stage "web") -Recurse
  Optimize-WebRelease (Join-Path $stage "web")
} finally {
  Pop-Location
}

Copy-Item (Join-Path $root "README.md") $stage

Write-Host "== 3/3 Package Release ==" -ForegroundColor Cyan
$zipPath = Join-Path $out "Aurora-WebServer-$Version-windows-x64.zip"
Compress-Archive "$stage\*" $zipPath
$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
"$hash  $(Split-Path $zipPath -Leaf)" | Set-Content (Join-Path $out "SHA256SUMS.txt") -Encoding UTF8
Write-Host "Done: $zipPath (SHA256: $hash)" -ForegroundColor Green
