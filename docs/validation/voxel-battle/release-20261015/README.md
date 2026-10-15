# CQ game-only release validation — 2026-10-15

Release 0.17v-cq-experimental is built from experimental/cq-voxelspace using portable native Linux server/client and Windows libraries. Build receipts verified current native source fingerprints and the Linux glibc baseline before packaging.

- `build.json`: launcher-free platform packs and live connection preset.
- `packaged-server.json`: isolated local dedicated server admission and destruction smoke.
- `packaged-clients.json`: Linux desktop, synthetic tracked-controller and Windows-under-Wine gameplay admission; all passed. Wine does not validate Windows GPU/OpenXR hardware.
- `vps-smoke.json`: transferred file hashes and isolated VPS runtime validation.
- `deployment.json`: active production runtime, 64 slots, destruction, adaptive tick and stopped competing services.
- `public-server-client.json`: synthetic tracked client passed gameplay admission over the public network after activation.
- `default-connection.log`: unconfigured shipped client joins the public server through its baked-in preset.

CoreCU was stopped gracefully locally (console save-and-exit, then database shutdown and container stop). Remote SWGXR services were already inactive and are explicitly stopped; boot target and daily restart timer are disabled. Persistent CoreCU data is retained. Only the new production CQ server remains; private smoke servers are stopped.

The first activation was safely rolled back because the legacy sv_maxclients validator rejects 64. Retrying with sv_maxclients 32 and CQ-specific sv_cq_maxclients 64 succeeded. The rollback backup is retained remotely. These checks validate startup, connection and selected mechanics; they do not qualify sustained 64-player load or establish headset performance.
