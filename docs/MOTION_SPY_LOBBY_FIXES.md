# Movement, Spy and lobby feedback

These are source changes after 0.9v, using protocol
`fpsloppa-29-acknowledged-movement`. Both client and server need the updated
version. No release was built or published as part of this investigation.

## Local movement and VR body

The previous client simulated movement immediately, but compared incoming
server positions directly with its newer predicted position. Every snapshot
also replaced vertical velocity. A grounded snapshot arriving just after a
local jump could remove the upward velocity and create apparent jump delay.

Snapshots now acknowledge the last accepted input sequence. A bounded history
compares the authoritative state with that input's saved predicted state.
Corrections preserve subsequent local movement, including newer jumps, and
ignore small differences caused by the server holding inputs between packets.
Small positional corrections converge visually; large divergence, respawn and
teleport reset prediction. This is historical state-difference reconciliation,
not full command replay. Server collision, damage and impulses remain authoritative.

The local tracked avatar uses the same render origin as the headset and reads
the current tracking sample before IK. Network echoes no longer replace local
tracking or crouch height. Local first-person VRM spring simulation and cosmetic
damage sway are disabled; remote and mirror avatars retain secondary animation.

Local shot effects previously could use the yaw from an older snapshot while
the visible VR gun used current yaw. They now use current local yaw and tracked
weapon pose. The aim guide starts 4 cm beyond its previous origin and extends
60 cm, remaining clipped by map geometry. VR fists use physical melee only;
desktop trigger-driven fists remain supported.

## Spy recording and rules

The supplied 22.9-second recording shows a Spy disappear around 12–13 seconds
and reappear around 14 seconds. A second, differently named Spy is also visible
later; the frames do not establish that these are one player changing models.
Disappearance is consistent with the released six-second enemy cloak, which
could end early on attacks or damage. The recording alone does not establish
the observer's team or the event that caused the reveal.

The original [TeamFortress 2.8 readme](https://www.filefactory.org/tf/file/2)
describes server-selectable disguise or cell-powered invisibility. FPSloppa's
released simultaneous timed cloak and disguise was a custom adaptation.

Following the requested change, disguise is now the default. A dedicated server
can select invisibility instead with `set sv_tf_spy_invisibility "1"`. It uses
one cell on activation and one per second thereafter, with one cell per second
regenerated while visible, up to 50. These rates are FPSloppa tuning, not a claim
of exact original TF timings. The server policy reaches clients and their class
descriptions. Disguise persists until revealed; invisibility ends when toggled
off, cells run out, or a reveal condition occurs.

Missed melee does not reveal either undercover state. Accepted melee damage to
health or armor reveals the attacker; friendly-fire rejection and spawn
protection do not. Damaging buildings also reveals the Spy. Gunfire still
reveals on a miss. Receiving damage, flag carrying and class changes retain
their reveal behavior.

## Map interactions

Hyperborea (`lqdm3`) has three `trigger_push` ramps using pitch/yaw `angles`.
The old loader ignored these angles and applied one tenth of the Quake push
speed. Their actual BSP brush triggers now launch players in the authored
direction and at the proper Quake scale. Original Quake's multiplier is
documented in its [trigger implementation](https://github.com/id-Software/Quake/blob/master/qw-qc/triggers.qc).
Generated HiSlop pads retain their calibrated strength through legacy detection
and an explicit scale attribute in newly generated maps.

Entering a pad emits a short spatial whoosh and cyan launch effect, replicated
and recorded with ability feedback. Remaining inside a brush does not spam
activation effects. Portal destinations telefrag overlapping player capsules,
including protected or friendly blockers, while respecting vertical separation
and excluding spectators. Removing an already frozen player does not award a
second death or frag.

## Lobby transitions and voting

Assault's empty team-spawn lists were still consulted inside the lobby, making
players fall back to the same first spawn. Lobby spawning now uses all 32 indoor
positions, skips previous-mode spawn equipment, and recovers players outside
the room. Spectators retain their separate movement behavior.

The enlarged wall has separate proposal and current-vote columns. It shows the
proposal, Yes/No counts, required majority, remaining time, eligibility, the
player's response, outcome and selected next match. Lobby proposals use the
same server-authoritative majority voting as in-game votes. Approval changes
the match selected for the end of the lobby countdown; rejection retains the
previous selection. Popups keep their selection order and stay open during
refreshes. Dummy drag-test entries cannot become playable proposals.

The real two-client test also exposed a second transition bug: clients leaving
Assault applied stale Assault map restrictions to a newly voted non-AS map.
The map offer now includes its destination mode before local lookup or download.

## Validation limits

Focused tests cover delayed grounded snapshots at 33–400 ms in an isolated
collision fixture, bounded prediction history, impulses, actual bundled VRM
spring suppression, four facing directions, stale tracking echoes, Spy rules,
all three real Hyperborea ramps, telefrags, and lobby voting controls. Separate
ENet tests exercise actual server/client movement and AS → lobby → voted IG
transitions. The board layout was also rendered and inspected.

Results are in `docs/validation/motion-spy-lobby.json`. Delay injection in the
focused prediction test is synthetic; the ENet runs use loopback networking.
These checks do not replace confirmation of motion comfort in a live headset.
Existing Godot shutdown ObjectDB warnings and some bundled asset UID fallback
warnings remain. Windows SteamVR/microphone crash diagnosis is tracked separately
in `LIVE_09_FEEDBACK.md`.
