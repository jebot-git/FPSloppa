# Multiplayer session log review — 0.7v

Input: `../logs.log`, SHA-256 recorded in `test-results/session-07-audit.json`.
The original log is retained outside the repository. The audit report contains
aggregates and event sequence references, not player names or chat content.

The file contains 394 consecutive JSON records from 2026-09-10 17:59:07 to
21:36:58 UTC (217.84 minutes), using protocol `fpsloppa-20-quake-movement`.
There are 18 connections/disconnections and five distinct display names. The
63 join events include map-change handshakes; they do not represent 63 players.

## What the evidence supports

- 90 kill announcements: 43 opponent kills and 47 same-name kills, including
  environmental deaths. The latter comprise 18 environment, 15 Circus Hunger,
  eight falls, and six rocket self-kills.
- No sequence gaps or backwards uptime timestamps. No announced kills in the
  waiting lobby. No killer name missing from the reconstructed active roster.
- The shortest interval between deaths of the same player within a map epoch
  is 2.245 seconds. No interval violates the two-second respawn delay. This is
  a check of announced fatalities, not of duplicate/nonfatal hit processing.
- The two individual-frag round results (events 5 and 39) reconstruct to the
  reported 0 and 2 frags. Team objective scores cannot be reconstructed from
  death announcements alone, particularly KOTH's time-based points.
- IG records only railgun kills. CC records 20 chainsaw kills, 15 hunger deaths
  and six falls; it records no weapon-whip or other weapon kills. The single
  weapon-whip kill is in KOTH.
- Hazard fatalities concentrate on lqdm4 (nine), tf_original_2fort5 (five),
  lqdm3 (four), ad_arena_ad_akalakha (six falls), and threewave_ctf2m1 (two falls).
  The log has no positions or hazard identifiers, so these counts cannot
  distinguish intentional hazards from bad collision, drowning or movement.
- After the last disconnect at 19:00:04 UTC, 15 empty-server rounds end with
  zero-score draws. Current code already pauses an empty dedicated server;
  `deathmatch/tests/vr_gestures.gd` was rerun and passed that regression check.

## What it cannot establish

This normal-level file has **no shot, miss, damage, ping, input-age, rewind-time,
projectile-contact or health records**. It cannot measure hit-registration rate,
missed shots, pellet duplication, lag-compensation accuracy, or the timing of
VR weapon swings/jumps. No combat/network change is justified solely by these
fatality summaries. Current networking was separately regression-tested; that
does not retroactively validate the 0.7v match.

For another diagnostic session, existing server configuration supports:

```cfg
set sv_log_level "verbose"
set sv_log_file "logs/combat-session.jsonl"
set sv_log_max_mb "32"
set sv_log_backups "3"
```

Verbose mode adds applied damage, pickups, spawns and periodic ping/input/counter
summaries. It still does not reconstruct every missed shot; correlate a demo or
recorded view with focused hit/latency tests for that purpose. Voice samples,
raw tracker poses and chat contents are not included by this logger.

Reproduce the aggregate audit:

```sh
python3 tools/audit_session_log.py ../logs.log --output test-results/session-07-audit.json
```
