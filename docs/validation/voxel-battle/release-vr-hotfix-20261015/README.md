# Corrected 0.17 release clients — 2026-10-15

The published Linux VR startup log showed XRTools hand, pointer and viewport scripts failing to compile. The hand offset class was registered but depended on XRHelpers, which the packager omitted because that helper has no explicit extends declaration. Pointer event classes were omitted for the same reason. Filtering Godot's generated metadata preserves resolved inheritance and includes those implicit RefCounted classes.

Real rendered validation also exposed terrain arrays allocated only inside assertions. Release templates skip assertion expressions; the arrays then retain placeholder formats and reject every streamed update. Allocation now executes normally, returns/checks errors, and is exercised by the packaged resource probe. Binary voxel headers are also consumed outside assertions.

Linux WiVRn-Pro / Quest Pro startup and Windows Forward+ Vulkan execution under Wine both connected to the public server and exited normally. Neither had script compilation or terrain texture-format errors. The resource probe passed on both platforms, and desktop/tracked/Wine gameplay probes all passed. The gameplay suite used the initial candidate with a collision-cache write cleanup; that cleanup was removed to retain the existing map fingerprint. Subsequent real rendered clients verified connection against the unchanged public server. No map, gameplay protocol or native binary changes are required on the deployed server.

Known shutdown-only OpenXR session/vendor signal/RID warnings remain in the Linux log. Glove material UIDs resolve through their valid text paths. Windows hardware/OpenXR was not tested natively. Frame pacing in these logs is not a performance qualification: multiple rendering and packaging jobs were running concurrently.

The final package keeps version 0.17v-cq-experimental, as requested. Its Linux client is installed in Downloads/FPSloppaCQ-Linux-x86_64 and launched against the public server. Previous release archives are replaced, and the tag is updated to the corrected source commit. Raw startup/render evidence is compressed alongside validation.json and build.json.
