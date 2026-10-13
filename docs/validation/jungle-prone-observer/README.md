# Standing observer, prone player in tall grass

Randomly selected bundled model: **World Leaders · Macron**. Observer eye height is **1.70 m above its local terrain**, with a **3.0 m horizontal distance** to the model root. Vulkan Forward+, 1,600×1,000, 60° camera FOV and the current 96 m hybrid grass radius.

[Render in grass](prone-in-grass.png), [same pose with grass disabled](prone-reference.png), [selection/placement receipt](receipt.json), [render log](render.log).

This is a frozen still preview using original straight-body `Breath1` frame 25 and the production prone rotation. The normal gameplay prone path currently chooses a crouch animation, which raises the knees when rotated; gameplay animation selection was not changed for this render. The model is fitted above sampled terrain using transformed native vertex bounds so concealment does not result from buried mesh geometry. Tracking and AI are absent.

Reproduce the same random roster selection and deterministic tall-grass patch:

```sh
godot --xr-mode off --rendering-method forward_plus --rendering-driver vulkan --path . --script tools/voxel_battle/prone_observer.gd -- --seed 4127984082040278291
```

Omit `--seed` for a new random bundled model. The script checks terrain streaming has settled before capture. The paired reference changes undergrowth visibility only.
