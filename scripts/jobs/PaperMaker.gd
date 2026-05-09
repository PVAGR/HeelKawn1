extends RefCounted

class_name PaperMaker

## NPC job for making paper from plant fibers (STICK proxy).

func perform_work(pawn: HeelKawnian, job: Job) -> bool:
	if pawn.data.carrying != Item.Type.STICK or pawn.data.carried_count < 3:
		# Need materials
		return false

	# Consume 3 sticks, produce 1 paper
	pawn.data.carried_count -= 3
	var paper = Item.new()
	paper.type = Item.Type.PAPER
	# Add to pawn inventory or stockpile
	StockpileManager.add_item_to_nearest(paper, pawn.data.tile_pos)
	WorldMemory.record_event({
		"type": "paper_made",
		"pawn_id": int(pawn.data.id),
		"tile": job.tile,
		"tick": GameManager.tick_count,
	})

	job.complete(pawn)
	return true

func get_work_time() -> int:
	return Job.tool_job_work_ticks(Job.Type.PAPER_MAKING)

func required_tool() -> int:
	return Item.Type.FLINT_KNIFE  # cutting tool
