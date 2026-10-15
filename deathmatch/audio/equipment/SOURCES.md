# Equipment activation SFX

Original deterministic FPSloppa synthesis, dedicated to CC0-1.0.
No third-party recordings or music.

`nvg_toggle.wav`: 110 ms mechanical detent/electrical click.
`cloak_on.wav`: 380 ms subdued coil/air pulse.
Mono PCM16 at 24 kHz, normalized peak 0.7; playback is quiet and spatialized,
with a hard 8 m proximity limit, distance falloff and wall muffling.

Rebuild: `python3 tools/cq_audio/generate_equipment.py`.
