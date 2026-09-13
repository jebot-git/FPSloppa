# BA-2 mechanical stomps

Original FPSloppa procedural sound design, released under CC0-1.0. No third-party samples or recordings were used. Three 1.45-second mono variants combine a sustained ground-compression impact, low-mid rumble, granular asphalt crushing, lower steel resonance, panel rattles and piston hiss. Short dark reflections are baked into each sample. The heavier revision retains the original peak ceiling while increasing low-frequency energy and body; it does not add a runtime reverb effect. 44.1 kHz PCM, normalized to -1.5 dBFS peak before game mixing.

Reproduce with `python3 tools/ba2/audio/generate.py`, then run Godot headless with `--script res://tools/ba2/audio/prepare.gd`. The generated AudioStreamWAV `.res` files are self-contained runtime assets for all platforms. Source WAVs and the walking preview remain under tools and are excluded from exports.

Foot contacts follow the existing authored gait: swing ends at phase 0.20, with subsequent feet offset by quarter cycles (Front.L, Rear.R, Front.R, Rear.L). At 0.8 m/s and 2.52 m stride, impacts are 0.7875 seconds apart. Travel drives cadence, including acceleration/braking; stopped robots produce no new contacts and existing tails finish naturally. Late joins, resets and large travel corrections do not replay missed impacts.

Sounds use the bounded shared spatial mixer, effects volume control, optional Steam Audio backend, static-world muffling and 100 m maximum distance. There are no additional RPCs, continuous audio emitters or timers per robot.

The heavier revision is auditionable in `tools/ba2/audio/walking-preview.wav`. `comparison-before-after.wav` plays the previous version, a one-second gap, then the revision. Technical comparisons are in `test-results/titanball/stomp-weight-comparison.json`. At cruise, the bounded 1.45-second samples overlap by no more than two voices, including existing pitch variation.
