extends SceneTree

## Diagnostic: measure ticks-per-frame and batch cost at 200x to resolve the avg_tick mystery.

const BOOT_WAIT: int = 30
const MEASURE_TICKS: int = 2000
const SPEED_IDX: int = 5
const PAUSED_FRAMES: int = 200
const RESUME_FRAMES: int = 200
const SEGMENT_FRAMES: int = 60
var SEGMENTS: Array = ["WorldViewport", "UI_Viewport", "CreatorDebugMenu", "DayNight", "-MAIN-"]

var _spawned: bool = false
var _boot_wait: int = -1
var _last_tick: int = -1
var _measure_start_tick: int = -1
var _sample_count: int = 0
var _ticks_per_frame: Array[int] = []
var _batch_usec_samples: Array[int] = []
var _phase: String = "boot"
var _paused_frame_times: Array[int] = []
var _resume_frame_times: Array[int] = []
var _last_frame_time: int = -1
var _ablate_ui: bool = false
var _ablate_main_process: bool = false
var _ablate_children: Array = []
var _ablate_visible: String = ""
var _ablate_self: String = ""
var _saved_process_mode: int = -1
var _segments: bool = false
var _segment_idx: int = -1
var _segment_times: Array[int] = []
var _segment_phase: bool = false

func _process(_delta: float) -> bool:
	if not _spawned:
		for a in OS.get_cmdline_user_args():
			if a == "--ablate-ui":
				_ablate_ui = true
			if a == "--ablate-main-process":
				_ablate_main_process = true
			if a.begins_with("--ablate-children="):
				_ablate_children = (a.get_slice("=", 1) as String).split(",", false)
			if a.begins_with("--ablate-visible="):
				_ablate_visible = (a.get_slice("=", 1) as String)
			if a.begins_with("--ablate-self="):
				_ablate_self = (a.get_slice("=", 1) as String)
			if a == "--segments":
				_segments = true
				_ablate_main_process = true
			if a.begins_with("--segments-list="):
				SEGMENTS = (a.get_slice("=", 1) as String).split(",", false)
				_segments = true
				_ablate_main_process = true
		_spawned = true
		var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
		if packed == null:
			print("[FP] FAIL reason=Main_load_failed")
			quit(1)
			return false
		root.add_child(packed.instantiate())
		# Sync BOTH managers like real UI
		var gm = root.get_node_or_null("GameManager")
		var tm = root.get_node_or_null("TickManager")
		if gm != null and gm.has_method("set_speed_index"):
			gm.call("set_speed_index", SPEED_IDX)
		if tm != null and tm.has_method("set_speed_index"):
			tm.call("set_speed_index", SPEED_IDX)
		if tm != null and tm.has_method("resume"):
			tm.call("resume")
		if gm != null and gm.has_method("resume"):
			gm.call("resume")
		if tm != null:
			tm.set("_split_mode", true)
		_boot_wait = BOOT_WAIT
		return false

	if _boot_wait > 0:
		_boot_wait -= 1
		if _boot_wait == 0:
			_phase = "paused"
			var tm = root.get_node_or_null("TickManager")
			if tm != null and tm.has_method("pause"):
				tm.call("pause")
			print("[FP] PHASE paused (200x, no ticks)")
		return false

	var now: int = Time.get_ticks_usec()
	if _last_frame_time > 0:
		var fdt: int = now - _last_frame_time
		match _phase:
			"paused":
				_paused_frame_times.append(fdt)
				if _paused_frame_times.size() >= PAUSED_FRAMES:
					_print_frame_stats("PAUSED", _paused_frame_times)
					if _ablate_ui:
						var ui: Node = root.get_node_or_null("Main/UI_Viewport")
						if ui != null:
							ui.visible = false
							print("[FP] ABLATE: UI_Viewport hidden")
						var dbg: Node = root.get_node_or_null("Main/CreatorDebugMenu")
						if dbg != null:
							dbg.visible = false
					if _ablate_main_process:
						var main_node: Node = root.get_node_or_null("Main")
						if main_node != null:
							_saved_process_mode = main_node.process_mode
							main_node.process_mode = Node.PROCESS_MODE_DISABLED
							print("[FP] ABLATE: Main subtree process_mode=DISABLED (ticks still driven by autoloads)")
					elif not _ablate_self.is_empty():
						var self_node: Node = root.get_node_or_null("Main/" + _ablate_self) if _ablate_self.find("Main") == -1 else root.get_node_or_null(_ablate_self)
						if self_node != null:
							self_node.set_process(false)
							if self_node.has_method("set_physics_process"):
								self_node.set_physics_process(false)
							print("[FP] ABLATE: %s set_process(false) (children unaffected)" % str(self_node.get_path()))
						else:
							print("[FP] ABLATE: %s NOT FOUND" % _ablate_self)
					elif not _ablate_visible.is_empty():
						var vis_main: Node = root.get_node_or_null("Main")
						if vis_main != null:
							var vis_node2: Node = vis_main.get_node_or_null(_ablate_visible)
							if vis_node2 != null:
								vis_node2.visible = false
								print("[FP] ABLATE: Main/%s visible=false" % _ablate_visible)
							else:
								print("[FP] ABLATE: Main/%s NOT FOUND" % _ablate_visible)
					elif not _ablate_children.is_empty():
						var main_child: Node = root.get_node_or_null("Main")
						if main_child != null:
							for cn in _ablate_children:
								var child: Node = main_child.get_node_or_null(cn)
								if child != null:
									child.process_mode = Node.PROCESS_MODE_DISABLED
									print("[FP] ABLATE: Main/%s process_mode=DISABLED" % cn)
								else:
									print("[FP] ABLATE: Main/%s NOT FOUND" % cn)
					var tm2 = root.get_node_or_null("TickManager")
					if tm2 != null and tm2.has_method("resume"):
						tm2.call("resume")
					_phase = "resume"
					_last_frame_time = now
					return false
			"resume":
				_resume_frame_times.append(fdt)
				if _resume_frame_times.size() >= RESUME_FRAMES:
					_print_frame_stats("RESUME_200x", _resume_frame_times)
					if _segments:
						_phase = "segments"
						_setup_segment(0)
						print("[FP] SEGMENT %s" % SEGMENTS[0])
					else:
						_phase = "measure"
						_measure_start_tick = -1
						_last_tick = -1
						_sample_count = 0
						print("[FP] PHASE measure (200x, %d ticks)" % MEASURE_TICKS)
					_last_frame_time = now
					return false
			"segments":
				if _segment_phase:
					_segment_times.append(fdt)
					if _segment_times.size() >= SEGMENT_FRAMES:
						_print_frame_stats("SEG %s" % SEGMENTS[_segment_idx], _segment_times)
						var next_i: int = _segment_idx + 1
						if next_i >= SEGMENTS.size():
							_phase = "measure"
							_measure_start_tick = -1
							_last_tick = -1
							_sample_count = 0
							print("[FP] PHASE measure (200x, %d ticks)" % MEASURE_TICKS)
						else:
							_setup_segment(next_i)
							print("[FP] SEGMENT %s" % SEGMENTS[next_i])
						_last_frame_time = now
						return false
				else:
					_segment_phase = true
					_segment_times.clear()
					_last_frame_time = now
					return false
	_last_frame_time = now

	var gm = root.get_node_or_null("GameManager")
	var tm = root.get_node_or_null("TickManager")
	if gm == null or tm == null:
		return false

	var cur_tick: int = int(gm.get("tick_count"))
	if _phase != "measure":
		return false
	if _measure_start_tick < 0:
		_measure_start_tick = cur_tick

	var batch_usec: int = int(tm.get("_last_tick_usec")) if tm.get("_last_tick_usec") != null else 0

	if cur_tick - _measure_start_tick >= MEASURE_TICKS:
		# Done measuring
		var accum: Dictionary = gm.get("_gt_profile_accum") if gm.has_method("get") else null
		print("[FP] ticks=%d samples=%d ticks/frame_avg=%.2f" % [
			MEASURE_TICKS, _sample_count,
			float(MEASURE_TICKS) / float(max(_sample_count, 1))
		])
		if not _batch_usec_samples.is_empty():
			var sum: int = 0; var max_b: int = 0
			for v in _batch_usec_samples:
				sum += v
				if v > max_b: max_b = v
			print("[FP] batch_usec: avg=%.1f max=%d count=%d" % [float(sum)/float(_batch_usec_samples.size()), max_b, _batch_usec_samples.size()])
		# Print full gt accum (sorted)
		if accum != null and not accum.is_empty():
			var entries: Array = []
			var tot: int = 0
			for pl in accum:
				var u: int = int(accum[pl])
				entries.append({"label": str(pl), "usec": u})
				tot += u
			entries.sort_custom(func(a, b): return int(a["usec"]) > int(b["usec"]))
			print("[FP] game_tick total=%.1fms over %d ticks (accum window)" % [float(tot)/1000.0, MEASURE_TICKS])
			for e in entries.slice(0, 15):
				print("[FP]  %-70s %9.2fms" % [str(e["label"]), float(e["usec"])/1000.0])
		quit(0)
		return true

	if cur_tick != _last_tick:
		var dt: int = cur_tick - _last_tick
		_ticks_per_frame.append(dt)
		_batch_usec_samples.append(batch_usec)
		_last_tick = cur_tick
		_sample_count += 1

	return false

func _print_frame_stats(label: String, times: Array) -> void:
	if times.is_empty():
		print("[FP] %s: no samples" % label)
		return
	var sum: int = 0
	var maxv: int = 0
	var over16: int = 0
	for v in times:
		sum += v
		if v > maxv:
			maxv = v
		if v > 16000:
			over16 += 1
	var avg: float = float(sum) / float(times.size())
	print("[FP] %s: frames=%d avg_frame=%.2fms max_frame=%.2fms over16ms=%d" % [label, times.size(), avg / 1000.0, float(maxv) / 1000.0, over16])


func _setup_segment(idx: int) -> void:
	_segment_idx = idx
	_segment_phase = false
	_segment_times.clear()
	var main_node: Node = root.get_node_or_null("Main")
	if main_node == null:
		return
	main_node.process_mode = Node.PROCESS_MODE_INHERIT
	var target: String = SEGMENTS[idx]
	var direct: Array = ["WorldViewport", "UI_Viewport", "CreatorDebugMenu", "DayNight"]
	var target_direct: String = target.split("/")[0]
	if target_direct == "-WV-EXPLICIT-":
		target_direct = "WorldViewport"
	for cn in direct:
		var child: Node = main_node.get_node_or_null(cn)
		if child == null:
			continue
		child.process_mode = Node.PROCESS_MODE_INHERIT if cn == target_direct else Node.PROCESS_MODE_DISABLED
	if target.begins_with("WorldViewport/") or target == "-WV-EXPLICIT-":
		var wv: Node = main_node.get_node_or_null("WorldViewport")
		if wv != null:
			if target == "-WV-EXPLICIT-":
				for cc in wv.get_children():
					cc.process_mode = Node.PROCESS_MODE_INHERIT
			else:
				var enabled_names: Array = []
				for tok in target.get_slice("/", 1).split("+", false):
					enabled_names.append(tok)
				for cc in wv.get_children():
					cc.process_mode = Node.PROCESS_MODE_INHERIT if enabled_names.has(str(cc.name)) else Node.PROCESS_MODE_DISABLED
	elif target == "-WORLDVIEWPORT-MAIN-":
		var wv2: Node = main_node.get_node_or_null("WorldViewport")
		if wv2 != null:
			for cc in wv2.get_children():
				cc.process_mode = Node.PROCESS_MODE_DISABLED
