$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot
$test=Join-Path $project 'eq-test'
& (Join-Path $test 'build-window.ps1')
$runtime=Join-Path $PSScriptRoot 'runtime'
New-Item -ItemType Directory -Force $runtime | Out-Null
foreach($name in @('Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll','WebView2Loader.dll')) { Copy-Item -LiteralPath (Join-Path $test "runtime\$name") -Destination $runtime -Force }
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$hostSource=Join-Path $test 'TavernWindow.cs'
$liveSource=Join-Path $PSScriptRoot 'TavernLive.cs'
& $compiler /nologo /target:winexe /platform:x64 /main:TavernLive "/out:$runtime\TavernLive.exe" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll "/reference:$runtime\Microsoft.Web.WebView2.Core.dll" "/reference:$runtime\Microsoft.Web.WebView2.WinForms.dll" $hostSource $liveSource
if($LASTEXITCODE -ne 0){throw 'Live window compilation failed.'}
