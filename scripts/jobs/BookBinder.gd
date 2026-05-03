extends RefCounted

class_name BookBinder

## NPC job for binding books from paper + leather + ink.

func perform_work(pawn: Pawn, job: Job) -> bool:
	# Check for 5 paper, 2 leather, 1 ink
	# Consume from stockpile or carried
	var book = BookItem.new("")  # empty content
	StockpileManager.add_item_to_nearest(book, pawn.data.tile_pos)
	WorldMemory.record_event({
		"type": "book_bound",
		"pawn_id": int(pawn.data.id),
		"tile": job.tile,
		"tick": GameManager.tick_count,
	})

	job.complete(pawn)
	return true

func get_work_time() -> int:
	return Job.tool_job_work_ticks(Job.Type.BOOK_BINDING)

func required_tool() -> int:
	return Item.Type.PEN  # binding needs precision
