# bHaptics vest feedback (experimental)

For other Godot games, the reusable addon is published separately as [godot-bhaptics-native](https://github.com/jebot-git/godot-bhaptics-native), with [v0.1.0 downloads](https://github.com/jebot-git/godot-bhaptics-native/releases/tag/v0.1.0). FPSloppa retains its integrated gameplay profile and native backend described below.

FPSloppa has an authored **FPSloppa Vest v1** profile for weapon recoil, localized hits, explosions, hazards and healing in **Settings → Haptics**. Native Bluetooth is the default backend on Linux/Windows x86_64 and Android ARM64; an explicitly saved OSC choice is preserved. Feedback remains off until enabled. Recoil, damage, hazards and healing default on within the feature; armor/power pickup cues are opt-in. Controller vibration is unchanged.

**Update clients and servers together:** protocol `fpsloppa-33-haptic-damage-context` carries authoritative weapon names and explosion flags with hit effects. Servers require no Bluetooth hardware or native plugin. Seven/eight-argument legacy demo hit events remain readable.

| Backend | Current scope | Required runtime |
| --- | --- | --- |
| Native Bluetooth | Release libraries built for Linux x86_64, Windows x86_64 and Android ARM64. Linux X40 physically tested; exported Windows smoke test passes under Wine | Linux: BlueZ; Windows: OS BLE APIs; Android: Godot v2 AAR and Bluetooth permissions. No proprietary Player, credentials or separate helper |
| OSC receiver | Godot UDP sender, usable on Linux/Windows clients | External receiver implementing bHaptics OSC v2; the vendor receiver runs with bHaptics Player on Windows |

The native dependency also provides TactSuit Air mappings, which are enabled experimentally but have not been hardware-tested here. Pro, X16, limbs and gloves are excluded from the direct backend. Android ARM64 now has a direct-BLE Godot adapter, using btleplug’s Android backend and a Java permission/JNI bootstrap. A Quest 3 smoke test passed native loading, Java registration, JNI initialization, scanning and clean worker shutdown. The scan returned no supported vest, so it did not test vest connection or output. Windows uses btleplug’s WinRT backend. Native Windows Bluetooth and Android vest actuation still need hardware validation; Wine only verifies the Windows library loads. A missing or outdated native binary produces an actionable status, rather than silently sending to an OSC endpoint.

## Direct Bluetooth setup

1. Build the optional extension as described below. Local release builds for all three platforms are installed; ordinary source checkouts do not include the binary.
2. Power on the X40 and keep it near the machine. The live test used a vest already paired/trusted through the operating system. Pairing UI is outside this prototype.
3. Open **Settings → Haptics**, leave **Native Bluetooth** selected and enable bHaptics. Native is the default on supported desktop and Android ARM64 targets.
4. Select **Scan**, choose your vest and press **Connect**. Selection is explicit; startup never scans or connects automatically. Scanning can include devices cached by BlueZ, so a listed vest may be powered off.
5. On Android, allow **Nearby devices** when prompted, then tap Scan again. Android 11 and earlier use the location permission required by BLE scanning; enable system Location if scanning returns nothing. Bluetooth must be enabled in system settings.
6. Use **Test Vest**. Strength defaults to 25%; the X40 wire format quantizes this to 4/15. **Stop** releases output, disables haptics and closes the session.

Keep one application controlling the vest at a time. Connection errors appear in the settings status. After a lost connection, power on the vest and scan/connect again; effects are discarded while disconnected. A closing session may need a moment before enabling it again. The device choice is not persisted or automatically reconnected.

Gameplay feedback is suppressed in menus, demo playback, while spectating, on focus/tracking loss and during map loading. The explicit test button works in menus with focus. Disconnect, map cleanup and quit stop active effects. Dedicated/headless games never create the client service.

## Build and native interface

On Linux x86_64, install Rust/Cargo (edition 2024), a C linker, `pkg-config`, `strip` and libdbus development headers. Runtime requires BlueZ and access to its system D-Bus API. This local Linux binary references glibc 2.34; older distributions need a build against an older compatible sysroot. Windows can build locally with Rust MSVC and Visual Studio C++ tools, or cross-compile using LLVM-MinGW and Rust's `x86_64-pc-windows-gnullvm` standard library. Use a matching Rust compiler and target standard library; this session used official Rust 1.98.0 for cross targets because the Fedora compiler could not consume official target metadata.

```sh
# Host Linux or Windows:
python3 tools/build_bhaptics_native.py --release
# Windows from Linux (install the matching Rust target first):
python3 tools/build_bhaptics_native.py --release \
  --target x86_64-pc-windows-gnullvm --llvm-mingw /path/to/llvm-mingw
# Android ARM64 (Android SDK platform 36, JDK 17, Godot Android template AAR):
export ANDROID_SDK_ROOT=/path/to/Android/Sdk
export JAVA_HOME=/path/to/jdk-17
python3 tools/build_bhaptics_native.py --release \
  --target aarch64-linux-android --ndk /path/to/Android/Sdk/ndk/29.0.14206865
```

`RUSTC`, `CARGO_HOME` and `CARGO_TARGET_DIR` are honored; `--offline` uses cached dependencies. The Android build includes a standard AAR compiled from this addon's Java source and the exact locked btleplug/jni-utils Java sources. `--godot-aar` overrides the local Godot template AAR path. No Maven bHaptics SDK or Player is required. Android's minimum native API is 26; existing Quest/Pico game presets remain API 29 or later.

Built artifacts are installed under `addons/bhaptics_native/bin/`:

- Linux: `libfpsloppa_bhaptics_native.so`.
- Windows: `fpsloppa_bhaptics_native.dll`; LLVM-MinGW builds also ship `libunwind.dll` and its license. The installed descriptor declares that DLL as an export dependency.
- Android: `libfpsloppa_bhaptics_native.android.so` and `fpsloppa-bhaptics-android.aar`. The ELF uses 16 KB load alignment. Godot's Android export plugin adds the AAR to Gradle; the descriptor uses `android_aar_plugin` to avoid duplicating the library.

The helper installs the `.gdextension` descriptor after a successful build/package. These are ignored local build artifacts. Only a matching built native library is included by the game export filter. Use Gradle export for Android (already enabled in Quest/Pico presets). Building the AAR alone does not update an existing APK. The Android Player fallback is not implemented because the direct native build is available; an initialization failure is shown in settings instead of silently switching transports.

`python3 tools/validate_bhaptics_builds.py Android` (or `Windows`) creates a small exported smoke application under `test-results/bhaptics-build-smoke/`. The Android app has its own package ID (`org.fpsloppa.bhaptics.smoke`), checks JNI initialization and scans for ten seconds after permission is granted; it never connects or sends motor commands. Launch it via `com.godot.game.GodotAppLauncher` (the main activity itself is not exported). Run the installed test with `python3 tools/run_bhaptics_android_smoke.py --serial YOUR_DEVICE_SERIAL`; this installs the separate package, grants its requested Bluetooth permissions for testing, captures its own log and checks the result. Keep the headset awake and dismiss system dialogs. The game itself requests permissions through Android’s normal user-facing dialog. The fixture pre-registers the extension before editor startup to avoid a first-import teardown abort observed with this local Godot build.

The extension targets Godot's 4.5 API and was exercised with Godot 4.7.2. Source is in [addons/bhaptics_native/native](addons/bhaptics_native/native). `FpsloppaBhapticsBle` exposes `scan`, `devices_json`, `connect_device(id)`, `device_connected`, `submit_frame(values, intensity)`, `submit_levels(values, intensity)`, `stop`, `close`, `is_running`, `status_text` and `diagnostics_json`. Both frame APIs take exactly 40 bytes: front 0–19 and back 20–39, each five rows of four. The legacy `submit_frame` treats nonzero values as on; `submit_levels` preserves per-motor levels from 0–15. The profile uses levels. Global intensity is a finite 0–1 multiplier, so a profile level of 8 at 25% becomes 2/15 on hardware, while 15 becomes 4/15. The freehaptics model mapping converts logical rows into the device's packed 20-byte frame.

On Android, initialization caches the application Java classes and VM; the native worker attaches to that VM for its full lifetime, including disconnect. The AAR embeds its own `.gdextension` asset and the Java plugin returns its `res://` resource path, as verified on Godot 4.7.2.

A dedicated native thread performs Bluetooth work; no Godot APIs run on that thread. It keeps the latest frame with a 200 ms expiry and sends zero when refresh stops. It polls at approximately 50 ms, and each Bluetooth operation is bounded. The expiry is a host watchdog, not firmware enforcement: a stalled Bluetooth operation can delay zero output, and process termination/radio loss cannot guarantee delivery of a stop command. Writes use BLE write-without-response, so diagnostic counters describe successful host writes rather than device acknowledgements. Clean close writes zero, disconnects and joins the worker at destruction.

The native component and its freehaptics dependency are LGPL-3.0-or-later. See [native notices](addons/bhaptics_native/README.md) and the included license texts. No proprietary runtime is bundled. Native redistribution, dependency source/notices and exported-build portability still need release packaging validation; this work installs a development prototype only.

## OSC on Linux

Select **OSC receiver**, enter a numeric receiver IP and UDP port (default `127.0.0.1:9001`), enable and apply. Use the receiver's strength setting; this boolean protocol carries no intensity. For a receiver on another computer, enter that computer's LAN address and configure it to accept traffic on the selected port.

The sender implements these boolean OSC addresses with zero-based motor indices:

```text
/avatar/parameters/bOSC/v2/VestFront/0/others
… VestFront/19/others
/avatar/parameters/bOSC/v2/VestBack/0/others
… VestBack/19/others
```

OSC bundles use immediate timetags, padded strings and `T`/`F` type tags. Four small bundles form a 40-motor snapshot, refreshed at 20 Hz while active and 4 Hz while idle. Repeated zero snapshots release motors after normal events and help recover packet loss. UDP has no connection acknowledgement; the status deliberately reports the destination rather than claiming a connected suit.

This is viable as a Linux-to-receiver transport, including a relay to a Windows machine. It does **not** make the vendor Player or OSC receiver native Linux software. The [vendor OSC project](https://github.com/bhaptics/VRChatOSC) documents Player plus its Windows executable. A separate Linux receiver would need a direct device backend of its own; the native extension above already provides that path within Godot.

OSC hardware interoperability has not been tested against the vendor receiver. Older receivers may latch boolean state after sender failure: periodic/repeated zeros help with packet loss while the game runs, but cannot provide a receiver-side watchdog after a crash. Use the receiver's stop control if needed. Do not share these motor parameters with another sender during testing.

## Validation — 2026-09-12

- Built optimized Linux, Windows and Android libraries from locked dependencies. Linux native and game-profile regressions pass. An exported Windows application loads the DLL plus libunwind under Wine and passes inactive/invalid-frame/clean-close checks; this does not validate Windows BLE hardware.
- Connected directly to the local TactSuit X40 through BlueZ, without Player or an external bridge. Sent one front-chest frame at 25%, observed three successful active host writes followed by zero writes after the 200 ms expiry, explicitly stopped and closed the session. **The wearer confirmed feeling the pulse and that it stopped promptly.**
- A repeat attempt failed while the vest was unavailable; the ordinary BlueZ connection also failed. After the user powered the vest on, direct discovery/connection/pulse/stop passed again. Automatic reconnect is intentionally absent.
- Five Rust tests cover model filtering, expiry/disconnection, Air resampling/strength caps, packed motor encoding and profile-level scaling.
- Godot loopback regression covers OSC bytes, expiry, local/remote/spectator/demo/focus guards, hand selection, directional transforms, endpoint changes, saving and menu controls. Native regression checks absent D-Bus, nonblocking discovery dispatch, invalid frames and worker exit without scanning real hardware.
- Both settings backend pages fit the scaled VR menu canvas. Process auditing found no test-owned survivors or forced cleanup.

The [cross-platform build report](docs/validation/bhaptics-builds.json) records final artifact hashes and validation limits. The Android smoke APK packages the native ARM64 library exactly once, its AAR-owned extension descriptor, Java/JNI helpers and Bluetooth permissions; the APK passes 16 KB ZIP alignment and installs on the connected Quest 3. Its completed runtime test passed native loading, JNI setup, BLE scan and shutdown, with no supported vest discovered and no actuation. The full Quest game export attempt stopped during BSP map import with `double free or corruption (!prev)`, before Gradle packaging. A new full game APK was therefore not produced in this build pass.

The live simulations validate effect output and release on X40; exact anatomical alignment under tracked motion, real-match tuning, Air hardware, vendor OSC interoperability and packaged native exports remain unverified.

```sh
python3 tools/audit_processes.py --timeout 90 bhaptics -- godot --headless --xr-mode off --log-file /tmp/bhaptics.log --path . --script res://deathmatch/tests/bhaptics.gd
DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/fpsloppa-bhaptics-unavailable.sock python3 tools/audit_processes.py --timeout 30 bhaptics-native -- godot --headless --xr-mode off --log-file /tmp/bhaptics-native.log --path . --script res://deathmatch/tests/bhaptics_native.gd
cargo test --locked --manifest-path addons/bhaptics_native/native/Cargo.toml -j 2
```

The separate opt-in `deathmatch/tests/bhaptics_live.gd` takes one exact ID from `devices_json` after `--`, for example `hci0/dev_AA_BB_CC_DD_EE_FF`. It actuates the selected vest briefly and disconnects at exit; it is never included in ordinary regression runs.

### Sustained X40 hardware suite

`deathmatch/tests/bhaptics_soak.gd` is an opt-in, approximately four-minute hardware test, requiring the exact X40 ID after `--`. It runs at 25% with at most four motors active: all 40 motor channels individually, 600 alternating patterns at approximately 10 updates/second, two minutes with no producer submissions, post-idle recovery, ten seconds with a faster producer, explicit stop and watchdog recovery. It checks mapped frames at successful native host writes, connection count, write progress, errors and command-to-host-write timing. Faster producer frames intentionally coalesce into the latest state at the native worker's approximately 20 Hz output rate; the extension is not an every-event queue.

```sh
python3 tools/audit_processes.py --timeout 270 bhaptics-soak -- godot --headless --xr-mode off --log-file /tmp/bhaptics-soak.log --path . --script res://deathmatch/tests/bhaptics_soak.gd -- hci0/dev_AA_BB_CC_DD_EE_FF
```

The test saves `test-results/bhaptics-soak.json` and disconnects the test session on completion or failure. Timing metrics describe host writes, not mechanical motor response or a BLE acknowledgement. A finite soak test cannot establish indefinite connection reliability.

The [2026-09-12 X40 soak run](docs/validation/bhaptics-soak.json) passed in 203 seconds: one native connection, 3,837 successful host writes and zero write errors. All 40 mapped channels and all 600 requested rapid pattern transitions were observed in host writes. Two minutes of idle heartbeat preserved the connection and post-idle output resumed. The faster producer delivered 726 frames in ten seconds (about 73 Hz in this Godot run); bounded Bluetooth output continued without queuing stale effects. Median submission-to-observed-host-write time was 27.7 ms, p95 55.3 ms, maximum 55.4 ms. The largest output-write gap was 52.4 ms; explicit stop after overload was observed in 49 ms. These timings include the test's observation interval and do not measure physical motor latency. The wearer confirmed rapid front/back pulses, silence during idle, resumed pulses after idle and final silence. The session ended with zero output and clean worker/process cleanup.

## FPSloppa Vest v1 game profile

The editable [fpsloppa_vest.json](deathmatch/haptics/fpsloppa_vest.json) defines named motor groups, weapon families and timed stages with delay, duration and a 0–15 level. [profile.gd](deathmatch/haptics/profile.gd) resolves those stages into motor frames for the native plugin. There are no proprietary pattern files or cloud events. Profile stages overlap by maximum per-motor level, never by adding strength; their duration and queued-stage count are bounded. Stop, focus loss and menu transitions clear future stages too. OSC uses the same timing/zones, but necessarily reduces levels to booleans.

| Situation | Vest representation |
| --- | --- |
| Pistols / automatic weapons | Short firing-side upper-chest impulses; independently timed offhand |
| Shotgun / super shotgun | Strong initial kick followed by a weaker second pulse |
| Plasma / lightning / shock | Spaced energy pulses; rapid fire overlaps within the global cap |
| Rockets / BFG / Redeemer | Broader recoil and staged torso decay |
| Incoming bullets, pellets, energy, melee | Different rhythms centered on impact height and incoming side |
| Explosion damage / rocket jumping | Directional onset, core pulse, then a weaker belt pulse |
| Lava / burning, slime, drowning, falling | Lower-torso heat/acid patterns, paired chest pulses for drowning, lower-vest landing cue |
| Health pickup / medic / regeneration / lifesteal | Rising, four-stage front wave from observed local HP gains |
| Armor / power pickup | Optional paired torso or rising torso cues |

Impact positions and current collider height choose upper/lower vest rows, including crouched stances. Incoming direction is transformed by tracked torso yaw where available. **The X40 only covers the torso:** head hits map to the top row, arms to outer vest columns and legs to the bottom row. These are representations, not head/arm/leg devices. Respawns and health gained while feedback is suppressed do not produce delayed healing cues.

To repeat the hardware simulation:

```sh
python3 tools/audit_processes.py --timeout 150 bhaptics-gameplay -- godot --headless --xr-mode off --log-file /tmp/bhaptics-gameplay.log --path . --script res://deathmatch/tests/bhaptics_gameplay.gd -- hci0/dev_AA_BB_CC_DD_EE_FF
```

The 2026-09-12 [profile simulation](docs/validation/bhaptics-gameplay.json) passed all 40 scenarios in about 74 seconds at 25% global strength: 1,307 successful host writes, 243 active writes, one connection and no write errors. Every scenario returned to zero output. The wearer confirmed that the effects were distinct, comfortable and quiet afterward. Separate tests cover weapon-family selection for all three rulesets, localization, healing/respawn guards, settings layout, real ENet client/server traffic and old/new demo hit schemas. The broader legacy `post07.gd` test also reports an unrelated aim-guide length assertion; its damage/demo checks pass.
