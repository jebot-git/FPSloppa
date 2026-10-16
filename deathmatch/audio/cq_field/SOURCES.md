# CQ Frontier field audio sources

`building_collapse.wav` is a CC0 derivative of the existing Thimras **Battle at Sea** cannon-impact edits and denalwa thunder edit credited below. The project remix layers slowed, staggered impacts with low-pass rumble and a finite 3.5-second fade. Reproduce with `python3 tools/cq_audio/build_collapse.py`; its exact FFmpeg filter recipe and output hash are in `manifest.json`.

Runtime edits by the FPSloppa project. Source licenses apply to each derivative; no original commercial game recordings are included. Most sources are CC0-1.0. The heavy-engine recording uses CC-BY-3.0; the rocket-tank launch/travel recordings use the Pixabay Content License. Source-specific credits and terms are retained below.

| Source | Author | License | Download quality |
| --- | --- | --- | --- |
| [scifi](https://opengameart.org/content/50-cc0-sci-fi-sfx) | rubberduck | CC0-1.0 | original download |
| [motor_start](https://opengameart.org/content/enginemechanic-working-sound) | jwiese | CC0-1.0 | original download |
| [motor_loop](https://opengameart.org/content/enginemechanic-working-sound) | jwiese | CC0-1.0 | original download |
| [motor_end](https://opengameart.org/content/enginemechanic-working-sound) | jwiese | CC0-1.0 | original download |
| [heavy_engine](https://opengameart.org/content/engine-loop-heavy-vehicletank) | Nayckron and qubodup | CC-BY-3.0 | original download |
| [birds](https://opengameart.org/content/park-ambiences) | Thimras | CC0-1.0 | original download |
| [river](https://opengameart.org/content/park-ambiences) | Thimras | CC0-1.0 | original download |
| [rain](https://freesound.org/people/florianreichelt/sounds/422052/) | florianreichelt | CC0-1.0 | Freesound public HQ MP3 preview |
| [thunder](https://freesound.org/people/denalwa/sounds/472480/) | denalwa | CC0-1.0 | Freesound public HQ MP3 preview |
| [night](https://freesound.org/people/hdfreema/sounds/333221/) | hdfreema | CC0-1.0 | Freesound public HQ MP3 preview |
| [blacklodge](https://opengameart.org/content/50-free-scifi-soundfx-192khz-64-bit-24576kbps-wav) | blacklodgegames | CC0-1.0 | original download |
| [bolt](https://opengameart.org/content/gun-reload-sounds) | SpringySpringo | CC0-1.0 | original download |
| [clip1](https://opengameart.org/content/gun-reload-sound-effects) | Brian MacIntosh (BMacZero) | CC0-1.0 | original download |
| [clip2](https://opengameart.org/content/gun-reload-sound-effects) | Brian MacIntosh (BMacZero) | CC0-1.0 | original download |
| [tabasco_existing](https://opengameart.org/content/gunshot-sounds) | Tabasco | CC0-1.0 | existing project edit of original gunshot recording |

`engine_heavy.wav` and `engine_transport.wav`: **Engine-loop heavy vehicle/tank**, by **Nayckron**, derived from **qubodup**’s car-loop recording, [OpenGameArt](https://opengameart.org/content/engine-loop-heavy-vehicletank), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). Changes: pitch/resampling, mono conversion, filtering, DC removal, loop crossfade and level trim. No endorsement is implied.

`pistol`, `pistol_suppressed` and `smg` reuse the existing Tabasco CC0 field-recorded pistol transient; its original archive and notice remain in `../recorded/`.

The Freesound inputs are the site’s publicly served HQ MP3 previews, rather than authenticated lossless originals. Their exact URLs and SHA-256 values are recorded in `sources.json`. No Freesound credentials or API key were used. OGA inputs are original downloads.

Six intermediates were trimmed, filtered and normalized using Audacity 3.7.7 via xDarkzx/Audacity-MCP 0.1.24. Runtime editing includes band limiting, downsampling to mono 24 kHz PCM16, pitch changes, peak/RMS trim, edge fades and end-to-start loop crossfades. Ambience is Ogg, with stereo preserved for forest and river recordings. `manifest.json` maps every cue to its sources and processing.

Reproduction:

```sh
python3 tools/cq_audio/fetch_field_sources.py
# With Audacity 3.x running and mod-script-pipe enabled:
/path/to/audacity-mcp-python tools/cq_audio/edit_field_sources.py
/path/to/python-with-numpy tools/cq_audio/build_field_audio.py
/path/to/python-with-numpy tools/cq_audio/validate_field_audio.py
```

Fetched originals and intermediates live under the ignored `tools/audio-sources/cq-field/` cache and are excluded from the frontier deployment package. Retain this file, the source manifest and license notice when distributing the edited sounds.

## Weapon reauthoring pass, 2026-10-15

Seven energy/projectile reports and `energy_impact` now use the following user-selected CC0 recordings. The pistol/SMG retain the Tabasco firearm attack, with a quiet layered body; the suppressed pistol uses a lower level and narrow bandwidth. The energy family uses isolated blaster/pulse takes, with a heavier, longer beam report. Launchers and ordnance impacts retain their previous sounds.

| Recording | Author | License |
| --- | --- | --- |
| [BLASTER (multiple)](https://freesound.org/people/C3Sabertooth/sounds/480872/) | C3Sabertooth | CC0-1.0 |
| [blaster shot single 4](https://freesound.org/people/MikeE63/sounds/466868/) | MikeE63 | CC0-1.0 |
| [enhanced blaster](https://freesound.org/people/MikeE63/sounds/466834/) | MikeE63 | CC0-1.0 |
| [LAPD 2049 PKD Blaster](https://freesound.org/people/nioczkus/sounds/378185/) | nioczkus | CC0-1.0 |
| [ScifiHeavyBlasterShot](https://freesound.org/people/SuperPhat/sounds/531861/) | SuperPhat | CC0-1.0 |
| [JH FX Sci-Fi Energy Weapons 1](https://freesound.org/people/Johnnie_Holiday/sounds/697894/) | Johnnie_Holiday | CC0-1.0 |
| [Sci-fi gun shot x6](https://freesound.org/people/humanoide9000/sounds/330293/) | humanoide9000 | CC0-1.0 |
| [laserblast effect](https://freesound.org/people/LimitSnap_Creations/sounds/344809/) | LimitSnap_Creations | CC0-1.0 |

These inputs are public HQ MP3 previews, with pinned download URLs and hashes. Layer isolation, relative gains and playback rates are recorded in `manifest.json`; Audacity MCP performs the mix, filtering, attack/tail fades, DC removal and normalization. Runtime encoding is mono 24 kHz PCM16. The [authoring recipes, MCP receipt and cadence audition](../../../docs/audio/cq-weapons-20261015/README.md) document the pass.

Fourteen further takes are edited in `tools/cq_audio/tier_reserve/`, with their own manifest and credits; they are intentionally unassigned and excluded from runtime resource scanning and packaging. `reauthor_weapons.py --fetch` downloads verified source inputs; run the script without flags to author through Audacity, or `--build` to encode existing edited masters. Full-library regeneration now finishes with this weapon pass, so it cannot silently restore the older reports.

## Vehicle fire and explosions, 2026-10-15

- **Battle at Sea**, by **Thimras**, [OpenGameArt](https://opengameart.org/content/battle-at-sea), [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/): original Ogg downloads `cannon_fire_1`, `cannon_hit_cannon_1`, `cannon_hit_1`, `cannon_hit_wall_no_splash`. These form distinct light/heavy/turret firing reports and the shared ordnance explosion; a quiet cannon transient reinforces the rocket launch.
- **Katyusha Rocket (Multiple)**, by **kuiycb**, [Pixabay](https://pixabay.com/sound-effects/technology-katyusha-rocket-multiple-114774/), **Pixabay Content License**: a short single-launch excerpt, mixed with cannon attack and filtered/faded for the rocket tank's eight-round cadence.
- **Rocket Loop**, by **Mozfoo (Freesound)**, distributed by **freesound_community**, [Pixabay](https://pixabay.com/sound-effects/film-special-effects-rocket-loop-99748/), **Pixabay Content License**: interior motor excerpt, Audacity filtering/normalization, followed by mono conversion, gain trim and a 120 ms loop crossfade.

[Pixabay Content License summary](https://pixabay.com/service/license-summary/) and [full terms](https://pixabay.com/service/terms/). These two derivatives are not CC0 and are supplied as integrated game effects. Their original MP3s remain in the ignored authoring cache. They were downloaded by the user, then copied from local Downloads because automated Pixabay requests returned HTTP 403. Exact input hashes, source pages and layer recipes are recorded in the manifests. Do not relabel these derivatives under the project's source-code license.

[Audition, recipes and Audacity MCP receipt](../../../docs/audio/cq-vehicles-20261015/README.md). Six masters were mixed/filtered/faded/normalized/exported through Audacity MCP; the runtime build performs 24 kHz PCM16 encoding and loop construction. `tools/cq_audio/reauthor_vehicles.py` reproduces this pass. Manually downloaded Pixabay sources must be supplied in the documented cache paths; source validation checks their hashes.

## User-selected jungle recordings, 2026-10-15

The five original WAVs supplied by the user as **CC0-1.0** replace the interim synthesized day/night beds. Original WAV hashes, authors from the supplied filenames, source pages and exact layer recipes are pinned in `tools/cq_audio/jungle_mix.json` and `sources.json`. These are original user downloads, not the older HQ-preview sources described above. The user's CC0 declaration is recorded; the source pages were not independently retrievable during this pass.

| Recording | Author | Source |
| --- | --- | --- |
| 653743__nonamethefish__peruvian-amazon-birds-frogs-daytime.wav | nonamethefish | [Freesound](https://freesound.org/people/nonamethefish/sounds/653743/) |
| 653742__nonamethefish__peruvian-amazon-frogs-birds-jungle.wav | nonamethefish | [Freesound](https://freesound.org/people/nonamethefish/sounds/653742/) |
| 332727__sethlind__birds-and-bugs-in-the-woods-of-costa-rica.wav | sethlind | [Freesound](https://freesound.org/people/sethlind/sounds/332727/) |
| 619311__nicotep__ambiente_lacandon.wav | nicotep | [Freesound](https://freesound.org/people/nicotep/sounds/619311/) |
| 276067__anne82__jungleathmo.wav | anne82 | [Freesound](https://freesound.org/people/anne82/sounds/276067/) |

Daytime layers Peruvian daytime birds/frogs, Lacandon ambience and a quiet jungleathmo bed. Nighttime layers the Peruvian frog recording with jungleathmo and Lacandon. The Costa Rican layer was removed after the live rooster report; its original and credit remain preserved. Four supplied recordings are used across the pair. No music or synthetic replacement bed is added.

Source excerpts are band-limited, DC-corrected, level-matched and crossfaded into 128-second stereo stems. Audacity MCP applies the pinned per-layer gain ratios and exports stereo masters. Runtime finishing applies an eight-second equal-power tail/head overlap, quiet peak/RMS trim and 24 kHz stereo Vorbis encoding; each final loop is 120 seconds. Existing adaptive day/night/POI mixing, ambience slider and quiet runtime gains remain in effect.

Audacity's track-properties gain command did not change the actual audio gain in this installation. The final masters instead use verified `effect_amplify` ratios; exports correlate above 0.999 with the intended weighted source mix. Intermediate drafts are not used by the game.

Copy the five original WAVs into ignored `tools/audio-sources/cq-field/`, then run `python3 tools/cq_audio/reauthor_jungle.py`. `--stems DIRECTORY` prepares the editable layers; `--master-dir DIRECTORY` consumes Audacity's `forest_day.wav` and `forest_night.wav` exports. The ordinary field-audio build invokes this pass last, so rebuilding does not restore the old synthesized ambience. [Audition, verification and Audacity receipt](../../../docs/audio/cq-jungle-20261015/README.md).


## Daytime rooster correction, 2026-10-16

The daytime mix now excludes Peruvian daytime birds, Lacandon and jungleathmo after the repeated rooster report. It uses an insect-focused excerpt of hdfreema's [Night Crickets Back Porch](https://freesound.org/people/hdfreema/sounds/333221/), CC0, from the already cached public HQ MP3 preview. Source 60–188s is filtered in Audacity MCP and crossfaded to 120s. The night mix is unchanged. This section supersedes the daytime layering description above. [Current audition and verification](../../../docs/audio/cq-jungle-20261016/README.md). Use `reauthor_jungle.py --period day` to rebuild only daytime.
