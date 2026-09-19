# FPSloppa 0.15v CQ experimental — district gateway and prediction handoffs

Isolated experimental branch for CQ CONQUEST. This prerelease does not replace stable main or share its server/client protocol.

- Includes the decorated, baked Vesper city prototype and a 4×4 district layout, two 32-slot teams, four homebases, perimeter capture rules, district-aware radio and controlled respawning.
- Optional `sv_cq_backend districts` delegates simulation to authenticated private workers while one public gateway owns admission, capture rules and district-scoped replication.
- Generation-bound source escrow, destination commit and reliable client baselines hand movement prediction between districts, rejecting stale inputs, state and effects. A transferred human waits for fresh input before movement/combat resumes.
- Packages include the Linux/Windows clients, a Linux dedicated server and self-contained source. Use `Play-Conquest-Desktop` or `Play-Conquest-VR` with a server address. Start a server with `start-conquest-server.sh`; edit `conquest.cfg` to select the district backend and worker limit. Quest is retained as a project target but is not built for this CQ prerelease. Pico is excluded from all new releases.

## Validation and limitations

Two real headless ENet clients passed live internet crossings, stale-packet rejection and round restart. Warm handoffs measured 133–134 ms with zero hard prediction resets; cold worker startup froze movement for 5.7–9.3 seconds. Local tests cover 47 private-worker assertions, 221 CQ rule/configuration assertions, worker eviction/re-entry, and eight bots crossing districts. Worker loss stops the experimental match.

The temporary CQ public test server has been shut down. The test host was capped at four workers and was not a 64-player deployment. This is not a certification of 64-human performance, native Windows operation, graphical desktop/VR comfort, voice quality or balanced full matches. Cross-district ballistics, static-map streaming and durable worker failover are not implemented. The final exported Linux client also loaded the baked city graphically and joined the packaged gateway with a generation baseline and no runtime errors. See `docs/DISTRICT-SERVER-INTEGRATION.md` for the measured results and failure behavior.
