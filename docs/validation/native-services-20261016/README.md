# Native client connection, transfer and container services — 2026-10-16

`FPSClientServices` now owns asynchronous DNS resolution/cancellation, endpoint resume-token lookup, atomic profile persistence, avatar download queues and protocol state, disk-streamed downloads, bounded background verification/cache-budget checking and atomic publication, persistent upload streams, busy-server retries and send-backpressure handling. It is the default standalone CQ path; scene/UI/resource hooks remain adapters. There is no new wire format or standalone-server code change.

## Avatar input

The UTAV reader/inspector is now native by default. It validates size/header/manifest bounds, credits, dimensions, geometry and UVs, clip names/ranges/rates, animation positions and bounds, arm/head IK profiles, sockets/weights, base identity and PNG signature/dimensions. It does not create textures, execute source code or fully decode PNG pixel data; the visual loader still handles image decoding. File size is bounded before checksum scanning. `ut_format.gd` retains explicit independent reference methods and `--gdscript-avatar-format`.

Downloads write at most one incoming 32KiB packet payload at a time to a unique private temporary file, instead of assembling a whole download in a script PackedByteArray. One bounded validation worker checks the checksum/container and scans cache usage; only final publication happens on the main thread. Only the current connection generation can publish a verified file to its content-addressed canonical path and emit an installed event. Reset removes partial files immediately and discards in-flight stale completions; normal reset does not wait for validation. Shutdown joins the worker. Validation can hold a bounded full container/position payload internally; zero transfer buffer does not mean zero worker memory.

Upload handles stay open for the transfer. One chunk is exposed per poll, and its offset advances only after successful ENet enqueue; a failed enqueue retains that exact packet. Busy acknowledgements retry after two seconds. Downloads and uploads time out after 30 seconds without progress, including missing begin/final acknowledgements. Cache publication retains the 1GB budget and never exposes an incomplete canonical file.

Profiles keep the existing ConfigFile format/location, now with a unique temporary save followed by rename. Sequential updates preserve other endpoints. Concurrent processes still have last-writer-wins profile updates; no cross-process merge lock is claimed. `--cq-profile-file PATH` supports separate local client identities and isolated QA stores. The default remains `user://cq_native_profiles.cfg`.

## Validation

- [121 service/container checks](services.log) pass: native/reference metadata parity for all 25 bundles, malformed headers/manifests/nested IK/positions, finite bounds, truncation, unsafe identifiers, oversized files before hashing, DNS cancellation, profile updates, disk reception, offset/size/chunk limits, partial cancellation, stale validation, checksum mismatch, sparse quota rejection, timeouts, busy retries, failed-enqueue replay and catalog selection.
- [1,207 session/entity checks](session-regression.log) and [239 state/reconciliation checks](state-regression.log) still pass.
- A real isolated standalone authority accepted a new **6,346,373-byte** avatar uploaded by the [producer client](producer.json). A second client with an empty isolated cache [downloaded and installed it](consumer.json), verified the exact hash and observed its authoritative selection. Both finish with no pending transfer/validation, and no whole-download transfer buffer. Tests use independent cache/profile roots and localhost DNS.
- Full [desktop](desktop.json) and [simulated tracked](tracked.json) functional clients pass combat, grenades, NVG, squads, team changes, jetpack, destruction, death/gibbing/respawn. Both have zero steady-state movement corrections/resets; tracked poses are observed. These are local smoke tests, not capacity tests.
- [All 13 anime avatars render](avatar-render.log) in [idle](avatars-idle.png) and [tracked poses](avatars-tracked.png) through the native reader in the real Forward+ renderer.
- [Inspection timings](inspection-timings.json) show roughly 25× lower metadata-inspection time in the paired fixture. Other local QA was active, and native inspection also warms file caches for the reference. This is not a whole-client FPS or target-device performance claim.

The first two-client attempt used the shared default profile store and correctly hit the authority's duplicate-profile rejection. The successful fixture uses explicitly separate stores. Test tokens/profile files are not included in this report.

## Remaining native port

P1/P3 still retain scene factories/signals, camera/menu activation, main-thread visual/GPU construction, avatar library selection/eviction orchestration, compatibility dictionaries, and cosmetic/audio/voice dispatch. VR interaction state machines, world/environment orchestration and launcher services remain. `--gdscript-client-services` retains the old connection/transfers for differential fixtures; `--gdscript-client-session` selects the full prior session adapter as well. These diagnostic fallbacks still need production release gating.

No Windows/Android/headset QA, commit/push or live deployment was performed.
