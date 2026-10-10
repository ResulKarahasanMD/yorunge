class_name DemoReport
extends Node
## End-to-end self-test recorder (demo mode only). For every level played it
## keeps real-time frame statistics measured in-game (independent of any
## external profiler), errors and warnings caught through an OS logger, the
## LevelStats, DemoBot counters and one screenshot; at the end it prints a
## table and writes demo_report.json next to the screenshots.
## Hitch hunting: the load phases (GameMain.load_profile), the first frames,
## pipeline compilations per frame (load / play), every hitch frame with its
## compilations and window focus, and slow (< 40 FPS) periods with focus.

const LOG_TAG := "Report"
const REPORT_DIR_PREFIX := "--report-dir="
const SCREENSHOT_AFTER := 6.0
const USEC_PER_SECOND := 1000000.0
const MSEC_PER_SECOND := 1000.0
const LOW_PERCENTILE := 0.99
const MAX_MESSAGES := 30
## Frames right after a level appears (scene setup, first-use pipelines) are
## reported as load_hitch_ms instead of gameplay frames.
const LOAD_FRAMES := 5
## Frames after a screenshot (GPU readback) are reported as screenshot_ms.
const SCREENSHOT_FRAMES := 3
## A gameplay frame at least this long is a hitch: kept with the pipeline
## compilations and the window state of that frame.
const HITCH_MS := 50.0
## Frames slower than this (under 40 FPS) count as slow; runs of them below
## HITCH_MS form slow periods.
const SLOW_FRAME_MS := 25.0
## Slow frames closer together than this belong to the same slow period.
const SLOW_GAP_S := 0.25
## Slow periods shorter than this are not listed.
const SLOW_PERIOD_MIN_S := 0.5
const MAX_HITCHES := 12
const MAX_SLOW_PERIODS := 12
## Cumulative pipeline compilation monitors; per-frame deltas are reported.
const PIPELINE_NAMES: Array[String] = ["canvas", "mesh", "surface", "draw", "specialization"]
const PIPELINE_MONITORS: Array[Performance.Monitor] = [
	Performance.PIPELINE_COMPILATIONS_CANVAS,
	Performance.PIPELINE_COMPILATIONS_MESH,
	Performance.PIPELINE_COMPILATIONS_SURFACE,
	Performance.PIPELINE_COMPILATIONS_DRAW,
	Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
]


## Counts engine/script errors and warnings. Called from any thread.
class ErrorCounter extends Logger:
	var errors: int = 0
	var warnings: int = 0
	var messages: PackedStringArray = PackedStringArray()
	var _mutex: Mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		_mutex.lock()
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1
		if messages.size() < MAX_MESSAGES:
			messages.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_mutex.unlock()

	func snapshot() -> Vector2i:
		_mutex.lock()
		var result := Vector2i(errors, warnings)
		_mutex.unlock()
		return result


var main: GameMain = null
var report_dir: String = ""
var rows: Array[Dictionary] = []

var _counter: ErrorCounter = ErrorCounter.new()
var _level: Level = null
var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _level_seconds: float = 0.0
var _last_usec: int = 0
var _baseline: Vector2i = Vector2i.ZERO
var _shot_taken: bool = false
var _run_started_usec: int = 0
var _load_frames_left: int = 0
var _screenshot_frames_left: int = 0
var _load_hitch: float = 0.0
var _screenshot_cost: float = 0.0
var _worst_gameplay_frame: float = 0.0
var _worst_frame_at: float = 0.0
var _logger_attached: bool = false
var _save_tasks: PackedInt64Array = PackedInt64Array()
var _pipeline_last: PackedInt64Array = PackedInt64Array()
var _pipelines_load: PackedInt64Array = PackedInt64Array()
var _pipelines_play: PackedInt64Array = PackedInt64Array()
var _load_frames: Array[float] = []
var _hitches: Array[Dictionary] = []
var _slow_frames: int = 0
var _slow_unfocused: int = 0
var _unfocused_seconds: float = 0.0
var _focus_changes: int = 0
var _was_focused: bool = true
var _slow_periods: Array[Dictionary] = []
var _open_period: Dictionary = {}
var _decorate_at_start: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(_counter)
	_logger_attached = true
	report_dir = DemoMode.option(REPORT_DIR_PREFIX, "")
	if not report_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	main.screen_changed.connect(_on_screen_changed)
	GameState.level_recorded.connect(_on_level_recorded)
	_last_usec = Time.get_ticks_usec()
	_run_started_usec = _last_usec
	_pipeline_last = _pipeline_counts()
	_was_focused = _window_focused()
	GameLog.info(LOG_TAG, "recording to %s" % (report_dir if not report_dir.is_empty() else "(log only)"))


func _exit_tree() -> void:
	detach()


## Unhooks the logger and waits for pending screenshot writes. Must run before
## the engine shuts down: a script logger still registered at exit is called
## after its script is gone (crashed a windowed run on quit).
func detach() -> void:
	for task: int in _save_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_save_tasks.clear()
	if _logger_attached:
		OS.remove_logger(_counter)
		_logger_attached = false


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame := float(now - _last_usec) / USEC_PER_SECOND
	_last_usec = now
	# Compilations are attributed to the frame interval they happened in,
	# whatever the screen, so a level never inherits a menu's count.
	var compiled := _pipeline_deltas()
	var focused := _window_focused()
	if focused != _was_focused:
		_focus_changes += 1
		_was_focused = focused
	if _level == null or main.screen != GameMain.Screen.PLAYING:
		return
	_level_seconds += frame
	if not focused:
		_unfocused_seconds += frame
	if _load_frames_left > 0:
		_load_frames_left -= 1
		_load_hitch = maxf(_load_hitch, frame)
		_load_frames.append(snappedf(frame * MSEC_PER_SECOND, 0.1))
		_add_counts(_pipelines_load, compiled)
	elif _screenshot_frames_left > 0:
		_screenshot_frames_left -= 1
		_screenshot_cost = maxf(_screenshot_cost, frame)
		_add_counts(_pipelines_play, compiled)
	else:
		_frame_times.append(frame)
		_add_counts(_pipelines_play, compiled)
		if frame > _worst_gameplay_frame:
			_worst_gameplay_frame = frame
			_worst_frame_at = _level_seconds
		_track_slow(frame, focused, compiled)
	if not _shot_taken and _level_seconds >= SCREENSHOT_AFTER:
		_shot_taken = true
		_screenshot()


func _track_slow(frame: float, focused: bool, compiled: PackedInt64Array) -> void:
	var frame_ms := frame * MSEC_PER_SECOND
	if frame_ms >= HITCH_MS and _hitches.size() < MAX_HITCHES:
		_hitches.append({"at_s": snappedf(_level_seconds, 0.01), "ms": snappedf(frame_ms, 0.1),
			"focused": focused, "minimized": _window_minimized(), "pipelines": _named(compiled)})
	if frame_ms < SLOW_FRAME_MS:
		if not _open_period.is_empty() and _level_seconds - float(_open_period["to_s"]) > SLOW_GAP_S:
			_close_slow_period()
		return
	_slow_frames += 1
	if not focused:
		_slow_unfocused += 1
	if frame_ms >= HITCH_MS:
		# Listed as a hitch; slow periods are sustained low frame rates.
		return
	if _open_period.is_empty():
		_open_period = {"from_s": _level_seconds - frame, "to_s": _level_seconds, "frames": 0, "seconds": 0.0, "unfocused_frames": 0}
	_open_period["to_s"] = _level_seconds
	_open_period["frames"] = int(_open_period["frames"]) + 1
	_open_period["seconds"] = float(_open_period["seconds"]) + frame
	if not focused:
		_open_period["unfocused_frames"] = int(_open_period["unfocused_frames"]) + 1


func _close_slow_period() -> void:
	if _open_period.is_empty():
		return
	var length := float(_open_period["to_s"]) - float(_open_period["from_s"])
	if length >= SLOW_PERIOD_MIN_S and _slow_periods.size() < MAX_SLOW_PERIODS:
		_slow_periods.append({"from_s": snappedf(float(_open_period["from_s"]), 0.01), "to_s": snappedf(float(_open_period["to_s"]), 0.01),
			"slow_frames": _open_period["frames"], "slow_fps": snappedf(int(_open_period["frames"]) / maxf(float(_open_period["seconds"]), 0.0001), 0.1),
			"unfocused_frames": _open_period["unfocused_frames"]})
	_open_period = {}


func _on_screen_changed(screen: GameMain.Screen) -> void:
	if screen == GameMain.Screen.PLAYING and main.level != null and main.level != _level:
		_level = main.level
		_frame_times = PackedFloat32Array()
		_level_seconds = 0.0
		_shot_taken = false
		_baseline = _counter.snapshot()
		_load_frames_left = LOAD_FRAMES
		_screenshot_frames_left = 0
		_load_hitch = 0.0
		_screenshot_cost = 0.0
		_worst_gameplay_frame = 0.0
		_worst_frame_at = 0.0
		_pipelines_load = _zero_counts()
		_pipelines_play = _zero_counts()
		_load_frames = []
		_hitches = []
		_slow_frames = 0
		_slow_unfocused = 0
		_unfocused_seconds = 0.0
		_focus_changes = 0
		_slow_periods = []
		_open_period = {}
		_decorate_at_start = SurfaceDecorator.build_usec_total


func _on_level_recorded(stats: LevelStats) -> void:
	var row := stats.to_dict()
	var counts := _counter.snapshot() - _baseline
	row["errors"] = counts.x
	row["warnings"] = counts.y
	row.merge(_frame_stats(_frame_times))
	row["load_hitch_ms"] = snappedf(_load_hitch * MSEC_PER_SECOND, 0.1)
	row["screenshot_ms"] = snappedf(_screenshot_cost * MSEC_PER_SECOND, 0.1)
	row["worst_frame_at_s"] = snappedf(_worst_frame_at, 0.01)
	row.merge(main.load_profile)
	# Props are built on the frames after the load frame (one planet each).
	row["decorate_after_load_ms"] = snappedf(float(SurfaceDecorator.build_usec_total - _decorate_at_start) / USEC_PER_SECOND * MSEC_PER_SECOND, 0.01)
	row["load_frames_ms"] = _load_frames
	row["pipelines_load"] = _named(_pipelines_load)
	row["pipelines_play"] = _named(_pipelines_play)
	_close_slow_period()
	row["hitches"] = _hitches
	row["slow_frames"] = _slow_frames
	row["slow_frames_unfocused"] = _slow_unfocused
	row["slow_periods"] = _slow_periods
	row["unfocused_s"] = snappedf(_unfocused_seconds, 0.01)
	row["focus_changes"] = _focus_changes
	# Growth across levels here would mean a leak (nodes or objects piling up).
	row["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	row["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	row["orphan_nodes"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var bot := _level.input_source as DemoBot if _level != null else null
	if bot != null:
		row["hops"] = bot.hops
		row["hops_landed"] = bot.hops_landed
		row["goals_skipped"] = bot.goals_skipped
		row["stomp_attempts"] = bot.stomp_attempts
	row["screenshot"] = _shot_path(rows.size(), stats.level_id) if _shot_taken and not report_dir.is_empty() else ""
	rows.append(row)
	GameLog.info(LOG_TAG, "level %d: %s" % [rows.size(), row])
	_level = null


## Prints the table and writes the JSON report.
func finish() -> void:
	var total := {"levels": rows.size(), "run_seconds": float(Time.get_ticks_usec() - _run_started_usec) / USEC_PER_SECOND,
		"errors": _counter.errors, "warnings": _counter.warnings, "messages": _counter.messages}
	GameLog.info(LOG_TAG, "| # | level | time s | damage | deaths | stomps | stardust | fps avg | fps 1% low | worst ms | load ms | errors | warnings | hops | skipped |")
	for i in rows.size():
		var row := rows[i]
		GameLog.info(LOG_TAG, "| %d | %s | %.2f | %d | %d | %d | %d/%d | %.1f | %.1f | %.1f | %.1f | %d | %d | %d/%d | %d |" % [
			i + 1, row["level_id"], row["time"], row["damage"], row["deaths"], row["stomps"], row["collected"], row["total"],
			row["fps_avg"], row["fps_low"], row["worst_frame_ms"], row["load_hitch_ms"], row["errors"], row["warnings"],
			row.get("hops_landed", 0), row.get("hops", 0), row.get("goals_skipped", 0)])
	GameLog.info(LOG_TAG, "| # | level | build ms | enter ms | decorate after load ms | load frames ms | pipelines load | pipelines play | hitches | slow frames (unfocused) | unfocused s |")
	for i in rows.size():
		var row := rows[i]
		GameLog.info(LOG_TAG, "| %d | %s | %.2f | %.2f | %.2f | %s | %d | %d | %d | %d (%d) | %.2f |" % [
			i + 1, row["level_id"], row.get("build_ms", 0.0), row.get("enter_ms", 0.0), row.get("decorate_after_load_ms", 0.0),
			row["load_frames_ms"], _sum(row["pipelines_load"]), _sum(row["pipelines_play"]), (row["hitches"] as Array).size(),
			row["slow_frames"], row["slow_frames_unfocused"], row["unfocused_s"]])
		for hitch: Dictionary in row["hitches"]:
			GameLog.info(LOG_TAG, "  hitch %s" % hitch)
		for period: Dictionary in row["slow_periods"]:
			GameLog.info(LOG_TAG, "  slow period %s" % period)
	GameLog.info(LOG_TAG, "total: %s" % total)
	if report_dir.is_empty():
		return
	var file := FileAccess.open(report_dir.path_join("demo_report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"levels": rows, "total": total}, "  "))
		file.close()


static func _frame_stats(frame_times: PackedFloat32Array) -> Dictionary:
	if frame_times.is_empty():
		return {"frames": 0, "fps_avg": 0.0, "fps_low": 0.0, "worst_frame_ms": 0.0}
	var sum := 0.0
	for value: float in frame_times:
		sum += value
	var sorted := frame_times.duplicate()
	sorted.sort()
	var low := sorted[mini(int(sorted.size() * LOW_PERCENTILE), sorted.size() - 1)]
	return {
		"frames": frame_times.size(),
		"fps_avg": snappedf(frame_times.size() / sum, 0.1),
		"fps_low": snappedf(1.0 / maxf(low, 0.0001), 0.1),
		"worst_frame_ms": snappedf(sorted[sorted.size() - 1] * MSEC_PER_SECOND, 0.1),
	}


static func _pipeline_counts() -> PackedInt64Array:
	var counts := PackedInt64Array()
	for monitor: Performance.Monitor in PIPELINE_MONITORS:
		counts.append(int(Performance.get_monitor(monitor)))
	return counts


func _pipeline_deltas() -> PackedInt64Array:
	var counts := _pipeline_counts()
	var deltas := PackedInt64Array()
	for i in counts.size():
		deltas.append(counts[i] - (_pipeline_last[i] if i < _pipeline_last.size() else 0))
	_pipeline_last = counts
	return deltas


static func _zero_counts() -> PackedInt64Array:
	var counts := PackedInt64Array()
	counts.resize(PIPELINE_MONITORS.size())
	return counts


static func _add_counts(total: PackedInt64Array, add: PackedInt64Array) -> void:
	for i in mini(total.size(), add.size()):
		total[i] += add[i]


## Non-zero counts by monitor name.
static func _named(counts: PackedInt64Array) -> Dictionary:
	var named := {}
	for i in counts.size():
		if counts[i] != 0:
			named[PIPELINE_NAMES[i]] = counts[i]
	return named


static func _sum(named: Dictionary) -> int:
	var total := 0
	for value: Variant in named.values():
		total += int(value)
	return total


static func _window_focused() -> bool:
	return DisplayServer.get_name() == "headless" or DisplayServer.window_is_focused()


static func _window_minimized() -> bool:
	return DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED


func _shot_path(index: int, level_id: String) -> String:
	return report_dir.path_join("%02d_%s.png" % [index + 1, level_id])


## Grabs the last drawn frame (no await: waiting for frame_post_draw sometimes
## resumed a level later and mislabelled the file).
func _screenshot() -> void:
	if report_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	_screenshot_frames_left = SCREENSHOT_FRAMES
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	# PNG encoding off the main thread; only the GPU readback stays here.
	# A lambda keeps the Image alive (a bound Callable would not).
	var path := _shot_path(rows.size(), _level.level_id)
	_save_tasks.append(WorkerThreadPool.add_task(func() -> void: image.save_png(path)))
