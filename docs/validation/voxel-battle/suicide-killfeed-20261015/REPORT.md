# CQ suicide button and VR status feed — 2026-10-15

Worktree: `.worktrees/cq-voxelspace`; branch: `experimental/cq-voxelspace`.

## Changes

Alive CQ players see **SUICIDE**; pressing it submits the existing authenticated, life-bound suicide action and closes the menu. Dead or staging players see **RESPAWN**, which opens squad/spawn selection. The native action accepts menu-blocked input while retaining the current-round and fresh-input checks. Death, scoring and the ordinary respawn delay remain authoritative. This native fix must also be deployed to the server before it can be validated live.

The stereo status HUD shows the newest three unexpired entries from the same canonical feed as the desktop HUD. Each row truncates long names, preserves chat space, and expires at the existing event deadline. The health/ammunition panel retains its original position; the extra rows extend upwards.

## Validation

- Godot 4.7.2 native Linux server-profile extension build passed.
- Resident authority suite: **264,883 checks passed**, including blocked-menu suicide at 30/60 Hz, spawn protection, respawn delay and duplicate/dead actions.
- Focused headless UI suite: **13 checks passed** (`deathmatch/tests/cq_respawn_killfeed.gd`).
- Editor import completed with no script parse errors. Sandbox restrictions prevented its debugger socket and editor-settings writes.
- Rendered headset validation was not possible.

## Upstream synchronization

After full access became available, a normal Git fetch and fast-forward completed on `experimental/cq-voxelspace`, from `9c3bf118` to `1a6f952cc4433d24df407550766e99dc2c09db30`. All 802 upstream changes, including the rain audio and destruction topology resource, are now present. The seven task files were backed up and restored around the fast-forward; the task changes remain uncommitted. The earlier connector source-sync limitation is resolved.

`task.patch` records this task relative to the remote snapshot; the changes are already applied to the working tree. `sync-manifest.json` records the synchronized upstream files.

## Live VR test

The first two launch attempts were blocked by the earlier restricted sandbox. After full access became effective, the source client launched successfully through the WiVRn-Pro OpenXR runtime, using the Meta Quest Pro and Forward+ stereo rendering.

- Client PID: **459023**; local telemetry collector: **459024**.
- Connected to **87.106.27.237:7777**, protocol `fpsloppa-cq-frontier-28-headlights`.
- Confirmed `XR_READY OpenXR`, local player admission, and telemetry showing `active: true`, `xr: true`, `focused: true`, `map_loading: false`. The client starts in the deployment menu.
- Client gameplay/process/GPU/WiVRn analytics: `/home/blux/.cache/cq-vr-test-20261015/162245/`.
- Remote server PID: **1664887**; telemetry collector: **1665721**; remote telemetry folder: `/home/blux/fpsloppa-cq/analytics/vr-client-20261015T142310Z`.
- Both passive process collectors run for up to two hours, or until their target exits.
- No remote service or release was replaced. The deployed release remains `20261015-cq-headlights-destruction64`; the new native server-side suicide fix is not deployed by this client launch.

The client and analytics collectors were left running for the user's live test. These startup checks confirm connection and tracking; they do not constitute headset validation of the gameplay changes.
