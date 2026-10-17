param([string]$ZigExe='zig')
$ErrorActionPreference='Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
    $build=Join-Path $PSScriptRoot 'build'
    $plugins=Join-Path $build 'reframework/plugins'
    $data=Join-Path $build 'reframework/data/IssenImpact'
    $autorun=Join-Path $build 'reframework/autorun'
    New-Item -ItemType Directory -Force -Path $plugins,$data,$autorun | Out-Null
    & $ZigExe cc -shared -O2 -s -target x86_64-windows-gnu Launcher.c -o (Join-Path $plugins 'IssenImpactLauncher.dll') -lkernel32
    if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed.' }
    Copy-Item -LiteralPath 'issen_impact.lua' -Destination $autorun
    foreach ($name in @('Start-Impact.ps1','Native.cs','SDL-LICENSE.txt')) {
        Copy-Item -LiteralPath $name -Destination $data
    }
    Write-Output 'Built launcher and copied scripts. Supply SDL3.dll and your own authorized 16-bit PCM issen.wav in build/reframework/data/IssenImpact/ before use.'
} finally { Pop-Location }
