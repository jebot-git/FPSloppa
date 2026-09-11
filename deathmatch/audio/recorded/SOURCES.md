# Recorded sound sources

Gunshots: Tabasco, CC0, https://opengameart.org/content/gunshot-sounds
Original archive: https://opengameart.org/sites/default/files/sounds.zip
CZ-52 and SKS transients trimmed into four variants each; shotgun trimmed into one variant for each shotgun. Mono 48 kHz, high-pass, noise reduction, limiter and tail fades. See tools/prepare_recorded_sounds.py. These field recordings retain some distortion from the original recording.

Concrete footsteps, heavy punches and light metal impacts: Kenney Impact Sounds, CC0, https://kenney.nl/assets/impact-sounds
Original archive: https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip
Five variants of each, retained in Ogg format. Both original license notices are included here. Remaining energy, chainsaw and explosion sounds are original procedural project audio.

## Pain feedback (0.3v)

Three short human grunts by **HaelDB**, from [Male Grunt/Yelling Sounds](https://opengameart.org/content/male-gruntyelling-sounds), used under its offered **CC0 1.0** license.
Archive: https://opengameart.org/sites/default/files/yelling%20sounds.zip .
Selected files: `yelling sounds/3grunt3.wav`, `3grunt4.wav`, `3grunt5.wav`; converted to mono 22.05 kHz PCM, high-pass filtered at 80 Hz, faded and peak-normalized to −3 dBFS as `pain_0/1/2.wav`.

Regenerate using `python3 tools/generate_feedback_sounds.py /path/to/extracted/grunts`. The same tool authors pickup, respawn and powerful-item spawn cues, layering original tonal/percussive envelopes with the existing Kenney CC0 `impactMetal_light_000.ogg` recording. These new cues are also dedicated under CC0 1.0. No weapon recording or weapon-level calibration is changed.

Archive SHA-256: `e9100a4e3b9dcd146993089970dc6097dcf9935fa4683b196040012bad65d67a`.

## Chainsaw contact

`../saw_grind.wav` is an original 220 ms grinding cue, dedicated under CC0 1.0.
`tools/generate_saw_grind.py` layers the existing Kenney CC0
`impactMetal_light_000.ogg` transient with seeded filtered noise and mechanical
pulses, producing mono 32 kHz PCM at −8 dBFS peak. It uses the normal effects bus,
spatial attenuation and a per-player 180 ms contact-feedback limit. It does not
change the weapon-report loudness calibration.

## Current selection

Weapon reports, explosions and pickups now select the edited effects described in `../doom-style/SOURCES.md`. The field-recorded gunshots and generated tonal pickups above remain legacy assets. Footsteps, impacts and pain grunts remain active; their CC0 recordings also supply the new pickup and jump/landing layers.
