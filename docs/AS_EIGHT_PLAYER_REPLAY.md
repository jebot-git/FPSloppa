# Eight-player Assault demo and announcer update

Recorded a dedicated server and eight separate ENet clients (4v4) on the HiSpeed concept BSP. The final recording is `Builds/HiSpeed-Concept/recordings/as-eight-02.fpsdemo`; `as-eight-01` and earlier video exports are superseded diagnostic captures.

The 22.62-second demo contains 453 authoritative frames, all eight players, both ordered objectives in each leg, the role swap, combat/deaths/projectiles and BLUE winning the return assault. This is the existing short scripted regression scenario: the harness stages duels, moves players to objectives and adjusts the clock. It is not an unassisted navigation playthrough or balance test.

The visual review found that the original duel setup used an incorrect roof height. The final setup raycasts the actual BSP roof before placing participants. Replays also now advance the effects/audio clock. Movie export advances exactly once per captured frame and holds the final view until queued voice playback finishes. A gib-expiry callback found during the crowded combat replay was changed to use a weak reference, avoiding references to gibs evicted by the 32-piece limit.

The final H.264/AAC video is 27 seconds (810 frames at 1440×900 / 30 FPS), including an audio-aware final hold. Full decode validation passes; its render log confirms all four objective calls started, no queued/playing voice remains at the end, and no runtime errors occurred.

Production replay validation checks the complete file, all eight first-person/chase viewpoints, seeking, both legs, projectiles, effects and the final score. All four AS objective-complete voice events are present exactly once. Legacy recordings containing removed voice names remain readable, while those calls are suppressed.

## Announcer behavior

Active calls are first blood, double kill, triple kill, rampage, dominating, unstoppable, and objective completed. Objective completed is global for TF flag captures and each AS objective. Closely spaced distinct objectives each retain their queued voice. The existing capture fanfare is unchanged.

Match start, team/mode introductions, capture-the-flag introduction, last-man-standing, round-winner and game-over voice recordings have been removed from the runtime audio directory. Their attribution, license, source manifest and audio are archived under `docs/audio/retired-announcer/`, excluded from exports.

## Files and reproduction

- Final demo: `../Builds/HiSpeed-Concept/recordings/as-eight-02.fpsdemo`
- Final chase video: `../Builds/HiSpeed-Concept/videos/eight-player-02-final/hispeed-as-chase.mp4`
- Required map: `../Builds/HiSpeed-Concept/maps/tf_hispeed_concept.bsp` (SHA-256 `af9d23ae64f764b4ed768b6f297797665fbe707c8483a3d6d43ba1c3f2a1a495`)
- Network results: `test-results/as-eight-recorded-02/RESULT.json`
- Replay results: `test-results/as-eight-replay.json`, `as-eight-replay-02.log`
- Audio policy/mixer results: `test-results/announcer-results.json`
- TF capture voice check: `test-results/tf-objective-announcer.log`

From the Godot project directory, substitute your Godot 4.7.2 binary for `Godot`:

```sh
Godot --path . --xr-mode off --fixed-fps 30 --rendering-method mobile --script res://deathmatch/tests/hispeed_movie.gd -- ../Builds/HiSpeed-Concept/recordings/as-eight-02.fpsdemo ../Builds/HiSpeed-Concept/maps/tf_hispeed_concept.bsp chase
```

This replays the recorded match in a desktop window, following the attacking team. For interactive viewpoint controls, install the matching BSP in the game's external `maps/` directory, then open the demo using `--demo PATH --demo-view chase` in desktop mode.

The headless checks report the pre-existing ObjectDB shutdown warning; graphical teardown also reports retained resources. Runtime script errors are checked separately and are not accepted. This work does not constitute headset or release-build validation.
