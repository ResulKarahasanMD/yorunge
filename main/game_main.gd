class_name GameMain
extends Node
## Persistent root scene. Owns the screen flow (main menu, level select,
## settings, playing, pause, level complete), hosts either the menu backdrop or
## the active Level under LevelHost, binds the HUD, records results through
## SaveSystem and GameState, and is the single exit path of the game.

signal screen_changed(screen: Screen)
## The tutorial sequence ended (before returning to the main menu).
signal run_finished

enum Screen { MAIN_MENU, LEVEL_SELECT, SETTINGS, PLAYING, PAUSED, LEVEL_COMPLETE, ENDLESS_SETUP }

const LOG_TAG := "Main"
const QUIT_SETTLE_FRAMES := 5
const MENU_BACKDROP := preload("res://world/menu_backdrop.tscn")

@export var retry_delay: float = 1.5
## Pause between entering the portal and the summary screen (portal effects).
@export var complete_screen_delay: float = 1.2

var level: Level = null
var screen: Screen = Screen.MAIN_MENU
var autopilot: MenuAutopilot = null
var report: DemoReport = null

var _deaths: int = 0
var _settings_return: Screen = Screen.MAIN_MENU
var _backdrop: Node3D = null

@onready var level_host: Node3D = $LevelHost
@onready var hud: Hud = $UI/Hud
@onready var main_menu: MainMenu = $UI/MainMenu
@onready var level_select: LevelSelect = $UI/LevelSelect
@onready var settings_panel: SettingsPanel = $UI/SettingsPanel
@onready var pause_menu: PauseMenu = $UI/PauseMenu
@onready var level_complete: LevelCompleteScreen = $UI/LevelComplete
@onready var endless_setup: EndlessSetup = $UI/EndlessSetup


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_host.process_mode = Node.PROCESS_MODE_PAUSABLE
	_wire_screens()
	if DemoMode.is_active():
		autopilot = MenuAutopilot.new()
		autopilot.name = "MenuAutopilot"
		autopilot.main = self
		add_child(autopilot)
		report = DemoReport.new()
		report.name = "DemoReport"
		report.main = self
		add_child(report)
	show_main_menu()


## Runs before the GUI. `pause` (Esc / P / Start) only acts inside a level;
## menus go back on `menu_back` (Esc / gamepad B) alone, so a "p" typed into
## the seed field stays text.
func _input(event: InputEvent) -> void:
	var pause_pressed := event.is_action_pressed(InputBindings.PAUSE)
	var back_pressed := event.is_action_pressed(InputBindings.MENU_BACK)
	if not pause_pressed and not back_pressed:
		return
	match screen:
		Screen.PLAYING:
			if not pause_pressed:
				return
			pause()
		Screen.PAUSED:
			resume()
		Screen.SETTINGS:
			if not back_pressed:
				return
			close_settings()
		Screen.LEVEL_SELECT, Screen.ENDLESS_SETUP:
			if not back_pressed:
				return
			show_main_menu()
		_:
			return
	get_viewport().set_input_as_handled()


# --- Screens -----------------------------------------------------------------------

func show_main_menu() -> void:
	get_tree().paused = false
	_unload_level()
	_show_backdrop()
	main_menu.refresh(not GameState.history.is_empty() or SaveSystem.current.unlocked_tutorials() > 1, true)
	_set_screen(Screen.MAIN_MENU, main_menu)


func show_level_select() -> void:
	var best_times: Array[float] = []
	for path: String in GameStateManager.TUTORIAL_LEVELS:
		best_times.append(SaveSystem.current.best_time(_level_id(path)))
	level_select.refresh(SaveSystem.current.unlocked_tutorials(), best_times)
	_set_screen(Screen.LEVEL_SELECT, level_select)


func show_endless_setup() -> void:
	endless_setup.refresh(SaveSystem.current.endless_best_depth())
	_set_screen(Screen.ENDLESS_SETUP, endless_setup)


func open_settings() -> void:
	_settings_return = screen
	_set_screen(Screen.SETTINGS, settings_panel)


func close_settings() -> void:
	if _settings_return == Screen.PAUSED:
		_set_screen(Screen.PAUSED, pause_menu)
	else:
		_set_screen(Screen.MAIN_MENU, main_menu)


func pause() -> void:
	if screen != Screen.PLAYING:
		return
	get_tree().paused = true
	_set_screen(Screen.PAUSED, pause_menu)
	GameLog.info(LOG_TAG, "paused")


func resume() -> void:
	get_tree().paused = false
	_set_screen(Screen.PLAYING, null)
	GameLog.info(LOG_TAG, "resumed")


# --- Levels -------------------------------------------------------------------------

## "Start/Continue": the furthest unlocked tutorial.
func continue_game() -> void:
	start_tutorial(mini(SaveSystem.current.unlocked_tutorials(), GameStateManager.TUTORIAL_LEVELS.size()) - 1)


func start_tutorial(index: int) -> void:
	GameState.start_tutorial(index)
	_deaths = 0
	_load_current()


func start_endless(base_seed: int) -> void:
	GameState.start_endless(base_seed)
	_deaths = 0
	GameLog.info(LOG_TAG, "endless run, base seed %d" % base_seed)
	_load_current()


func restart_level() -> void:
	_deaths = 0
	_load_current()


func next_level() -> void:
	if GameState.has_next_level():
		GameState.advance()
		_deaths = 0
		_load_current()
	else:
		_finish_run()


## Tutorial scene or freshly generated endless level for the current position.
func _load_current() -> void:
	if GameState.mode == GameStateManager.Mode.ENDLESS:
		var started := Time.get_ticks_usec()
		var spec := GameState.current_endless_spec()
		var built := LevelBuilder.build(spec)
		GameLog.info(LOG_TAG, "generated %s: %d planets, %d enemies in %.1f ms" % [
			spec.level_id(), spec.planets.size(), spec.enemies.size(), float(Time.get_ticks_usec() - started) / 1000.0])
		_spawn_level(built)
	else:
		_spawn_level((load(GameState.current_level_path()) as PackedScene).instantiate() as Level)


func _spawn_level(next: Level) -> void:
	get_tree().paused = false
	_hide_backdrop()
	_unload_level()
	level = next
	level_host.add_child(level)
	level.completed.connect(_on_level_completed)
	level.failed.connect(_on_level_failed)
	hud.bind(level)
	_set_screen(Screen.PLAYING, null)
	GameLog.info(LOG_TAG, "loaded %s" % level.level_id)


func _unload_level() -> void:
	if level == null:
		return
	level_host.remove_child(level)
	level.queue_free()
	level = null


func _on_level_completed(stats: LevelStats) -> void:
	stats.deaths = _deaths
	var save := SaveSystem.current
	var endless := GameState.mode == GameStateManager.Mode.ENDLESS
	var best_before := save.best_time(stats.level_id)
	var deepest_before := save.endless_best_depth()
	var tutorial := -1 if endless else GameState.tutorial_index
	var new_record := save.record_level(stats, tutorial, GameState.endless_depth if endless else 0)
	GameState.record(stats)
	var completed_level := level
	await _level_time(complete_screen_delay)
	if level != completed_level or screen != Screen.PLAYING:
		return
	if endless:
		level_complete.show_endless_stats(stats, GameState.endless_depth, deepest_before)
	else:
		level_complete.show_stats(stats, best_before, new_record, GameState.has_next_level())
	_set_screen(Screen.LEVEL_COMPLETE, level_complete)


func _on_level_failed(_stats: LevelStats) -> void:
	_deaths += 1
	var failed_level := level
	await _level_time(retry_delay)
	if level == failed_level and screen == Screen.PLAYING:
		_load_current()


## Waits in game time: the timer stops while the tree is paused, so a pause
## during the portal or death wait delays the next screen instead of losing it
## (a pause-proof timer ran out while paused and the screen check dropped it).
func _level_time(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false).timeout


func _finish_run() -> void:
	GameLog.info(LOG_TAG, "tutorials finished")
	run_finished.emit()
	show_main_menu()


## End of a self-test: print every recorded level, then quit if asked to.
func finish_demo() -> void:
	GameLog.info(LOG_TAG, "run finished: %d levels" % GameState.history.size())
	for stats: LevelStats in GameState.history:
		GameLog.info(LOG_TAG, "  %s" % stats.to_dict())
	if report != null:
		report.finish()
	if DemoMode.should_exit_on_finish():
		quit_game()


## Single exit path: silence audio, let the audio server release its
## playbacks for a few frames, then quit (otherwise they leak at exit).
func quit_game() -> void:
	GameLog.info(LOG_TAG, "quit")
	if report != null:
		report.detach()
	if AudioSystem.current != null:
		AudioSystem.current.stop_all()
	for i in QUIT_SETTLE_FRAMES:
		await get_tree().process_frame
	get_tree().quit()


# --- Helpers -------------------------------------------------------------------------

func _wire_screens() -> void:
	main_menu.continue_requested.connect(continue_game)
	main_menu.levels_requested.connect(show_level_select)
	main_menu.settings_requested.connect(open_settings)
	main_menu.quit_requested.connect(quit_game)
	main_menu.endless_requested.connect(show_endless_setup)
	endless_setup.start_requested.connect(start_endless)
	endless_setup.back_requested.connect(show_main_menu)
	level_select.level_chosen.connect(start_tutorial)
	level_select.back_requested.connect(show_main_menu)
	settings_panel.back_requested.connect(close_settings)
	pause_menu.resume_requested.connect(resume)
	pause_menu.restart_requested.connect(restart_level)
	pause_menu.settings_requested.connect(open_settings)
	pause_menu.menu_requested.connect(show_main_menu)
	level_complete.next_requested.connect(next_level)
	level_complete.retry_requested.connect(restart_level)
	level_complete.menu_requested.connect(show_main_menu)


func _set_screen(new_screen: Screen, overlay: Control) -> void:
	screen = new_screen
	for control: Control in [main_menu, level_select, settings_panel, pause_menu, level_complete, endless_setup]:
		control.visible = control == overlay
	hud.visible = level != null and (new_screen == Screen.PLAYING or new_screen == Screen.PAUSED)
	var playing := new_screen == Screen.PLAYING
	if level != null:
		level.set_player_control(playing)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing and _human_playing() else Input.MOUSE_MODE_VISIBLE
	if overlay != null and overlay.has_method(&"focus_default"):
		overlay.call_deferred(&"focus_default")
	GameLog.info(LOG_TAG, "screen -> %s" % Screen.keys()[new_screen])
	screen_changed.emit(new_screen)


func _human_playing() -> bool:
	return level != null and level.input_source is HumanInput


func _show_backdrop() -> void:
	if _backdrop == null:
		_backdrop = MENU_BACKDROP.instantiate() as Node3D
		level_host.add_child(_backdrop)


func _hide_backdrop() -> void:
	if _backdrop != null:
		level_host.remove_child(_backdrop)
		_backdrop.queue_free()
		_backdrop = null


static func _level_id(path: String) -> String:
	return path.get_file().get_basename()
