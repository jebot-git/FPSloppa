# Classic arena effects

Freedoom v0.13.0, commit `cfb8644b1a8dc7d7d2177e6a892ccaa2922bdaae`, BSD-3-Clause. [Upstream](https://github.com/freedoom/freedoom/tree/cfb8644b1a8dc7d7d2177e6a892ccaa2922bdaae). Original copyright and terms are preserved in LICENSE.txt; upstream contributors in CREDITS.txt. No commercial Doom sound recordings are included.

Pinned inputs, download URLs and SHA-256 hashes are retained in `tools/audio-sources/freedoom/SOURCES.json`. Output hashes and durations are in manifest.json. Rebuild with `python3 tools/prepare_arena_sfx.py`, then `python3 tools/balance_weapon_audio.py`; ffmpeg is required.

| Output | Inputs |
| --- | --- |
| weapon_1 | dssawful |
| weapon_2, weapon_5 | dspistol |
| weapon_3 | dsshotgn, dssgcock |
| weapon_4 | dsdshtgn, dsdbopn, dsdbload, dsdbcls |
| weapon_6 | dsrlaunc |
| weapon_7 | dsplasma |
| weapon_8 | dsbfg |
| explosion | dsbarexp |
| pickup_ammo | dsdbload, Kenney metal |
| pickup_weapon | dssgcock, dsdbcls |
| pickup_armor | Kenney metal/footstep, dsdbcls |
| pickup_health | Kenney footstep, dsdbopn |
| pickup_mega | Kenney metal, dsdbload, dsdbcls |
| jump_0–2 | Kenney footsteps, edited HaelDB grunts |
| land_0–2 | Kenney footsteps |

Freedoom inputs are band-limited, resampled, trimmed, faded and layered, with levels normalized before runtime weapon attenuation. Outputs are mono 22.05 kHz PCM. Reload layers are cosmetic and do not alter weapon cadence. Jump grunts are shortened and sped up, with a preceding boot push-off; landing layers combine two boot contacts. Pickup cues use mechanical/foley layers without musical oscillators.

Kenney Impact Sounds and HaelDB Male Grunt/Yelling Sounds are CC0 1.0. Their source links, original notices and selected recording names are in `../recorded/SOURCES.md`. Mixed Freedoom/CC0 derivatives retain the Freedoom BSD notice. Jump and landing edits containing only CC0 sources are dedicated to CC0 1.0.
