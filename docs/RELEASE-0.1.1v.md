# FPSloppa 0.1.1v — VR controller tracking hotfix

Fixes controllers and weapons remaining at floor level in VR. The game requested OpenXR action names (`grip_pose`, `aim_pose`) where Godot expects runtime tracker pose names (`grip`, `aim`). Both hands and independent weapon aim now use the correct names.

Untracked hands are hidden; pointers and weapon input require a valid tracked pose. Eye gaze has its own action instead of sharing the controller default pose, and the gaze regression fixture now matches that action.

The existing Touch, Index and Pico grip/aim profile bindings remain intact. No controller-profile reset should be needed for this naming bug.

Validation: runtime-style XRControllerTracker regression tests cover late connection, 6DoF movement, distinct grip/aim poses, disconnection, and controller-profile bindings. VR combat and eye/body tests are also run. Physical VDXR/SteamVR headset verification remains pending; this release does not claim measured headset performance.

Download and extract the entire Linux/Windows ZIP, or sideload the appropriate Quest/Pico APK (version code 5). Source and dedicated server packages are also included. All seven uploads have SHA-256 verification. Protocol `entryway-dm-7-eyes` is unchanged and remains compatible with 0.1v servers. The original 0.1v release is preserved.
