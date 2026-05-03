extends RefCounted

class_name ToolMaker

## NPC job for crafting pens from stick + wood + meat (leather strip).

func perform_work(pawn: Pawn, job: Job) -> bool:
	# Check materials in inventory or stockpile
	if pawn.data.carried_count < 3:  # stick, wood, meat
		return false

	# Consume
	var pen = Item.new()
	pen.type = Item.Type.PEN
	StockpileManager.add_item_to_nearest(pen, pawn.data.tile_pos)
	WorldMemory.record_event({
		"type": "pen_crafted",
		"pawn_id": int(pawn.data.id),
		"tile": job.tile,
		"tick": GameManager.tick_count,
	})

	job.complete(pawn)
	return true

func get_work_time() -> int:
	return Job.tool_job_work_ticks(Job.Type.TOOL_MAKING)

func required_tool() -> int:
	return Item.Type.FLINT_KNIFE  # carving tool
