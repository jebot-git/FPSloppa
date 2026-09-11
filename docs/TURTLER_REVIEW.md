# Turtler — local conversion review

Inspected FortressOne/map-repo revision `e9b4176be5a7be4a7eb072a529aa3df33d413bf6`, package `fortress/package/turtler`. Map worldspawn credits BladeZ, with ideas attributed to grey/bm. Source hashes and URLs are in `tools/fortressone/sources.json`.

Sources: https://github.com/FortressOne/map-repo/tree/e9b4176be5a7be4a7eb072a529aa3df33d413bf6/fortress/package/turtler and the repository README. No map-specific license/readme or explicit redistribution grant was found. The game project's license does not automatically cover archived maps. **Not added to the base TF map manifest or rotation; BSP remains local only.**

Local result: `../Builds/Turtler-Local/maps/tf_fo_turtler.bsp`. Geometry uses the existing converter and shared named texture counterparts, with LibreQuake fallback donors for custom names. Existing lightmaps are enabled. Native flag models, capture zones, team spawn points and resupply replace original mod dependencies. The original BSP assigns both flags to team 2; the pinned FortressOne `.ent` corrects goal 1 to owner 1. That specific correction is applied and recorded.

Validation: runtime traversal passed with no engine errors. Native pickup, flag drop, captures and resupply passed for both teams. All three simulated bots left their spawn area and retained finite positions. The all-spawns-to-all-objectives walking-route check failed, so this is not accepted as a base bot map even if redistribution is later cleared. Six in-game inspection images are under `test-results/fortressone-previews/tf_fo_turtler-*`. No headset playtest was performed.
