# ST base infrastructure and bot counterplay

Historical report: [steps 4–6](ST-FIELD-SYSTEMS.md) supersede its zero-health service threshold and single-source power limitations.

Subsequent implementation: [offence, construction and fixed defences](ST-OFFENCE-DEFENCES.md) adds the skills and fixed systems listed as future work in this historical report.

Stonehenge has four independently damageable inventory stations and two
operational medium pulse sensors. Both station service and fixed scanning
require their team's generator. Destroying a station disables that station
without disabling its sibling; a friendly repair gun restores it. Disabled
fixtures keep their existing collision and remain repairable. Direct projectiles,
beams and visible blast damage use the actual BSP/native fixture geometry.
Friendly-fire policy applies to equipment damage.

A medium pulse sensor scans at 5 Hz over 250 m with world line of sight and
can detect stationary enemies. Personal and remote jammers suppress pulse
contacts; motion sensors and cameras retain their existing detection rules.
The shared desktop/VR status row reads `SENSOR: CLEAR`, `DETECTED` or `JAMMED`.
Detection takes precedence if another sensor still sees the player. These
contacts inform team defence assignments but never bypass bot firing LOS.

Bot maintenance selects damaged generators first, then inventory stations,
nearby friendly deployables and fixed sensors. Bots skip disabled inventory
pads when seeking purchases or resupply. Offensive equipment acquisition runs
at 5 Hz, checks field of view and LOS, and uses ordinary weapons and ammunition.
Runners can shoot an exposed hostile turret while retaining their flag route;
siege bots can also target other remote equipment. A close player threat takes
priority. Broader deployment planning and fixed-asset siege objectives remain
future work.

The uphill steering decision compares slope, direction and available momentum.
Low-speed climbing releases ski for walking traction; useful fast uphill
coasting and downhill acceleration remain available. The player physics,
weapon damage and bot inventory rules are unchanged.

## Reference and adaptations

The pinned community [inventory station script](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/stations/inventorystation.cs)
and [medium pulse sensor script](https://github.com/shayk-siege/t1.41-base/blob/c077e0f6ee5c5b0987f9eddf4834a139b5a5a332/server/items/sensors/sensor.cs)
provide 1.0 durability and the sensor's 250 m LOS scan. Durability follows the
project's `.66 → 100 HP` scale, giving approximately 151.5 HP per fixture.
These scripts are not authenticated retail source. The Stonehenge fixture
count derives from the documented mission variant, not a verified stock mission.

Object shields, fractional disable thresholds, multiple power sources, fixed
turrets, long-range sensors and the full commander interface are not implemented.
The current generator remains a 300 HP approximation. Service resumes above
zero HP with generator power. Sensor and station labels are native meshes/text;
no additional image assets or spring bones are used.

Protocol `fpsloppa-60-st-base-assets` carries bounded fixture-health arrays and
scan suppression. New peers must use the same protocol. Older six-field Tribes
demo states remain readable, with intact fixed fixtures as the legacy default.

## Verification

`deathmatch/tests/st_base_assets.gd` checks all six actual map hitboxes, friendly
fire, station service, repair beams, blasts, fixed scan LOS/jamming/power,
bot equipment targeting/repair, malformed snapshots and actual 20-degree
uphill movement in all three armour classes. ENet tests cover destruction,
repair and detection replication to the owner and a late spectator. UI tests
cover both shared HUD text and rendered station/sensor status. See the
[validation receipt](validation/st-infrastructure-2026-09-27.json) for navigation
and contested match results and limitations.
