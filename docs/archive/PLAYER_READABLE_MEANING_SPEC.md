# Player-Readable Meaning Refinement Specification

**Phase 4 - Identity & Meaning**
**Date:** 2026-04-30
**Purpose:** Define non-text-forward cues for settlement state transitions without text overlays

## Design Principles

1. **Deterministic from Facts:** All cues derive from WorldMemory, WorldMeaning, and SettlementMemory
2. **No RNG:** Cues are deterministic based on state transitions
3. **Subtle Over Time:** Changes accumulate gradually, not instant flips
4. **No Text Overlays:** Visual/audio/behavioral cues only
5. **Performance-Conscious:** Lightweight per-tick checks, cached where possible

## Meaning Labels (from WorldMeaning)

- **quiet:** 0 deaths (peaceful, stable)
- **scarred:** 1-2 deaths (early trauma, recovering)
- **bloodied:** 3-5 deaths (conflict, violence)
- **grave:** 6+ deaths (catastrophe, mass death)

## Settlement States (from SettlementMemory)

- **active:** Thriving settlement
- **revivable:** Can be revived (moderate scar, quiet period)
- **recovering:** Post-abandonment healing
- **abandoned:** Recently abandoned
- **permanently_abandoned:** Scar level >= 3, recent conflict, or non-revivable

## Cue Specifications

### 1. Audio Cues (Procedural, No External Assets)

**Implementation:** Use `AudioStreamGenerator` for procedural tones (same system as inspect tooltip)

| Transition | Audio Cue | Characteristics |
|------------|-----------|----------------|
| quiet → scarred | Low hum (100-150Hz) | Soft, sustained, volume 0.15 |
| scarred → bloodied | Dissonant chord (200-300Hz) | Two frequencies, volume 0.25 |
| bloodied → grave | Descending tone (400-100Hz) | 1.5s decay, volume 0.3 |
| grave → recovering | Rising arpeggio (150-250Hz) | 3 notes, volume 0.2 |
| recovering → quiet | Clear chime (600Hz) | Short, bright, volume 0.15 |

**Trigger:** On settlement state change (detected via SettlementMemory hysteresis)
**Cooldown:** 30 seconds between same-settlement audio cues to prevent spam

### 2. Ambiance Changes (Lighting & Color Grading)

**Implementation:** Modify `WorldEnvironment` or overlay `ColorRect` with tweened transitions

| Meaning Label | Ambient Color | Saturation | Brightness |
|---------------|--------------|------------|------------|
| quiet | Warm amber (1.0, 0.95, 0.85) | 1.0 | 1.0 |
| scarred | Muted gray-blue (0.85, 0.9, 0.95) | 0.7 | 0.9 |
| bloodied | Desaturated red tint (0.95, 0.85, 0.85) | 0.5 | 0.85 |
| grave | Cold blue-gray (0.8, 0.85, 0.9) | 0.4 | 0.8 |

**Transition:** 5-second linear tween on meaning label change
**Scope:** Global ambient (applies to entire world view)
**Cache:** Last meaning label per region to avoid redundant tweens

### 3. Behavior Density Changes

**Implementation:** Modify pawn movement speed and clustering patterns based on region meaning

| Meaning Label | Pawn Speed Multiplier | Clustering Radius | Wander Bias |
|---------------|----------------------|-------------------|-------------|
| quiet | 1.0 (normal) | 128px (normal) | 0.5 (balanced) |
| scarred | 0.9 (cautious) | 96px (tighter) | 0.3 (near structures) |
| bloodied | 0.8 (nervous) | 64px (very tight) | 0.2 (huddle) |
| grave | 0.7 (fearful) | 48px (extreme huddle) | 0.1 (minimal) |

**Application:** Per-region via `Pawn._process_tick` reading WorldMeaning
**Determinism:** Speed/clustering derived from meaning_label only
**Performance:** Cache meaning_label per pawn, refresh every 100 ticks

### 4. Settlement Posture Visual Indicators

**Implementation:** Modify wall/door/bed colors and patterns via `TileFeature.apply_culture_tint_to_built_color`

| Settlement State | Wall Pattern | Wall Color | Door Color | Bed Color |
|------------------|--------------|------------|------------|-----------|
| active | Solid | Warm brown | Dark brown | Muted tan |
| revivable | Slightly worn | Faded brown | Weathered | Pale tan |
| recovering | Cracked pattern | Gray-brown | Rust | Light gray |
| abandoned | Broken pattern | Desaturated | Dark gray | Ash |
| permanently_abandoned | Ruined pattern | Cold gray | Black | Charcoal |

**Transition:** Immediate on state change (no tween for structures)
**Scope:** Per-settlement zone only
**Cache:** Last state per settlement_id in SettlementMemory

## Implementation Order

1. **Phase 1: Audio Cues**
   - Add `MeaningAudioCue` autoload (procedural tone generator)
   - Hook into SettlementMemory state change detection
   - Implement cooldown per settlement

2. **Phase 2: Ambiance**
   - Add `MeaningAmbianceController` autoload
   - Hook into WorldMeaning recompute
   - Implement ambient color tweening

3. **Phase 3: Behavior Density**
   - Extend `Pawn._process_tick` to read region meaning
   - Apply speed/clustering modifiers
   - Add meaning_label cache per pawn

4. **Phase 4: Settlement Posture**
   - Extend `TileFeature.apply_culture_tint_to_built_color`
   - Add state-based color mapping
   - Hook into SettlementMemory state changes

## Validation Criteria

- No RNG in any cue generation
- All cues derive from existing facts (WorldMemory, WorldMeaning, SettlementMemory)
- Performance impact < 1ms per tick at 100x speed
- Deterministic: same seed produces same cues
- No text overlays added
- Existing UI unchanged

## Risks & Mitigations

- **Risk:** Audio cue spam on rapid state changes
  - **Mitigation:** 30-second cooldown per settlement

- **Risk:** Ambient tween conflicts with other systems
  - **Mitigation:** Single authoritative ambiance controller, check for existing tweens

- **Risk:** Behavior density changes affect gameplay balance
  - **Mitigation:** Modifiers are subtle (0.7-1.0 range), preserve simulation outcomes

- **Risk:** Visual color changes conflict with culture tinting
  - **Mitigation:** Apply meaning tint after culture tint, use additive blending
