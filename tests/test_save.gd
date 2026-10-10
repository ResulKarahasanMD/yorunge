extends TestSuite
## SaveSystem persistence on a private test profile (never the player's save).
## Only the files this suite creates are removed afterwards.

const TEST_PATH := "user://test_save.cfg"
const GARBAGE := "this is not a config file [[["
## One slider drag across its range (0.05 steps).
const SLIDER_STEPS := 20


func _fresh() -> SaveSystem:
	var save := SaveSystem.new()
	save.use_path(TEST_PATH)
	save.reset_to_defaults()
	return save


func _stats(level_id: String, time: float) -> LevelStats:
	var stats := LevelStats.new()
	stats.level_id = level_id
	stats.time = time
	return stats


func test_defaults() -> void:
	var save := _fresh()
	check(save.get_setting("sensitivity") == SaveSystem.DEFAULT_SETTINGS["sensitivity"], "default sensitivity")
	check(save.unlocked_tutorials() == 1, "only the first tutorial is open")
	check(save.best_time("tutorial_01") < 0.0, "no best time yet")
	save.free()


func test_settings_round_trip() -> void:
	var save := _fresh()
	save.set_setting("sensitivity", 1.5)
	save.set_setting("invert_y", true)
	save.set_setting("music_volume", 0.25)
	save.set_setting("sensitivity", 1.5)
	save.flush_settings()
	var reloaded := SaveSystem.new()
	reloaded.use_path(TEST_PATH)
	check_near(float(reloaded.get_setting("sensitivity")), 1.5, "sensitivity survives a reload")
	check(bool(reloaded.get_setting("invert_y")), "invert_y survives a reload")
	check_near(float(reloaded.get_setting("music_volume")), 0.25, "music volume survives a reload")
	save.set_setting("sensitivity", 99.0)
	check_near(float(save.get_setting("sensitivity")), SaveSystem.MAX_SENSITIVITY, "sensitivity is clamped")
	save.free()
	reloaded.free()


func test_progress_and_best_times() -> void:
	var save := _fresh()
	check(save.record_level(_stats("tutorial_01", 20.0), 0, 0), "first finish is a record")
	check(not save.record_level(_stats("tutorial_01", 25.0), 0, 0), "slower run is not")
	check(not save.record_level(_stats("tutorial_01", 19.996), 0, 0), "same time at stored precision is not a record")
	check_near(save.best_time("tutorial_01"), 20.0, "best time kept")
	check(save.record_level(_stats("tutorial_01", 15.0), 0, 0), "faster run is a record")
	check_near(save.best_time("tutorial_01"), 15.0, "best time improved")
	check(save.unlocked_tutorials() == 2, "finishing tutorial 1 opens tutorial 2")
	save.record_level(_stats("endless_7", 30.0), -1, 7)
	save.record_level(_stats("endless_3", 30.0), -1, 3)
	check(save.endless_best_depth() == 7, "endless best depth only grows")
	var reloaded := SaveSystem.new()
	reloaded.use_path(TEST_PATH)
	check_near(reloaded.best_time("tutorial_01"), 15.0, "best time survives a reload")
	check(reloaded.unlocked_tutorials() == 2 and reloaded.endless_best_depth() == 7, "progress survives a reload")
	save.free()
	reloaded.free()


## A slider drag sends a change per step: no disk write per step (debounced
## until the drag settles or the screen closes), and only the fullscreen
## switch touches the window mode (re-applying it un-maximised the window).
func test_slider_drag_neither_writes_each_step_nor_resets_the_window() -> void:
	var save := _fresh()
	var window_before := save.window_mode_requests
	_remove(TEST_PATH)
	for i in SLIDER_STEPS + 1:
		save.set_setting("master_volume", float(i) / SLIDER_STEPS)
	check(not FileAccess.file_exists(TEST_PATH), "no disk write while the slider moves")
	check(save.window_mode_requests == window_before, "volume changes leave the window mode alone (%d re-applies)" % [
		save.window_mode_requests - window_before])
	save.set_setting("fullscreen", false)
	check(save.window_mode_requests == window_before + 1, "the fullscreen switch applies the window mode once")
	save._process(SaveSystem.SETTINGS_SAVE_DELAY * 0.5)
	check(not FileAccess.file_exists(TEST_PATH), "still waiting half a delay after the last change")
	save._process(SaveSystem.SETTINGS_SAVE_DELAY)
	check(FileAccess.file_exists(TEST_PATH) and not save.has_pending_save(), "one write once the changes settle")
	var reloaded := SaveSystem.new()
	reloaded.use_path(TEST_PATH)
	check_near(float(reloaded.get_setting("master_volume")), 1.0, "the last slider value is the one saved")
	save.set_setting("music_volume", 0.3)
	save.flush_settings()
	reloaded.use_path(TEST_PATH)
	check_near(float(reloaded.get_setting("music_volume")), 0.3, "flush writes a pending change at once")
	save.free()
	reloaded.free()


## Every endless seed is a new level: storing its time made each one a
## "new record" and grew the save without bound.
func test_endless_levels_keep_no_best_times() -> void:
	var save := _fresh()
	save.record_level(_stats("tutorial_01", 20.0), 0, 0)
	check(not save.record_level(_stats("endless_11_1", 30.0), -1, 1), "first endless level is not a record")
	check(not save.record_level(_stats("endless_22_2", 31.0), -1, 2), "second endless level is not a record")
	check(_best_time_count(save) == 1, "best times hold only the tutorial (%d entries)" % _best_time_count(save))
	check(save.best_time("endless_11_1") < 0.0, "no best time for an endless level")
	check(save.endless_best_depth() == 2, "deepest endless level still recorded")
	save.free()


## Saves written before the fix carry endless_* times: dropped on load.
func test_old_endless_best_times_are_dropped_on_load() -> void:
	_write(TEST_PATH, "[meta]\nversion=1\n[progress]\nendless_best_depth=3\n" +
		"best_times={\"tutorial_01\": 20.0, \"endless_5_1\": 12.5, \"endless_9_3\": 40.0}\n")
	var save := SaveSystem.new()
	save.use_path(TEST_PATH)
	check(_best_time_count(save) == 1, "only the tutorial time is left (%d entries)" % _best_time_count(save))
	check_near(save.best_time("tutorial_01"), 20.0, "tutorial best time kept")
	check(save.endless_best_depth() == 3, "deepest endless level kept")
	var reloaded := SaveSystem.new()
	reloaded.use_path(TEST_PATH)
	check(_best_time_count(reloaded) == 1, "the cleaned save was written back")
	save.free()
	reloaded.free()


func test_corrupt_and_old_saves_fall_back_to_defaults() -> void:
	for content: String in [GARBAGE, "[meta]\nversion=99\n[settings]\nsensitivity=2.5\n"]:
		_write(TEST_PATH, content)
		var save := SaveSystem.new()
		save.use_path(TEST_PATH)
		check(save.get_setting("sensitivity") == SaveSystem.DEFAULT_SETTINGS["sensitivity"], "unusable save -> defaults")
		check(FileAccess.file_exists(TEST_PATH + SaveSystem.BACKUP_SUFFIX), "unusable save backed up")
		check(not FileAccess.file_exists(TEST_PATH), "unusable save moved out of the way")
		save.free()
		_remove(TEST_PATH + SaveSystem.BACKUP_SUFFIX)


func teardown_suite() -> void:
	_remove(TEST_PATH)
	_remove(TEST_PATH + SaveSystem.BACKUP_SUFFIX)


static func _best_time_count(save: SaveSystem) -> int:
	return (save._config.get_value(SaveSystem.PROGRESS, SaveSystem.BEST_TIMES, {}) as Dictionary).size()


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
