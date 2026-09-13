# Reproducing the competitive AI study

Run from the project root. Godot and Python 3 are required. Results go to ignored `test-results/ai-study`; summaries go to `docs/validation`.

```
python3 tools/ai_study/run.py --label before --baseline --modes dm,tdm,ctf,koth,ig,if,ft,cc,tf,as
python3 tools/ai_study/run.py --label after --modes dm,tdm,ctf,koth,ig,if,ft,cc,tf,as
python3 tools/ai_study/network.py --label network-before --baseline
python3 tools/ai_study/network.py --label network-after
```

Use fresh labels to preserve old evidence. Network tests bind loopback port 29777, run eight real bot clients plus an observer, record a demo, switch CTF → KOTH without lobby, and reap every child in `finally`. They do not connect to the remote server. Do not run before/after tests simultaneously when comparing performance.

`audit.gd INPUT.fpsdemo OUTPUT.json` validates and measures demo frames. `summarize.py` assembles known result labels into the durable receipt. `soak.gd` adds behavior counters to the existing full-physics soak harness. `baseline` contains the exact AI/adapter at the start of this study, with only preload paths redirected to the snapshot; movement/combat engine and assets are shared, so it is an AI-only baseline. `ledge.gd` is the targeted qsrc_dm3 floor/navigation diagnostic.

See `docs/AI-COMPETITIVE-BEHAVIOUR-STUDY.md` for source provenance, interpretation and limitations.
