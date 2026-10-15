# Default adaptive CQ server — 15 October 2026

Dedicated unified-map CQ now selects resident native authority and adaptive 60/30 Hz automatically through ordinary `--server --config server.cfg` startup. Existing configs that omit `sv_cq_adaptive_tick` inherit `1`, even if they contain the previous `sv_cq_tick_rate "30"`. Adaptation starts at 60 Hz; the latter setting selects the fixed rate only when adaptation is disabled.

Operators can use `sv_cq_adaptive_tick "0"` with `sv_cq_tick_rate "30"` or `"60"`. `--cq-fixed-tick` disables adaptation using that configured rate. `--cq-script-authority` retains the previous script authority for regression comparisons. Clients discover native presentation from server frames; disconnect resets that state. Map resets retain the server's selected authority.

The governor policy, native library, team/squad limits and 32-player supported configuration are unchanged from [the adaptive 64-player experiment](../adaptive-64-20261015/REPORT.md). This change does not promote 64-player capacity. No new load-performance claim is made.

## Validation scope

The isolated VPS package derives from `adaptive-20261015-complete-release`, preserving the deployment assets and native library while replacing four registered scripts: base arena, CQ authority, server config and class arena. The final derivative additionally replaces the QA client with an eight-second post-deployment warm-up. `cq-server.patch.json` and `release-sha256.json` identify the derivative. The library remains `8c11a52d323b98cf247a7db4f95313e561815244f3b65146014dc5271bfbcdd4`.

The actual packaged server is launched without `--cq-native-authority` or `--cq-adaptive-tick`, on loopback UDP 28009. Its default-test config omits both tick settings. A real admission/presentation client exercises shooting, grenade selection/throwing, NVG, suicide/gib/respawn, squads, team changes and jetpack. This is headless gameplay integration, not a rendered headset or load test.

Configuration tests cover inherited defaults, explicit config and CLI fixed-rate overrides, server reset persistence, client disconnect reset, the script regression switch and invalid adaptive values. Four deployment-tool tests pass. Direct authority/base arena parse checks pass. The local full class-arena parse check encounters the existing missing imported `Unitblock.ttf`/FONT cache; packaged integration uses the imported font resources.

Two immediate post-admission runs missed grenade and NVG checks (eight and six shots), without engine diagnostics. Their failures are retained. A diagnostic repeat with per-second client states and action logging passed all checks with 17 shots. That timing-sensitive outcome motivated using the load fixtures' eight-second warm-up in this smoke, after deployment and before timed actions. All gameplay assertions remain in place, and the startup timeout increases to cover the warm-up. This is a test stabilization change; it does not establish a production ability fix or prove the cause of the original misses. Final uninstrumented results are recorded below.

## Final results

| Packaged mode | Startup | Client shots | Gameplay assertions | Engine diagnostics |
| --- | --- | --- | --- | --- |
| Inherited defaults, no opt-in flags | 60 Hz, adaptive true | 17 | All pass | None |
| Explicit fixed 30 Hz config | 30 Hz, adaptive false | 17 | All pass | None |

Both final runs use the same uninstrumented package and native library; only server configuration differs. The QA-only warm-up is eight seconds after initial deployment. Fixed 60 Hz and the command-line fixed override are covered by the configuration tests, not an additional packaged match. The 64-player governor's pressure/recovery evidence remains the preceding experiment; no load cases were repeated for this default-selection change.

The production service remains active at PID 1652607, start time 06:10:23 UTC, with zero restarts. Its release, config and service were not changed. The new default applies on the next launch of a rebuilt server package. Isolated cases were cleaned up by their runners.

Remote final bundle: `/home/blux/fpsloppa-cq/validation/default-20261015-warmed-release`.
