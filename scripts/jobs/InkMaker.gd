extends RefCounted

class_name InkMaker

## NPC job for making ink from berries + stone (coal).

func perform_work(pawn: HeelKawnian, job: Job) -> bool:
	# Check for berry and stone (coal proxy)
	var berries = pawn.data.carried_count if pawn.data.carrying == Item.Type.BERRY else 0
	var stones = 0  # assume stockpile check
	if berries < 1:
		return false

	# Consume
	# produce ink
	var ink = Item.new()
	ink.type = Item.Type.INK
	StockpileManager.add_item_to_nearest(ink, pawn.data.tile_pos)
	WorldMemory.record_event({
		"type": "ink_made",
		"pawn_id": int(pawn.data.id),
		"tile": job.tile,
		"tick": GameManager.tick_count,
	})

	job.complete(pawn)
	return true

func get_work_time() -> int:
	return Job.tool_job_work_ticks(Job.Type.INK_MAKING)

func required_tool() -> int:
	return Item.Type.FLINT_KNIFE
