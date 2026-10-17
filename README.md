# Issen Impact Sound Rumble

Windows REFramework mod and source by **dodo**, developed with assistance from ChatGPT/Codex. Adds an extra sound and short controller rumble on recognized Issen impacts in *Onimusha: Way of the Sword*.

**[Download the complete mod ZIP](https://github.com/dodoisfree/IssenImpactSoundRumble/raw/refs/heads/main/IssenImpactSoundRumble-1.0.1.zip)** — includes the supplied effect sound, launcher DLL, SDL3 runtime and scripts. No separate sound download is needed.

The source and build instructions below are included for inspection and launcher rebuilds. This is separate from the Sword Sound Boost bank modification.

## Quick installation

1. Install REFramework separately if it is not already installed.
2. Download `IssenImpactSoundRumble-1.0.1.zip` above (do not install GitHub's source-code ZIP as the mod).
3. Install it with Vortex, select **Loose Lua/Plugin (REFramework)** as the mod type, enable it and deploy.
4. Restart the game. Settings are under `Script Generated UI > Issen Impact - DS4` (the current internal menu name).

For manual installation, copy the ZIP's `reframework` folder beside `OnimushaWotS.exe`. Do not use both manual and Vortex installation.

## Components and behavior

* `issen_impact.lua`: observes action-entry and impact callbacks, checks explicit Counter/Block/Break/Chain Issen action names, and writes a small local JSON event for the companion. Does not change combat values. Includes settings and a manual test button in REFramework.
* `Launcher.c`: REFramework DLL plugin. Resolves the game directory relative to its own location, then starts the Windows PowerShell companion with `-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden` and `CREATE_NO_WINDOW`. It passes the game PID; the companion exits when that process closes. Execution-policy bypass is for this child invocation, not a persistent system-policy change.
* `Start-Impact.ps1`: loads the local C# wrapper and SDL3, watches fresh JSON events, plays `issen.wav` through .NET SoundPlayer, and requests controller rumble. Skips stale events and independently checks the Issen action filter. Writes `impact.log` locally.
* `Native.cs`: SDL3 P/Invoke declarations and 16-bit PCM WAV gain scaling. Also contains an unused procedural test-sound helper.

The shipped implementation selects Sony controller VID `054c` with PID `05c4`, `09cc`, or `0ba0`. Sound can work without a selected controller. Other controller support is not claimed. Chained Issen names are allowed by the filter, but all real chain variants have not been verified.

No network requests, credentials, telemetry upload, or automatic downloads are implemented in these runtime sources. Local files include event/config/audit JSON, a log, and a generated volume-adjusted WAV. Do not put a `STOP` file beside the companion unless you want it to stop.

## Build (Windows x64)

1. Install/extract **Zig 0.15.2** from https://ziglang.org/download/ and make `zig.exe` available, or pass its absolute path below.
2. Run from this source folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -ZigExe zig
```

Equivalent launcher compilation:

```powershell
zig cc -shared -O2 -s -target x86_64-windows-gnu Launcher.c -o build/reframework/plugins/IssenImpactLauncher.dll -lkernel32
```

No REFramework SDK headers or C# SDK are needed for this build: the launcher uses the Windows SDK interface provided by Zig, and Windows PowerShell compiles `Native.cs` with `Add-Type` at runtime. `build.ps1` only compiles/copies local files; it does not download dependencies or install into the game.

3. To rebuild a complete payload, extract the bundled `IssenImpactSoundRumble-1.0.1.zip` into a temporary folder and copy its `SDL3.dll` and `issen.wav` to `build/reframework/data/IssenImpact/`. Keep the included `SDL-LICENSE.txt` there. You do not need to obtain another effect sound.
4. The included SDL runtime is **3.4.18 Windows x64**, from https://github.com/libsdl-org/SDL/releases/tag/release-3.4.18 . Reference SHA-256 hashes are in `review-hashes.json`. Runtime scripts and launcher source are unchanged from the local working mod. The generated launcher replaces the prebuilt launcher when assembling a rebuilt package.

## Install and use

Install REFramework separately: https://github.com/praydog/REFramework . Copy the contents of the generated `build` folder to the folder containing `OnimushaWotS.exe`, or package it for your mod manager. For Vortex select mod type **Loose Lua/Plugin (REFramework)**, deploy, and restart the game. Some game extensions may otherwise package it as a Fluffy mod.

Settings: `REFramework > Script Generated UI > Issen Impact - DS4` (the current internal display name). Enable sound/rumble and adjust sound volume, rumble strength, and duration. To uninstall, close the game and disable/deploy the mod in Vortex. Manually installed users should remove only this mod's seven payload files, not shared REFramework files.

## Review notes

The launcher was built locally with Zig 0.15.2 using the command above. A rebuild is not guaranteed byte-identical across compiler installations or source paths. `review-hashes.json` identifies the original components for comparison. The code is posted for inspection; no particular antivirus verdict or Nexus approval is claimed.

## Audio provenance

The included effect WAV was recorded from a YouTube Elden Ring gameplay/sound clip and processed for noise reduction. ChatGPT/Codex assisted with processing; the effect is not represented as an original AI-generated recording. No permission from the original audio rights holder is claimed. The bundled sound is the same effect used in the tested personal mod.

## Credits and licensing

* Mod source: dodo, assisted by ChatGPT/Codex. No additional reuse license is granted by this source publication.
* REFramework: praydog and contributors; separate dependency, not bundled here.
* SDL: SDL developers, zlib license, see `SDL-LICENSE.txt`. SDL source is available at https://github.com/libsdl-org/SDL . The SDL license applies to SDL, not to the mod's source or audio.
