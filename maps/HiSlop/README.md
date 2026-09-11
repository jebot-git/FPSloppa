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

An empty `as_maplist` loads `maps/as_maplist.txt`, whose default is `as_hislop`.
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
