class_name MainMenu
extends Control
## Title screen. Emits intents; GameMain decides what happens.

signal continue_requested
signal levels_requested
signal endless_requested
signal settings_requested
signal quit_requested

const TITLE_SIZE := 72
const SUBTITLE_SIZE := 24

var continue_button: Button
var levels_button: Button
var endless_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var column := UiBuilder.centered_column(self)
	UiBuilder.label(column, UiText.GAME_TITLE, TITLE_SIZE, UiTheme.FOCUS_COLOR)
	UiBuilder.label(column, UiText.GAME_SUBTITLE, SUBTITLE_SIZE)
	continue_button = UiBuilder.button(column, UiText.START, continue_requested.emit)
	levels_button = UiBuilder.button(column, UiText.LEVELS, levels_requested.emit)
	endless_button = UiBuilder.button(column, UiText.ENDLESS, endless_requested.emit)
	UiBuilder.button(column, UiText.SETTINGS, settings_requested.emit)
	UiBuilder.button(column, UiText.QUIT, quit_requested.emit)


## `has_progress`: some level finished before, so "Start" reads "Continue".
func refresh(has_progress: bool, endless_available: bool) -> void:
	continue_button.text = UiText.CONTINUE if has_progress else UiText.START
	endless_button.visible = endless_available


func focus_default() -> void:
	continue_button.grab_focus()
