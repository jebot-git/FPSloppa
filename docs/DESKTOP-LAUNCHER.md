# Desktop launcher

Run `./run-launcher.sh` from a Linux source checkout, or `run-launcher.bat` on
Windows with Godot on PATH (`GODOT_BIN` can select another runtime). Packaged PC
builds include `Launch-FPSloppa.sh` / `Launch-FPSloppa.bat`. No Python or web server
is needed for the launcher. The launcher runs the same Godot client as the game.

## Servers

Add a numeric IPv4/IPv6 address with separate game and query ports (normally
7777 and 7779). Favourites and the optional HTTPS master URL use the exact same
client settings as the in-game browser, including `--client-config`. The query
port must be enabled by the server operator. Known servers refresh every 20
seconds; Refresh checks immediately within the existing rate limit.

Rows show live humans, bots, open human seats, map, mode and query ping. Details
include spectators, download reservations, capacity, weapon rules and version.
Bots can yield slots, so bot-filled servers remain joinable. Full servers and
known protocol mismatches disable joining. A missing query response keeps direct
joining available. Select Join VR or Join Desktop; Spectate applies to either.
The prominent **PLAY IN VR** button opens the normal VR menu; the smaller
**Play on desktop** link opens desktop play. The launcher stays on the desktop.

The Direct join row accepts a hostname, IPv4 address or IPv6 address, with a
separate game port. Connect VR / Connect Desktop enter that match immediately,
without requiring a query port, favourite, or master directory. Brackets around
IPv6 addresses are optional. Spectate also applies to these direct connections.

## Player identity

Choose a name, optional clan tag and installed VRM above the server list. Import
VRM validates and installs a new model; Rescan refreshes the choices. Save Profile
persists the selection, and every game launch saves it automatically. The explicit
avatar hash is passed to the game, so direct connections use the chosen model.
The regular in-game avatar picker can still change models after joining.

Names support **18 visible characters** and clan tags **8 visible characters**.
Colour codes do not count toward those limits. The Colours menu inserts a code
into whichever name/clan field was last focused; the adjacent preview shows the
combined identity, for example cyan `[VR]` followed by red `Red` and white `Fox`:

```text
Name: ^1Red^7Fox
Clan: ^5VR
```

Codes are `^0` black, `^1` red, `^2` green, `^3` yellow, `^4` blue,
`^5` cyan, `^6` magenta and `^7` white. `^^` displays a literal caret.
Clan brackets are added automatically. Controls and direction-changing hidden
characters are removed; user text is rendered literally, never as rich-text markup.
Name and clan fields are also available in the in-game player menu.

Colours appear in world nametags, scoreboards and the chat/event feed. Team
symbols retain their team colour and stay hidden with names during death/cloaking;
all name glyphs remain occluded by world geometry. Colour codes do not influence
scoreboard alphabetical sorting. Clan tags are cosmetic, with no membership or
authentication system. Identity updates apply on the next connection.

This update uses protocol `fpsloppa-73-player-identity`; clients and servers must
both be updated. Command-line launches also accept `--name`, `--clan`, and
`--avatar <installed-VRM-SHA256>` after the engine's `--` separator.

## Maps and avatars

Add BSP/VRM files and choose Import locally to validate and install them in the
game's external `maps/` and `vrm/` library. Source files are preserved. Imported
files use content hashes and the game's import metadata conventions. The same
25,000,000-byte limits, BSP spawn checks, and self-contained humanoid VRM checks
apply. Choose an imported avatar from MODEL in the game.

Select a server on the Servers tab, then:

- **Preload assets** downloads its current map and currently announced avatars.
  This temporarily connects as a spectator, occupying a server slot. It does
  not enumerate or download the server's entire map rotation: the existing
  protocol only serves the active map and announced player models.
- **Submit to server** imports the selected files locally, connects as a
  temporary spectator, and sends them using the normal authenticated game
  transfers. BSP upload permissions, storage budgets and the 30-second cooldown
  still apply. VRMs are offered in turn as the temporary connection's avatar;
  this does not change your saved avatar. Success requires server acknowledgement.

Workers run separately from the window. Transfer progress uses actual byte
acknowledgements/download counts; connection and validation phases are shown as
indeterminate. Cancel disconnects the worker. Already verified files remain in
the cache; acknowledged uploads cannot be undone by cancelling. Jobs and status
receipts are in the game's user-data `launcher-jobs/` directory.

`--asset-root` is shared with child processes. The displayed Assets folder is
the installation being managed. Use matching current game/server versions.

## Music playlists

Choose global, a mode, or an installed map; optionally enable Climax / win_.
Add Ogg Vorbis `.ogg` files, move tracks up/down, remove tracks, and Save playlist.
Load a saved launcher playlist to edit it. Original audio is never moved.

The launcher writes `bgm/launcher_global.m3u8`, `bgm/dm_launcher.m3u8`,
`bgm/<map>_launcher.m3u8`, or their `win_` forms. It copies audio into a hidden
`.launcher-tracks/` folder with numbered filenames because the game sorts tracks
by filename even inside M3U playlists. Hidden copies are only included through
their playlist, avoiding duplicate/global playback. Up to 256 tracks can be
edited per playlist; the game retains its global 4,096-track scan limit.

Map music overrides mode music, then global music. Other existing tracks in the
same scope are still combined by the game. Title/lobby music is unchanged.
Restart the game to rescan. Existing non-launcher playlists are not overwritten.
Older audio copies are retained so editing does not interrupt a running client.
The hidden `.launcher-playlists.json` records playlist ownership and display names.

## GitHub release updates

Packaged Linux and Windows launchers check GitHub's public stable
[latest-release API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)
on startup. Checks are cached for one hour; **CHECK UPDATES** forces a refresh.
No GitHub token is bundled. Drafts and prereleases are excluded. Version comparison
is numeric (`0.22v`, `v0.22.0`), never a downgrade. Release notes and download size
are available beside the update controls.

When the installed version is older, **UPDATE TO …** replaces all VR, desktop,
server-join and direct-connect buttons. Keyboard/direct launch callbacks obey the
same gate. Clicking Update downloads the matching full client ZIP with byte
progress and cancellation, verifies the GitHub asset SHA-256, then validates every
file against the embedded `INSTALL-MANIFEST.json` before staging it. A missing or
invalid release archive keeps the confirmed outdated client gated. An offline
check without a previously known update allows play; known updates remain gated.

`tools/build_release.py` stamps each package with release version, platform,
repository and file ownership hashes. Source checkouts and older unmanaged
packages are never overwritten by the launcher. Install an updater-enabled
package once to enter this update channel. Every subsequent published client ZIP
must contain its generated install manifest and expose an API SHA-256 digest.
The current 0.21v public packages predate this updater. The 0.22v expansion is still
a draft as checked on 2026-10-08; publication is required for anonymous delivery.

The installer runs from a separate copy of the current runtime, waits for all
registered clients, launchers and asset workers to close, and uses a journal plus
rollback copies in `.launcher-update/`. It restores the old files after a failed
installation and automatically reopens the launcher on success. If interrupted,
start **Launch-FPSloppa** again: the packaged wrapper invokes the recovery helper
even if replacement of the main executable was interrupted. Keep this folder
until recovery finishes. Close the waiting installer to postpone an update;
restart the wrapper to resume it. Installation itself cannot be cancelled.

Custom maps, avatars, maplists, playlists, settings and extra expansion content
are preserved. Untouched package-owned base assets can be upgraded. Modified or
unowned program-file conflicts stop installation instead of overwriting local
changes. Symbolic links, traversal, duplicate paths, wrong platform/version,
unlisted ZIP files, missing entries and checksum mismatches are rejected. Optional
expansion packs have no separate automatic update channel yet.

## Verification

`python3 tools/launcher/test.py --visual` uses isolated client/server assets and
preferences. It checks real server queries, current-map/avatar preloading,
acknowledged BSP/VRM submission, favourites persistence, admission rules and
playlist ordering through the game's music catalog, plus identity persistence,
colour rendering, direct-join arguments and a real server's avatar acknowledgement.
Screenshots and logs are
written under `test-results/launcher/`. Omit `--visual` for headless checks.

The background reuses `docs/art/slop-title-parody.png`, copied into the exported
client resources at `deathmatch/launcher/title.png`.

Updater regression checks (isolated fixtures):

```sh
python3 tools/launcher/test_updates.py
```

These cover version/release policy, ZIP validation, preserved files, rollback,
interruption recovery, UI launch gating, and real HTTP download/cancellation.
Windows replacement and recovery use the same file transaction and a separate
helper runtime; Windows execution still requires verification on a Windows host.
