class_name DemoReport
extends Node
## End-to-end self-test recorder (demo mode only). For every level played it
## keeps real-time frame statistics measured in-game (independent of any
## external profiler), errors and warnings caught through an OS logger, the
## LevelStats, DemoBot counters and one screenshot; at the end it prints a
## table and writes demo_report.json next to the screenshots.

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
	if _level == null or main.screen != GameMain.Screen.PLAYING:
		return
	_level_seconds += frame
	if _load_frames_left > 0:
		_load_frames_left -= 1
		_load_hitch = maxf(_load_hitch, frame)
	elif _screenshot_frames_left > 0:
		_screenshot_frames_left -= 1
		_screenshot_cost = maxf(_screenshot_cost, frame)
	else:
		_frame_times.append(frame)
		if frame > _worst_gameplay_frame:
			_worst_gameplay_frame = frame
			_worst_frame_at = _level_seconds
	if not _shot_taken and _level_seconds >= SCREENSHOT_AFTER:
		_shot_taken = true
		_screenshot()


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


func _on_level_recorded(stats: LevelStats) -> void:
	var row := stats.to_dict()
	var counts := _counter.snapshot() - _baseline
	row["errors"] = counts.x
	row["warnings"] = counts.y
	row.merge(_frame_stats(_frame_times))
	row["load_hitch_ms"] = snappedf(_load_hitch * MSEC_PER_SECOND, 0.1)
	row["screenshot_ms"] = snappedf(_screenshot_cost * MSEC_PER_SECOND, 0.1)
	row["worst_frame_at_s"] = snappedf(_worst_frame_at, 0.01)
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
