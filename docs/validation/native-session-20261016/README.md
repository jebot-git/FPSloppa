# Native client session and entity membership — 2026-10-16

`FPSClientSession` now owns per-connection admission validation, bounded avatar catalog, roster membership/deltas, engine entity bindings, ordered snapshot tick/epoch acceptance, life/death transitions, presentation-event watermark, staging/deployment/round transitions and action sequencing. Production standalone CQ selects it by default and requires the rebuilt extension. `--gdscript-client-session` selects the retained reference path.

Native roster application updates compatibility player state, invokes the existing scene factories on admission, retains existing body instances across refreshes, changes nametags only when their identity/team/colour changes, and releases departed bodies and interpolation entries. Bindings use engine instance IDs rather than retained dangling node pointers. Reset clears membership, bindings, catalog and all watermarks/sequences; old frames/actions cannot be accepted after teardown. Invalid duplicate/malformed roster batches are rejected before entity mutation. Scene factory failure remains a fatal adapter failure, not a rollback transaction.

Native frame planning drops repeated/out-of-order/wrong-epoch frames, sorts presentation events and emits them once, tracks life transitions, and avoids the script's repeated scan/string construction for dead-player fallback effects. Explicit authoritative death events and fallback effects retain the existing final visual deduplication. Action 10 still expands into the same two deployment packets and sequence progression.

## Results

- [1,207 session/entity checks](session.log) pass: 64/128-member roster parity, body identity, duplicate rejection, nametag change suppression, departures/interpolation cleanup, negative bot IDs, catalog/download deduplication, ordered events, life/death transitions, malformed frames, wrong epochs and reconnect reset.
- [239 existing player-state/reconciliation checks](state-regression.log) pass.
- Full local standalone authority: [desktop](desktop.json), [simulated tracked](tracked.json) and [script reference desktop](reference-desktop.json) all report zero failures. Both native clients observe shooting, incapacitation/death/gibbing/respawn, grenades, NVG, squads, team presentation, jetpack and destruction. Tracked poses are observed in the tracked fixture. All have zero steady-state correction/resets in their movement sample.
- Roster refresh fixture: native/reference 81.43/89.17 µs for 64 players; 171.13/213.77 µs for 128. These are small low-rate roster fixtures, not overall client FPS or capacity measurements. The initial direct port performed worse; caching unchanged nametags removed redundant script calls before acceptance.

An extra reference run against the nearly expired first test server failed its jetpack observation at the server's 180-second deadline. It was repeated against a fresh isolated authority and passed; the completed fresh result is linked above. No production server was involved.

## Remaining boundary

Connection setup/DNS, profile persistence, asset transfer/cache, scene resource/signal wiring, camera/menu activation, the arena's post-roster visual hooks, compatibility dictionaries and actual cosmetic effect execution remain script adapters. This completes a session/membership slice of P1, not the entire client port. VR interactions, world/audio orchestration and launcher services remain separate phases. No real-headset or Windows/Android validation was performed.
