# ST hand attachments and vehicle impacts

The retained avatar hands and armour cuffs now share the wrist transform. This
matters in VR because tracked reach can translate the Hand bone independently of
the forearm. After removing the armour gloves, retargeting blends the distal
sleeve from LowerArm to Hand; the edge of the retained donor hand has its residual
forearm influence transferred to Hand. Finger weights and the source mesh remain
intact. The same change covers Light, Medium and Heavy, on both sides.

Moving Scouts and transports damage and push pedestrians on authoritative hull
contact. Both hull sweeps and player movement into a hull are checked. Impact
requires at least 3 m/s hull speed and relative closing speed, uses the existing
ram damage and armour-mass impulse systems, and credits the pilot. A 350 ms
per-vehicle/player/life cooldown prevents repeated damage from persistent contact.
Parked or tangential contacts, occupants, spawn protection, and friendly-fire-off
teammates are excluded. No network snapshot fields changed.

Validation on 2026-09-29:

- `tribes_bodies.gd`: 241 checks, no failures, Vulkan wrist stills for both hands
  and all three armour classes. Includes tracked extension and wrist rotations.
- `st_vehicle_impacts.gd`: 25 checks, no failures. Actual hull sweeps and player
  slide contacts, all three craft, damage, impulse, mass and contact safeguards.
- Existing `st_scout.gd`: 55 checks; `st_transports.gd`: 93 checks; no failures.

Evidence is under `test-results/st-hands-impacts/`. This is automated and desktop
render validation; a fresh headset test has not been performed for these changes.
