# FPSloppa 0.22v - Launcher, soundtrack and final expansion

- Desktop launcher with a prominent Play in VR button, desktop play, direct match joining and spectating. Select an avatar, player name and clan tag before launch, with Q3-style name colours.
- Shared favourites show live players, maps and server status. Preload the current BSP and announced VRMs, import local assets or submit supported files to a server, with progress and cancellation.
- GitHub stable-release updater replaces play/join controls when a newer client is known. Downloads and installed files are checked by SHA-256; a separate helper applies updates with recovery and rollback. Custom assets, maplists, playlists and settings are preserved.
- Launcher BGM playlist editor and approved CC0 defaults for every mode, the main menu and the lobby. Bundled music loops and blends with ambience; custom playlist conventions remain supported.
- Corrected MP5/HK VR reload sequence: pull fully back and lock the latch, replace the magazine, release grip, then slap the latch down or sideways. Ordinary charging remains supported.
- ST bots can buy, board and fly Scout/Shrike vehicles using normal team energy and controls, including covered-bay exits and firing at visible enemies. Transport/passenger coordination remains outside this bot implementation.
- Six additional Tribes 2 vehicle adaptations, ST weather and ambience, DE material penetration and bot combat/movement improvements.
- Rewritten illustrated player manual: 17 chapters, 43 pages, searchable offline HTML and a linked PDF. Included with both PC clients and as a separate manual download.

The Final Expansion contains 78 maps: 22 Classic ST adaptations, 14 DE maps,
31 classic arenas, seven ChaosUT KOTH maps and four Unreal Assault conversions.
The ST and DE additions are also bundled base assets. Expansion maplists retain
the original supported maps and exclude retired DE layouts and ten RCMD source
adaptations. Multiple authored KOTH hills rotate; single hills remain fixed.

Pumpfac, Skyville, Twintower and Atlantica use native switches/destructible targets
with ordered objectives and attack/defend legs. Runtime support extends to eight
ordered Assault objectives and 128 maps per rotation. Converted maps adapt the
original layouts; unsupported scripting and some visual details are not reproduced.
The expansion selection is closed; subsequent changes are necessary fixes only.

Downloads: Linux and Windows PC clients, experimental Quest ARM64 APK, Linux
dedicated server, Linux bot worker, master service, self-contained source,
Final Expansion and the offline manual. Start PC clients with Launch-FPSloppa.
Older 0.21v packages require a one-time full-client installation to obtain the
updater. The expansion alone does not update an executable or PCK.

Use matching 0.22v clients and servers. Windows and Quest are cross-built and
package-verified; no new native Windows, physical-headset or haptic-vest playtest
is claimed. Converted-map route checks and short bot matches do not certify
competitive balance or full-capacity performance. See the [release validation receipt](validation/release-0.22v.json) and
[cleanup report](RELEASE-CLEANUP-0.22v.md) for completed checks and limitations.

Original asset notices remain included. Converted maps and ST artwork retain
their documented licences; the CC0 music selection does not relicense other assets.
