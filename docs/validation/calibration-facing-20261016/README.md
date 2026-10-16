# Calibration preview facing — 2026-10-16

The preview now removes tracking-origin horizontal translation and headset yaw from a private pose copy. It applies the same rigid frame to head, hands, weapon and other tracked transforms. Head height, pitch/roll, relative reach, scale metadata and handedness remain intact. The existing horizontal texture flip provides the mirror. Vertical gaze reuses the last usable horizontal facing. Multiplayer and real controller transforms are not changed.

Validation on Godot 4.7.2:

- `--headless --xr-mode off --path . --script deathmatch/tests/calibration_facing.gd`: 41 checks passed (cardinal and arbitrary yaw, rotated/translated origins, pitch/roll, vertical gaze, metadata, missing tracking and source immutability).
- `--headless --xr-mode off --path . --script deathmatch/tests/calibration_preview_live.gd`: 25 checks passed with the real bundled soldier avatar and default native animation.
- Same live test with `-- --gdscript-animation`: 25 checks passed with reference animation.
- Same live test on desktop with `-- --capture`: 25 checks passed; Vulkan Forward+ on Intel ADL-N. Visually inspected [the preview](front-facing.png); the avatar faces the camera after a −90° tracking origin. Capture is the raw viewport; horizontal mirroring is applied by the UI TextureRect and separately asserted by the test.
- Native-port inventory covers all 1,140 scripts under `deathmatch/` and `tools/`; generation reproduces the checked-in JSON. Representative UI, snapshot, weather and baking classifications checked. `git diff --check` passed.

The existing broad `cq_vr_port.gd -- --cq-legacy-transport` test could not reach its calibration section: charging-handle assertions fail for weapons 0, 2 and 9, then line 65 dereferences a missing remote avatar. The process was stopped after that script error. These unrelated failures were not modified or counted as passes. The new isolated test exercises the real calibration widget and avatar without requiring a legacy multiplayer host. Real-headset ergonomic validation remains outstanding.
