# HeelKawn Observer Toolkit

This toolkit provides a repeatable "AI observer" run that mirrors live playtest watching:

- runs mini-simulation sweeps at each speed tier
- tracks timeline events (calendar, settlement state changes, job pressure buckets)
- checks canon guards (100x cap, SimTime tick match, required autoload presence)
- writes machine-readable and human-readable reports

## One-command run

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File "tools/Benchmark-Speeds.ps1"
```

## Output artifacts

Observer reports are written to:

- `logs/observer/*.json` (structured report for tooling)
- `logs/observer/*.md` (human-readable report)
- cleanup decisions: `docs/OBSERVER_CLEANUP_LOG.md`

Each run includes:

- speed results with elapsed/expected/ratio/pass status
- timeline events for world observation context
- canon guard results
- final failure count (`0` means pass)

## How to use in dev loop

1. Run observer benchmark.
2. Inspect latest `logs/observer/*.md`.
3. If failures exist, patch highest-impact deterministic hotpath first.
4. Re-run benchmark and compare ratios.
5. Keep changes that improve report quality/performance or reduce runtime noise.

## Determinism and scope

- Do not introduce RNG-based history changes.
- Keep speed tiers at `100x` max.
- Treat observer output as evidence for cleanup decisions.
- UI should remain reflective of simulation state, not authoritative.
