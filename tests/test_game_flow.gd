extends TestSuite
## GameMain screen flow on a private save profile (never the player's save):
## the level-end and death waits survive a pause, menu keys never steal text
## input, and endless results stay out of the best times. Short delays keep the
## suite quick; the waits run the same code as the real ones.

const MAIN_SCENE := preload("res://main/main.tscn")
const TEST_SAVE := "user://test_flow_save.cfg"
const SHORT_DELAY := 0.2
## Real time spent paused or waiting: comfortably past SHORT_DELAY.
const WAIT := 0.6
const ENDLESS_SEED := 2026
const SETTLE_FRAMES := 2

var _player_save: SaveSystem = null
var _save: SaveSystem = null


func _start() -> GameMain:
	_player_save = SaveSystem.current
	_save = SaveSystem.new()
	_save.use_path(TEST_SAVE)
	_save.reset_to_defaults()
	SaveSystem.current = _save
	var main := MAIN_SCENE.instantiate() as GameMain
	main.complete_screen_delay = SHORT_DELAY
	main.retry_delay = SHORT_DELAY
	spawn(main)
	return main


func cleanup() -> void:
	super.cleanup()
	tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _save != null:
		SaveSystem.current = _player_save
		_save.free()
		_save = null
	_remove(TEST_SAVE)


func test_pause_during_level_end_wait_still_shows_summary() -> void:
	var main := _start()
	main.start_tutorial(0)
	await _frames(SETTLE_FRAMES)
	_finish(main.level)
	check(main.screen == GameMain.Screen.PLAYING, "summary waits for the portal effects")
	tree.root.push_input(_key(KEY_ESCAPE))
	check(main.screen == GameMain.Screen.PAUSED, "Esc pauses during the wait")
	await _real_seconds(WAIT)
	check(main.screen == GameMain.Screen.PAUSED, "no summary while paused")
	tree.root.push_input(_key(KEY_ESCAPE))
	check(main.screen == GameMain.Screen.PLAYING, "Esc resumes")
	await _real_seconds(WAIT)
	check(main.screen == GameMain.Screen.LEVEL_COMPLETE, "summary appears after resuming (screen %s)" % _screen(main))


func test_pause_during_death_wait_still_retries() -> void:
	var main := _start()
	main.start_tutorial(0)
	await _frames(SETTLE_FRAMES)
	var dead := main.level
	dead.player.health.take_damage(dead.player.health.max_hearts, "test")
	check(dead.is_finished(), "explorer died")
	tree.root.push_input(_key(KEY_ESCAPE))
	check(main.screen == GameMain.Screen.PAUSED, "Esc pauses during the wait")
	await _real_seconds(WAIT)
	check(main.level == dead, "no retry while paused")
	tree.root.push_input(_key(KEY_ESCAPE))
	await _real_seconds(WAIT)
	check(main.level != null and main.level != dead, "level restarted after resuming")
	check(main.screen == GameMain.Screen.PLAYING, "playing the retry (screen %s)" % _screen(main))


func test_p_in_seed_field_is_text_not_back() -> void:
	var main := _start()
	main.show_endless_setup()
	await _frames(SETTLE_FRAMES)
	var field := main.endless_setup.seed_field
	field.text = ""
	field.grab_focus()
	field.edit()
	tree.root.push_input(_key(KEY_P, "p".unicode_at(0)))
	check(main.screen == GameMain.Screen.ENDLESS_SETUP, "P in the seed field keeps the screen (screen %s)" % _screen(main))
	check(field.text == "p", "P types a letter (text \"%s\")" % field.text)
	field.unedit()
	tree.root.push_input(_key(KEY_ESCAPE))
	check(main.screen == GameMain.Screen.MAIN_MENU, "Esc still goes back (screen %s)" % _screen(main))


func test_endless_summary_is_not_a_record() -> void:
	var main := _start()
	main.start_endless(ENDLESS_SEED)
	await _frames(SETTLE_FRAMES)
	var level_id := main.level.level_id
	_finish(main.level)
	await _real_seconds(WAIT)
	check(main.screen == GameMain.Screen.LEVEL_COMPLETE, "endless summary shown (screen %s)" % _screen(main))
	check(_save.best_time(level_id) < 0.0, "endless level keeps no best time")
	check(main.level_complete.best_line() != UiText.NEW_RECORD, "endless level is not a new record")
	check(main.level_complete.best_line() == UiText.DEPTH_LINE % [1, 1], "summary shows the depth (\"%s\")" % main.level_complete.best_line())


# --- Helpers ---------------------------------------------------------------------

func _finish(level: Level) -> void:
	for goal: Node3D in level.demo_goals():
		(goal as Stardust).collect()
	level.portal._on_body_entered(level.player)


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


## Unscaled, pause-proof wait (the test itself must keep running while paused).
func _real_seconds(seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout


static func _key(keycode: Key, unicode: int = 0) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = unicode
	event.pressed = true
	return event


static func _screen(main: GameMain) -> String:
	return GameMain.Screen.keys()[main.screen]


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
