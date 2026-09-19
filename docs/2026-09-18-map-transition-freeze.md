# September 18 live-session map transition freeze

The server stopped simulating admitted players while any other peer remained in `pending_names` after a map rotation. Clients had already passed their individual admission checks and resumed movement prediction. The server continued accepting their commands and sending acknowledgements with unchanged spawn positions. Reconciling those snapshots repeatedly pulled moving clients back toward spawn. Voting also rejected proposals while the server's `map_loading` flag remained set.

The same barrier applied to matches and the waiting lobby. It explains a short entry freeze while the last client loads, or a prolonged lobby freeze when a join stalls. The lobby's displayed seconds were calculated from the server clock even while `lobby.tick()` was blocked, so the board could count down to zero without advancing to the next map.

All three supplied demos were decoded without executing serialized objects. The two affected lobby segments have **zero recorded player position changes**, despite thousands of advancing input acknowledgements:

| Demo | Time within recording | Observed duration | Peak admitted players | Advancing input acknowledgements | Server round timer |
|---|---|---:|---:|---:|---|
| `2026-09-18T19-47-14.fpsdemo` | 03:25.05–04:32.20 | 67.15 s | 5 | 5,679 | Fixed at 45 s |
| `2026-09-18T19-58-22.fpsdemo` | 04:31.58–06:57.98 | 146.40 s | 7 | 18,535 | Fixed at 45 s |

The later `2026-09-18T20-35-49.fpsdemo` contains four lobbies that reach eight admitted players, record movement, and advance their round timers. This is consistent with a readiness barrier rather than a permanent lobby collision problem. Sampled frames from `slop.mp4`, including the transition around 31:30, also show the asset-loading screen followed by the lobby. Video sampling alone does not establish the networking cause.

The demos do not record the pending join dictionaries or asset-loader errors. They cannot establish why the remaining peers had not completed admission; that would require the corresponding server logs.

The fix releases the server transition when the first player is admitted. Each remaining peer still completes its own map/model checks before spawning. An empty destination continues waiting for readiness, but a slow peer no longer blocks ready players, voting, countdowns, or the next map transition. The round now starts with the first admitted player rather than the last.

Validation:

- The new deterministic regression reproduced six failures before the fix: lobby movement, countdown, proposal, majority vote, match-entry movement, and match timer. All pass afterward. It also checks that an entirely unready destination still waits.
- `python3 tools/validate_map_loading_progress.py` passed with a dedicated server and eight independent ENet clients. The eighth client withheld asset readiness across both lobby and match transitions; the other seven moved, voted, and advanced. Releasing the eighth client admitted it into the current map successfully.
- In that network run, the moving client recorded zero prediction resets; maximum correction error was approximately 0.22 m in the lobby and 0.14 m in the match.
- `GODOT_BIN=godot python3 tools/validate_session_features.py` passed, including lobby movement, votes, demo playback, and existing/late client transitions.
- `GODOT_BIN=godot python3 deathmatch/tests/run_rotation_tests.py` passed, including missing-map download, rotation wraparound, preserved identities/teams/spectator state, and rejection of old-map snapshots.

The older test fixtures were updated to use bundled Quake maps, include the current vote-result rules field, and compare downloaded map checksums instead of their local alias names. The forced-download test excludes every catalog entry with the target hash so previous cached downloads do not bypass it.

Headless tests retain the existing single ObjectDB shutdown warning. This source fix has not been packaged, deployed, or verified in a headset/WAN playtest.
