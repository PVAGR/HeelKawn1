# CANON CHANGELOG

Track all proposals that alter established world truth.

## Entry Template

Date:
Proposed by:
Affected file(s):
Current canon:
Proposed canon:
Reason:
Status: proposed | accepted | rejected

---

## 2026-04-30 - Cultural architecture documentation

Date: 2026-04-30
Proposed by: assistant
Affected file(s): `docs/WORLD_BIBLE/GLOSSARY.md`, `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md`
Current canon: near-term feature queue item "cultural architecture signature set" lacked detailed specification
Proposed canon: Document architecture constants in GLOSSARY.md with signature table (PERIM_R, DOOR2_MIN_SPAN, OPEN_VILLAGE_WALL, PEACE_TICKS per culture type); mark item as documented in queue
Reason: formalize already-implemented Phase 4 identity system; provide implementation anchor for future reference
Status: accepted

---

## 2026-04-30 - Legacy docs authority + execution queue

Date: 2026-04-30
Proposed by: assistant
Affected file(s): `HEELKAWN_INTEGRATION.md`, `docs/LLM_ONBOARDING.md`, `.github/copilot-instructions.md`, `HEELKAWN_KERNEL.md`, `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md`, `docs/WORLD_BIBLE/MASTER_INDEX.md`
Current canon: old integration language risked being interpreted as current engineering authority; determinism wording varied across onboarding docs.
Proposed canon: legacy docs are canon-reference context only; implementation authority remains `docs/HEELKAWN_STATE.md` + `HEELKAWN.txt`; seeded emergence via `WorldRNG` is canon-safe while unseeded historical randomness is not.
Reason: keep universe history usable while preventing stale architecture claims from steering active feature/system work.
Status: accepted

## 2026-04-25 - World Bible bootstrap

Date: 2026-04-25
Proposed by: assistant
Affected file(s): WORLD_BIBLE/*
Current canon: scattered lore/context across chats and partial docs
Proposed canon: centralized world-bible structure with deterministic canon governance
Reason: prevent context loss from rate limits and cross-LLM fragmentation
Status: accepted
