# Class armour and live test — 14 October 2026

Native CQ now spawns shocktroops with 100 armour, medics and technicians with 50, and scouts with zero. Those values are the recharge caps. A living player inside a friendly, uncontested POI capture cylinder regains two armour points per second, with the existing capture height/radius and line-of-sight constraints. Overlapping sites do not stack. Leaving eligibility discards fractional recharge; spawn/class change resets it. Existing damage absorption and bypass rules remain in effect.

The change targets the resident C++ authority. Existing snapshots carry the resulting armour; paired client/server remain protocol `fpsloppa-cq-frontier-21-squads`. Old bare-health damage fixtures explicitly clear armour so their attribution, revival and entity assertions retain their original purpose. Added native checks cover class starting values, overlap, contest, scouting, departure, death, caps and class change.

## Validation

- [Native golden checks](core-tests.json): 910,103 passed.
- [ASan/UBSan](sanitizers.log): 910,103 passed.
- [Jolt/ENet suite](suite.json): 33,891 Jolt checks passed; 64 tracked synthetic clients completed 301 measured ticks with zero disconnects and 100% accepted minimum offered input. This was a ten-second measurement after warmup, not sustained live capacity certification.
- Portable server build verified and [packaged](package.log). [Binary hashes](release-sha256.json), [build receipt](linux-server-build.json), and [source hashes](source-sha256.json) retained.
- Uploaded files verified against their SHA-256 manifest on the remote host. Isolated native startup passed on loopback UDP 28817 with 64 slots before activation.

## Live deployment

Release: `/home/blux/fpsloppa-cq/releases/20261014-squads-armour-live` on `87.106.27.237`. Activated through the visible sudo prompt. The old service was stopped, the release symlink switched, and native CQ startup verified on UDP 7777. Service PID 1634124; collector PID 1634223. The previous release/config are retained for rollback. Server analytics are staged under `/home/blux/fpsloppa-cq/analytics/20261014-squads-armour-live`; client diagnostics and WiVRn/process collectors use `/tmp/cq-armour-live-analytics-20261014`.

## Observed VR launch

The matching source client (PID 171821) connected to the deployed authority through the running WiVRn-Pro OpenXR runtime, identifying `Meta Quest Pro on WiVRn`, runtime 26.9.3. Accepted frames report an active match, focused XR session, map loaded and initial shocktroop armour 100. It remains at the player-controlled class/calibration/deployment menus; calibration was not bypassed. [Launch check](live-client-check.json) and initial console/gameplay/process/compositor samples are retained here. Collectors continue for up to two hours while their target processes exist. No raw microphone or controller/tracker poses are serialized by the new client diagnostics.

Existing XR glove resource UID warnings fall back to their valid text paths; no script/engine errors were observed in the initial client log. Physical reload, recoil, POI recharge and squad/radio ergonomics have not been manually confirmed in this live session. The client and collectors are left running for the player.
