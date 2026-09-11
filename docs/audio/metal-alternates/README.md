# Selected metal soundtrack and A/B audition

The metal direction was selected after the three-track A/B audition and extended
to all eight gameplay modes. The three auditioned renders are used unchanged.
Title and lobby retain their ambient/elevator arrangements. Files here are
source and comparison assets, excluded from game exports; selected renders are
installed under `deathmatch/audio/music/`.

[Play the complete current-versus-metal comparison](comparison.ogg) — about
89 seconds. Spoken labels introduce DM, CC and Freeze Tag; each pair plays the
previous industrial track first and the selected metal track second.
The original spoken "current" label refers to the industrial version at audition
time; that version is now archived under `docs/audio/industrial-originals/`. The 12-second excerpts
use matching positions in their arrangements and are independently normalized
to −19 LUFS for comparison. The labels are not part of the full music tracks.

| Mode | Candidate | Direction | Full track | A/B comparison |
| --- | --- | --- | --- | --- |
| DM | Iron Teeth | Low E power chords, palm-muted thrash riffing, double-kick accents | [1:51](dm_iron_teeth.ogg) | [Current → metal](dm_comparison.ogg) |
| CC | Chain Drive | Low D guitar groove, syncopated chugs and heavy half-time snare | [1:41](cc_chain_drive.ogg) | [Current → metal](cc_comparison.ogg) |
| Freeze Tag | Cold Anvil | Low C doom riffing, ringing power chords and slow drum weight | [2:28](ft_cold_anvil.ogg) | [Current → metal](ft_comparison.ogg) |
| TDM | Breach Formation | Low D marching metal | [2:00](tdm_breach_formation.ogg) | — |
| CTF | Redline Relay | Fast galloping guitar phrases | [1:45](ctf_redline_relay.ogg) | — |
| KOTH | Crowned in Rust | Half-time low C sludge riffs | [2:12](koth_crowned_in_rust.ogg) | — |
| Instagib | Razor Current | Fast F-sharp riffing | [1:33](ig_razor_current.ogg) | — |
| TF | Siege Engine | C-sharp battle rhythm | [2:04](tf_siege_engine.ogg) | — |

Each candidate has a short introduction, an eight-bar riff and response, an
exposed middle, and a heavier final section. Guitars use separate recorded takes
for left and right, with open/palm-muted articulations, explicit pick attacks,
tight rests and bass following the low root. Saturation is applied after chord
voices combine, followed by filtering and EQ to approximate a guitar amplifier
and cabinet. Drum recordings retain their acoustic attack and cymbal tails.
There are no flute, piano or orchestral pad parts in these candidates.

## Formats and reproduction

The eight full gameplay tracks use stereo 44.1 kHz Vorbis, about 12.70 MiB total. They are
mastered to −19 LUFS with a −3 dBTP target before encoding. These auditions use
a recorded-sample renderer rather than reducing instruments to 8-bit MOD data;
editable note events, articulations, tuning, tempo and checksums are in
`scores.json`. The source remains compact and reproducible.

- `python3 tools/generate_metal_alternates.py` renders all eight metal scores. Add `--install` to install them in-game while
  preserving title/lobby and the archived industrial comparison set.
- `python3 tools/compare_metal_alternates.py` creates the A/B previews and checks
  loudness, peaks, loop seams, sample hashes and the preserved industrial baseline.
- Both require NumPy and FFmpeg. The comparison tool uses `espeak-ng` only for
  spoken A/B labels. Its temporary WAV preview is saved under `test-results/`.
- `comparison.json` contains final measurements and cue timestamps.
- `baseline-hashes.json` records the industrial soundtrack before this audition.

The three original audition tracks decode successfully, measure within 0.2 LU of the intended
level, have true peaks below −2 dBTP after encoding, and pass the loop seam check.
The A/B excerpts measure within 0.15 LU of one another's −19 LUFS target.
Rendering alone does not change playback selection. The explicit `--install`
option installs the metal set; `tools/validate_soundtrack.py` then audits all
eight gameplay tracks plus title/lobby.

## Recorded sources and license

Recordings come from Karoryfer Lecolds' **Black and Green Guitars**,
**Growlybass**, and **Big Rusty Drums**. Guitar recordings are by Brian Wood.
The publisher makes these free libraries available under **CC0 1.0**:
[Karoryfer's source and license notice](https://shop.karoryfer.com/pages/free-samples).

Four additional individual guitar takes are pinned to revision
`b3b3249d37dc977a1a297bd2dc053e6d9b6b805c` of
[sfzinstruments/karoryfer.black-and-green-guitars](https://github.com/sfzinstruments/karoryfer.black-and-green-guitars/tree/b3b3249d37dc977a1a297bd2dc053e6d9b6b805c):
`twang_e3_f_rr1/rr2.wav` and `staccato_e3_rr1/rr2.wav`. The E3 filenames refer to
recorded fundamentals around 82–84 Hz; the renderer measures and tunes each take.
`sources.json` records exact URLs, source SHA-256 values and prepared-file hashes.

Bass, kick, snare, hat and crash recordings reuse the project's existing pinned
[Karoryfer sources](../../../deathmatch/audio/music/SOURCES.md). Prepared source
snippets keep the first four seconds (or the entire shorter recording), converted
to mono 44.1 kHz signed 16-bit PCM with metadata removed. No full sample library
or existing song is included.

These original compositions, arrangements, edited instruments and music renders
are dedicated under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).
This does not change the licenses of the game, its tools or other assets.
