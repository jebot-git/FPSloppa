# NVG exposure and nearby equipment cues — 14 October 2026

Implemented in `experimental/cq-voxelspace`; these changes have not been deployed or evaluated through a headset.

## Behaviour

Daylight grain amplitude rises from .045 to .65 for regular NVG and .012 to .18 for scout NVG. Daylight itself does not request whiteout. Direct visible lamps use a 2.5° outer/.6° inner gaze cone; the sun uses 1°/.25°. Looking away clears local whiteout immediately. Static visibility is cached at 10 Hz, while gaze alignment is evaluated every rendered frame.

Muzzle flashes and explosions generate bounded, soft-edged angular white spots. Radius scales with physical source size and distance, with a .35-radian cap preventing a nearby blast from requesting full-field whiteout. Cover and rearward sources are rejected. Transient spots do not impose authoritative blindness or globally disable spotting. Native C++ owns direct-source gameplay checks; GPU and local presentation own exposure rendering. Each eye receives its own transformed source directions; at most 12 spots/384 bytes per eye are retained.

Original CC0 NVG detent (110 ms, −18 dB) and cloak pulse (380 ms, −20 dB) use the existing spatial effects backend, distance attenuation and wall muffling. They have a hard 8 m proximity limit and at most 12 concurrent voices. NVG on/off and cloak activation follow accepted state transitions, including nearby opponents. Joining, respawning and repeated snapshots prime silently. Cloak clock-offset jitter cannot replay activation. No extra RPCs or wire fields were added.

## Validation

- 12 actual Vulkan compositor checks passed on Intel Arc A770. Fixed-time daylight high-frequency variation measured .15268 versus .00383 at night (~40×). Doubling flash radius increased sampled white area from 375 to 1,486 pixels; doubling distance reduced it to 95. Soft borders, rear rejection, capped near blasts, immediate look-away and separate eye origins passed.
- 25 NVG service checks passed, including cover, direct/peripheral source distinction, expiry and no transient spotting penalty.
- 16 equipment-audio checks passed using actual imported streams and spatial backend, including quiet range, bounded voices, accepted edges, repeated snapshots, clock jitter and respawn baseline.
- 909,771 standalone native checks passed, also under ASan/UBSan. Portable Linux server build and source receipt verified.
- 33,891 Jolt adapter/VR/terrain/entity/transport checks passed. Tracked 32- and 64-client jungle smoke runs completed 301 ticks each with zero disconnects and >99.6% of minimum offered inputs accepted.

The full native smoke source manifest predates the final client-only cloak jitter guard. Native sources and library are unchanged; the final equipment-audio test and source manifest include that guard. GPU checks use a mono render target and separate-eye math checks, not a live OpenXR multiview session. Quiet cue audibility and tuning still require a headset/live proximity test. No live server or client was restarted for this work.
