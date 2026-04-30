# PLAYER-READABLE MEANING REFINEMENT PACKET

**Phase:** 4 (Identity & Meaning)  
**Date:** 2026-04-30  
**Status:** SPECIFIED → READY FOR IMPLEMENTATION  
**Priority:** High (bridges simulation state to player experience)

---

## PURPOSE

Translate `WorldMeaning` states (`quiet`/`scarred`/`bloodied`/`grave`) into **non-text-forward sensory cues** that players can perceive without reading chronicles or debug panels. This packet defines:

1. **Audio signatures** per meaning state (ambient beds, event stingers, silence patterns)
2. **Ambiance modifiers** (particle density, color grading, lighting temperature)
3. **Behavior density** (pawn movement speed, gathering patterns, vocalization frequency)
4. **Settlement posture** (building placement logic, memorial structures, activity clustering)

All cues are **deterministic** and derived from `WorldMeaning.get_region_meaning_label(region_key)`.

---

## CANON GUARDS

✅ **Allowed:**
- Cues triggered by `WorldMeaning` state (already deterministic from facts)
- Audio/visual variations using `WorldRNG` with named streams (e.g., `WorldRNG.unit_for("ambient_wind Scarred_Region42")`)
- Behavior tuning via existing pawn state machine thresholds

❌ **Disallowed:**
- Scripted heroic moments or forced narrative beats
- Non-deterministic RNG (no `randf()` / `randi()` without `WorldRNG` wrapper)
- UI text popups explaining the state (show, don't tell)

---

## MEANING STATES AND CUES

### QUIET (0-2 deaths, stable biome)

**Emotional tone:** Calm, potential, unnoticed growth

| Domain | Specification | Implementation Anchor |
|--------|---------------|----------------------|
| **Audio** | - Ambient bed: light wind, distant bird calls (2-3/sec)<br>- No stingers unless events occur<br>- Pawn vocalizations: normal pitch, relaxed cadence | `AudioBusLayout.tbus_set_volume("Quiet_Ambience", 0.8)`<br>`PawnSpawner.vocalize_pitch_range = [0.95, 1.05]` |
| **Ambiance** | - Particle density: low (0.3x default)<br>- Color grade: warm (+5% saturation, +3% brightness)<br>- Lighting: soft shadows, 5500K daylight | `WorldEnvironment.set_particle_density(0.3)`<br>`ColorRect.material.set_shader_param("saturation_boost", 1.05)` |
| **Behavior Density** | - Movement speed: 100% baseline<br>- Gathering clusters: 2-4 pawns, loose formation<br>- Idle animations: stretching, looking at horizon | `Pawn.MOVE_SPEED *= 1.0`<br>`JobManager.max_cluster_size = 4` |
| **Settlement Posture** | - Buildings: spread out, organic placement<br>- Memorials: none (no deaths to commemorate)<br>- Activity zones: mixed, no segregation | `SettlementPlanner.building_spacing = 12-18 tiles` |

---

### SCARRED (3-5 deaths, first conflict/famine memory)

**Emotional tone:** Caution, remembrance, heightened awareness

| Domain | Specification | Implementation Anchor |
|--------|---------------|----------------------|
| **Audio** | - Ambient bed: wind with low drone undertone (-6dB)<br>- Occasional distant thud/stump impact (every 40-60 ticks)<br>- Pawn vocalizations: slightly lower pitch, shorter duration | `AudioStreamPlayer.pitch_scale = WorldRNG.range_for("scarred_vocal_pitch", 0.88, 0.95)`<br>`_play_sfx("res://assets/audio/ambience/scarred_drone.ogg", volume_db=-12)` |
| **Ambiance** | - Particle density: medium (0.6x default)<br>- Color grade: desaturated (-10% saturation, neutral brightness)<br>- Lighting: harder shadows, 6000K cool daylight | `WorldEnvironment.set_particle_density(0.6)`<br>`ColorRect.material.set_shader_param("saturation_boost", 0.9)` |
| **Behavior Density** | - Movement speed: 90% baseline (cautious)<br>- Gathering clusters: 3-5 pawns, tighter formation<br>- Idle animations: looking around, checking surroundings | `Pawn.MOVE_SPEED *= 0.9`<br>`JobManager.max_cluster_size = 5`<br>`Pawn._tick_idle() adds scan_step()` |
| **Settlement Posture** | - Buildings: clustered near resources, defensive spacing<br>- Memorials: simple stone markers at death locations (if `WorldMemory` has KIND_PAWN_DEATH)<br>- Activity zones: work areas closer to stockpiles | `SettlementPlanner.building_spacing = 8-12 tiles`<br>`if WorldMeaning.get_region_meaning_label(rk) == "scarred": spawn_memorial_marker(death_pos)` |

---

### BLOODIED (6-9 deaths, repeated trauma)

**Emotional tone:** Tension, loss, survival focus

| Domain | Specification | Implementation Anchor |
|--------|---------------|----------------------|
| **Audio** | - Ambient bed: wind + low rumble (-3dB), no birds<br>- Random sharp cracks/branches snapping (every 20-30 ticks)<br>- Pawn vocalizations: muted (50% chance to skip), lower pitch | `AudioStreamPlayer.pitch_scale = WorldRNG.range_for("bloodied_vocal_pitch", 0.82, 0.90)`<br>`_play_sfx("res://assets/audio/ambience/bloodied_crack.ogg", volume_db=-8, pitch=WorldRNG.range_for("crack_pitch", 0.9, 1.1))` |
| **Ambiance** | - Particle density: high (0.9x default)<br>- Color grade: cold (-15% saturation, -5% brightness)<br>- Lighting: harsh shadows, 6500K cold daylight | `WorldEnvironment.set_particle_density(0.9)`<br>`ColorRect.material.set_shader_param("saturation_boost", 0.85)`<br>`ColorRect.material.set_shader_param("brightness_boost", 0.95)` |
| **Behavior Density** | - Movement speed: 75% baseline (alert)<br>- Gathering clusters: 4-6 pawns, tight defensive formation<br>- Idle animations: crouching, weapon-checking (if combat unlocked) | `Pawn.MOVE_SPEED *= 0.75`<br>`JobManager.max_cluster_size = 6`<br>`Pawn._tick_idle() adds alert_scan_step(frequency=3)` |
| **Settlement Posture** | - Buildings: fortified, walls/palisades if tech available<br>- Memorials: stacked stone cairns, bone piles at region center<br>- Activity zones: segregated (workers guarded, children near center) | `SettlementPlanner.building_spacing = 6-10 tiles`<br>`SettlementPlanner.defensive_perimeter = true`<br>`spawn_memorial_cairn(region_center)` |

---

### GRAVE (10+ deaths, collapse-level trauma)

**Emotional tone:** Desolation, reverence, ghost-town stillness

| Domain | Specification | Implementation Anchor |
|--------|---------------|----------------------|
| **Audio** | - Ambient bed: near-silence (-18dB), occasional wind howl<br>- No pawn vocalizations (0%)<br>- Single bell toll or deep gong every 100-150 ticks (deterministic from tick count) | `AudioBusLayout.bus_set_volume("Master", -0.3)`<br>`if tick % 120 == 0: _play_sfx("res://assets/audio/ambience/grave_bell.ogg", volume_db=-6)` |
| **Ambiance** | - Particle density: maximum (1.2x default, ash-like)<br>- Color grade: monochrome-leaning (-25% saturation, -10% brightness)<br>- Lighting: very long shadows, 7000K twilight blue | `WorldEnvironment.set_particle_density(1.2)`<br>`ColorRect.material.set_shader_param("saturation_boost", 0.75)`<br>`ColorRect.material.set_shader_param("brightness_boost", 0.9)` |
| **Behavior Density** | - Movement speed: 60% baseline (mournful/exhausted)<br>- Gathering clusters: 1-2 pawns only (isolated)<br>- Idle animations: kneeling, staring at ground, slow head turns | `Pawn.MOVE_SPEED *= 0.6`<br>`JobManager.max_cluster_size = 2`<br>`Pawn._tick_idle() adds mournful_pause(ticks=8-12)` |
| **Settlement Posture** | - Buildings: ruins interspersed with active ones, overgrown paths<br>- Memorials: large grave fields, ritual circles, abandoned structures<br>- Activity zones: minimal, huddled around last safe stockpile | `SettlementPlanner.building_spacing = 4-8 tiles`<br>`SettlementPlanner.allow_ruin_overlap = true`<br>`spawn_grave_field(high_death_locations)` |

---

## TRANSITION RULES

When `WorldMeaning.recompute()` detects a state change:

1. **Crossfade audio** over 30 ticks (3 seconds at 10 ticks/sec)
   ```gdscript
   Tween.create_tween().tween_method(_set_ambient_volume, current_vol, target_vol, 3.0)
   ```

2. **Interpolate color grade** over 60 ticks (6 seconds)
   ```gdscript
   Tween.create_tween().tween_method(_lerp_color_params, start_params, end_params, 6.0)
   ```

3. **Update pawn behavior immediately** (no tween, state is factual)
   ```gdscript
   Pawn.MOVE_SPEED = BASE_SPEED * _get_meaning_speed_multiplier(new_label)
   ```

4. **Trigger settlement restructuring** on next `SettlementPlanner.plan_tick()` (every 200 ticks)
   - New buildings follow new spacing rules
   - Memorials spawned at death locations from `WorldMemory.events`

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Core Systems (This Session)
- [ ] Create `MeaningAmbianceController.gd` autoload (audio/visual interpolation)
- [ ] Add `Pawn._get_meaning_behavior_modifiers()` method
- [ ] Extend `SettlementPlanner` with memorial spawning logic
- [ ] Wire `WorldMeaning.recompute()` to trigger transition events

### Phase 2: Asset Placeholders
- [ ] Create placeholder audio files (silence, drone, bell, crack) in `assets/audio/ambience/`
- [ ] Add shader parameters to `WorldEnvironment.tres` for saturation/brightness control
- [ ] Define particle system presets for density levels

### Phase 3: Validation
- [ ] Observer test: run benchmark with forced death events, verify cues change
- [ ] Canon guard: confirm all RNG uses `WorldRNG` with named streams
- [ ] Player test: incubate 10 minutes, verify state is readable without UI

---

## OBSERVER BENCHMARK HOOK

Add to `tools/Benchmark-Speeds.ps1`:
```powershell
# Force meaning state transitions for testing
if ($args.MeaningTest) {
    Godot --test-meaning-transition --world-seed 20260430
}
```

Exit criteria: benchmark reaches tick 600 with at least one meaning state transition logged to `ChronicleLog`.

---

## RELATED FILES

- `/workspace/autoloads/WorldMeaning.gd` - source of truth for meaning labels
- `/workspace/scripts/pawn/Pawn.gd` - behavior density tuning
- `/workspace/autoloads/SettlementPlanner.gd` - settlement posture logic
- `/workspace/docs/WORLD_BIBLE/GLOSSARY.md` - canon term definitions
- `/workspace/docs/SESSION_LOG.md` - session tracking

---

## NEXT SESSION SUGGESTION

After implementation: move to **Revival storyline constraints** (document canon-safe revival boundaries so rebirth behavior remains emergent but interpretable).
