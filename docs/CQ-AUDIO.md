# CQ music and district ambience

The experimental CQ desktop client now opens on a small campaign menu with
**Standards at Dusk**, a quiet military orchestral cue. Music and ambience have
independent volume sliders, saved in `user://cq_audio.cfg`. `autoconnect: true` in
client JSON skips the menu; existing smoke-test configurations still autojoin.

In a district, only its quiet environmental loop plays until combat starts.
**Iron Vespers** is an original brass-led orchestral action cue with driving
strings, horn melody, low brass, timpani, snare and concert percussion. It uses
the requested broad Basil Poledouris action-score vocabulary; it contains no
reference soundtrack recordings or quoted melodies. The menu cue shares its
original theme in a restrained arrangement.

| Asset | Length | Measured level before volume controls |
|---|---:|---:|
| Iron Vespers | 1:46.667, 144 BPM | -19 LUFS |
| Standards at Dusk | 1:20, 72 BPM | -27 LUFS |
| Eleven district ambience loops | 1:04 each | approximately -35 LUFS |

All 81 maps use their existing theme to select cathedral, bastion, arcology,
data, docks, foundry, garden, market, observatory, reactor or transit ambience.
Air, electrical/ventilation hum, distant mechanical traffic and sparse metal
resonances vary by theme. There is no environmental music, intelligible speech
or simulated gunfire in these beds. The complete mapping is in
`deathmatch/audio/cq/manifest.json`. Encoded runtime audio totals about **14.5 MiB**.

## Combat and fades

The client reads existing authoritative snapshots; no extra protocol fields,
worker synthesis, master traffic or uploaded sound files are introduced.

* A confirmed local shot or melee action starts music.
* Enemy shots within 75 m start music; allied shots do so only with an enemy
  nearby. Distant fights and unopposed allied target practice leave ambience alone.
* Nearby hostile projectiles, combat hurt events and health/armour loss near an
  enemy also trigger it. Held fire without a confirmed event is insufficient.
* Each new event extends a 12-second combat hold. Repeated snapshot sequences
  do not extend it. After the hold, the score fades out over up to three seconds.
* Death and district changes clear the hold. The no-fire hub (d40) and waiting
  room suppress combat music entirely.
* Music fades in over about one second. District beds crossfade over 2.5 seconds
  and are quieter under combat music. At most **three streams** play at once,
  with at most four compressed streams cached. Vorbis decoding happens locally;
  all synthesis, tuning, orchestration and reverb are baked offline.

Audio settings can also be supplied as `music_volume` and `ambience_volume`
(client JSON numbers from 0 to 1). These override saved slider values for that
launch. Muting music leaves ambience available.

## Sources and rebuild

The music was composed/rendered locally from individually recorded **VSCO 2
Community Edition** instruments. The publisher provides those under CC0:
[Versilian Studios](https://versilian-studios.com/vsco-community/).
The generated compositions and procedural ambience are also dedicated to CC0.
Full credits and the license are in `deathmatch/audio/cq/SOURCES.md` and
`VSCO-LICENSE.txt`. Pinned sample paths and SHA-256 checksums are recorded under
`tools/cq_audio/`; source recordings are fetched build inputs, not runtime assets.

```sh
python3 tools/cq_audio/fetch_samples.py
python3 tools/cq_audio/render.py
# Optional selective render:
python3 tools/cq_audio/render.py --only combat menu
```

This needs Python, NumPy and FFmpeg. Every pitched event is saved in the two
`.score.json` files. The renderer checks finite decoded samples, true peaks,
encoded duration and loop discontinuities, and retains boundary auditions under
`test-results/cq-audio-render/`. Music/reverb tails wrap into the loop start.

## Verification

```sh
godot --headless --xr-mode off --path . --script tools/district_cluster/test_soundscape.gd
python3 -m tools.district_cluster.audio_live_test --output /tmp/fresh-cq-audio-test
```

The state test covers menu playback, independent sliders, join retry, nearby vs
far combat, allied target practice, snapshot deduplication, the inactivity fade,
death, hub/waiting suppression, damage, hostile projectiles, all 81 district
assignments, and bounded cache/voice counts. A Vulkan menu screenshot and real
CQ worker/ENet combat transition receipt are recorded under `docs/validation/`.
The existing packaged service/VRM live test also passed with the soundscape enabled.
This is the separate experimental desktop client's audio path; the worker and
master packages remain headless and contain no new audio dependencies.
