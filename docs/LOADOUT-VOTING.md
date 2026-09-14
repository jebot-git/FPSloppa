# Loadout voting — 14 September 2026

The in-game Teams & Player Votes menu and the waiting-lobby voting wall now include a loadout selector alongside mode and map.

| Modes | Loadout selection |
| --- | --- |
| DM, TDM, CTF, KOTH, Freeze Tag | Doom, Quake or UT99 |
| TF, Titanball | Quake, fixed |
| Assault | UT99, fixed |
| Instagib, Instafreeze, Chainsaw Carnage | Doom-based fixed weapon rules |

In an eligible live match, **Vote Loadout Only** changes the current map's arsenal after a majority approves. Select the current mode and a different loadout; map selection does not change this action's destination. The ballot explicitly says that this restarts the match. **Call Match Vote** proposes mode, map and loadout together, including a different loadout on the same mode/map.

The lobby always votes on the next mode/map/loadout combination. Approval updates the visible next-match summary; the chosen match starts when the lobby timer expires. Required loadouts appear as a disabled, single-choice field. The server rejects incompatible combinations even if submitted outside the UI.

Passed changes use the existing map transition: pickup entities are rebuilt for the chosen arsenal, players receive fresh inventories, and peers receive the authoritative weapon rules through the existing map offer. A loadout-only restart preserves team assignments. Forced-mode choices do not overwrite the remembered loadout preference for freely selectable modes. Existing electorate, spectator, majority, timeout and proposal cooldown rules apply.

## Validation

- `loadout_votes.gd`: all mode restrictions, invalid/unchanged values, spectators, late voters, repeated votes, rejected ballots and lobby behavior.
- `loadout_vote_network.gd`: a dedicated server and two real ENet clients vote Doom → Quake on the same BSP, then vote CTF/UT99 in the lobby. Both clients confirm the transitions and receive the expected authoritative inventories.
- `loadout_vote_ui.gd`: rendered Vulkan Mobile checks at 854×640 for the in-game menu and 1200×720 for the lobby wall. Pointer selection, popup persistence, fixed-mode controls, proposals, approval summaries and layout bounds pass. Screenshots were visually inspected.
- Existing vote, vote UI, lobby transition and late-join lobby network regressions are also run. Local logs, screenshots and summaries are retained under `test-results/loadout-votes/`.

The network scenario's client arguments are `server`, `first` and `second`, using port 28994. Run each with `godot --headless --xr-mode off --path . --script res://deathmatch/tests/loadout_vote_network.gd -- ROLE` (server first). Other cases are standalone SceneTree scripts; the visual case requires a graphical Vulkan renderer. Tests do not access the remote server. Scene teardown can emit the existing ObjectDB warnings.

Linux and Windows hotfix test candidates contain these changes. They remain unpublished; native Windows and headset use of the new voting controls still need device testing.
