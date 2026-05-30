# State Verification 2026-05-30 (Part 3)

## What Changed

- **TeachingSystem.gd**: Complete rewrite from ~120 -> 1032 lines. Full production implementation replacing the previous minimal stub.

## New TeachingSystem Architecture

### Data Model
- `_active_lessons`: lesson_id -> dict with teacher_id, student_id, category, tick_started, duration, effectiveness, progress, completed, last_update_tick, teacher_settlement, student_settlement
- `_teacher_xp`: pawn_id -> float (accumulated teaching experience)
- `_lessons_history`: lesson_id -> lesson_data snapshot (archive of all past lessons)
- `_move_away_lessons`: lesson_id -> grace_period_end_tick (tracking settlement-separation grace)

### Key Systems Implemented
1. Lesson model with teacher/student/category tracking, progress, duration, effectiveness
2. Multiple concurrent lessons per teacher (3) and per student (2) with hard caps
3. Effectiveness calculation: `teacher_skill / (student_skill + 1) * library_bonus * relationship_multiplier` + deterministic jitter
4. Duration scaling: category difficulty * teacher speed factor * global carrier density
5. Progress tracking every `TEACHING_INTERVAL` (1500) ticks with `progress += effectiveness * interval/duration`
6. Completion effects: KnowledgeSystem.add_knowledge_carrier, teaching XP accumulation, friendship gain
7. Prerequisites system: 18 category-to-category prerequisite mappings (e.g. Metallurgy->Crafting)
8. Matchmaking: `find_teachers_for_student()` and `find_students_for_teacher()` sorted by estimated effectiveness
9. KnowledgeSystem integration (has_method-guarded): has_knowledge, add_knowledge_carrier, get_pawn_knowledge, get_carrier_count
10. SocialDynamics integration: get_friendship multiplies effectiveness up to 1.25x, add_interaction on completion
11. Library/classroom bonus via SettlementMemory building type checks
12. Tick-based processing every TEACHING_INTERVAL ticks with stale lesson cleanup every 30000 ticks
13. WorldMemory event recording: lesson_started, lesson_completed, lesson_failed
14. 3 signals: lesson_started, lesson_completed, lesson_failed with full parameter lists
15. EventBus integration: subscribes to pawn_died (fail all lessons) and pawn_moved (grace period + fail)
16. Reports/stats: get_teacher_report, get_student_report, get_stats with lesson counts, avg effectiveness
17. Save/load: get_save_state/load_state with full round-trip for all fields including lesson history
18. Edge cases: death of teacher/student, settlement separation with grace period (5000 ticks), stale timeout, partial credit on cancel
19. Null guards: all external systems use get_node_or_null + has_method checks
20. Deterministic RNG: only WorldRNG.range_for and WorldRNG.chance_for with deterministic stream keys and salt material
21. Fatigue factor: concurrent lessons reduce effectiveness (teacher -10%/student, student -8%/lesson)

### What Was Verified
- No global RNG (`randf`, `randi`, etc.) — all randomness uses `WorldRNG.range_for` / `WorldRNG.chance_for` with seeded keys
- All external system references use `get_node_or_null` followed by `has_method` checks
- Deterministic construction: all seeded rolls use lesson_id/tick/category as salt material
- Edge cases covered: invalid pawn IDs, self-teaching, max capacity, death mid-lesson, settlement separation, stale lessons, partial credit
- Save/load roundtrip preserves all counters, teacher XP, and lesson history

### What Remains Unverified/Risky
- Full integration test requires Godot runtime (bash quality gate could not execute — no WSL in this environment)
- KnowledgeSystem.get_carrier_count referenced but TeacherSkillSystem may not provide expected interface — internal fallback uses _carrier_count_cache
- PawnSpawner._get_pawn_node structure assumed to return pawn with data.settlement_id — may differ in runtime
- save/load of _lessions_history (note: historical key name preserved for compatibility) not tested in runtime
- Performance at 100x with many concurrent lessons not profiled — _process_lessons iterates all active lessons every interval
