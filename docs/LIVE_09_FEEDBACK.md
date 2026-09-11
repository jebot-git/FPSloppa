# 0.9v live feedback and follow-up fixes

## Dedicated server log

`serverup.log` covers 2026-09-11 13:00:02–13:51:40 UTC: 619 health samples,
138 with a client present, and at most one simultaneous client. During occupied
samples, physics time p95 was 6.886 ms (maximum 8.885 ms); process time p95 was
5.066 ms (maximum 17.057 ms, just after a map change). These are instantaneous
five-second samples, not a complete frame-time distribution. There are no memory
measurements or native crash stacks, so this cannot establish leak freedom.

All 20,412 counted input packets were accepted. Ping was predominantly 27–28 ms;
one early sample reached the server's 400 ms reporting cap. Input age was normally
17–33 ms, with two stalls at initial admission and the waiting lobby. The server
recorded eight sentry damage events, fourteen drowning events, and a completed
Assault with role switching. The voice relay counter reached 84 with zero rejected
packets, but there was no second client to demonstrate audible reception.

A disconnect at 13:32:08 occurred during the transition into CC on lqdm4. The
same tester reconnected at 13:32:36. The log does not state whether this was a
client crash, a voluntary departure, or a transport failure. Do not attribute it
to SteamVR or microphone switching without a matching client log.

[Aggregate source-log data](validation/serverup-09.json) excludes player names.

## Additional live spectator observation

An isolated copy of released `5105fb8`, with a local snapshot timing callback,
joined 45.147.228.101:7777 using protocol `fpsloppa-26-fortress-effects`.
The probe was a headless spectator with its microphone disabled, did not vote or
send chat/gameplay actions, and disconnected after 180 seconds. Three other
players were present in the sampled rosters. The probe downloaded required
assets, joined in 5.514 s, and remained connected across TF → Assault.

3,573 snapshots arrived: median interval 49.999 ms, p95 58.600 ms. Sampled ping
was 25–34 ms. Two gaps exceeded 250 ms; the longest was 1.451 s. Measurements
include map preparation and cannot uniquely attribute gaps to the server or
network. Sampled client orphan counts remained zero. Memory declined after the
map switch; this short observation is not an extended leak test.

[Live observation data](validation/live-spectator-09.json). The pending source
changes use protocol 28 and were tested locally, not against this live server.

## Turrets and TF feedback

Older HiSlop BSPs contain a chaingun pickup on each sentry mount. Runtime loading
now removes just those overlapping chainguns on every peer, retaining ordinary
chaingun pickups. Future generated HiSlop maps omit them. Engineers also cannot
place a structure over a chaingun waiting to respawn.

Sentries aim their actual barrel axis through a centered pivot, including pitch
and the first rendered frame. Target scans update between shots, bounded to
10 Hz (TF's shared tick can reduce this to 4 Hz). Damage remains 12 per shot with
a half-second cooldown. Muzzle flashes/tracers originate at the barrel end.
The sentry firing cue is raised 8 dB to the player-chaingun gain, retaining the
shared weapon normalization and spatial attenuation.

TF afterburn now replicates remaining duration for avatar flames and a local
orange damage cue. VR uses a gentle peripheral effect and a BURNING HUD label.
Emitters are bounded to one per affected player and are removed on expiry,
healing/resupply, death, or leaving TF. Demo snapshots retain the burn state.

Dispensers are intended to replenish **health, armour and class ammo**. Tests
confirm all nine classes receive their allowed ammo types within three metres.
Per one-second supply tick: up to 10 health, 7 armour, 20 bullets, 5 shells,
2 rockets and 20 cells, limited to the class's supply caps (engineers can stock
120 cells). They do not grant new weapons or refill unsupported ammo types.

## Microphone switching and Windows reports

Device selection previously changed the native audio device while capture was
active, then the panel restarted capture a second time. It now closes capture
first and starts one replacement after device selection. The new input opens
before its sample rate is read for the resampler. Failed startup releases capture
synchronously; a failed/old node cannot later disable a newer capture. Native
encoder creation is checked and a changed input rate rebuilds the resampler.

Automated menu/lifecycle tests and the multi-process Opus relay/playback test pass.
The local PulseAudio test cycles four inputs twice with no crash and no audio
saved or transmitted. Both native runs produced a PulseAudio “Bad state” error
while closing one device; this is recorded as a limitation, not hidden as a clean
Windows reproduction. Retesting the affected Windows input remains necessary.

The fuller SteamVR screenshot reaches `XR_READY` after creating OpenXR 1.0.54
on SteamVR/OpenXR 2.17.9. The earlier instance errors were recovered by Godot's
[OpenXR 1.1 → 1.0 fallback](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/openxr/openxr_api.cpp).
It shows no crash stack. Object picking is now explicitly disabled on the stereo
root viewport; VR pointers already use their own ray tests. No runtime, Vive
tracker or Index support has been removed. VDXR working while SteamVR fails is
useful comparison evidence, but the actual failure is still unconfirmed.

Copy [Diagnose-VR.cmd](../tools/Diagnose-VR.cmd) beside the affected Windows
`FPSloppa.exe` and run it with SteamVR/headset active. It preserves stdout/stderr,
verbose initialization and the process exit code in
`%TEMP%\FPSloppa-VR-startup.log`, then keeps the console open. For a separate
renderer comparison, run `Diagnose-VR.cmd --rendering-method gl_compatibility`.
This changes only that launch; it is a diagnostic comparison, not a confirmed fix.
The script is staged into subsequent Windows releases.

## File browsing and prediction

VRM and BSP imports now share an in-canvas browser with single-click directories,
UP, drive/common-folder locations, direct path entry, trigger-drag scrolling and
explicit IMPORT. It keeps the import controls visible and pages large folders to
bound UI node creation. File filters retain folders and match extensions without
case sensitivity. Operating-system access restrictions still apply.

Local motion prediction remains active in released 0.9v and current source.
Movement simulates immediately with physics delta. Server snapshots arrive at
20 Hz; local correction eases position by 18% beyond 12 cm and snaps beyond
2.5 m. Horizontal velocity eases, but vertical velocity is replaced on each
snapshot. This is prediction with correction, **without acknowledged-input replay**;
it can therefore still introduce jump/stair correction under latency. This review
did not replace the networking prediction scheme.

[Automated follow-up results](validation/live-feedback-fixes.json) include the
shared browser, flame lifecycle, turret targeting, all dispenser classes, voice
menu switching, network audio, and simulated VR UI/controller checks.
