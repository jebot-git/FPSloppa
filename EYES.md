# VRM eye tracking

Gaze and measured blinks are cosmetic and replicate with the existing XR pose snapshots. All peers must use the same current game protocol. Eye tracking never affects aim, collision or damage.

The OpenXR `XR_EXT_eye_gaze_interaction` profile supplies combined gaze through `/user/eyes_ext`. Runtimes exposing a Godot `XRFaceTracker` at `/user/face_tracker` additionally supply left/right eyelid closure and, when combined gaze is absent, eye-look weights. The official Vendors plugin's optional Meta face extension is enabled for capable hardware such as standalone Quest Pro. Permit the headset's tracking permissions; if first-time permission changes do not activate the tracker, restart the app.

Hardware eye-tracking support alone is insufficient: the active OpenXR runtime must expose the relevant extension. A PC headset's vendor software or streaming runtime may expose gaze without eyelids, or neither. Quest headsets without eye-tracking sensors cannot supply measured eye motion. Generic gaze does not contain blink data, so the game does not pretend to synchronize blinks in that case. Native input paths are covered by simulated Godot XR tracker tests; hardware findings are recorded separately in LIVE_VR_TEST.md.

On VRMs with both eye bones, the driver rotates them relative to their authored rests and never changes eye-bone positions. Otherwise it uses declared `lookLeft`, `lookRight`, `lookUp`, `lookDown` expression bindings. It supports VRM 0.x and 1.0 expression animations. Missing expressions/bones are simply skipped. Left/right blink expressions are preferred; a combined blink expression is the fallback.

Limits are applied both to network input and to rendering:

- Horizontal rotation: ±12 degrees; vertical: ±8 degrees.
- Look-expression weights: at most 0.30; opposing directions never blend together.
- Blink weights: at most 0.90, with combined bindings also capped after summing.
- Eye deflection reduces as eyelids close; gaze and eyelids are smoothed separately.
- Nonfinite/malformed cosmetic data is discarded while valid weapon poses remain usable. Session focus loss or disappearance of tracker data returns eyes to rest.

These conservative limits reduce clipping on the bundled models. An arbitrary custom VRM can contain malformed bone pivots or self-intersecting blend shapes; numerical clamps cannot repair such geometry. Fix those shapes in the source avatar if necessary. Voice-driven mouth shapes continue to work independently. Only bounded angles, blink weights and capability flags are networked; eye-camera images are not captured or transmitted.

Implementation: `deathmatch/vr/eyes.gd`, `deathmatch/avatars/eyes.gd`, and `deathmatch/vr/poses.gd`. Validation: `deathmatch/tests/eyes_bots.gd` and the real ENet scenario in `run_network_tests.py`.

References: [Godot vendor body/face tracking](https://godotvr.github.io/godot_openxr_vendors/manual/body_tracking.html), [XRFaceTracker API](https://docs.godotengine.org/en/stable/classes/class_xrfacetracker.html).

The lobby mirror forwards the full local XR pose, including measured eyelid closure, to its avatar. Linux x86_64 includes a vendor face-source compatibility patch for visual-only runtimes such as WiVRn; provenance and rebuild instructions are in `addons/godotopenxrvendors/FPSLOPPA-NOTES.md`.
