# Tank turret pivot correction — 2026-10-15

The light-tank GLB retained the source object's translation `(-1.86214, 1.27518, 0)` on all three mesh nodes, despite its vertices already being baked into normalized vehicle coordinates. The hull could look correct after runtime normalization, while the same offset on the turret/barrel rotated around the yaw/pitch pivot and detached them from the hull.

The GLB mesh-node offsets are now zero. Vertex buffers, textures, material count and triangle count are unchanged. The exporter clears the joined object transform and explicitly uses identity child transforms so rebuilding does not restore the error. The existing runtime aiming transform is factored into a shared function for testing; firing behavior and projectile parameters are unchanged.

- **482 checks passed**, for both actual imported tank assets: pivot attachment, barrel hinge, aim-axis agreement and gun endpoint alignment across five yaw angles, three pitch angles, two hull headings and flat/sloping support. The focused test exits cleanly in headless and graphical runs.
- The existing hover-tank suite passed (`CQ_HOVER_RESULT []`), covering boarding, drive/turn, elevation limits, damage, firing/reloads, collision support, repair and snapshots. It still reports its existing shutdown resource/ObjectDB leak warnings; the new focused fixture does not.
- [Rendered yaw/elevation preview](axes.png) was visually inspected. Rear row: light tanks; front row: heavy tanks. The three columns show sideways/forward/opposite-side aim, with the barrel hinge remaining on the hull.
- Python compilation and `git diff --check` passed. The local desktop driving session was relaunched with the corrected imported model. No live deployment was performed.
