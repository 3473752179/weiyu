$ErrorActionPreference = 'Stop'

$hdcCandidates = @()
if ($env:DEVECO_SDK_HOME) {
  $hdcCandidates += (Join-Path $env:DEVECO_SDK_HOME 'default\openharmony\toolchains\hdc.exe')
}
$hdcCandidates += 'D:\download\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
$hdcPath = $hdcCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $hdcPath) {
  throw '未找到 hdc.exe，请先设置 DEVECO_SDK_HOME。'
}

$existingMappings = (& $hdcPath fport ls) -join "`n"
if ($existingMappings -notmatch 'tcp:8787\s+tcp:8787\s+\[Reverse\]') {
  & $hdcPath rport tcp:8787 tcp:8787
  if ($LASTEXITCODE -ne 0) {
    throw '模拟器端口映射失败，请确认 DevEco 模拟器已经启动。'
  }
}

Write-Host '模拟器端口已连接：127.0.0.1:8787 -> 电脑 8787'
& node (Join-Path $PSScriptRoot 'server.mjs')
