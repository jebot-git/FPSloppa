# CQ physical weapon melee

CQ retains FPSloppa tracked weapon whips: 10 damage, a shared 0.8 second activation cooldown, 1 m/s swing threshold, 0.35 m/s rearm threshold, 0.22 second contact window and one hit per swing. The existing headset-relative, swept 0.5 m weapon sampling and tracking/discontinuity filters are unchanged. A swing must slow down before it rearms. Incidental aiming swings only interrupt shooting when contact occurs.

The native dispatch previously used 0.14 seconds for its shared activation delay and desktop melee. Both now use the same named 0.8 second constant as the native swing sampler. This also prevents alternating hands from bypassing the shared delay. CQ VR commands require a held weapon for melee; the server independently rejects released-weapon melee even when the command claims melee is enabled. Release preserves the activation cooldown.

Validation:

- Native authority regression suite: 915,312 checks pass, including 64-player deterministic replay and 6,000 script-generated melee samples with swept-segment parity.
- Added real authority dispatch regressions at 30 and 60 Hz: unheld weapon rejection, 10 damage once per swing, shared delay, continuous movement without rearm, deliberate rearmed swing, release/regrip/offhand cooldown, tracking loss and desktop delay.
- Linux client and dedicated-server native libraries rebuild successfully and pass source/receipt validation.
- Godot editor import succeeds without script errors.
- The legacy `deathmatch/tests/melee.gd` arena fixture cannot start in this checkout: no compatible legacy arena is installed and its unguarded bot cleanup encounters null. Its script sampler is independently exercised through the golden reference export above.

Reproduce the native check after building `tools/authority_core`:

```
Godot --headless --xr-mode off --path . --script tools/authority_core/reference_export.gd -- --output /tmp/cq-melee-golden
authority-tests /tmp/cq-melee-golden
```

Live VR hardware testing remains manual.
