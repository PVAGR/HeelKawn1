extends Resource
class_name TraitData

@export_var var id: String = ""
@export_var var name: String = ""
@export_var var tier: String = "Minor"
@export_var var krond_cost: float = 0.0
@export_var var effects: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"tier": tier,
		"krond_cost": krond_cost,
		"effects": effects.duplicate(true)
	}

static func new_from_dict(d: Dictionary) -> TraitData:
	var t: TraitData = TraitData.new()
	if d.has("id"):
		t.id = str(d.get("id"))
	if d.has("name"):
		t.name = str(d.get("name"))
	if d.has("tier"):
		t.tier = str(d.get("tier"))
	if d.has("krond_cost"):
		t.krond_cost = float(d.get("krond_cost"))
	if d.has("effects") and d.get("effects") is Dictionary:
		t.effects = (d.get("effects") as Dictionary).duplicate(true)
	return t
