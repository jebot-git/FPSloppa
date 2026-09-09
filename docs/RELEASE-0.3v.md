# Entryway 0.3v

This build adds dedicated-server TDM, CTF and KOTH, team switching, and majority votes for map changes, team balancing and allowed game modes. In-game hosting remains DM-only and capped at eight; dedicated servers can configure up to 16 connections. Matches display the final scoreboard, and players can join as spectators.

Three additional BSD-licensed LibreQuake arenas bring the bundled catalog to eight. All eight have reachable team bases and hill placements. CTF uses original pole, cloth and team-emblem models with animated fabric. These are adapted arena layouts, not purpose-built symmetrical CTF maps.

Menus use a consistent iron, brass and red visual style. Audio/graphics controls, a head-relative VR status display, improved pickup models, restored CC0 super shotgun, and four original compact tracker compositions are included. Music has its own volume control. Dual pistols improve starting damage and accuracy; low-damage weapon-whip melee has a shared cooldown.

Steam Audio HRTF spatializes effects and built-in voice on Linux, Windows and Android. Local native patches fix sound-source lifetime races, normalize nearby sound levels and support Android 16 KiB pages. Dedicated servers can optionally advertise an external Mumble endpoint; this is a separate-client handoff, not an embedded Mumble implementation. Client-hosted games keep the built-in voice channel.

Dedicated diagnostics support `sv_log_level off|normal|verbose`, optional JSONL files, bounded rotation and periodic connection/performance summaries. Verbose logs include combat and vote events while excluding recorded speech, chat contents and raw body poses. See [SERVER.md](../SERVER.md).

Controller hand/finger handling, native tracker bindings, OSC alignment and body calibration were improved. Bridges that expose lower-leg trackers without feet now provide estimated ankle motion. Real foot poses override the estimate. The final Quest Pro/WiVRn wearer test confirmed tracking and audio after fixes. A local second player recorded 424 microphone packets (8.48 seconds) and replayed them through the game voice path. See [LIVE_VR_TEST.md](../LIVE_VR_TEST.md) and the [validation record](validation/release-0.3v.json).

Use matching `entryway-13-team-modes` clients and servers. Quest/Pico APKs are experimental sideload builds; standalone hardware, physical native Vive/Index tracking, WAN performance and external Mumble operation remain separate validation work. This commit builds local packages and does not publish a new hosted release.

## Rocket jumping, feedback and HUD layout

- Rocket splash applies distance-scaled, wall-blocked knockback. Self splash damage is halved; a healthy player can rocket jump above normal jump height. Airborne horizontal momentum persists; stacked horizontal/upward speed is capped at 20 m/s. Respawn clears momentum, and friendly-fire protection blocks teammate knockback. Server snapshots carry blast momentum for client prediction.
- Three recorded pain grunts, a stronger player respawn cue, distinct health/armour/ammo/weapon/mega pickup sounds, and a replicated cue when megahealth, mega armour or BFG respawns.
- Cyan megahealth and cobalt/gold mega armour have distinct labels and moving luminous halos.
- Four original tracker scores, including Foundry Run and Dark Relay; all now use CC0 recorded guitar, bass and acoustic drums. Runtime soundtrack totals 2.67 MiB; editable modules remain about 52 KiB each.
- Persistent VR HUD size (70–140%) and vertical placement (−65 to +55 cm), adjustable in Graphics.
