# Isolated Jolt regression deployment

This bundle tests the branch's integrated Jolt runtime and standalone native
collision experiments. It does not restart services, change production configs,
open firewall ports or establish 64-player server capacity.

Prepare from the source worktree, after committing the intended source:

```sh
python3 tools/collision_service/prepare_deployment.py --template /path/to/linux_release.x86_64 --jolt-source /path/to/pinned-jolt --output /tmp/cq-jolt-tests
```

The Jolt dependency must match commit
`e77f175595e64cb44218cc9d9d56fc365ad0e36a` (5.6.0), either a clean Git
checkout or the verified Git-blob manifest checkout used in the recorded tests.
The prepared bundle includes the dependency sources/license, suite sources,
current server pack, portable native libraries and SHA-256 manifest. It includes
an optimized TwoVoIP library alias for the full editor's debug-feature lookup.
The library uses the same GDExtension ABI; the server release remains unchanged.
It includes no local credentials or production profiles. Source commit/dirty status records
exactly which working tree was packaged; deploy a clean commit for reviewable
provenance. The pack retains the Jolt selection and current CQ protocol.

Copy the bundle into its own directory on the VPS, for example
`~/fpsloppa-cq/validation/jolt-<commit>/`. Do not replace `current` or overwrite
the active release. Transfer `manifest.json` through the same trusted channel
as the bundle; checksums detect corruption, not an untrusted distributor.

Prerequisites on the test host:

- Python 3.10+, CMake 3.20+, a C++17 compiler, Make or Ninja.
- A **full Godot 4.7.2 executable with Jolt**, available as `godot` or supplied
  with `--godot /absolute/path/to/Godot`. Export templates cannot run the
  `--script` fixtures. The full Godot executable is not included in the bundle.
- Approximately 3 GB free disk space for package, build and results.
- Free local test UDP ports 28803, 28807, 28810, 28814, 28816, 28819 and 28820.

Run as an ordinary user without sudo:

```sh
python3 run_suite.py --output /tmp/cq-jolt-results --jobs 4 --godot /path/to/Godot
```

The runner verifies every bundled file, builds Jolt locally without dependency
downloads, runs all three native CTest targets, then executes the integrated
map/crowd acceptance, movement, jetpack, vehicles, ballistics, CQ, prediction,
terrain and paired ENet fixtures against the packaged assets. CS/acceptance fixtures cover crouch/prone hulls;
the legacy generic-arena water fixture requires separately installed arenas and
is not part of this CQ deployment.
Preferences, profiles, cache and logs go into the new output directory, separate
from the live server's data. First use generates the terrain cache and may take
longer. The paired network fixtures use test UDP 28816 and 28820. Snapshot differential
and benchmark coverage also uses UDP 28819.
Use `--native-only` for a compiler-only check; its results do not validate the
runtime integration.

The process returns nonzero for failed tests, unexpected engine errors, timeout,
checksum failure or a mismatched Godot version. Existing arena teardown's exact
eight-resource diagnostic is recorded and allowed; other errors are failures.
`results.json` records the source commit, individual results and explicitly
states that this is not capacity validation. Do not add the native microbenchmark
timings to integrated movement or full-server tick timings.

After regression acceptance, the included capacity tools can launch isolated,
separately recorded 32/64-player full-server tests:

```sh
python3 capacity/native_compare.py --binary release/cq-server --fleet capacity/client_fleet.py --config capacity/server.cfg --output /tmp/cq-jolt-capacity --players 32 64 --seconds 120 --port 7779
```

Run from the bundle directory. `--fleet` must resolve from that directory.
These clients run on the same host and consume CPU; use an off-host fleet for
deployment capacity conclusions. Check `report.json`, each fleet's exit codes,
achieved tick rate and sustained population; completion alone is not acceptance.
Keep the live 32-slot configuration
unchanged; 64 slots remain an unsupported option. Native batching is still a
test-service experiment, not the current Godot backend's implementation.

The authority rewrite experiments are packaged with this suite. Run
`python3 run_suite.py --output /tmp/cq-authority-regressions --authority-experiments`
to exercise gameplay with native player bookkeeping, input projection, fanout and
immutable snapshot buffers. The separate ordered capacity comparison is
`python3 tools/player_simulation/run_suite.py --binary release/cq-server --output /tmp/cq-authority-capacity`.
It defaults to five stages, 32/64 separate ENet clients and 120 measured seconds
per case. See `tools/player_simulation/README.md` for switches and interpretation.
These commands do not change the live service, the protocol or production defaults.
