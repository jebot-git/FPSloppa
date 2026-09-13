# Direct Bluetooth Godot prototype

A standalone addon for other Godot projects is maintained in [godot-bhaptics-native](https://github.com/jebot-git/godot-bhaptics-native), with its own API, demo and release binaries. This directory remains FPSloppa’s integrated version.

Linux/Windows x86_64 and Android ARM64 GDExtension source, targeting Godot API 4.5. Built for all three targets; physically tested on Linux in Godot 4.7.2 with TactSuit X40. No proprietary bHaptics Player, SDK binary, credentials or helper process is used. See [BHAPTICS.md](../../BHAPTICS.md) for build instructions, settings and validation limits.

`native/src/lib.rs` implements the Godot class and bounded Bluetooth worker. `native/Cargo.lock` fixes dependency versions. The installed library and `.gdextension` descriptor are ignored build artifacts; `.gdextension.in` is the source template. The export plugin excludes this addon on unsupported architectures/platforms, on dedicated-server targets and when the target native library is absent. Windows cross-compilation uses LLVM-MinGW and includes libunwind; an exported Godot smoke app passes under Wine. Android combines the ARM64 library with `android/BhapticsAndroid.java` and pinned upstream Java helpers in a Godot v2 AAR. Permission requests and JNI initialization occur only when Scan/Connect is selected. See the main guide for build commands and hardware-validation limits.

## Sources and notices

- [freehaptics 0.3.1](https://docs.rs/crate/freehaptics/0.3.1), by Orion Moonclaw, LGPL-3.0-or-later: direct BLE protocol, X40/Air mapping and motor frame encoder. [Upstream source](https://codeberg.org/Orion_Moonclaw/freehaptics), [versioned source archive](https://static.crates.io/crates/freehaptics/freehaptics-0.3.1.crate). The dependency is unmodified.
- [godot-rust 0.5.5](https://docs.rs/godot/0.5.5/godot/): GDExtension bindings.
- [btleplug 0.11.8](https://docs.rs/btleplug/0.11.8/btleplug/): Bluetooth discovery and device connection.
- Android additionally uses jni 0.19.0 and jni-utils 0.1.1. Their versions and the Java sources packaged from btleplug/jni-utils are fixed by Cargo.lock.
- LLVM-MinGW Windows builds require the bundled libunwind DLL; the toolchain license is copied beside it.
- Tokio and serde_json provide the worker runtime and status serialization. Exact versions of these and transitive dependencies are recorded in `native/Cargo.lock`.

This native component is licensed LGPL-3.0-or-later, as declared in `native/Cargo.toml` and the source header. [COPYING.LESSER](COPYING.LESSER) contains LGPLv3 and [COPYING](COPYING) contains its GPLv3 base terms. Package corresponding sources and dependency notices alongside any distributed native build; the development build helper currently installs the local library and descriptor only.

The independent library describes itself as work in progress. Support is limited to the model names with implemented mappings; no arbitrary BLE device is accepted. The X40 motor characteristic checked before use is `6e40000a-b5a3-f393-e0a9-e50e24dcca9e`. No pairing database, bond keys, firmware or persistent device settings are read or modified by this extension.

The game profile uses `submit_levels` for per-motor 0–15 amplitudes multiplied by the global strength. Legacy boolean `submit_frame` remains available. See the FPSloppa Vest v1 section in the user guide for the editable profile and scenario simulation.
