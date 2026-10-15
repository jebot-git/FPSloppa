# CQ Frontier field audio sources

Runtime edits by the FPSloppa project. Source licenses apply to each derivative; no original commercial game recordings are included. All sources are CC0-1.0 except the heavy-engine recording, used under CC-BY-3.0. The latter is credited below and its license is retained.

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
