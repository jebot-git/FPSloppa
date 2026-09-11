# Scoreboard and stuck-player respawn

The active-match main menu has **SUICIDE · −1 FRAG**. The server performs normal
death handling, including dropping a carried flag, charging one death and one
negative frag, and respawning after the normal two-second delay. Armour and spawn
protection do not prevent it. Spectators, already-dead players, frozen FT players,
intermission and the waiting lobby cannot use it to bypass their rules.

The RPC identifies its caller from the connection and checks the map epoch and
life serial. Duplicate requests do not cause multiple penalties, and delayed
requests cannot kill a newly respawned player. Both client and server need the
updated protocol `fpsloppa-24-suicide`.

The scoreboard fits 16 players on the 1024×640 VR menu surface. It uses bundled
Bebas Neue typography, clipped name columns, consistent numerical columns,
red/blue team text/backgrounds and active TF class labels. Spectators have a
separate compact summary. Higher unsupported player limits show the first 16
ranked entries with an explicit notice.

Hold the configured Scores control (Tab on desktop; movement-hand secondary
button by default in VR). Releasing it hides the scoreboard immediately. VR
focus/tracking loss also clears the hold. Intermission no longer forces it open;
the existing round status remains available separately.

Validation: `scoreboard_suicide.gd`, `presentation.gd`, the real three-process
`tools/validate_suicide_network.py` test, and the existing four-process network
suite pass. A full 16-player render is in `test-results/scoreboard-16-tf.png`.
Physical-headset interaction has not been retested this turn.
