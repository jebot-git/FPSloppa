# Tribes personal equipment test

The `tribes` loadout now uses its own personal arsenal, three armour bodies,
backpacks and ammunition. It replaces the earlier Quake weapon placeholders.
Stonehenge is the dedicated ST test map. ST also supports seven
[remote deployables](TRIBES-DEPLOYABLES.md); fixed base defences and the full
commander/sensor interface remain incomplete.

## Equipment and controls

- Blaster, plasma gun, chaingun, disc launcher, grenade launcher, laser rifle,
  ELF gun, heavy mortar, repair gun and targeting laser.
- Hand grenades and proximity mines use the shared shoulder grab, throw preview
  and free-hand aiming assistance in VR. Vertical turn-stick input selects the
  shoulder item without unequipping the gun. Desktop G switches the selection;
  desktop weapon selection also permits firing/throwing the utility slot.
- Light carries three guns, Medium four, Heavy five. Laser rifle requires Light
  and an energy pack; mortar requires Heavy. The repair pack supplies a repair
  gun without consuming a primary-gun slot.
- One optional pack: energy, ammunition, repair, shield or sensor jammer. Energy adds
  3/second to the base 8/second recharge. Ammunition increases per-weapon limits.
  Use activates shields/jamming or selects the repair gun. H or the inventory
  entry uses the one carried repair kit.
- B opens the shared buy wheel on desktop. In VR the dominant-hand wheel opens
  inventory at a friendly inventory station on Stonehenge; its carried-weapons entry returns to normal
  selection. The TF class panel also supports armour, pack and gun selection.
- Stonehenge ST uses two inventory stations per team, Light spawn kits, shared
  team energy, equipment trade-ins, ammunition replenishment and gradual repair.
  Walk onto a pad to open the wheel. Save favourites anywhere; purchase them at
  a friendly station. See [Stonehenge ST](STONEHENGE-CTF.md).
- Other maps without stations retain the prototype: refit within 5 m of a
  friendly spawn, otherwise queue for respawn; full equipment cost is charged.

Energy weapons and jets share the same authoritative energy pool. The chaingun
has a half-second spin-up and three-second coast-down. Projectiles inherit
movement according to weapon type; discs accelerate after launch. Grenades and
mortar shells bounce before arming. Mines arm after resting, react to nearby
players (including their owner), and can be destroyed or set off in a chain.
Shields spend personal energy to absorb damage. Repair restores armour
condition, represented by health; the HUD armour gauge represents energy.

## Armour bodies and avatars

The coordinated armour family uses a reduced **MEC-VAL-白狐 suit by KEIV** with
new angular shell geometry, exported as headless VRM 0.0 bodies and imported
through the game's VRM pipeline. Light exposes most of the fitted suit with
compact chest/shoulder plates, bracers and knee pads. Medium uses the previous
Light shell design. Both retain suit footwear and have fitted neck gaiters to
cover the head-swap seam. Heavy has its own canted cuirass, overlapping shoulder
plates on separate shoulder/upper-arm bindings, wrapped abdominal rings,
pelvic chassis and moving hip skirts. Enclosed thighs, reinforced greaves,
neck protection, broad boots and rear cooling/service panels complete its
powered-armour silhouette. All three share chevron plates, class tally marks,
fasteners, colours and material finish.

Full models contain 8,610 / 11,442 / 9,814 triangles, 19 humanoid bones and
four material surfaces each. They add no spring bones. Two shared mipmapped
atlases preserve the suit texture (2048×1024) and plate finish (1024×512).
The combined bodies retain KEIV's non-commercial/attribution terms:
[asset notice](../deathmatch/weapons/tribes/SOURCES.md).

The runtime binds the body to the player's existing skeleton. It retains the
original head, neck, hair, face morphs and original hands when hand geometry is
available. Generated gauntlets are omitted for those hands. Fallback avatars
retain their original head and use generated gauntlets. Red/blue team panels
use per-player material copies, independent of skin and hair. First-person
masking removes chest/head obstruction; switching loadouts restores the
original body and material overrides.

Backpacks use the animated chest position with its imported rest-axis rotation
removed. This keeps them behind the wearer on VRMs whose model root faces +Z;
the hip-tracked VR attachment and fallback-avatar attachment remain separate.

Blender source: `tools/tribes/refined/tribes-bodies.blend`. Rebuild using
`tools/tribes/body.py` through Blender MCP, then Godot
`--headless --script tools/tribes/import_bodies.gd`. Do not import these bodies
as plain GLB: the VRM importer canonicalizes the humanoid axes. Blender's VRM
Add-on 4.7.2 was installed, enabled and verified with an import/export round trip.

## References and adaptations

Mechanics use the public [Tribes 1.41 base scripts](https://github.com/shayk-siege/t1.41-base/tree/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items),
pinned to `c077e0f6ee5c5b0987f9eddf4834a139b5a5a332`. This community distribution
is not authenticated retail 1.11 source. Armour silhouettes were reviewed
against pages 40–41 of the [original manual](https://www.the-flet.com/dynamix/t1/TribesManual.pdf).
Weapon/pack geometry, plate geometry/finish, icons and synthetic audio are
original project assets. The fitted suit is the credited KEIV derivative
described above. No retail Tribes art is included.

Damage normalizes original `.66` Light durability to 100 health. The existing
Godot collision, blast falloff, VR aiming and head hit detection remain in use;
this is not a bit-identical engine recreation. Stonehenge's finite reserve, reconnect-safe contribution tracking and free emergency
spawn are documented [adaptations](STONEHENGE-CTF.md). Other maps retain the
older spawn-area economy. Sensor jamming currently hides enemy player
labels for the wearer and nearby teammates within 20 m; ST remote sensors and turrets also honour pulse-sensor jamming. The complete
fixed-base network remains unimplemented. The targeting laser is a harmless designation beam, without
artillery targeting orders. ST bots use the arsenal, inherited-velocity aiming, continuous outdoor skiing,
staged tower approaches, station purchases and situational team roles. They
can construct defensive remote turrets. Competitive coordinated tactics remain
incomplete; see the [implementation audit](TRIBES-IMPLEMENTATION-GAPS.md).
The dedicated mode and physical hip/chest controls are described in [ST](ST-TRIBES.md).

## Validation

- Arsenal integration: 37 checks; armour/economy integration: 87 checks.
- Movement: 36 checks at 30/60/120 Hz; demo lifecycle: 13 checks.
- Real local ENet server, owner and late spectator pass lifecycle, armour and
  energy replication, including delayed/dropped movement commands.
- Shared CS hand-mask/aim-support regression: 31 checks.
- Native armour gallery tests preserve heads, hands, face morphs, team colours,
  first-person masking and full-body restoration. Eight additional CC0 VRoid
  avatars pass all three classes: 24 combinations, 1,628 checks. The default
  gallery adds 205 checks on the three existing VRMs and fallback bodies.
  Asset checks verify the four-surface/12k-triangle budgets, distinct suit and
  plate textures, mipmaps and attribution metadata. Front, rear, quarter and
  crouched views are captured in `test-results/tribes-armour-family/`.
  Heavy close views and all five backpack previews are under
  `test-results/tribes-heavy-iteration/`. Backpack checks verify rearward
  orientation despite imported skeleton/model axes.

Receipts and native screenshots are under `test-results/tribes-arsenal/` and
`test-results/avatars-cc0/`. These do not replace a headset playtest of the new
arsenal and armour; the earlier Light skiing feel was tested by the user.
