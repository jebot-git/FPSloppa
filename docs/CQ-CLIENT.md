# FPSloppa Conquest experimental desktop

This standalone client runs the 81-district CQ campaign with UT99 weapons, 128 players overall and 16 players per district. It requires Vulkan. It cannot connect to the main FPSloppa server protocol.

1. Install and activate the WireGuard profile supplied by the server administrator.
2. Place your supplied private game profile beside the executable as `client.json`, or select it when the client opens. Keep the profile and your saved identity private.
3. Run `launch-conquest.sh` on Linux, `launch-conquest.bat` on Windows, or the executable directly. A profile path may also be passed to the launcher.
4. Choose **Join campaign**. WASD moves, the mouse aims, double Space activates the jetpack, 1–9 selects weapons, R respawns after death, and Esc releases/captures the cursor. F8 opens the password-protected moderator menu; unlocked moderators hold F9 for global announcements.

First-time players enter the no-fire inner city (d40). If its 16 slots are full or its worker is unavailable, newcomers wait for an inner-city slot. Returning players retain their identity, team, statistics and custom VRM. They reconnect at their last saved location when its district is available and entry remains permitted. If it is full/unavailable or a homebase gate has become locked, they use the nearest friendly district with space, then an eligible neutral district, then the instanced waiting room. Death respawns retain friendly-first selection.

Workers save location every five seconds and on orderly logout. An interrupted connection can lose up to the last five seconds of location updates; a reconnect while the existing actor is still resident resumes that actor. An obstructed or airborne saved position falls back to a safe spawn in the selected district. Back up the client identity under Godot's `app_userdata/FPSloppa Conquest` user-data directory; deleting it creates a new player. Source builds use the source project's user-data directory unless an explicit `identity_file` is configured.

Optional profile fields include `name`, `team` (0 red/1 blue for new identities), `vrm` (absolute local VRM path), `music_volume` and `ambience_volume`. Custom VRM is the only client-uploaded content. The server supplies private connection fields; do not invent or reuse credentials from another campaign.

This remains an experimental desktop transport: it uses authoritative snapshots and smoothing. Windows is packaged from the pinned Godot template; this release's live execution checks were performed on Linux/Vulkan. No Quest or Pico CQ client is included.
