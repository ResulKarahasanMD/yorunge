class_name PauseMenu
extends Control
## In-level pause overlay (runs while the tree is paused).

signal resume_requested
signal restart_requested
signal settings_requested
signal menu_requested

const TITLE_SIZE := 44
const DIM_COLOR := Color(0.0, 0.0, 0.05, 0.45)

var resume_button: Button
var settings_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var column := UiBuilder.centered_column(self, 420.0)
	UiBuilder.label(column, UiText.PAUSED, TITLE_SIZE)
	resume_button = UiBuilder.button(column, UiText.RESUME, resume_requested.emit)
	UiBuilder.button(column, UiText.RESTART, restart_requested.emit)
	settings_button = UiBuilder.button(column, UiText.SETTINGS, settings_requested.emit)
	UiBuilder.button(column, UiText.MAIN_MENU, menu_requested.emit)


func focus_default() -> void:
	resume_button.grab_focus()
