# HEELKAWN NEURAL NETWORK STATE

This document tracks the current state of the neural network matrix integration for AI handoff.

**Last Updated:** 2026-04-28  
**Neural Network Version:** 2.0  
**Status:** ✅ Fully Integrated

## Current Neural Network Architecture

### Neuron Groups (54 neurons across 6 domains)

**World State Neurons (9)**
- collapse_risk
- trust_level
- authority_stability
- knowledge_retention
- environmental_health
- population_pressure
- technological_progress
- social_complexity
- historical_momentum

**Civilization Neurons (8)**
- civil_authority
- military_authority
- religious_authority
- knowledge_authority
- urbanization_level
- governance_complexity
- law_enforcement
- social_justice

**Cultural Neurons (7)**
- knowledge_scarcity
- teaching_activity
- artistic_expression
- religious_diversity
- cultural_coherence
- myth_formation
- tradition_strength

**Environmental Neurons (6)**
- ruin_density
- resource_depletion
- historical_layering
- climate_stability
- biodiversity
- environmental_health

**Economic Neurons (5)**
- production_efficiency
- economic_stability
- labor_specialization
- wealth_accumulation
- trade_volume

**Religious Neurons (5)**
- religious_fervor
- ritual_complexity
- religious_influence
- sacred_sites
- belief_diversity

### Neural Interconnections

- civ_to_env, civ_to_cult, civ_to_econ
- env_to_cult, cult_to_econ, env_to_econ
- Dynamic weight adaptation
- Emergent pattern detection

## Completed Integrations

### 1. Economic System Integration ✅
- JobManager notifies WorldAI when jobs complete
- Job completions update economic neurons (production_efficiency, economic_stability, labor_specialization)
- High-priority jobs boost economic stability more
- Economic events: economic_boom, market_crash
- SettlementAI handles economic events (expansion/investment, emergency/recovery)

### 2. Religious System Integration ✅
- SettlementAI tracks sacred_sites, ritual_complexity, religious_fervor
- establish_sacred_site() and perform_ritual() functions
- WorldAI updates religious neurons (fervor, complexity, influence, sacred_sites)
- Religious events: religious_schism, religious_conversion
- SettlementAI handles religious events (unity goals, integration goals)

### 3. Collapse System Integration ✅
- CollapseSystem notifies WorldAI when collapse metrics change
- WorldAI updates collapse risk neuron based on trust, authority, knowledge, environment
- Collapse risk = 1.0 - average stability
- predict_collapse_stage() function for collapse stage prediction (0-5)
- get_collapse_stage_name() helper function

### 4. Neural Network Training ✅
- _train_neural_network_from_event() for reinforcement learning
- Trains on: job_completed, collapse_metric_change, sacred_site_established, ritual_performed, knowledge_lost, authority_change, entity_decay, entity_loss
- Positive events reinforce relevant neurons
- Negative events increase scarcity/decay awareness
- Learning rate scales adjustments appropriately

### 5. Neural-Driven Succession Candidates ✅
- rank_succession_candidates() for leadership selection
- Government-specific scoring: MONARCHY, THEOCRACY, TECHNOCRACY, REPUBLIC, TRIBAL
- Adds deterministic tie-break jitter to prevent flat outcomes without global RNG
- Returns sorted candidate IDs from highest to lowest score

### 6. Neural Network Visualization ✅
- AI Control Panel displays neural network state
- Progress bars for: collapse_risk, trust_level, economic_stability, religious_fervor
- Color-coded collapse risk (green/yellow/red)
- Real-time updates with neural network state
- get_neural_network_summary() returns Dictionary of neuron values

### 7. Neural-Driven Diplomatic Relations ✅
- calculate_diplomatic_modifier() for settlement relationships
- Returns modifier from -1.0 (hostile) to 1.0 (friendly)
- Factors: trust, economic stability, religious fervor/diversity, civil authority, teaching activity, collapse risk, military authority
- get_diplomatic_attitude() returns: ALLIED, FRIENDLY, NEUTRAL, CAUTIOUS, HOSTILE, WAR

### 8. Neural-Driven Settlement Goal Priorities ✅
- SettlementAI propose_collective_goal() uses neural network state
- Goal priorities adjusted by neural network state
- Resource conservation priority scales with resource_depletion
- Economic recovery priority scales with economic_stability
- Religious unity priority scales with religious_fervor
- Knowledge preservation priority scales with knowledge_scarcity
- Modifier range: -10 to +30 priority points

## Event-Driven Architecture

### Event Handlers in WorldAI
- on_job_completed() - Economic neuron updates
- on_collapse_metric_change() - Collapse risk neuron updates
- on_sacred_site_established() - Religious neuron updates
- on_ritual_performed() - Religious neuron updates
- on_knowledge_lost() - Cultural neuron updates
- on_authority_change() - Civilization neuron updates
- on_entity_decay() - Environmental neuron updates
- on_entity_loss() - Environmental neuron updates

### Pattern Detection
- _detect_emergent_patterns() - Analyzes neural network activity
- _detect_collapse_warning_patterns()
- _detect_knowledge_crisis_patterns()
- _detect_authority_vacuum_patterns()
- _detect_historical_saturation_patterns()
- _detect_economic_boom_patterns()
- _detect_market_crash_patterns()
- _detect_religious_schism_patterns()
- _detect_religious_conversion_patterns()

### Event Broadcasting
- _broadcast_event_to_settlements() - Dispatches events to settlements
- SettlementAI handles: environmental_degradation, economic_boom, market_crash, religious_schism, religious_conversion

## Save/Load Support

- get_neural_network_summary() - Returns Dictionary of neuron values
- save_neural_network() - Saves neural network state to Dictionary
- load_neural_network() - Loads neural network state from Dictionary
- All neuron groups persisted: world_state, civilization, cultural, environmental, economic, religious

## Known Issues & Resolutions

### Deterministic Neural Initialization (Resolved 2026-04-30)
- `WorldAI`, `AIAgentManager`, `WorldEvolution`, and `ErrorTracker` no longer initialize neural weights/biases from global `randf_range()`.
- Neural/event rolls now use named `WorldRNG` streams so the same world seed and tick history reproduce the same neural state.
- `WorldEvolution` now builds interconnections from local matrix pieces instead of reading `neural_evolution_engine` before initialization completes.

### Compilation Errors (Resolved 2026-04-28)
- Fixed WorldAI duplicate get_neural_network_summary → get_neural_network_summary_string
- Fixed KnowledgeSystem duplicate get_carrier_count → get_total_carrier_count
- Fixed Pawn duplicate record_skill_gain (removed stub)
- Fixed WorldMeaning variable names (meaning_by_region, meaning_by_settlement)
- Fixed AuthoritySystem conflicts dict reference
- Added KnowledgeSystem reference to CollapseSystem
- Fixed ColonyHUD _world_meaning_line indentation

## Future Neural Network Expansions

### High Priority
1. Military Neuron Group (military_strength, combat_experience, tactical_awareness, weapon_quality, morale)
2. Neural-Driven War Declarations
3. Technology Neuron Group (innovation_rate, tech_adoption, research_efficiency, tech_diversity, innovation_stagnation)
4. Neural-Driven Technology Discovery

### Medium Priority
5. Migration Neuron Group (migration_pressure, settlement_capacity, population_growth, migration_success, overcrowding_risk)
6. Neural-Driven Migration & Settlement Founding
7. Weather/Environment Neuron Group (season_severity, climate_stability, disaster_risk, drought_severity, flood_risk)
8. Neural-Driven Weather & Disasters
9. Trade Route Neuron Group (trade_volume, resource_flow, market_integration, trade_risk, economic_interdependence)
10. Neural-Driven Trade Routes & Markets
11. Social Neuron Group (social_cohesion, class_stratification, cultural_diversity, social_mobility, social_tension)
12. Neural-Driven Social Movements & Class Conflict
13. Political Neuron Group (political_stability, faction_power, diplomatic_reputation, government_effectiveness, political_polarization)
14. Neural-Driven Alliances & Treaties

### Low Priority
15. Health Neuron Group (public_health, disease_resistance, life_expectancy, sanitation_level, healthcare_access)
16. Neural-Driven Disease & Healthcare
17. Infrastructure Neuron Group (road_network, irrigation_systems, fortification_level, building_quality, infrastructure_maintenance)
18. Neural-Driven Infrastructure Projects
19. Agriculture Neuron Group (crop_yield, food_security, agricultural_innovation, soil_health, famine_risk)
20. Neural-Driven Farming & Famine

## Key Files

- scripts/ai/WorldAI.gd - Neural network matrix core
- scripts/ai/SettlementAI.gd - Settlement AI with neural integration
- autoloads/JobManager.gd - Economic event notifications
- autoloads/CollapseSystem.gd - Collapse metric notifications
- autoloads/KnowledgeSystem.gd - Knowledge system integration
- autoloads/AuthoritySystem.gd - Authority event notifications
- scripts/ui/AIControlPanel.gd - Neural network visualization

## Design Rules

- No RNG in neural network updates
- Event-driven architecture only
- Deterministic neuron value updates
- Smooth updates via exponential moving averages
- Clamped neuron values (0.0-1.0)
- Pattern emergence threshold configurable
- Learning rate configurable
- All neural changes logged to WorldMemory

## Integration with Existing Systems

- WorldMemory - Records all neural network events
- SettlementMemory - Settlement-specific neural state
- AuthoritySystem - Authority changes update neurons
- CollapseSystem - Collapse metrics update neurons
- JobManager - Job completions update neurons
- KnowledgeSystem - Knowledge events update neurons
- PersistenceSystem - Entity decay/loss updates neurons
- WorldMeaning - Neural state influences meaning computation

---

**For AI Handoff:** Read this file first when working on neural network features, then consult docs/HEELKAWN_STATE.md for overall project state.
