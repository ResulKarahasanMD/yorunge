class_name MenuAutopilot
extends Node
## Drives the menus in demo mode the way a player would, by emitting the
## buttons' `pressed` signals (same handlers as a click):
## main menu -> Levels -> level 1; Next after every level; once, during
## `pause_test_tutorial`, pause -> Settings -> change sensitivity -> Back ->
## Resume, so the pause flow and saving are exercised end to end.

const LOG_TAG := "Autopilot"
## Command-line override of press_delay (slower menus for screenshots).
const MENU_DELAY_PREFIX := "--menu-delay="

@export var press_delay: float = 0.8
@export var pause_test_tutorial: int = 1
@export var pause_test_after: float = 4.0
@export var test_sensitivity: float = 1.35

var main: GameMain = null
## Verification counters.
var presses: int = 0
var pause_tests_done: int = 0

var _started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DemoMode.menu_delay > 0.0:
		press_delay = DemoMode.menu_delay
	var flag := FrameCapture._arg_value(MENU_DELAY_PREFIX)
	if flag.is_valid_float():
		press_delay = flag.to_float()
	main.screen_changed.connect(_on_screen_changed)


func _on_screen_changed(screen: GameMain.Screen) -> void:
	match screen:
		GameMain.Screen.MAIN_MENU:
			if not _started:
				_started = true
				await _delay(press_delay)
				_press(main.main_menu.levels_button)
		GameMain.Screen.LEVEL_SELECT:
			await _delay(press_delay)
			_press(main.level_select.level_button(0))
		GameMain.Screen.PLAYING:
			if pause_tests_done == 0 and GameState.tutorial_index == pause_test_tutorial:
				pause_tests_done = 1
				_run_pause_test()
		GameMain.Screen.LEVEL_COMPLETE:
			await _delay(press_delay)
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
