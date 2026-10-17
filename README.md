# Issen Impact Sound Rumble

귀무자: 검의 길에서 일섬 적중 시 효과음과 짧은 패드 진동을 추가하는 모드입니다.

**[모드 다운로드](https://github.com/dodoisfree/IssenImpactSoundRumble/raw/refs/heads/main/IssenImpactSoundRumble-1.0.1.zip)**

음원과 실행 파일이 모두 포함되어 있습니다. REFramework는 별도 설치가 필요합니다.

## 설치

1. [REFramework](https://github.com/praydog/REFramework)를 설치합니다.
2. 위 모드 ZIP을 Vortex로 설치합니다.
3. Mod Type을 **Loose Lua/Plugin (REFramework)**으로 지정하고 활성화·배포합니다.
4. 게임을 재시작합니다.

수동 설치 시 ZIP의 `reframework` 폴더를 `OnimushaWotS.exe`가 있는 폴더에 복사합니다. Vortex 설치와 중복 적용하지 마세요.

## 설정

`REFramework → Script Generated UI → Issen Impact - DS4`

효과음과 진동을 각각 켜고 끄거나, 볼륨·진동 강도·지속 시간을 조절할 수 있습니다.
패드 종류에 따라 진동 지원 여부가 다를 수 있습니다.

제거할 때는 게임을 종료하고 Vortex에서 비활성화한 뒤 배포하세요.

## 소스 및 빌드

런처 C 소스, Lua 스크립트, PowerShell 보조 프로그램과 C# 래퍼를 함께 제공합니다.
Windows x64에서 [Zig 0.15.2](https://ziglang.org/download/)를 준비한 뒤 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -ZigExe zig
```

런처 컴파일 명령:

```powershell
zig cc -shared -O2 -s -target x86_64-windows-gnu Launcher.c -o build/reframework/plugins/IssenImpactLauncher.dll -lkernel32
```

빌드 후 모드 ZIP의 `SDL3.dll`과 `issen.wav`를 `build/reframework/data/IssenImpact/`에 복사하면 됩니다. 파일 확인용 SHA-256은 `review-hashes.json`에 있습니다.

## 제작 및 크레딧

제작: dodo · ChatGPT/Codex 도움으로 제작

- REFramework: praydog 및 기여자
- SDL: SDL 개발팀 · zlib 라이선스 · `SDL-LICENSE.txt` 참고
