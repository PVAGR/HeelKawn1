# HeelKawn v1 Upgrade Pass (2026-05-15)

This pass focuses on mobile playability, frame stability, AI completion work, and systemic polish.

## Completed Upgrades (60)

1. Added mobile runtime detection helper to active pawn runtime (`_is_mobile_runtime`).
2. Added mobile visual interval bonus constant for pawn rendering throttling.
3. Added mobile redraw interval bonus constant for pawn draw-call reduction.
4. Raised base nearby-scan lane interval to reduce per-tick scan pressure.
5. Raised base social lane interval to reduce social CPU spikes.
6. Raised base narrative lane interval to reduce non-critical AI overhead.
7. Added challenge range constant for leadership duels.
8. Added challenge scan radius constant for local authority contention.
9. Added challenge influence-delta gate to avoid spam challenges.
10. Added challenge base duration constant.
11. Added challenge cooldown constant.
12. Added crafting base duration constant for direct craft state.
13. Added crafting cooldown constant.
14. Added explicit challenge cooldown runtime state.
15. Added direct crafting runtime job id tracking.
16. Added direct crafting runtime time-left tracking.
17. Added direct crafting output-item tracking for equip fallback.
18. Added direct crafting cooldown runtime state.
19. Added mobile-aware visual interval clamping for path interpolation updates.
20. Added mobile-aware redraw threshold clamping for pawn `_draw`.
21. Added path-complete handlers for `FLEEING` state.
22. Added path-complete handlers for `HIDING` state.
23. Added tick-state dispatch for `CRAFTING`.
24. Added tick-state dispatch for `GATHERING`.
25. Added tick-state dispatch for `FLEEING`.
26. Added tick-state dispatch for `HIDING`.
27. Hardened challenge resolution to avoid calling missing `FactionManager.resolve_conflict`.
28. Implemented fallback leadership resolution when faction resolver is unavailable.
29. Added leadership challenge event logging to `WorldMemory`.
30. Added challenge finish cooldown guard.
31. Implemented real `_maybe_start_challenge()` target selection and activation logic.
32. Added challenge candidate filtering by path component.
33. Added challenge candidate scoring by influence + grudge + rapport + distance.
34. Added challenge cooldown scheduling on challenge miss/failure.
35. Implemented `challenge_for_leadership(target)` public API behavior.
36. Implemented `craft_simple_tool(tool_type)` with CraftingSystem recipe lookup.
37. Added CraftingSystem `can_craft_recipe` gating in direct craft flow.
38. Added CraftingSystem `start_crafting` integration in direct craft flow.
39. Added direct craft consciousness event recording.
40. Implemented `_tick_crafting()` to track active CraftingSystem jobs.
41. Added post-craft auto-equip fallback when pawn has no valid equipped tool.
42. Added post-craft mood bump and consciousness completion event.
43. Added mobile stride optimization for direct material gather tile scans.
44. Added urgency override for gather scan stride (emergency still scans densely).
45. Added mobile stride optimization for water search in thirst behavior.
46. Added emergency override for water search stride when thirst is critical.
47. Added health-based body tint feedback in pawn rendering.
48. Added thirst-emergency body tint feedback in pawn rendering.
49. Enabled procedural pixel pawn overlay inside active `_draw` path.
50. Added mobile lane-interval multiplier in `_lane_interval_for_speed`.
51. Increased tap-threshold support on touch devices in `Main`.
52. Added `_touch_tap_threshold_px()` dynamic helper in `Main`.
53. Added mobile social pair-budget scaling in `Main._accumulate_social_rapport`.
54. Added mobile WorldMemory social event budget scaling.
55. Added mobile consciousness social event budget scaling.
56. Added mobile crowded-cell processing cap scaling.
57. Added mobile nearby-neighbor cap scaling in social grid pass.
58. Reduced mobile starter pawn count in `PawnSpawner` for better FPS.
59. Added low-resolution mobile starter-count fallback.
60. Reduced mobile spawn spacing (less travel lag, tighter early colony loops).

## Additional Runtime Caps (Applied in this pass)

- AnimalSpawner now uses mobile-specific initial wildlife counts and max population caps.
- EnemySpawner now uses mobile-specific raid size and max enemy caps.
- TickManager now caps mobile speed to 26x to avoid thermal/frame collapse from 50x/100x bursts.
- Mobile controls now expose 26x as the top practical fast-forward button.
- Mobile settings bootstrap now applies a one-time low-latency preset (`MOBILE_PROFILE_VERSION=1`).

