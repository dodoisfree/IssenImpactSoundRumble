param([string]$GameDir='C:\Program Files (x86)\Steam\steamapps\common\OnimushaWotS',[switch]$Probe,[switch]$Test,[int]$ParentProcessId=0)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
$mutex=New-Object System.Threading.Mutex($false,'Local\OnimushaIssenImpactDS4')
if (-not $mutex.WaitOne(0)) { exit }
$joy=[IntPtr]::Zero
$trackedParent=$null
function Write-ImpactLog([string]$Message) { Add-Content -LiteralPath "$PSScriptRoot\impact.log" -Value "$(Get-Date -Format o) $Message" }
try {
    if ($ParentProcessId -gt 0) {
        $trackedParent=[System.Diagnostics.Process]::GetProcessById($ParentProcessId)
        # Obtain a process handle now so a later PID reuse cannot keep us alive.
        $parentHandle=$trackedParent.Handle
        Write-ImpactLog "Auto mode: following parent PID=$ParentProcessId"
    }
    Add-Type -Path "$PSScriptRoot\Native.cs"
    if ([ImpactSDL]::LoadLibrary("$PSScriptRoot\SDL3.dll") -eq [IntPtr]::Zero) { throw 'Cannot load SDL3.dll' }
    [ImpactSDL]::SDL_SetHint('SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS','1') | Out-Null
    [ImpactSDL]::SDL_SetHint('SDL_JOYSTICK_HIDAPI','1') | Out-Null
    [ImpactSDL]::SDL_SetHint('SDL_JOYSTICK_HIDAPI_PS4','1') | Out-Null
    if (-not [ImpactSDL]::SDL_Init(0x200)) { throw [Runtime.InteropServices.Marshal]::PtrToStringAnsi([ImpactSDL]::SDL_GetError()) }
    $soundPath="$PSScriptRoot\issen.wav"
    if (-not (Test-Path -LiteralPath $soundPath)) { throw 'Approved sound file issen.wav is missing.' }
    $sound=New-Object System.Media.SoundPlayer($soundPath)
    $sound.Load()
    $currentVolume=1.0
    $eventPath=Join-Path $GameDir 'reframework\data\issen_impact_event.json'
    $lastKey=''; $lastStamp=[DateTime]::MinValue
    if (Test-Path -LiteralPath $eventPath) {
        try { $initial=Get-Content -LiteralPath $eventPath -Raw | ConvertFrom-Json; $lastKey="$($initial.session):$($initial.seq)" } catch {}
    }
    Write-ImpactLog 'Started. Awaiting DS4 and fresh Issen events.'
    $nextScan=[DateTime]::MinValue
    $nextParentCheck=[DateTime]::MinValue
    while (-not (Test-Path -LiteralPath "$PSScriptRoot\STOP")) {
        if ($null -ne $trackedParent -and [DateTime]::UtcNow -ge $nextParentCheck) {
            $nextParentCheck=[DateTime]::UtcNow.AddSeconds(1)
            if ($trackedParent.HasExited) { Write-ImpactLog 'Game closed; companion stopping.'; break }
        }
        [ImpactSDL]::SDL_UpdateJoysticks()
        if ($joy -ne [IntPtr]::Zero -and -not [ImpactSDL]::SDL_JoystickConnected($joy)) {
            [ImpactSDL]::SDL_CloseJoystick($joy); $joy=[IntPtr]::Zero
            Write-ImpactLog 'DS4 disconnected.'
        }
        if ($joy -eq [IntPtr]::Zero -and [DateTime]::UtcNow -ge $nextScan) {
            $nextScan=[DateTime]::UtcNow.AddSeconds(2)
            $count=0; $ids=[ImpactSDL]::SDL_GetJoysticks([ref]$count)
            try {
                for ($i=0;$i -lt $count;$i++) {
                    $id=[uint32][Runtime.InteropServices.Marshal]::ReadInt32($ids,$i*4)
                    $candidate=[ImpactSDL]::SDL_OpenJoystick($id)
                    if ($candidate -eq [IntPtr]::Zero) { continue }
                    $vendor=[ImpactSDL]::SDL_GetJoystickVendor($candidate)
                    $product=[ImpactSDL]::SDL_GetJoystickProduct($candidate)
                    $name=[Runtime.InteropServices.Marshal]::PtrToStringAnsi([ImpactSDL]::SDL_GetJoystickName($candidate))
                    Write-ImpactLog "Controller: $name VID=$vendor PID=$product"
                    if ($vendor -eq 0x054c -and $product -in @(0x05c4,0x09cc,0x0ba0)) { $joy=$candidate; break }
                    [ImpactSDL]::SDL_CloseJoystick($candidate)
                }
            } finally { if ($ids -ne [IntPtr]::Zero) { [ImpactSDL]::SDL_free($ids) } }
            if ($joy -ne [IntPtr]::Zero) { Write-ImpactLog 'DS4 selected.' }
        }
        if ($Probe) { Write-ImpactLog "Probe: DS4 present=$($joy -ne [IntPtr]::Zero)"; break }
        $evt=$null
        if ($Test) { $evt=[pscustomobject]@{sound=$true;rumble=$true;strength=1.0;duration_ms=80} }
        elseif (Test-Path -LiteralPath $eventPath) {
            $file=Get-Item -LiteralPath $eventPath
            if ($file.LastWriteTimeUtc -ne $lastStamp) {
                try {
                    $data=Get-Content -LiteralPath $eventPath -Raw | ConvertFrom-Json
                    $key="$($data.session):$($data.seq)"
                    if ($key -ne $lastKey) {
                        $lastKey=$key
                        if (([DateTime]::UtcNow-$file.LastWriteTimeUtc).TotalSeconds -lt 0.35) { $evt=$data }
                    }
                    $lastStamp=$file.LastWriteTimeUtc
                } catch {}
            }
        }
        # Defense in depth: also filter messages from a Lua session loaded before
        # the stricter action check was installed. Explicit UI tests are allowed.
        if ($null -ne $evt -and -not $Test -and $evt.test -ne $true) {
            $allowedAction='^app\.Player(?:OneHanded|TwoHanded|Common)Action\.c(?:Counter|Block|Break|Chain)Issen[A-Za-z0-9_]*$'
            if ([string]$evt.action -cnotmatch $allowedAction) {
                Write-ImpactLog "Blocked non-Issen event: action=$($evt.action)"
                $evt=$null
            }
        }
        if ($null -ne $evt) {
            if ($evt.sound) {
                $volume=1.0
                if ($null -ne $evt.volume) { $volume=[Math]::Max(0,[Math]::Min(1,[double]$evt.volume)) }
                if ($volume -ne $currentVolume) {
                    $volumePath=Join-Path $PSScriptRoot 'issen-volume.wav'
                    $sound.Stop()
                    $sound.Dispose()
                    [ImpactSDL]::ScaleWav($soundPath,$volumePath,$volume)
                    $sound=New-Object System.Media.SoundPlayer($volumePath)
                    $sound.Load()
                    $currentVolume=$volume
                }
                if ($volume -gt 0) { $sound.Play() }
            }
            if ($evt.rumble -and $joy -ne [IntPtr]::Zero) {
                $strength=[Math]::Max(0,[Math]::Min(1,[double]$evt.strength))
                $ms=[uint32][Math]::Max(40,[Math]::Min(220,[int]$evt.duration_ms))
                $ok=[ImpactSDL]::SDL_RumbleJoystick($joy,[uint16](65535*$strength),[uint16](65535*$strength),$ms)
                Write-ImpactLog "Effect: rumble=$ok duration=$ms action=$($evt.action) trigger=$($evt.trigger)"
            } else { Write-ImpactLog 'Effect: sound only (rumble disabled or DS4 absent).' }
            if ($Test) { $end=[DateTime]::UtcNow.AddMilliseconds(300); while ([DateTime]::UtcNow -lt $end) { [ImpactSDL]::SDL_UpdateJoysticks(); Start-Sleep -Milliseconds 8 }; break }
        }
        Start-Sleep -Milliseconds 8
    }
} catch { Write-ImpactLog "ERROR: $_"; throw }
finally {
    if ($joy -ne [IntPtr]::Zero) { [ImpactSDL]::SDL_RumbleJoystick($joy,0,0,0) | Out-Null; [ImpactSDL]::SDL_CloseJoystick($joy) }
    try { [ImpactSDL]::SDL_Quit() } catch {}
    if ($null -ne $trackedParent) { $trackedParent.Dispose() }
    $mutex.ReleaseMutex(); $mutex.Dispose()
}
