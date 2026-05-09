extends Node
## Phase 3: Genetic Algorithm for AI Evolution
## Successful AI architectures have higher reproduction rates
## Crossover: combine networks from two parents
## Mutation: random weight changes, structural modifications

## Population of neural networks for evolution
var population: Array = []  # Array of {network, fitness, generation}
var population_size: int = 50
var mutation_rate: float = 0.01
var crossover_rate: float = 0.7
var elite_count: int = 5  # Top N preserved each generation
var current_generation: int = 0

## Fitness tracking
var fitness_history: Array = []
var best_fitness: float = 0.0
var best_network = null

func _ready() -> void:
	_initialize_population()


## Initialize random population
func _initialize_population() -> void:
	population.clear()
	for i in range(population_size):
		var personality: Dictionary = _generate_random_personality()
		var network = _new_network(personality)
		population.append({
			"network": network,
			"fitness": 0.0,
			"generation": 0,
			"personality": personality
		})
	
	current_generation = 0


## Generate random personality for initial population
func _generate_random_personality() -> Dictionary:
	return {
		"openness": WorldRNG.range_for(StringName("gen:openness:%d" % current_generation), 0.0, 1.0),
		"conscientiousness": WorldRNG.range_for(StringName("gen:conscientiousness:%d" % current_generation), 0.0, 1.0),
		"extraversion": WorldRNG.range_for(StringName("gen:extraversion:%d" % current_generation), 0.0, 1.0),
		"agreeableness": WorldRNG.range_for(StringName("gen:agreeableness:%d" % current_generation), 0.0, 1.0),
		"neuroticism": WorldRNG.range_for(StringName("gen:neuroticism:%d" % current_generation), 0.0, 1.0)
	}


## Evaluate fitness of all individuals
func evaluate_fitness(fitness_function: Callable) -> void:
	var total_fitness: float = 0.0
	
	for individual in population:
		var fitness: float = fitness_function.call(individual.network, individual.personality)
		individual.fitness = fitness
		total_fitness += fitness
	
	# Track best
	for individual in population:
		if individual.fitness > best_fitness:
			best_fitness = individual.fitness
			best_network = individual.network
	
	fitness_history.append({
		"generation": current_generation,
		"average_fitness": total_fitness / population.size(),
		"best_fitness": best_fitness
	})


## Evolve to next generation
func evolve() -> void:
	current_generation += 1
	
	# Sort by fitness (descending)
	population.sort_custom(func(a, b): return a.fitness > b.fitness)
	
	# Preserve elite
	var new_population: Array = []
	for i in range(elite_count):
		var elite = population[i].duplicate()
		elite.generation = current_generation
		new_population.append(elite)
	
	# Generate offspring through crossover and mutation
	while new_population.size() < population_size:
		var parent1 = _select_parent()
		var parent2 = _select_parent()
		
		if WorldRNG.range_for(StringName("gen:crossover:%d" % current_generation), 0.0, 1.0) < crossover_rate:
			var child = _crossover(parent1, parent2)
			_mutate(child)
			new_population.append(child)
		else:
			# Clone parent1 with mutation
			var child = parent1.duplicate()
			if parent1.network != null and parent1.network.has_method("duplicate"):
				child.network = parent1.network.duplicate()
			else:
				child.network = _deep_copy_network(parent1.network)
			_mutate(child)
			new_population.append(child)
	
	population = new_population


## Select parent using tournament selection
func _select_parent() -> Dictionary:
	var tournament_size: int = 5
	var best: Dictionary = population[WorldRNG.rangei(0, population.size() - 1)]
	
	for i in range(tournament_size - 1):
		var competitor = population[WorldRNG.rangei(0, population.size() - 1)]
		if competitor.fitness > best.fitness:
			best = competitor
	
	return best


## Crossover two parents to create child
func _crossover(parent1: Dictionary, parent2: Dictionary) -> Dictionary:
	var child_personality: Dictionary = {}
	
	# Blend personalities
	var p1_personality: Dictionary = parent1.get("personality", {})
	var p2_personality: Dictionary = parent2.get("personality", {})
	for trait_key in p1_personality.keys():
		var blend_factor: float = WorldRNG.range_for(StringName("gen:blend:%s:%d" % [trait_key, current_generation]), 0.0, 1.0)
		child_personality[trait_key] = lerp(
			float(p1_personality.get(trait_key, 0.5)),
			float(p2_personality.get(trait_key, 0.5)),
			blend_factor
		)
	
	# Create child network with blended personality
	var child_network = _new_network(child_personality)
	
	# Crossover network weights
	_crossover_weights(child_network, parent1.network, parent2.network)
	
	return {
		"network": child_network,
		"fitness": 0.0,
		"generation": current_generation,
		"personality": child_personality
	}


## Crossover network weights between parents
func _crossover_weights(child, parent1, parent2) -> void:
	# This is a simplified crossover - in practice would need access to internal network structure
	# For now, we'll let the child's random initialization serve as the crossover baseline
	# The personality blending already provides genetic material
	pass


## Mutate an individual
func _mutate(individual: Dictionary) -> void:
	# Mutate personality
	var personality: Dictionary = individual.get("personality", {})
	for trait_key in personality.keys():
		if WorldRNG.range_for(StringName("gen:mut_trait:%s:%d" % [trait_key, current_generation]), 0.0, 1.0) < mutation_rate:
			var mutation: float = WorldRNG.range_for(StringName("gen:mut_val:%s:%d" % [trait_key, current_generation]), -0.1, 0.1)
			personality[trait_key] = clamp(float(personality.get(trait_key, 0.5)) + mutation, 0.0, 1.0)
	individual["personality"] = personality
	
	# Mutate network topology based on success rate
	if individual.network != null:
		var success_rate: float = individual.fitness / max(best_fitness, 1.0)
		individual.network.evolve_topology(success_rate)


## Deep copy network (simplified)
func _deep_copy_network(network):
	var new_network = _new_network({})
	if new_network == null or network == null:
		return new_network
	if network.has_method("to_dict") and new_network.has_method("from_dict"):
		var network_dict: Dictionary = network.to_dict()
		new_network.from_dict(network_dict)
	return new_network


## Get best individual
func get_best_individual() -> Dictionary:
	if population.is_empty():
		return {}
	
	var best: Dictionary = population[0]
	for individual in population:
		if individual.fitness > best.fitness:
			best = individual
	
	return best


## Get average fitness
func get_average_fitness() -> float:
	if population.is_empty():
		return 0.0
	
	var total: float = 0.0
	for individual in population:
		total += individual.fitness
	
	return total / population.size()


## Get fitness statistics
func get_fitness_stats() -> Dictionary:
	if population.is_empty():
		return {}
	
	var fitnesses: Array = []
	for individual in population:
		fitnesses.append(individual.fitness)
	
	fitnesses.sort()
	
	return {
		"generation": current_generation,
		"min": fitnesses[0],
		"max": fitnesses[-1],
		"average": get_average_fitness(),
		"median": fitnesses[fitnesses.size() / 2]
	}


## Inject external network into population
func inject_network(network, personality: Dictionary, fitness: float = 0.0) -> void:
	# Replace worst individual
	if population.size() > 0:
		population.sort_custom(func(a, b): return a.fitness > b.fitness)
		population[-1] = {
			"network": network,
			"fitness": fitness,
			"generation": current_generation,
			"personality": personality
		}


## Reset evolution
func reset() -> void:
	current_generation = 0
	best_fitness = 0.0
	best_network = null
	fitness_history.clear()
	_initialize_population()


## Save evolution state
func to_dict() -> Dictionary:
	var population_data: Array = []
	for individual in population:
		population_data.append({
			"network": _network_to_dict(individual.network),
			"fitness": individual.fitness,
			"generation": individual.generation,
			"personality": individual.personality
		})
	
	return {
		"population": population_data,
		"population_size": population_size,
		"mutation_rate": mutation_rate,
		"crossover_rate": crossover_rate,
		"elite_count": elite_count,
		"current_generation": current_generation,
		"fitness_history": fitness_history,
		"best_fitness": best_fitness
	}


## Load evolution state
func from_dict(data: Dictionary) -> void:
	population_size = data.get("population_size", 50)
	mutation_rate = data.get("mutation_rate", 0.01)
	crossover_rate = data.get("crossover_rate", 0.7)
	elite_count = data.get("elite_count", 5)
	current_generation = data.get("current_generation", 0)
	fitness_history = data.get("fitness_history", [])
	best_fitness = data.get("best_fitness", 0.0)
	
	population.clear()
	var population_data: Array = data.get("population", [])
	for individual_data in population_data:
		var personality: Dictionary = individual_data.get("personality", {})
		var network = _new_network(personality)
		var network_dict: Dictionary = individual_data.get("network", {})
		if network != null and not network_dict.is_empty() and network.has_method("from_dict"):
			network.from_dict(network_dict)
		
		population.append({
			"network": network,
			"fitness": individual_data.get("fitness", 0.0),
			"generation": individual_data.get("generation", 0),
			"personality": personality
		})


func _new_network(personality: Dictionary) -> Variant:
	return HeelKawnianData.create_neural_network(personality)


func _network_to_dict(network: Variant) -> Dictionary:
	if network == null or not network.has_method("to_dict"):
		return {}
	return network.to_dict()
