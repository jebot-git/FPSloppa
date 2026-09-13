# bHaptics feasibility and prototype — 2026-09-12

**A Player-free native Godot plugin is viable on Linux for the tested TactSuit X40.** This now has a working implementation and a wearer-confirmed chest pulse/stop test. The initial Windows-first assessment has been superseded by the direct Bluetooth prototype. See [BHAPTICS.md](../BHAPTICS.md) for setup, architecture and validation.

| Target / route | Current result | Remaining work |
| --- | --- | --- |
| Linux x86_64, direct BLE | Rust Godot GDExtension built; X40 connects, actuates and stops without proprietary Player | Physical directional mapping, sustained gameplay, exported-build validation |
| TactSuit Air, direct BLE | Upstream mappings wired into the same extension | Real Air hardware validation |
| Linux / Windows OSC sender | Client settings, OSC v2 motor messages and loopback regression implemented | Vendor receiver interoperability / hardware test |
| Windows x86_64, direct BLE | Release DLL cross-built; exported Godot smoke app passes under Wine with packaged libunwind | WinRT BLE on actual Windows hardware |
| Android ARM64, direct BLE | Release SO/AAR and aligned smoke APK built; Quest 3 loads, initializes JNI, scans and shuts down successfully without Player | No supported vest appeared in the scan; connection and motor-output validation remain |

## Why direct Linux support became possible

The independent [freehaptics 0.3.1 library](https://docs.rs/crate/freehaptics/0.3.1), by Orion Moonclaw, provides direct BLE access, X40/Air mappings and motor encoding. Its [source repository](https://codeberg.org/Orion_Moonclaw/freehaptics) and versioned crate source were inspected. This is an LGPL-3.0-or-later community implementation, not an official bHaptics Linux SDK. It describes itself as work in progress.

The prototype combines freehaptics with btleplug and godot-rust in an in-process GDExtension. Godot supplies local gameplay effects and settings; a native worker performs discovery, explicit connection and bounded motor writes through BlueZ. No external player, relay, application ID or API key is used. A 200 ms host watchdog expires stale motor frames independently of the Godot render loop. It cannot guarantee a physical stop after a process crash or radio failure.

On 2026-09-12 the local X40 was discovered and connected directly. A short 25% front-chest pulse produced successful active writes followed by zero writes after expiry, then clean disconnect. Following a power-on and repeat test, the user confirmed feeling the pulse and that it stopped promptly. Physical left/right/back alignment and gameplay tuning remain unverified. The native debug library is installed locally, not published as a release.

## What OSC does and does not solve

The [official VRChatOSC repository](https://github.com/bhaptics/VRChatOSC) documents a Windows executable used with bHaptics Player. Its [parameter generator](https://github.com/bhaptics/VRChatOSC/blob/main/Unity/Assets/bHapticsOSC/VRChat/Scripts/Editor/bAnimator.cs) defines boolean bOSC/v2 vest channels. FPSloppa now emits those parameters over standard UDP OSC, using zero-based front/back motor indices and the `/others` channel. The [OSC 1.0 specification](https://opensoundcontrol.stanford.edu/spec-1_0.html) defines the implemented packet alignment, bundle timetag and boolean type tags.

Linux can send these packets to a compatible receiver on another machine. This makes OSC a viable transport option, but does not supply a native Linux device runtime. The vendor receiver still needs its supported environment and Player. The independent direct-BLE plugin removes that runtime requirement for the tested X40, so OSC is optional rather than a prerequisite.

Loopback tests verify encoding and event suppression, not actual vendor receiver interoperability. Receiver strength configuration controls this boolean protocol's intensity. UDP offers no suit status acknowledgement. The [archived original receiver](https://github.com/HerpDerpinstine/bHapticsOSC) retains motor state; sending zero snapshots helps packet loss during execution, but a receiver timeout is needed to cover sender crashes reliably.

## Official SDK routes remain separate

The official [C++ SDK2 repository](https://github.com/bhaptics/tact-cpp2) supports Windows 10/11 and exposes device status, named events, intensity and stop operations in its [API header](https://github.com/bhaptics/tact-cpp2/blob/master/tact-cpp2/tact-cpp2/library.h). A Godot GDExtension can wrap it without migrating FPSloppa to C#. That adapter is not part of this prototype.

The [current vendor runtime guide](https://docs.bhaptics.com/sdk/unity/guide) lists Quest/Pico, requires bHaptics VR Player on Android and deprecates its older standalone workflow. This establishes vendor platform capability, not an existing Godot integration. [Godot Android plugin v2](https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html) could wrap the current Android integration; the exact artifact/API, package visibility, credentials, redistribution and headset behavior need separate validation.

## Implemented game integration

The new local service receives recoil from `_play_shot_fx` and `_melee_fx`, impacts from `_hurt_fx`, and optional health/armor/power feedback from `_pickup_event`. Existing shot prediction/echo suppression and controller vibration are preserved. The profile revision extends hit feedback with weapon names and explosion context, under protocol `fpsloppa-33-haptic-damage-context`; clients and servers must update together. Servers still have no haptics runtime dependency.

Damage reverses the incoming travel direction and transforms it into the wearer's torso frame, using tracked chest/hips yaw when available, otherwise head yaw in VR and local yaw on desktop. The logical direction tests pass; a wearer still needs to verify the physical side mapping. Dedicated/headless, remote-player, spectator, demo, focus-loss and map-loading paths suppress gameplay output. See the user guide for the complete test scope and remaining prototype limitations.

Profile follow-up: [FPSloppa Vest v1](../BHAPTICS.md#fpsloppa-vest-v1-game-profile) now defines weapon-specific sequences, hit-height localization, hazards and healing. Native is the default on Linux/Windows x86_64 and Android ARM64 build targets. All three release libraries now compile; Windows exported loading also passes under Wine. The Android route uses direct BLE and does not require the vendor Player. Hardware certification on Windows and Android remains separate from compilation. The 40-case local X40 simulation passed.
