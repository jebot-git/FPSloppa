# Transport wheel and medic interaction follow-up

Branch: `experimental/cq-voxelspace`. Local changes on upstream base `1a6f952`. The remote deployed service is unchanged; the refreshed isolated medic scene uses matching protocol `fpsloppa-cq-frontier-29-vr-mechanics`.

## Transport wheel

An original procedural mesh adds a 36 cm diameter three-spoke wheel and fixed steering column to the driver's cabin. Wheel: 492 triangles, one surface; column: 48 triangles, one surface. Meshes and material are shared between all four transports. It adds two mesh draws per visible transport, with no textures, per-frame mesh rebuilding, or new physical collision bodies.

Grip either hand within 8.5 cm of the rim, then turn physically. Hands keep their wheel attachment and grip orientation until released; two-hand angular changes are averaged, not added. Rotation is limited to ±135°. Chassis yaw carries the seated driver and gripped hands, while preserving tracked head rotation. Weapon-hand stick up accelerates; down brakes through zero then reverses. It respects left-handed weapon selection. Both grips released, tracking loss, menu opening, death, or leaving the driver seat neutralize the controls; resuming after interrupted tracking/menu requires a new grip edge. Desktop driving and tank controls are unchanged.

The existing native authority still owns driving, seats and collision. Steering/throttle axes are individually clamped for the authenticated transport driver, preventing full steering from reducing throttle through circular movement normalization. Foot movement retains its circular speed bound. No new input or snapshot layout is required.

[Cabin render](cabin.png).

## Medic fixes

- Injector scale is consistent when stowed and held: about 21 cm long, up from the previous 12 cm held length / 6.5 cm stowed length. The corrected grip directs the orange needle end away from the thumb, out of the pinky side of the fist. A shared manifest scale generates the native needle-tip offset.
- Contact plus trigger starts a three-second native revival. The confirmed contact pins the visible hand and needle to that point on the patient while administering. A bounded native contact latch tolerates normal wrist drift; releasing trigger/grip, walking out of reach, losing the tool, or invalid target state cancels progress. Native lifecycle, team and line-of-sight checks remain authoritative.
- Either free hand can grip an incapacitated ally to drag. This no longer requires holding a gun; utility decoration no longer clears the drag gesture. Physical hand identity and validated weapon/offhand poses remain consistent. Native dragging binds the patient life, limits pull speed to 2 m/s, uses collision-safe motion and rejects obstructed contact.
- Medical/ammo boxes are deployed by releasing the grip. Trigger while carrying a box cannot heal or deploy. A reliable action identifies the releasing physical hand, and native bounded hand velocity plus gravity/sweeps determine the throw and landing. Airborne boxes cannot supply. Grounded medical boxes heal within a 3 m horizontal radius, with a vertical limit and line-of-sight check; ammo boxes retain their previous range, capacity and cooldown rules.
- Resetting the medic fixture clears the player's old boxes so the fresh low-health state is preserved. The test uses a passive patient controller instead of building AI navigation. Before the change, the isolated scene logged roughly 35–45 ms physics and 1.76 GB static memory after navigation build; after, two idle health samples were about 0.8 ms / 458 MB. These are setup diagnostics, not a controlled VR-performance comparison.

[Injector render](injector.png).

## Validation

- Native core + recorded references: **917,448 checks passed**.
- AddressSanitizer / UndefinedBehaviorSanitizer: **917,448 checks passed**.
- Native/Jolt tracked-medic wire test: **407 checks passed**, including revival, drift, release, actual collision-backed dragging, box drop/landing/healing and fixture reset.
- Existing native/Jolt integration: **593 checks passed**.
- Wheel interaction: **20 checks passed**, including independent hands, chassis motion, handedness, throttle/reverse, release, tracking loss and passenger exclusion.
- Medic gesture test using XR controller trackers: **16 checks passed**, including trigger suppression, one release action, tool pose, attached injection point, free-hand drag and pose validation.
- Existing simulated live mechanics: **31 checks passed**.
- Production desktop/tracked loopback clients and four-bot scenario passed. The suite's source manifest predates the isolated scene's passive-controller optimization; the ordinary arena and native library are unchanged after that suite. A separate current-scene headless medic fixture check passed.
- Rendered inspection confirms the wheel is visible in the cabin and has a fixed column. No additional live-headset ergonomics or gameplay success is claimed yet.

Evidence is under [checks](checks). Existing glove UID fallback warnings and medic test-client exit resource cleanup warnings remain; neither is suppressed.

## Live test

The refreshed local test was launched again at **17:54:13 Europe/Prague**, with player medic 35 HP / 0 armour and an allied incapacitated bot at 1 HP about 1.2 m away. Reset with **F8** or **RESET MEDIC TEST**. [launch.json](launch.json) pins native library identity, process IDs and output directory. Client gameplay, frame pacing, client/server process counters and WiVRn performance collection are attached. No new remote deployment was performed.
