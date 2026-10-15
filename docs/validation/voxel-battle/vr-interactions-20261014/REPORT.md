# CQ native VR interaction continuation — 14 October 2026

Branch: `experimental/cq-voxelspace`. This candidate extends the existing resident
C++ rewrite. It has not replaced the live protocol-18 release. Client and server
must be updated together to protocol `fpsloppa-cq-frontier-19-vr-interactions`.

## Changes

Local first-person hands use tracked controller transforms without avatar IK or
animated vertex offsets. Head-relative equipment mounts follow leaning and
recentring. World scale stays in metres. The primary draws from the chest and the
secondary from the hip on a grip edge; releasing returns the weapon. Conventional
weapon cycling is disabled. Virtual stock and render-only weapon kick are ported
from main; raw tracking still drives reload gestures and authoritative aim.

The C++ authority now uses authored CQ muzzle, magazine, charging-handle and support
anchors generated from the client manifest. Physical reloads retain chamber and
reserve accounting. Local presentation includes the pouch, carried ammunition and
bounded discarded magazines. Native CS-style recoil includes recovery, movement
and stance bloom, unsupported-long-gun penalties and support-hand correction.
Pistols require trigger release between shots. Existing CQ burst, charging, salvo
and guidance mechanics remain. Released grip is encoded in existing input/frame
flags: native firing/reload work stops and remote weapons return to their mounts.

New clients remain staged outside combat and capture until they choose class,
loadout and skin, review calibration and explicitly deploy. The calibration
submenu renders a private local avatar and live tracked gloves for alignment
confirmation. Recentring or changing the selected skin requires renewed confirmation. Staging, deploy actions,
life checks and combat admission run in C++; menu and preview rendering stay in
Godot. Confirmed players survive map reconstruction without a second setup gate.

Use/boarding routes through the resident action channel. Scope magnification is
remembered by weapon. Static structures stream around the camera's world position
and use XR-safe distance/LOD selection. Tank mesh bounds are centered and grounded.
Colored name runs preserve class prefixes and VR label sizing. CQ music is
disabled; local day/night jungle beds and nearby POI ambience crossfade, with
bounded audio players and voice ducking.

## Evidence and limits

Accepted results: **909,505 native checks**, also passing ASan/UBSan; **33,518
Godot/Jolt checks**; **49 rendered checks**. The 32/64-client smokes achieved
30.022/30.007 Hz respectively, with no bad frames, disconnects or queue overflow.
The final skin-confirmation guard and fallback-avatar holster presentation were
checked by the rendered suite after the transport run.

- `native-checks.json`: host-independent core, deterministic replay, golden
  comparisons, malformed protocol tests, physical reloads, staging/deployment,
  recoil, semi-auto trigger and grip packet/state checks.
- `sanitizers.log`: the same native checks under ASan and UBSan.
- `functional-results.json` and accompanying logs: real Godot/Jolt adapter, VR
  reload, terrain and entity integration checks.
- `render-qa.log`: rendered local scene checks. `calibration-preview.png` captures
  the private preview; synthetic controllers in this fixture are not a fitted
  human pose.
- `transport-smokes.json`: 32/64 tracked ENet clients on the authored jungle,
  ten-second measured windows after eight-second warmups. These establish smoke
  correctness, not VPS capacity or a performance comparison.
- `arena-results.json`: earlier full-arena desktop/tracked clients exercised
  shooting, grenades, NVG, prone death/gib/respawn, team change and jetpack; four
  bots traversed the authored map. This preceded the final grip-wire addition.
- `native-build-receipt.json`: portable Linux server library/source receipt.

Existing XR asset UID fallback warnings and Jolt solver-bias/navigation warnings
are retained. Native compiler warnings are recorded rather than suppressed.

The engine retains scene rendering, assets, XR input/audio, ENet and Jolt owner
thread operations. Moving those into the host-independent core would not improve
this port. There is no claim that all main-branch weapons or modes have been
migrated: the resident path supports the CQ arsenal and UT99 avatars described in
`tools/authority_core/README.md`.

Interactive validation remains necessary for real headset/controller reach,
two-hand/stock feel, recoil comfort, physical magazine gestures, vehicle boarding,
POI visibility and audio balance. Synthetic tracked clients and a rendered desktop
fixture cannot establish those. The running WiVRn-Pro live session and its deployed
protocol-18 server were not restarted by this implementation pass.
