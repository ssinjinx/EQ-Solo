$ErrorActionPreference='Stop'
$runtime=Join-Path $PSScriptRoot 'runtime'
$sdk=Join-Path $runtime 'sdk'
New-Item -ItemType Directory -Force $runtime | Out-Null
if (!(Test-Path "$sdk/lib/net462/Microsoft.Web.WebView2.WinForms.dll")) {
    Invoke-WebRequest 'https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.4191.47/microsoft.web.webview2.1.0.4191.47.nupkg' -OutFile "$runtime/webview2.zip"
    Expand-Archive -LiteralPath "$runtime/webview2.zip" -DestinationPath $sdk -Force
}
Copy-Item "$sdk/lib/net462/Microsoft.Web.WebView2.Core.dll" $runtime -Force
Copy-Item "$sdk/lib/net462/Microsoft.Web.WebView2.WinForms.dll" $runtime -Force
Copy-Item "$sdk/runtimes/win-x64/native/WebView2Loader.dll" $runtime -Force
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$source=Join-Path $PSScriptRoot 'TavernWindow.cs'
& $compiler /nologo /target:winexe /platform:x64 "/out:$runtime\TavernWindow.exe" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$runtime\Microsoft.Web.WebView2.Core.dll" "/reference:$runtime\Microsoft.Web.WebView2.WinForms.dll" $source
if ($LASTEXITCODE -ne 0) { throw 'Tavern window compilation failed.' }
