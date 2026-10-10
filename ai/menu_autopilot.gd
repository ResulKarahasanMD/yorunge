class_name MenuAutopilot
extends Node
## Drives the menus in demo mode the way a player would, by emitting the
## buttons' `pressed` signals (same handlers as a click):
## main menu -> Levels -> level 1; Next after every tutorial; once, during
## `pause_test_tutorial`, pause -> Settings -> change sensitivity -> Back ->
## Resume. After the tutorials, optionally an endless run of `endless_levels`
## levels from `endless_seed` (main menu -> Endless -> seed -> Start), then
## GameMain.finish_demo().
## Command line: --menu-delay=S --endless-levels=N --endless-seed=S

const LOG_TAG := "Autopilot"
const MENU_DELAY_PREFIX := "--menu-delay="
const ENDLESS_LEVELS_PREFIX := "--endless-levels="
const ENDLESS_SEED_PREFIX := "--endless-seed="

@export var press_delay: float = 0.8
@export var pause_test_tutorial: int = 1
@export var pause_test_after: float = 4.0
@export var test_sensitivity: float = 1.35
@export var endless_levels: int = 0
@export var endless_seed: int = 2026

var main: GameMain = null
## Verification counters.
var presses: int = 0
var pause_tests_done: int = 0
var endless_played: int = 0

var _started: bool = false
var _tutorials_done: bool = false
var _endless_started: bool = false
var _finished: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DemoMode.menu_delay > 0.0:
		press_delay = DemoMode.menu_delay
	press_delay = _float_flag(MENU_DELAY_PREFIX, press_delay)
	endless_levels = int(_float_flag(ENDLESS_LEVELS_PREFIX, endless_levels))
	endless_seed = int(_float_flag(ENDLESS_SEED_PREFIX, endless_seed))
	main.screen_changed.connect(_on_screen_changed)
	main.run_finished.connect(func() -> void: _tutorials_done = true)
	GameLog.info(LOG_TAG, "plan: 3 tutorials, then %d endless levels from seed %d" % [endless_levels, endless_seed])


func _on_screen_changed(screen: GameMain.Screen) -> void:
	match screen:
		GameMain.Screen.MAIN_MENU:
			await _delay(press_delay)
			if not _started:
				_started = true
				_press(main.main_menu.levels_button)
			elif _tutorials_done and endless_levels > 0 and not _endless_started:
				_endless_started = true
				_press(main.main_menu.endless_button)
			elif not _finished:
				_finished = true
				main.finish_demo()
		GameMain.Screen.LEVEL_SELECT:
			await _delay(press_delay)
			_press(main.level_select.level_button(0))
		GameMain.Screen.ENDLESS_SETUP:
			await _delay(press_delay)
			main.endless_setup.seed_field.text = str(endless_seed)
			_press(main.endless_setup.start_button)
		GameMain.Screen.PLAYING:
			if pause_tests_done == 0 and GameState.mode == GameStateManager.Mode.TUTORIAL \
					and GameState.tutorial_index == pause_test_tutorial:
				pause_tests_done = 1
				_run_pause_test()
		GameMain.Screen.LEVEL_COMPLETE:
			await _delay(press_delay)
			if GameState.mode == GameStateManager.Mode.ENDLESS:
				endless_played += 1
				if endless_played >= endless_levels:
					_press(main.level_complete.menu_button)
					return
			_press(main.level_complete.next_button)


func _run_pause_test() -> void:
	await _delay(pause_test_after)
	GameLog.info(LOG_TAG, "pause test: pausing")
	main.pause()
	await _delay(press_delay)
	_press(main.pause_menu.settings_button)
	await _delay(press_delay)
	main.settings_panel.sensitivity_slider.value = test_sensitivity
	GameLog.info(LOG_TAG, "pause test: sensitivity -> %.2f (saved %.2f)" % [
		test_sensitivity, float(SaveSystem.current.get_setting("sensitivity"))])
	await _delay(press_delay)
	_press(main.settings_panel.back_button)
	await _delay(press_delay)
	_press(main.pause_menu.resume_button)


func _press(button: Button) -> void:
	presses += 1
	GameLog.info(LOG_TAG, "press \"%s\" on %s" % [button.text, GameMain.Screen.keys()[main.screen]])
	button.pressed.emit()


func _delay(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


static func _float_flag(prefix: String, fallback: float) -> float:
	var value := FrameCapture._arg_value(prefix)
	return value.to_float() if value.is_valid_float() else fallback
