extends TestSuite
## DemoReport maths and the error-counting logger (no game run needed).

const FRAME := 1.0 / 120.0
const SPIKE := 0.05
const HITCH := 1.0
const SLOW := 1.0 / 32.0
const SLOW_RUN := 64
const FAST_FRAMES := 120


func test_frame_stats() -> void:
	var frames := PackedFloat32Array()
	for i in 1000:
		frames.append(FRAME)
	var steady := DemoReport._frame_stats(frames)
	check_near(steady["fps_avg"], 120.0, "steady 120 Hz average", 0.11)
	check_near(steady["fps_low"], 120.0, "steady 1% low equals average", 0.11)
	check_near(steady["worst_frame_ms"], FRAME * 1000.0, "worst frame of a steady run", 0.06)
	for i in 20:
		frames[i * 50] = SPIKE
	var spiky := DemoReport._frame_stats(frames)
	check_near(spiky["worst_frame_ms"], SPIKE * 1000.0, "spike shows up as the worst frame", 0.06)
	check_near(spiky["fps_low"], 1.0 / SPIKE, "2% spikes pull the 1% low down to the spike rate", 0.11)
	check(spiky["fps_avg"] < steady["fps_avg"], "spikes lower the average")
	check(DemoReport._frame_stats(PackedFloat32Array())["frames"] == 0, "empty input is safe")


func test_error_counter() -> void:
	var counter := DemoReport.ErrorCounter.new()
	counter._log_error("f", "a.gd", 1, "code", "why", false, Logger.ERROR_TYPE_ERROR, [])
	counter._log_error("f", "a.gd", 2, "code", "why", false, Logger.ERROR_TYPE_SCRIPT, [])
	counter._log_error("f", "a.gd", 3, "code", "why", false, Logger.ERROR_TYPE_WARNING, [])
	check(counter.snapshot() == Vector2i(2, 1), "two errors and one warning counted (got %s)" % counter.snapshot())
	check(counter.messages.size() == 3 and counter.messages[0].begins_with("a.gd:1"), "messages kept with location")


## Hitch hunting: a long frame is kept with its pipeline compilations and focus;
## a run of slow frames becomes one slow period with its unfocused share.
func test_hitches_and_slow_periods() -> void:
	var report := DemoReport.new()
	report._pipelines_play = DemoReport._zero_counts()
	var calm := PackedInt64Array([0, 0, 0, 0, 0])
	var compiling := PackedInt64Array([0, 0, 2, 0, 1])
	_feed(report, FAST_FRAMES, FRAME, true, calm)
	_feed(report, 1, HITCH, true, compiling)
	_feed(report, FAST_FRAMES, FRAME, true, calm)
	_feed(report, SLOW_RUN, SLOW, false, calm)
	_feed(report, FAST_FRAMES, FRAME, true, calm)
	report._close_slow_period()
	check(report._hitches.size() == 1, "one hitch kept (got %d)" % report._hitches.size())
	var hitch: Dictionary = report._hitches[0]
	check_near(hitch["ms"], HITCH * 1000.0, "hitch length", 0.06)
	check(hitch["pipelines"] == {"surface": 2, "specialization": 1}, "hitch carries its compilations (got %s)" % [hitch["pipelines"]])
	check(report._slow_periods.size() == 1, "one slow period (got %d)" % report._slow_periods.size())
	var period: Dictionary = report._slow_periods[0]
	check(int(period["slow_frames"]) == SLOW_RUN, "every slow frame counted")
	check(int(period["unfocused_frames"]) == SLOW_RUN, "slow frames happened unfocused")
	check_near(period["slow_fps"], 1.0 / SLOW, "slow period rate", 0.11)
	check(report._slow_frames == SLOW_RUN + 1 and report._slow_unfocused == SLOW_RUN, "slow frame counters (hitch counts as slow)")
	report.free()


func _feed(report: DemoReport, count: int, frame: float, focused: bool, compiled: PackedInt64Array) -> void:
	for i in count:
		report._level_seconds += frame
		report._track_slow(frame, focused, compiled)
