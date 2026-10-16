# Selection computation with identical grass drawing

Use `prepare_medic_test.py --grass --selection-only` to select this two-condition suite. The ordinary eight-condition fixture remains available without `--selection-only`.

- **A: selection ON, drawing held** performs the normal movement/dirty-triggered grass candidate scan, bucketing, selection, sorting and CPU transform-buffer construction. GPU instance submission is held.
- **B: selection OFF, same drawing** skips that work and keeps the same GPU drawing.

Grass audio is disabled and tree/bush selection remains live in both. Weather, daylight and background ambience use the same controls as the preceding suite. This specifically measures selection computation; it does **not** measure buffer-upload cost, which is omitted from both conditions.

Before the first take, **walk into visible grass**. START refuses a seed below **256 submitted instances**. Starting no longer respawns the player at the bare spawn area. The first five-second settling period seeds and locks the actual drawing. Subsequent A/B takes retain those exact buffers, instance counts, visibility flags and bounds. The headset banner shows the retained count.

Open the VR menu → **GRASS TEST: START TAKE**. After settling, follow the same 20-second still/head-turn, walking and running prompts. Use a short out-and-back path around the seed area, returning to the same place and facing for each take. Choose **NEXT CONDITION** for B and start again. Repeat in reverse order if possible. Opening the menu ends a take; it does not pause it.

Every take records `seed_instances`, `seed_drawing_sha256`, `end_drawing_sha256` and `drawing_unchanged`. Both conditions must show the same nonempty seed hash and counts. The per-frame `grass_instances` column now reports actual submitted drawing rather than the selector's unsubmitted CPU result. The summarizer flags a failed drawing control for rejection.

The graphics fixture verifies that moving/dirty selection computations can continue while populated GPU buffers remain byte-identical, and that disabling computation retains the same drawing. Normal buffer submission resumes outside this diagnostic mode.
