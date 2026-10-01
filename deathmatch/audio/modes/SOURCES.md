# Mode effects and environmental beds

Revised from user reference feedback for FPSloppa on 2026-09-30 with `tools/build_mode_audio.py` (NumPy and
ffmpeg). 148 mono effects and ten stereo, 16-second environmental loops; about
6 MiB of audio. Full input/output hashes, durations, levels and firing-cadence
budgets are in `manifest.json`.

The revision removes the shared FM/sine weapon sweeps and ambience drones.
Reports are built from firearm recordings and recorded mechanical/air/liquid
textures. The design follows weapon roles and environment character: dry mechanical CS
reports with distinct suppressors; coarse metallic Quake reports; differentiated
UT bio, shock, flak and plasma; Tribes discs, launchers and support emitters.
These are newly authored interpretations, not recordings from the commercial
games. The existing Freedoom-based Doom bank remains in use.

## Source recordings and licenses

- Historical first-pass source (no longer used in this bank): Tabasco, [Gunshot Sounds](https://opengameart.org/content/gunshot-sounds), CC0.
  Existing edited pistol, shotgun and rifle recordings in `../recorded/` supply
  transients. The original field recordings contain some distortion; the new
  edits add filtered bodies and mechanical detail, not claimed restoration.
- Kenney, [Impact Sounds](https://kenney.nl/assets/impact-sounds), CC0. Existing
  `impactMetal_light_000.ogg` provides mechanical detail. Original notices for
  both sources remain in `../recorded/`.
- Freedoom notices are retained for the earlier bank; revised mode effects no
  longer use Freedoom inputs. The separate Doom bank still does.
- Luke.RUSTLTD, [wind1](https://opengameart.org/content/wind1), CC0. Wind beds
  combine this source with generated air, surf, rain and low-frequency texture.
- yd, [Factory ambiance](https://opengameart.org/content/factory-ambiance), CC0.
  Industrial/tech/arena/void beds use an edited excerpt with procedural layers.

Original sources, download URLs and hashes for the last two recordings are in
`tools/audio-sources/ambience/SOURCES.json`. `factory-edited.wav` was processed
using Audacity 3.7.9 through audacity-mcp-server 0.1.23: 70 Hz high-pass and 3800 Hz
low-pass (12 dB/octave), DC removal, peak normalization to −9 dBFS, mono export.
That retained source makes subsequent builds independent of Audacity state.

New procedural material and edits containing only CC0 inputs are dedicated to
CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/ . Earlier Freedoom
derivatives retain the BSD notice above.

## Recorded replacement sources

- Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney,
  [The Free Firearm Sound Library](https://opengameart.org/node/21826), CC0.
  Ten trimmed recordings provide 9 mm/.45/revolver, AK, carbine, SMG, pump/semi-auto
  shotgun, rifle and sniper roles. Near/mid recording choices and original hashes
  are recorded in `tools/audio-sources/natural-weapons/SOURCES.json`.
- SpringySpringo, [Gun reload sounds](https://opengameart.org/content/gun-reload-sounds),
  CC0: airsoft mechanisms and shotgun cocking.
- jcpmcdonald, [Skippy Fish Water Sound Collection](https://opengameart.org/content/skippy-fish-water-sound-collection),
  CC0: recorded water and bubbles for bio/projector texture.

Retained source excerpts total approximately 1.3 MiB and are excluded from game
exports. They are mono/direct-report crops or original foley files, not game
recordings. Runtime clips preserve irregular transients and decay; energy
weapons use filtered metal/air/liquid and industrial textures instead of pitched
oscillator notes. Quake bandwidth remains rougher; CS reports retain more high
frequency detail. Tribes 2 references apply to matching Starsiege weapons only,
including ELF, repair and targeting tools. Damage, ammunition, cadence and
loadout rules are unchanged. Reference-video audio is not distributed or sampled.

## Mastering and playback

Effects use 32 kHz mono PCM, short attack/release fades, no DC offset, peaks at or
below −6 dBFS, and energy per firing cycle at or below −20 dBFS. Repair and
targeting emitters use lower ceilings. Two variants per non-CS sound and three
per CS sound rotate without immediate repetition; ordinary alt tags share their
primary bank, with distinct UT alternate sounds and CS USP/M4 suppressors.
Runtime effects still use the game's normal volume, attenuation and HRTF paths.

Ambience uses stereo Vorbis, overlap-spliced loops and a −25 dBFS RMS target
before the additional −12 dB playback trim. Wind beds soften indoors using the
existing room probes. Close weapon reports duck only ambience by 7 dB. No new
gunfire, voices, enemy footsteps or objective-like cues are hidden in the beds.
Any matching custom BGM playlist suspends ambience, even while loading or muted.

Validate decoded audio and regenerate the audition reel with:

```sh
python3 tools/review_mode_audio.py --output test-results/audio-review
```

The reel is dry stereo for evaluating timbre and balance, not a binaural headset
capture. Device listening and aesthetic preference remain listening checks.
