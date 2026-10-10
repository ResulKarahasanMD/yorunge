class_name LoadProbe
extends Node
## Level-load hitch probe: loads the end-to-end plan's levels back to back
## through GameMain (3 tutorials, then endless depth 1..N from a seed) with no
## menus and no waiting for completion, and logs for each load the phases
## (GameMain.load_profile), the time to free the previous level, and the first
## frames with their render CPU time (c, reported a frame late), the props
## built in that frame (d, decorations follow the load frame) and pipeline
## compilations.
## Windowed (real renderer):
##   Godot --path . --resolution 1280x720 res://debug/load_probe.tscn [-- --probe-frames=N --probe-endless=N --probe-seed=S]

const LOG_TAG := "LoadProbe"
const MAIN_SCENE := preload("res://main/main.tscn")
const FRAMES_PREFIX := "--probe-frames="
const ENDLESS_PREFIX := "--probe-endless="
const SEED_PREFIX := "--probe-seed="
const USEC_PER_MSEC := 1000.0
## Frames between loads, so one load's tail never lands in the next record.
const SETTLE_FRAMES := 20
const PIPELINE_MONITORS: Array[Performance.Monitor] = [
	Performance.PIPELINE_COMPILATIONS_CANVAS,
	Performance.PIPELINE_COMPILATIONS_MESH,
	Performance.PIPELINE_COMPILATIONS_SURFACE,
	Performance.PIPELINE_COMPILATIONS_DRAW,
	Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
]

@export var frames_per_load: int = 8
@export var endless_levels: int = 5
@export var endless_seed: int = 2026

var main: GameMain = null
var rows: Array[Dictionary] = []

var _loads_done: int = 0
var _recording: Array[Dictionary] = []
var _settle: int = SETTLE_FRAMES
var _last_usec: int = 0
var _pipeline_last: PackedInt64Array = PackedInt64Array()
var _decorate_last: int = 0
var _row: Dictionary = {}


func _ready() -> void:
	frames_per_load = int(DemoMode.option(FRAMES_PREFIX, str(frames_per_load)))
	endless_levels = int(DemoMode.option(ENDLESS_PREFIX, str(endless_levels)))
	endless_seed = int(DemoMode.option(SEED_PREFIX, str(endless_seed)))
	# Demo mode: the DemoBot drives (no mouse capture); its menu autopilot and
	# report are removed so only this probe acts.
	DemoMode.forced = true
	main = MAIN_SCENE.instantiate() as GameMain
	add_child(main)
	for helper: Node in [main.autopilot, main.report]:
		if helper != null:
			helper.free()
	main.autopilot = null
	main.report = null
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last_usec = Time.get_ticks_usec()
	_pipeline_last = _pipeline_counts()
	GameLog.info(LOG_TAG, "plan: 3 tutorials + %d endless from seed %d, %d frames each" % [endless_levels, endless_seed, frames_per_load])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := float(now - _last_usec) / USEC_PER_MSEC
	_last_usec = now
	var compiled := _pipeline_deltas()
	var decorated_ms := float(SurfaceDecorator.build_usec_total - _decorate_last) / USEC_PER_MSEC
	_decorate_last = SurfaceDecorator.build_usec_total
	if not _row.is_empty():
		var viewport := get_viewport().get_viewport_rid()
		_row["frames"].append({
			"ms": snappedf(frame_ms, 0.01),
			"render_cpu_ms": snappedf(RenderingServer.viewport_get_measured_render_time_cpu(viewport), 0.01),
			"render_gpu_ms": snappedf(RenderingServer.viewport_get_measured_render_time_gpu(viewport), 0.01),
			"decorate_ms": snappedf(decorated_ms, 0.01),
			"pipelines": compiled,
		})
		if (_row["frames"] as Array).size() >= frames_per_load:
			rows.append(_row)
			_log_row(_row)
			_row = {}
			_settle = SETTLE_FRAMES
		return
	if _settle > 0:
		_settle -= 1
		return
	if _loads_done >= GameStateManager.TUTORIAL_LEVELS.size() + endless_levels:
		_finish()
		return
	_load_next()


func _load_next() -> void:
	var previous := main.level
	if _loads_done < GameStateManager.TUTORIAL_LEVELS.size():
		main.start_tutorial(_loads_done)
	elif _loads_done == GameStateManager.TUTORIAL_LEVELS.size():
		main.start_endless(endless_seed)
	else:
		main.next_level()
	_loads_done += 1
	# GameMain queues the old level for deletion; free it here to time it
	# (the queued delete then finds nothing).
	var free_ms := 0.0
	if previous != null and is_instance_valid(previous):
		var started := Time.get_ticks_usec()
		previous.free()
		free_ms = float(Time.get_ticks_usec() - started) / USEC_PER_MSEC
	_row = main.load_profile.duplicate()
	_row["level_id"] = main.level.level_id
	_row["free_previous_ms"] = snappedf(free_ms, 0.01)
	_row["frames"] = []


func _log_row(row: Dictionary) -> void:
	var frames := PackedStringArray()
	var compiled := PackedInt64Array()
	compiled.resize(PIPELINE_MONITORS.size())
	for frame: Dictionary in row["frames"]:
		frames.append("%.1f(c%.1f d%.1f)" % [frame["ms"], frame["render_cpu_ms"], frame["decorate_ms"]])
		var deltas: PackedInt64Array = frame["pipelines"]
		for i in deltas.size():
			compiled[i] += deltas[i]
	GameLog.info(LOG_TAG, "%s: build %.2f, enter %.2f (decorate %.2f), total %.2f, free previous %.2f ms; frames %s; pipelines %s" % [
		row["level_id"], row.get("build_ms", 0.0), row.get("enter_ms", 0.0), row.get("decorate_ms", 0.0),
		row.get("total_ms", 0.0), row["free_previous_ms"], " ".join(frames), compiled])


func _finish() -> void:
	set_process(false)
	GameLog.info(LOG_TAG, "done: %d loads" % rows.size())
	main.quit_game()


static func _pipeline_counts() -> PackedInt64Array:
	var counts := PackedInt64Array()
	for monitor: Performance.Monitor in PIPELINE_MONITORS:
		counts.append(int(Performance.get_monitor(monitor)))
	return counts


func _pipeline_deltas() -> PackedInt64Array:
	var counts := _pipeline_counts()
	var deltas := PackedInt64Array()
	for i in counts.size():
		deltas.append(counts[i] - _pipeline_last[i])
	_pipeline_last = counts
	return deltas
