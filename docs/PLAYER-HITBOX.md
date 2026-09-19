# Player damage volumes

The old damage capsule was 0.80 m wide and extended from floor level to 1.80 m.
It was wider than the placeholder's head, taller than the visible avatar, and
narrower than its shoulders. The movement capsule is separate: radius 0.30 m,
standing height 1.65 m. Movement collision remains unchanged.

Damage now uses twelve oriented boxes based on the placeholder: head, torso,
two upper arms, two forearms, two thighs, two shins and two boots. The standing
avatar is 1.65 m tall, shoulders span 0.98 m, torso is 0.55 × 0.58 × 0.32 m,
and head is 0.35 × 0.34 × 0.34 m, with the visor included in its front face.
`deathmatch/avatars/hit_body.gd` supplies shared geometry constants to the
placeholder renderer and damage tests.

The volumes follow facing direction and the stable standing, crouched or prone
placeholder pose. Crouch height is resolved to one centimetre. Weapon models,
cosmetic walk-cycle swings, flinches and user-supplied VRM proportions do not
change the canonical damage anatomy. This keeps avatar choice from changing
combat balance; it is not per-frame skinned-mesh collision.

All direct weapon paths use this anatomy: ordinary and experimental hitscan,
penetrating rail shots, physical melee, projectiles, TF grenades and Titan cannon
direct hits. Projectile sweeps use their actual sphere radius against the box
faces, edges and corners. Moving-target sweeps, spawn boundaries and cover checks
remain active. The projectile candidate grid includes prone limbs at any yaw.
Lag compensation records/interpolates facing as well as position and height.
Headshot bonuses use the head box, including the rewound pose.

The narrower head exposed a desktop dual-pistol bug: shots travelled along
parallel rays offset ±0.18 m and could miss a head centered under the crosshair.
Desktop weapons now share the crosshair ray. Independent tracked VR muzzle
origins and directions remain in use.

## Verification

`deathmatch/tests/player_hitbox.gd` checks 1,053 sampled points from actual
placeholder meshes across standing, crouched and prone poses. It also checks
shoulder/head/boot boundaries, empty space, rounded projectile corners,
headshot classification, facing rewind and both desktop pistols. Pass `--visual`
after Godot's `--` separator to render front/side overlays into
`test-results/player-hitbox/placeholder-bounds.png`.

Other passing mechanics fixtures cover hit detection, 12,000 randomized
projectile candidate queries (no lost exact hits), TF arsenal, weapon variants,
lag compensation, combat, melee, fortress, dual pistols, stances, VR crouching,
Titan bot weapon selection and projectile ordering. A synthetic eight-player
server run with up to 281 projectiles measured 3.26 ms p95 simulation ticks on
this machine; this is a bounded local measurement, not a live-match guarantee.
The dedicated-server ENet fixture also passed for the server, shooter, target
and spectator, including hitscan kills, tracked melee/kicks, independent VR
pistol aim, rocket replication, respawn and late joining. Its same-map restart
explicitly disables the separate intermission ballot.

Live multiplayer/headset playtesting is still needed to assess feel, especially
the narrower head and torso. Existing ObjectDB shutdown warnings remain.
