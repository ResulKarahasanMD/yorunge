class_name SaveSystem
extends Node
## Autoloaded as `SaveManager` (typed access: `SaveSystem.current`).
## Settings and progress in one versioned ConfigFile. A missing file means
## defaults; an unreadable or wrong-version file is moved to `.bak` and
## replaced by defaults, so a bad save never blocks the game. The DemoBot
## uses its own profile so self-tests never touch the player's progress.

signal settings_changed

const LOG_TAG := "Save"
const SAVE_VERSION := 1
const PLAYER_PATH := "user://save.cfg"
const DEMO_PATH := "user://demo_save.cfg"
const BACKUP_SUFFIX := ".bak"
## Best times are stored (and compared) to this precision in seconds.
const TIME_PRECISION := 0.01
## Command-line flag: start from a default profile (deterministic demo runs).
const FRESH_FLAG := "--fresh-save"
const META := "meta"
const SETTINGS := "settings"
const PROGRESS := "progress"
const BEST_TIMES := "best_times"

const DEFAULT_SETTINGS := {
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"sensitivity": 1.0,
	"invert_y": false,
	"fullscreen": false,
}
const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 3.0

static var current: SaveSystem = null

var path: String = PLAYER_PATH
var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	current = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	use_path(DEMO_PATH if DemoMode.is_active() else PLAYER_PATH)
	if DemoMode.has_flag(FRESH_FLAG):
		reset_to_defaults()


## Forgets settings and progress of the current profile (overwrites the file).
func reset_to_defaults() -> void:
	GameLog.info(LOG_TAG, "reset %s to defaults" % path)
	_config = ConfigFile.new()
	_apply_settings()
	save_to_disk()


## Switches profile (demo entry, tests) and loads it.
func use_path(new_path: String) -> void:
	path = new_path
	load_from_disk()


func load_from_disk() -> void:
	_config = ConfigFile.new()
	if not FileAccess.file_exists(path):
		GameLog.info(LOG_TAG, "no save at %s, using defaults" % path)
		_apply_settings()
		return
	var error := _config.load(path)
	var version := int(_config.get_value(META, "version", -1)) if error == OK else -1
	if error != OK or version != SAVE_VERSION:
		GameLog.warn(LOG_TAG, "unusable save %s (error %d, version %d): backed up, using defaults" % [path, error, version])
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + BACKUP_SUFFIX))
		_config = ConfigFile.new()
	else:
		GameLog.info(LOG_TAG, "loaded %s (sensitivity=%.2f, unlocked=%d)" % [path, get_setting("sensitivity"), unlocked_tutorials()])
	_apply_settings()


func save_to_disk() -> Error:
	_config.set_value(META, "version", SAVE_VERSION)
	var error := _config.save(path)
	if error != OK:
		GameLog.error(LOG_TAG, "could not write %s (error %d)" % [path, error])
	return error


# --- Settings ------------------------------------------------------------------

func get_setting(key: String) -> Variant:
	return _config.get_value(SETTINGS, key, DEFAULT_SETTINGS[key])


func set_setting(key: String, value: Variant) -> void:
	if key == "sensitivity":
		value = clampf(float(value), MIN_SENSITIVITY, MAX_SENSITIVITY)
	_config.set_value(SETTINGS, key, value)
	_apply_settings()
	save_to_disk()
	settings_changed.emit()


func _apply_settings() -> void:
	if AudioSystem.current != null:
		AudioSystem.current.set_bus_volume(&"Master", float(get_setting("master_volume")))
		AudioSystem.current.set_bus_volume(&"Music", float(get_setting("music_volume")))
		AudioSystem.current.set_bus_volume(&"SFX", float(get_setting("sfx_volume")))
	if _window_mode_controllable():
		var fullscreen := bool(get_setting("fullscreen"))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _window_mode_controllable() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()


# --- Progress ------------------------------------------------------------------

## How many tutorials can be started (the first is always open).
func unlocked_tutorials() -> int:
	return int(_config.get_value(PROGRESS, "unlocked_tutorials", 1))


func best_time(level_id: String) -> float:
	var times: Dictionary = _config.get_value(PROGRESS, BEST_TIMES, {})
	return float(times.get(level_id, -1.0))


func endless_best_depth() -> int:
	return int(_config.get_value(PROGRESS, "endless_best_depth", 0))


## Records a finished level. Returns true when it set a new best time.
func record_level(stats: LevelStats, tutorial_index: int, endless_depth: int) -> bool:
	var times: Dictionary = _config.get_value(PROGRESS, BEST_TIMES, {})
	var previous := float(times.get(stats.level_id, -1.0))
	# Compare at the stored precision, or an identical run looks like a record.
	var time := snappedf(stats.time, TIME_PRECISION)
	var improved := previous < 0.0 or time < previous
	if improved:
		times[stats.level_id] = time
		_config.set_value(PROGRESS, BEST_TIMES, times)
	if tutorial_index >= 0:
		_config.set_value(PROGRESS, "unlocked_tutorials", maxi(unlocked_tutorials(), tutorial_index + 2))
	if endless_depth > endless_best_depth():
		_config.set_value(PROGRESS, "endless_best_depth", endless_depth)
	save_to_disk()
	return improved
