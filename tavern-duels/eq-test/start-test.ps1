param(
    [string]$NodePath='node',
    [string]$ClientPath=(Join-Path $env:USERPROFILE 'Documents\NMS-Local'),
    [string]$MacroQuestPath=(Join-Path $env:USERPROFILE 'Documents\Codex\EQDream-MacroQuest-RoF2')
)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot
$state=Join-Path $project '.eq-test-state'
$queue=Join-Path $MacroQuestPath 'config\tavern-duels-queue'
if (!(Test-Path (Join-Path $ClientPath 'eqgame.exe'))) { throw 'NMS-Local test client was not found.' }
if ((Split-Path $ClientPath -Leaf) -ne 'NMS-Local') { throw 'Only NMS-Local is supported by the test bridge.' }
if (!(Test-Path (Join-Path $MacroQuestPath 'lua'))) { throw 'MacroQuest Lua directory was not found.' }
if (!(Test-Path (Join-Path $project 'dist-eq\index.html'))) { throw 'Build the test interface first (see README).' }
if (!(Test-Path (Join-Path $PSScriptRoot 'runtime\TavernWindow.exe'))) { & (Join-Path $PSScriptRoot 'build-window.ps1') }
New-Item -ItemType Directory -Force $state,$queue | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'eqdream_tavern.lua') (Join-Path $MacroQuestPath 'lua\eqdream_tavern.lua') -Force
$configPath=Join-Path $PSScriptRoot 'local-config.json'
@{port=17865;state=$state;queue=$queue;clientPath=$ClientPath;hostPath=(Join-Path $PSScriptRoot 'runtime\TavernWindow.exe')} | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding utf8
$ready=$false
try { $health=Invoke-RestMethod 'http://127.0.0.1:17865/health' -TimeoutSec 2; $ready=$health.service -eq 'eq-tavern-test' } catch {}
if (!$ready) {
    $server=Join-Path $PSScriptRoot 'server.mjs'
    $process=Start-Process -FilePath $NodePath -ArgumentList @(('"'+$server+'"'),('"'+$configPath+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $state 'service.log') -RedirectStandardError (Join-Path $state 'service-error.log')
    $process.Id | Set-Content (Join-Path $state 'service.pid')
    for ($attempt=0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 500
        if ($process.HasExited) { throw ('Service failed. See '+(Join-Path $state 'service-error.log')) }
        try { $health=Invoke-RestMethod 'http://127.0.0.1:17865/health' -TimeoutSec 1; if ($health.service -eq 'eq-tavern-test') { $ready=$true; break } } catch {}
    }
}
if (!$ready) { throw 'Tavern Duels did not become ready.' }
Write-Host 'Tavern Duels test service is ready. In NMS-Local, run /lua run eqdream_tavern and then /tavern.'
