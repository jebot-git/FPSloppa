# Frozen 0.22v expansion

The final scope is 78 maps. `manifest.json` fixes their identities, all payload
hashes and combined old/new rotations. No further content additions are planned.
Only necessary fixes may change the archive; record the reason with
`build.py --necessary-fix 'actual repair reason'`. That path still rejects a
changed map selection. Preserve previous released ZIPs/checksums when fixing.

Build prerequisites are the hash-matching installed assets and checked-in
conversion/validation receipts. Run the engine's `cache_selection.gd` to record
exact active cache variants, then `python3 tools/final_expansion/build.py`.
An initial freeze uses `--freeze`; later ordinary builds must match the lock.
`--verify-only` validates the existing ZIP and the frozen source payload.

The ZIP includes only selected runtime caches, not redundant preparation copies.
Every file is read back and SHA-256 checked after packaging. The release builder
stages it as an explicit asset when preparing 0.22v. The normal release publisher
verifies GitHub's uploaded digest and includes it in the release SHA256SUMS.

`base_rotations.py` keeps ordinary base lists free of local test rotations and
optional imports. Expanded lists are generated inside the ZIP. Installation
and content limitations are in `docs/FINAL-EXPANSION.md`.
