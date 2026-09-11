# Recorded VR review and environment feedback — 2026-09-11

Reviewed `/home/blux/Downloads/last.mp4`, a 4:49, 1920×1080 recording, using
timestamped frame samples across its duration and denser one-second samples
from 2:12–2:51. This recording shows HiSlop followed by the waiting lobby;
it is not a Frigate playtest. The wearer reports swimming, avatar jitter,
map layout, lobby behavior and gun-to-wall collision working correctly.

## Comparison with the test goals

| Goal | Evidence and assessment |
| --- | --- |
| HiSlop layout and stairs | Repeated cabin, stair, roof and outer walkway traversal throughout 0:00–3:50. The upper control-cabin terminal is visible around 1:24 and 2:50. This agrees with the wearer's successful traversal report. |
| Sludge swimming and escape | The tank and its surrounding walkways are visible around 2:30–2:35. These sampled frames do not establish an entire submerged entry/exit sequence. Record the wearer's explicit confirmation as the live result, alongside the earlier liquid/surface-jump regression checks. |
| Local avatar jitter | Tracked arms and weapons remain usable throughout the traversal. The wearer confirms the improvement. Sparse video samples cannot measure tracking latency or rule out frame-scale jitter; no frame-time claim is derived from the video's unusual variable-frame-rate metadata. |
| Close-wall gun behavior | Close-wall aiming appears around 0:36, 2:16–2:18 and 2:41–2:43. The wearer reports correct collision behavior. Authoritative damage/ammunition rejection remains covered by the earlier ENet tests rather than inferred from an image. |
| Lobby return and cleanup | By approximately 3:56 the view is inside the lobby. No leftover turret is visible in the sampled lobby views. The tracking mirror is in use around 4:04–4:12. |
| Wall voting | Mode selection is open around 4:20. By 4:28 the board displays an approved CTF map choice, and the map selector is used again around 4:36. Current-vote and Yes/No controls are visible. This supports the lobby usability goal. |
| Body calibration | The mirror shows arms extended around 4:04–4:12. The wearer reports pose detection was too strict; the changes below address that usability issue. |

The reported small moving-wall animation inconsistency remains a minor visual
follow-up. Its cause is not established by this sampled review. Door tween
handling has been hardened, but this is not evidence that the particular recorded
artifact has been fixed. No map geometry was changed for this request.

## Changes after the recording

Doors now play separate opening and closing motor/latch cues through the shared
positional SFX backend. The 0.78-second mono cues use original procedural motor
sound with a bundled CC0 Kenney metal impact. Their peaks are normalized to
−3 dBFS. Audio emits only when the door state changes. Duplicate updates do not
restart motion, reversals cancel the previous tween, and freeing a door or resetting
an Assault leg cancels its old animation. Listener-side placement avoids the
door's own solid panel permanently occluding its motor sound.

Map teleporters retain the existing portal cue and now emit it at both departure
and arrival. Adjacent endpoints within two metres use one cue to avoid doubling
the sound. Feedback uses reliable replication and the existing demo event format;
telefrag and cooldown behavior is preserved.

Automatic full-body calibration now accepts a more relaxed T-pose held for about
1.1 seconds, with modest head tilt, lowered/forward hands, small jitter and brief
pose deviations. It recenters before applying new tracking corrections. Existing
focus, grounded, full-body and non-swimming safeguards remain, as do the completion
jingle/haptics and five-second cooldown. Arms must lower before another trigger.
The new behavior has automated coverage; it has not yet had a new wearer test.

The application icon now uses a simplified version of the title artwork's SloP
lettering and VRM heroine. See [icon source and generation prompt](art/slop-icon.md).

Validation results are recorded in [environment-feedback.json](validation/environment-feedback.json).
Raw video, sampled frames and local logs remain outside release assets. No new
binary export or publication was requested for this update.
