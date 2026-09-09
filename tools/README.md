# Asset conversion

Run Blender in background mode with `--python tools/export_weapons.py` or `--python tools/export_fist.py` using an absolute script path. The fist script uses the bundled CC0 VRoid D file. For weapons, extract https://opengameart.org/sites/default/files/afps_weapons.zip into `WeaponSource/` beside the Godot project directory first. That source pack is CC0 by Drummyfish. The game itself uses the already converted files in `deathmatch/weapons/` and does not require Blender.

Run `python3 tools/generate_sounds.py` from any directory to regenerate the twenty original CC0 mono WAV effects with Python’s standard library. The generator uses a fixed random seed; no external samples are required.

`python3 tools/build_release.py` exports Linux/Windows PC clients and a Linux dedicated server, then packages them and the source ZIP. Install matching Godot 4.7.2 export templates first; set GODOT_BIN to choose the executable. `--package-only` refreshes archives from existing binaries. Android presets are experimental and excluded from this release script.

`python3 tools/build_android.py` builds separate Quest/Pico release APKs and validates signing and alignment. See STANDALONE.md for toolchain setup and local signing details. Generated Android templates and caches are excluded from source archives.
