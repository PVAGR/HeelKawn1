extends RefCounted

class_name LeatherWorker

## NPC job for tanning leather from hides (MEAT proxy).

func perform_work(pawn: Pawn, job: Job) -> bool:
	if pawn.data.carrying != Item.Type.MEAT or pawn.data.carried_count < 2:
		return false

	# Consume 2 meat (hides), produce 1 leather
	pawn.data.carried_count -= 2
	var leather = Item.new()
	leather.type = Item.Type.LEATHER
	StockpileManager.add_item_to_nearest(leather, pawn.data.tile_pos)
	WorldMemory.record_event({
		"type": "leather_tanned",
		"pawn_id": int(pawn.data.id),
		"tile": job.tile,
		"tick": GameManager.tick_count,
	})

	job.complete(pawn)
	return true

func get_work_time() -> int:
	return Job.tool_job_work_ticks(Job.Type.LEATHER_MAKING)

func required_tool() -> int:
	return Item.Type.FLINT_KNIFE  # tanning knife
