# Anime bundles and continued native client port — 2026-10-16

## Delivered

Thirteen new selectable avatar variants, including all seven AsiaBots variants found in its package. All pass the bounded UTAV reader and SHA256 checks. The native renderer produced [idle](idle.png) and [tracked](tracked.png) galleries on the Intel N95 / Intel ADL-N, Godot 4.7.2 Forward+. These images show the supplied source textures rather than invented replacements. See [asset notes and source terms](../../../deathmatch/avatars/models/anime/README.md) and [per-asset provenance](bundles.json).

Asuka's AMS skeletal animation dependency is baked offline, preserving 1,152 frames and deriving tracked IK weights from original bones. No AMS runtime is required. The server cooker now shares the client manifest instead of selecting only five stock models: native validation accepts 25 bundled avatars totalling 161,587,400 bytes. Map collision/navigation is unchanged.

`FPSMovement.snapshot_apply_fields` validates a row batch before applying player fields, remote blast deltas and authoritative targets. `FPSMovement.prediction_reconcile` now owns ACK/reconciliation orchestration, stamina and jetpack correction and posture decisions. Existing engine/scene adapters still handle height, view reset and collision correction. Lifecycle, cosmetic callbacks and compatibility dictionaries remain scripted; this is another completed port slice, not completion of the client port. Reference switches: `--gdscript-client-state` and `--gdscript-reconciliation`.

## Validation

- [239 differential/state checks](client-state.log) passed. For 64 players: reference 314.72 µs, native 103.67 µs; 128 players: 612.93 µs versus 203.51 µs. This is about 3× faster for the field-application fixture, not whole-client FPS or server capacity.
- [All 13 bundle renders](render.log) passed in idle and tracked poses. No real headset test performed.
- [Local prediction](local-prediction.log), 472 compression-policy checks and [native cooked-world validation](world-validation.log) passed.
- Isolated local standalone authority, desktop Kusanagi and simulated tracked Asuka: both client fixtures reported zero failures, observed combat/death/respawn/team/destruction/utility flows and zero steady-state corrections/resets. See [desktop result](desktop-client.json) and [tracked result](tracked-client.json). CLI selected the new bundle hashes; persisted server profile confirms the final Kusanagi hash `7b4cf5608865a0bfcab3f9b474b5e8d45ada38c913487bffbc50f7e0abef54cc`. The fixture does not independently assert the rendered avatar identity.
- Obstacle suite retains one failure: Quake wall-stop view motion is 0.0050260723 m against a 0.005 m threshold. [Native](obstacles-native.log) and [reference](obstacles-reference.log) produce identical metrics and the same failure; other obstacle checks pass. The threshold was not relaxed.

No VPS deployment, public asset redistribution or capacity benchmark was performed for this change. The isolated test authority has exited.
