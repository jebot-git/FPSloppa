# FPSloppa 0.18v — VR weapon handling and DE interaction fixes

CS weapons now support more natural physical reloads and keep the rendered hands
attached through recoil. Retained magazines can be put back into the gun with
their exact remaining ammunition, shown by a small count while held. The count
excludes a chambered round; a tactical reload preserves that round.

- Refined CS weapon profiles, textures, magazine proportions, iron sights and
  moving parts. The M3 uses its pump without an unused charging handle.
- Added AK magazine bump release, a more forgiving MP5 slap/rack, a connected
  M249 feed belt, staged AWP bolt motion and forgiving pistol slide-release flicks.
  Offhand trigger and grip both operate reload parts. M3 automatic transfer to
  the offhand pump is optional in VR settings.
- Fixed stray held shotgun shells, persistent offhand support, magazine hand/drop
  orientation and dropped-magazine scale. Reloads and tweezer snips have sounds.
- Refined CS-only single-hand recoil penalties; pistols are exempt. Verified
  headshot damage and grounded crouch/prone accuracy modifiers.
- Improved first-person head/chest masking, tracked hip attachments and procedural
  hand placement. Bomb and tweezers sit lower on the chest to reduce accidental grabs.
- Gun-hand grip draws chest equipment and temporarily stashes the gun; release
  stows it. Bomb dropping requires Use. Keypad entry follows free-hand fingertip
  contact, and tweezers visibly snip on a fresh trigger press.
- Grenade selection keeps the gun equipped and reports the selected shoulder
  grenade with an icon/status notice. TF throwables use the shared aiming guidance.
  The buy menu now uses a grenade icon for its grenade category.
- Added bounded gunshot decals and refined gaze-driven stereo foveation on
  supported GPU/runtime combinations. Test-only fovea-mask previews are excluded.

The dedicated Tribes loadout and BSP29 skiing proposal is documented in the source
assessment. No Tribes movement or loadout is included in this release.

Downloads include Linux and Windows clients, the Linux dedicated server, Quest
APK, self-contained source, and the standalone master server. The clients retain
32 bundled maps and three base avatars. The original soundtrack is unchanged,
with the existing orchestral DE cue.

Use matching 0.18v clients and servers: protocol
`fpsloppa-53-retained-magazine`. Quest Android version code is 23. Configuration
and bindings remain compatible, including customised controller bindings.

Validation covers authoritative reload/ammunition handling, rendered VR input
fixtures, DE chest interactions, local client/server replication, exported
resources, compressed assets, package contents and Quest signing/alignment.
See `docs/validation/release-0.18v.json` for the release results. Local Linux
rendering and automated VR fixtures do not replace native Windows or physical
Quest validation. The latest changes still need an in-headset comfort check.
Quad-view rendering is not implemented.
