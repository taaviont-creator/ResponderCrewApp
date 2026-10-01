param([int]$Port = 8765)
$ErrorActionPreference = 'Stop'
$repoPath = Split-Path $PSScriptRoot -Parent
$demoPath = Join-Path $repoPath 'build/center-demo'
if (-not (Test-Path -LiteralPath (Join-Path $demoPath 'index.html'))) {
  throw 'Koosta esmalt keskuste prooviversioon. Juhend: docs/center-board-testing.md'
}
$url = "http://127.0.0.1:$Port"
$existing = $null
try {
  $existing = Invoke-RestMethod "$url/__respondcrew_preview_health" -TimeoutSec 2
} catch { }
if ($null -ne $existing) {
  if ($existing.application -eq 'RespondCrew center demo') { Write-Output $url; return }
  throw 'Port on teise teenuse kasutuses. Vali teine -Port.'
}
$pythonPath = if (Test-Path -LiteralPath 'C:/Python314/python.exe') { 'C:/Python314/python.exe' } else { (Get-Command python.exe).Source }
$serverScript = Join-Path $PSScriptRoot 'serve-center-demo.py'
$cachePath = Join-Path $repoPath '.local-cache'
New-Item -ItemType Directory -Force -Path $cachePath | Out-Null
$process = Start-Process -FilePath $pythonPath -ArgumentList @('-u', ('"' + $serverScript + '"'), '--directory', ('"' + $demoPath + '"'), '--port', "$Port") -WorkingDirectory $repoPath -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $cachePath 'center-demo-server.log') -RedirectStandardError (Join-Path $cachePath 'center-demo-server-error.log')
$process.Id | Set-Content -LiteralPath (Join-Path $cachePath 'center-demo-server.pid')
for ($attempt = 0; $attempt -lt 10; $attempt++) {
  Start-Sleep -Milliseconds 200
  if ($process.HasExited) { throw 'Server ei käivitunud. Vaata .local-cache/center-demo-server-error.log; vali vajadusel teine -Port.' }
  try {
    $health = Invoke-RestMethod "$url/__respondcrew_preview_health" -TimeoutSec 1
    if ($health.application -eq 'RespondCrew center demo') { Write-Output $url; return }
  } catch { }
}
throw 'Serveri käivitumist ei õnnestunud kinnitada. Vaata serveri logi.'
