# HEELKAWN — AI WORKING REPORT (Live)

Per-commit detailed log for AI agents. Append only. AGENTS.md is the curated record; this is the raw, commit-by-commit detail.

---

## 2026-09-06 — Session start (Phase 0.1: Foundations & Diagnosis)

### Mandate
User directive: begin Phase 0.1 work using the pasted 200x game log (t=1018, FPS 16-20, TICK_DIAG 17-30ms) as the baseline reality. Keep a detailed AI report per commit/push. Conclude with a short brief human summary.

### Baseline log facts (from user paste, 200x)
- Settlements: 0 formal / 0 proto / 0 polities after ~45 buildings + 22 hearths.
- Food: food_pressure 1.000; all stockpiles 0 at t=90/432; `food_units` declined; `famine_warning` printed at t=30 and 843 even though all pawns hunger=100.
- Jobs: 71 created / 38 completed at t=84 → 66 completed by t=1018; 5 claimed/0 open at end. `claim_next_for` per-claim warnings 1.9-2.9ms.
- Performance: TICK_DIAG wall spikes 512ms→890ms at 200x, 17-30ms per compat tick; some [output overflow] console floods from F10 AUTOLOAD INVENTORY + PAWN dumps.
- Events: some lack top-level `type`/`t` → printed `[t=?][?]`.
- GM_DIAG: 25-30ms elapsed; tick-batch oversized.

### PROFILED root cause of the 200x cost (diag_pawn_profile, tick 300 @200x fenced)
- `idle/util_build_context` n=1380 total=3,433,475us avg=2488us (dominant dispatch stage).
- NEURAL_CACHE_PROFILE: hits=258 miss_ttl=10 miss_sig=50 compute_count=84 compute_total_us=1,985,594.
- NEURAL_CACHE_SPLIT: input_vector_us=1813; **forward_us=1,706,222 (~20.3ms per resolve, 86% of compute)**; rule_context_us=254,920; rule_eval_us=18,550; output_nudge=1,652; result_cache_write=735.
- Conclusion: the per-pawn `PawnNeuralNetwork.forward_propagate` is the hot kernel. The B1 neural-state cache (TTL=128) misfires at 200x because need buckets flap every tick (miss_sig dominates).
- JOB_DIAG claim warnings are successful claims of the LAST open job (open_jobs printed AFTER removal); 2-4ms = fixed per-(pawn,tick) claim context cost, NOT an empty-scan bug.

### Readback (source of truth)
- `scripts/pawn/PawnNeuralNetwork.gd:116` `forward_propagate` — O(source×target) hot loop; per synaptic pair it builds a **String concat** (`source_conn_prefixes[source_idx] + target_id`) and does a `Dictionary.get(conn_id)` → ~6000 string allocs/dict lookups per pass, plus per-neuron `_sanitize_float(_apply_activation(...))`. Neurons' `bias` field is never used in the sum (pre-existing; do not change).
- `scripts/ai/WorldAI.gd:3405` `get_pawn_neural_state` — cache guard by `NEURAL_STATE_CACHE_TTL_TICKS=128` + `_pawn_neural_state_sig`. On miss: `_pawn_neural_input_vector` → `pd.neural_network.forward_propagate` → `_pawn_decision_rule_context` → `_pawn_decision_rule_matrix().evaluate` → output nudge → cache write.
- `scripts/ai/HeelKawnPawnBrain.gd:357` re-exposes `forward_propagate` via the pawn brain.

### DECISION — Phase 0.1 first change (this commit)
Behavior-neutral hot-path optimization of `PawnNeuralNetwork.forward_propagate`:
- Precompute a per-connection-layer **synaptic matrix** (`_forward_matrices`) mapping `(target_idx, source_idx) -> sanitized weight`, keyed by connection_key. Build lazily on first forward (mirrors old dict.get by constructed conn_id → identical lookup semantics regardless of dict iteration order).
- Inner loop becomes an ALIGNED Array-of-Array read with identical summation ORDER (source 0..N-1) → bit-identical float results; no String allocs, no dict.get per pair.
- Neuron `value`/`activation` dict writes and `_store_internal_state` preserved exactly (observability/obfuscation unchanged).
- Invalidate cache in `_update_weights` (backprop), `_add_neuron_to_layer`, `_prune_weak_connections`, `from_dict`.
- NOT touching: need-bucket sig stride (deferred fidelity risk per AGENTS 09-03), neural cache TTL, network topology, any sim/RNG/decision logic.

### Validation plan
- `diag_parse_check.gd` all 7 targets.
- Determinism argument: same float ops, same order, same WorldRNG streams → bit-identical. Fixed-fps determinism harness `diag_determinism.gd` is a further check but is the 02A frame-coupling cross-cut (pre-existing divergence), so parse + a fenced headless profile re-run comparing stages is the practical gate.
- Re-profile with `diag_pawn_profile.gd` (fenced + --profile-pawn-dispatch) and compare `forward_us`/`compute_total_us`.

### Test toolchain (reproducible)
```
& "C:\Users\Richard\hk\tools\godot\Godot_v4.6.2-stable_win64_console.exe" --headless --script res://tools/diag_parse_check.gd --path "C:\Users\Richard\Documents\GitHub\HeelKawn1" -- --playtest-no-save
& "C:\Users\Richard\hk\tools\godot\Godot_v4.6.2-stable_win64_console.exe" --headless --script res://tools/diag_pawn_profile.gd --path "C:\Users\Richard\Documents\GitHub\HeelKawn1" -- --profile-pawn-dispatch --playtest-no-save
```

---

## CHUNK 1 (commit) — Behavior-neutral PawnNeuralNetwork forward hot-path optimization

**Commit:** `fe16bdb6` — pushed to origin/main (`8cb89ae3..fe16bdb6`). 5 files, +362/−36.

### What changed
`scripts/pawn/PawnNeuralNetwork.gd`:
- `forward_propagate` no longer builds a String conn_id + `Dictionary.get` for every (source×target) pair (~6000 String allocs/pass → measured ~20ms).
- New lazy per-layer **synaptic matrix cache** `_get_forward_matrix()`: `matrix[target_idx][source_idx] = sanitized weight`, built from the SAME `connections` dict with the SAME conn_id convention, source 0..N-1. Inner loop is an aligned dot-accumulate → bit-identical float results, ~11.5× faster (bench).
- Invalidation added on every weight/topology mutation: `_update_weights` (backprop), `_add_neuron_to_layer`, `_prune_weak_connections`, `from_dict`.
- Neuron `value`/`activation` dict writes + `_store_internal_state` preserved exactly (observability/obfuscation unchanged).

Not touched: need-bucket sig stride (deferred fidelity risk), neural cache TTL, network topology/logic, all sim/RNG/decision code.

`tools/diag_parse_check.gd`: added `res://scripts/pawn/PawnNeuralNetwork.gd` to TARGETS (now 8 targets).
`tools/diag_nn_forward_equiv.gd`: NEW equivalence+determinism probe (reference reimplementation of the ORIGINAL algorithm; compares element-exact `==` across fresh/reuse/backprop/evolve-add/evolve-prune/save-load; also times both).

### Verification (fenced `--playtest-no-save`, production autosave untouched)
- `diag_parse_check.gd` → all 8 targets OK.
- `diag_nn_forward_equiv.gd` → **NN_EQUIV RESULT=PASS checks=18 failures=0** `new_300x_us=180227 ref_300x_us=2068913 speedup=11.5x`.
  - Probe note: direct `connections[x].erase()` does NOT invalidate the cache (only `_prune_weak_connections` does); that probe variant was removed as an invalid mutation path — all in-tree mutations go through the invalidation-annotated functions.
  - Probe must load() the script inside `_initialize` and avoid compile-time `class_name` typing (autoloads not yet registered when the SceneTree script compiles); has a 600-frame watchdog so a failed probe always quits.
- `diag_pawn_profile.gd` (fresh world, 200x, tick 300, same window as baseline) BEFORE → AFTER:
  - `[NEURAL_CACHE_PROFILE]` compute_total_us **1,985,594 → 399,823 (5.0×)**
  - `[NEURAL_CACHE_SPLIT]` forward_us **1,706,222 → 309,273 (5.5×)**; rule_context 254,920 → 81,663; input_vector 1,813 → 737
  - `dispatch/IDLE` total_us **6.7s → 1,789,496**, avg **4796 → 1277us (3.8×)**
  - Determinism markers unchanged: computes=84, hits=258, miss_ttl=10, miss_sig=50, n=1401 idle → the win is pure per-resolve speed, not fewer decisions.
  - jobs open=0 claimed=15 claim_successes=133 (same world evolution).
- Autosave fence active (`Main._save_writes_disabled_for_playtest==true` verified by the tool before running; wall clock measured).

### Expected user-visible effect
200x live-frame rate on the mature colony should improve substantially (the measured 200x cost was ~86% forward_propagate). Expect commit-level honest readback: F10 ENGINE `Effective World Speed` / frame rate. Playtest acceptance is the user's step.

### Next (open)
- Neural sig-flap at 200x (need buckets) — now less punishing since resolves are 5-11× cheaper; revisit TTL/sig only if playtest still stalls.
- P3 claim-context fixed cost; F10 AUTOLOAD INVENTORY overflow cap; `[t=?][?]` event format; TICK_DIAG wall spikes; settlement formation drift.