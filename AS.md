# Assault (AS)

HiSlop (`as_hislop`) is bundled in the external base maps package. This experimental
train assault has two ordered objectives, defensive sentries, checkpoints and
animated passing scenery. Both teams attack once: the return attack must beat the
first team's time. If neither finishes, the match is a draw. Players use the normal
arena weapons and start with a pistol; TF classes are unavailable.

Enable AS exactly like TF in `server.cfg`:

```cfg
set sv_gametype "as"
set sv_gametypes "as"
map "as_hislop"
set as_maplist ""
set timelimit "7"
```

An empty `as_maplist` loads `maps/as_maplist.txt`. The source build lists
`as_hislop` and `as_frigate`; previously published base packages list only HiSlop.
For mixed-mode voting, include AS in the allowlist, for example
`set sv_gametypes "dm tf as"`, and retain valid separate maplists for each mode.
The initial map must match the initial mode. AS votes only offer BSPs with AS
objectives. The optional waiting lobby and ordinary match voting both support AS.

HiSlop uses original brush construction and LibreQuake textures, inspired by the
train assault concept in UT99 AS-HiSpeed. No UT packages or extracted art are
included. Map notices and texture provenance are in `maps/HiSlop/`; editable
construction and build instructions are in `tools/hispeed_concept/`.

The eight-client simulation and objective/sentry tests pass. Autonomous bot route
completion, human balance and headset performance are not certified by those tests.
Recommended initial playtests: 4–10 players.

## VR objective buttons

Touch objectives have a small waist-height console: amber **PRESS / USE** for the
current objective, gray **LOCKED** for a later one, and a depressed green **DONE**
button after activation. Touch the current button with either hand using a short
pressing motion. A successful press gives controller feedback and the existing
objective announcement. The player must be an attacker, alive, within the objective
zone and able to reach the button without passing through map geometry.

Tracked clients activate objectives by pressing the button or using the existing
**Use** binding. Desktop clients retain proximity activation. Physical controls can
be disabled in **Settings → Bindings**; Use remains available in VR. Checkpoints,
sentries and the two-leg win conditions are unchanged. Using an already activated
console keeps its door unlocked for the rest of the leg.

## Frigate harbor assault

The source build also includes `as_frigate`: a dock warehouse, gangway approach,
underwater intake, aft machinery rooms, mess deck and locked bridge. Destroy the
240 HP compressor with weapon damage, then activate the gun console. The
compressor is a destructible target, not a touch button. Both roles' machinery
and door reset between attacks; bots can aim and fire at the compressor.

Select **Host → Assault → Frigate**, or set `map "as_frigate"` and
`as_maplist "as_hislop as_frigate"` on a dedicated server. Start with six minutes
and 4–8 players. Use matching updated clients/server. See the
[build and playtest notes](tools/frigate_concept/README.md).
