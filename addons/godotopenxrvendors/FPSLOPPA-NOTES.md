# FPSloppa face-tracking compatibility patch

The Linux x86_64 debug and release libraries are rebuilt from Godot OpenXR Vendors 5.1.0 source commit `7afcd397e6206d9751b82100559ff39a93a8f59e`, with godot-cpp submodule `58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74` using the upstream non-preview build configuration. Other platform libraries remain upstream binaries.

`tools/patches/openxr-supported-face-sources.patch` changes the Meta face tracker to request only data sources advertised by `XrSystemFaceTrackingProperties2FB`. WiVRn supports visual face tracking but rejects requests containing an unsupported audio source; the old unconditional visual+audio request prevented all eyelid data. Audio-driven mouth animation remains handled by TwoVoIP.

To reproduce, check out the pinned source and submodule, apply the patch with `git apply`, and run the following from the vendor source directory for each target (`template_debug` and `template_release`):

```sh
scons platform=linux arch=x86_64 target=template_debug custom_api_file=thirdparty/godot_cpp_gdextension_api/extension_api.json build_profile=thirdparty/godot_cpp_build_profile/build_profile.json -j4
```

Copy `demo/addons/godotopenxrvendors/.bin/linux/<target>/x86_64/libgodotopenxrvendors.so` to the matching addon path. Retain the bundled SDK and third-party licenses. `FPSLOPPA-BINARY-SHA256.json` identifies the patched binaries; do not replace them with upstream binaries without retaining the source-selection fix. Apply the same source patch when rebuilding for other platforms.

The Linux libraries are built with GCC 11 in Ubuntu 22.04 to retain compatibility with older Linux hosts. Experimental Meta preview extensions are excluded, matching the previously bundled binaries. The source prints the runtime's visual/audio face-source capability flags once at session startup for diagnosis.
