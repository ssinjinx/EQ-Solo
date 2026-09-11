$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
try {
    $picker = New-Object System.Windows.Forms.FolderBrowserDialog
    $picker.Description = 'Select your MacroQuest folder (the folder containing MacroQuest.exe). Close EQ and MacroQuest before updating.'
    if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }
    $mqFolder = $picker.SelectedPath
    if (!(Test-Path -LiteralPath (Join-Path $mqFolder 'MacroQuest.exe'))) { throw 'This folder does not contain MacroQuest.exe. Extract the ready-to-use bundle from the website first, or select your existing RoF2 MacroQuest folder.' }
    if (Get-Process eqgame -ErrorAction SilentlyContinue) { throw 'Please close EverQuest before updating Solo Assist.' }
    $luaFolder = Join-Path $mqFolder 'lua'
    $configFolder = Join-Path $mqFolder 'config'
    $backup = Join-Path $mqFolder ('EQDream-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Force -Path $luaFolder,$configFolder,$backup | Out-Null
    $names = @('eqdream_control.lua','eqdream_solo.lua','eqdream_settings.lua','eqdream_tavern_live.lua')
    foreach ($name in $names) {
        $src = Join-Path $PSScriptRoot ('lua\' + $name)
        if (!(Test-Path -LiteralPath $src)) { throw "Missing package file: $name. Extract the whole ZIP first." }
    }
    foreach ($name in $names) {
        $dest = Join-Path $luaFolder $name
        if (Test-Path -LiteralPath $dest) { Copy-Item -LiteralPath $dest -Destination (Join-Path $backup $name) }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('lua\' + $name)) -Destination $dest -Force
    }
    $tavern = Join-Path $mqFolder 'TavernDuels'
    New-Item -ItemType Directory -Force $tavern,(Join-Path $configFolder 'tavern-live') | Out-Null
    foreach ($name in @('TavernLive.exe','Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll','WebView2Loader.dll','LICENSE-WebView2.txt','NOTICE-WebView2.txt')) {
        $src = Join-Path $PSScriptRoot ('TavernDuels\' + $name)
        if (!(Test-Path -LiteralPath $src)) { throw "Missing Tavern Duels file: $name. Extract the whole ZIP first." }
        $dest = Join-Path $tavern $name
        if (Test-Path -LiteralPath $dest) { Copy-Item -LiteralPath $dest -Destination (Join-Path $backup $name) }
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
    $cfg = Join-Path $configFolder 'ingame.cfg'
    $line = '/lua run eqdream_control quiet'
    $lines = @()
    if (Test-Path -LiteralPath $cfg) {
        Copy-Item -LiteralPath $cfg -Destination (Join-Path $backup 'ingame.cfg')
        $lines = @(Get-Content -LiteralPath $cfg)
    }
    if (!($lines | Where-Object { $_ -match '^\s*/lua\s+run\s+eqdream_control(?:\s|$)' })) {
        $append = if ((Test-Path -LiteralPath $cfg) -and (Get-Item -LiteralPath $cfg).Length -gt 0) { "`r`n$line`r`n" } else { "$line`r`n" }
        [System.IO.File]::AppendAllText($cfg,$append,[System.Text.UTF8Encoding]::new($false))
    }
    if (!(Get-Content -LiteralPath $cfg | Where-Object { $_ -match '^\s*/lua\s+run\s+eqdream_tavern_live(?:\s|$)' })) {
        [System.IO.File]::AppendAllText($cfg,"`r`n/lua run eqdream_tavern_live quiet`r`n",[System.Text.UTF8Encoding]::new($false))
    }
    [System.Windows.Forms.MessageBox]::Show("Solo Assist installed. Your character settings were preserved.`n`nStart MacroQuest before EQ, then type /eqd for Solo Assist or /tavern for Tavern Duels in game. Combat starts only when you choose Start.`n`nBackups: $backup",'EQ Dream Solo Assist') | Out-Null
} catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Solo Assist setup could not finish') | Out-Null
    exit 1
}
