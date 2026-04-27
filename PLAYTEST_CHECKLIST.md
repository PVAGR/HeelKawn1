# HeelKawn Playtest Checklist (Quick)

Use this if you are tired. Just follow in order.

## 1) Start capture run

- Double-click `play_capture.bat`
- Let the game run until the moment you want to validate
- Close the game

## 2) Send me evidence (pick one)

- Screenshot of the terminal window, or
- Paste lines from `logs\playtest_latest.log`

## 3) What to capture for Phase 8 proof

- One `[PHASE8_PROOF_SUMMARY]` line (best single line)
- Optional extra:
  - one `[PHASE8_PROOF_RESULT]`
  - one non-active `[PHASE8_PROOF_BUNDLE]`
  - one `[PAWN_DIVERGENCE_SCHEMA]` line (packet schema/version marker for parser compatibility)
  - one `[PAWN_DIVERGENCE_EMIT]` line (emission reason: `tick_30000`, `tick_60000`, or `exit_tree`)
  - one `[PAWN_DIVERGENCE_PROOF]` line (should be dynamic center + scored_events_present=true when binding/scoring pass)
  - one `[PAWN_DIVERGENCE_HEALTH]` line (quick PASS/WARN/FAIL read)
  - one `[PAWN_DIVERGENCE_BINDING_QUALITY]` line (one-glance binding quality verdict + reason)
  - one `[PAWN_DIVERGENCE_BINDING_MIX]` line (native/fallback + context-source rates)
  - one `[PAWN_DIVERGENCE_ALERTS]` line (fast regression flags for triage)
  - one `[PAWN_DIVERGENCE_NEXT_ACTION]` line (operator hint for first follow-up)
  - one `[PAWN_DIVERGENCE_STATE]` line (fixed-field machine-parseable run snapshot)
  - one `[PAWN_DIVERGENCE_INVARIANT]` line (counter-consistency pass/fail for instrumentation trust)
  - one `[PAWN_DIVERGENCE_FINGERPRINT]` line (single-line digest for run-to-run diffing)
  - one `[PAWN_DIVERGENCE_CENTER_FINGERPRINT]` line (per-center scored/aligned/divergent/neutral digest)
  - one `[PAWN_DIVERGENCE_GATES]` line (explicit pass-criteria booleans + aggregate gate pass)
  - one `[PAWN_DIVERGENCE_GO_NO_GO]` line (`GO|HOLD|BLOCK` release-facing decision + reason)
  - one `[PAWN_DIVERGENCE_PACKET]` line (single-line packed handoff record with `emit_reason` + `packet_id`)
  - any `[PAWN_DIVERGENCE_CONTEXT_SUMMARY]` lines (shows settlement-context source mix per run)

## 4) What I will return to you

1. What this shows
2. PASS / FAIL / INCONCLUSIVE
3. What I will change now
4. What you do next (one action)

## 5) If run does not start

- Run `check_godot_path.bat`
- Send me screenshot of its output
