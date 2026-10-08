# Public release server

`release-server.cfg` is the requested configuration for 45.147.228.101:
16 players, all 13 modes enabled, a 45-second between-match lobby, and no local
or external-worker bots. TB, TF and CC are excluded only from the between-match
ballot; ordinary mode votes retain them. RCON is disabled.

DE has a 20-second preparation/purchase phase and at most six rounds. The game's
`sv_de_winlimit 4` means first to four, sides switching after three rounds, and a
six-round cap that allows a 3:3 draw. `sv_de_winlimit 6` would allow ten rounds and
is deliberately not used. `check.gd` exercises a six-round draw and ballot policy.

Gameplay uses UDP 7777; favourites query UDP 7779. No master registration is needed
for a manually added favourite (`sv_public 0`). Both ports must be reachable from
outside the host. Do not expose RCON or a bot-worker port for this deployment.

Install each verified dedicated-server release under
`~/.local/share/fpsloppa/releases/<version>/`, with the final expansion's BSPs,
navigation resources, maplists and notices in the same directory. Graphical map
caches are unnecessary for the console server. Keep the service configuration at
`~/.config/fpsloppa/server.cfg` and install `fpsloppa.service` under
`~/.config/systemd/user/`. The `current` symlink selects the active release.

The user service requires lingering for boot startup. After staging and verifying
the release, switch `current`, run `systemctl --user daemon-reload`, and enable/start
`fpsloppa.service`. Keep the previous release for rollback. Check journal startup,
query status from another host, and perform a real client join before declaring
success. Changing releases must preserve any locally uploaded maps/avatars.
