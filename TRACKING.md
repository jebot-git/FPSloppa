# Optional body and hand tracking

Body tracking animates VRM models and replicates to other players. The collision capsule, damage volumes, movement rules and controller-driven weapon aim stay unified. Missing joints fall back to the existing head/controller IK and animated, ground-adjusted feet. All clients and servers must use this release's `entryway-dm-7-eyes` protocol.

## Available input paths

| Input | Implementation | Device validation |
|---|---|---|
| Vive trackers / SteamVR tracker roles | OpenXR HTC tracker action bindings; hips, chest, feet, knees and elbows drive calibrated IK targets | Simulated pose/calibration and networking tested; physical trackers unavailable |
| SlimeVR server | Receives the server's VRChat OSC tracker output over UDP; no SteamVR required for this path | Actual OSC packets/bundles, coordinate conversion, timeout and calibration tested; hardware unavailable |
| Quest upper body | Official OpenXR Vendors 5.1 Meta body extension; valid XRBodyTracker joints drive hips/chest/limb IK | Synthetic native XRBodyTracker tested; Quest permission/runtime still needs headset testing |
| Quest optical hands | Optional OpenXR hand tracking; wrist poses and five finger curl estimates animate the VRM | Requires runtime to expose hand data, including simultaneous controller/hand tracking where supported |
| Native Pico Motion Trackers | Not implemented by the installed stable vendor plugin; upstream native support remains a draft | No claim of native Pico tracker support |

The generic XRBodyTracker adapter also consumes joints from another compatible runtime if it publishes them. Pico headsets can still use the SlimeVR OSC path; this does not turn their proprietary tracker API into a supported native input.

## Vive setup

Assign waist, chest, left/right foot, knee and elbow tracker roles in SteamVR. Use SteamVR as the active OpenXR runtime and enable its HTC Vive tracker extension support. Start the game, stand upright with feet pointing forward and arms relaxed, recenter, then select **CALIBRATE BODY** in the VR menu. Each detected tracker gets a mounting offset to the normalized avatar's standing targets. Calibrate again after adjusting trackers or recentering. Tracker additions require recalibration. Partial sets work; hips plus two feet is a useful starting set.

## SlimeVR setup

Calibrate the SlimeVR skeleton in its server, enable VRChat OSC output, and send it to the game's machine on UDP **9000**. Enable the hip, feet, knees, chest and elbow output roles you use. This is the VRChat OSC output, not VMC output and not raw IMU tracker packets. Enable **SLIMEVR OSC ON / OFF** in the game, then stand upright, face the same forward direction used for the Slime reset and select **CALIBRATE BODY**.

By default the listener accepts only `127.0.0.1`, for a server on the same PC. For SlimeVR on a separate PC sending to a standalone headset, create `tracking.cfg` in the game's Godot user-data directory:

```ini
[slime]
enabled=true
source_ip="192.168.1.50"
listen_port=9000
```

Set `source_ip` to the SlimeVR server's address. Set the SlimeVR destination to the headset's LAN address, using the same port. On desktop the file is under Godot's `app_userdata/Entryway Deathmatch`; Android uses the application's private user-data directory, so configuring it may require device development tools. The menu toggle persists; the address/port are configuration-file settings. The receiver accepts packets only from the configured source IP, caps packet/bundle work per frame, rejects malformed/nonfinite data and expires position samples after 250 ms. OSC itself is unencrypted and unauthenticated; use a trusted LAN.

## Quest setup and fallback

Enable tracking in the headset settings, use the Quest APK, grant the optional tracking permissions requested by the vendor plugin. **CALIBRATE BODY** can also request body permission. If the runtime did not start tracking after the first grant, restart the app. The runtime performs native body calibration. Optical hand availability depends on the headset/runtime's support, permissions and controller/hand coexistence. Hand poses animate the model; controllers remain necessary for arena movement, shooting and menus. This release does not provide a hands-only control scheme.

The menu's **BODY TRACKING ON / OFF** disables all extra cosmetic tracking. Focus loss, stale OSC samples and unavailable native joints return to the existing IK. Native leg data is used only when the runtime supplies it; Quest upper-body support alone is not evidence of measured leg tracking.

## Implementation and checks

Poses are bounded, finite rigid transforms relative to the authoritative player origin. The server validates cosmetic body targets separately from the weapon pose; invalid body data cannot move hitboxes or extend weapon reach. Remote poses are smoothed. The payload includes at most ten transforms and ten finger-curl floats per player; body tracking adds snapshot bandwidth, particularly with eight tracked players. No additional internet tracking service is used.

Tests cover native joint ingestion/loss, OSC decoding and calibration, rejected oversized/malformed poses, all bundled VRM mouth bindings, finite IK and server-to-client body-pose replication. Physical calibration quality, tracker mounting conventions, joint orientation and tracking latency still require real devices.

Sources: [Godot HTC tracker roles](https://docs.godotengine.org/en/stable/tutorials/xr/openxr_body_tracking.html), [official body tracking plugin documentation](https://godotvr.github.io/godot_openxr_vendors/manual/body_tracking.html), [SlimeVR OSC implementation](https://github.com/SlimeVR/SlimeVR-Server/blob/main/server/core/src/main/java/dev/slimevr/osc/VRCOSCHandler.kt), [Pico native tracking draft #365](https://github.com/GodotVR/godot_openxr_vendors/pull/365).
