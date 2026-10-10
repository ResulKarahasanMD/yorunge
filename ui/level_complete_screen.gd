class_name LevelCompleteScreen
extends Control
## End-of-level summary: time (with best / new record), hearts lost, enemies
## stomped, stardust; next / retry / menu.

signal next_requested
signal retry_requested
signal menu_requested

const TITLE_SIZE := 44
const RECORD_COLOR := Color(1.0, 0.85, 0.4)

var next_button: Button
var menu_button: Button

var _time_label: Label
var _best_label: Label
var _damage_label: Label
var _stomps_label: Label
var _stardust_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var column := UiBuilder.centered_column(self, 480.0)
	UiBuilder.label(column, UiText.COMPLETE_TITLE, TITLE_SIZE, UiTheme.FOCUS_COLOR)
	_time_label = UiBuilder.label(column, "")
	_best_label = UiBuilder.label(column, "")
	_damage_label = UiBuilder.label(column, "")
	_stomps_label = UiBuilder.label(column, "")
	_stardust_label = UiBuilder.label(column, "")
	next_button = UiBuilder.button(column, UiText.NEXT_LEVEL, next_requested.emit)
	UiBuilder.button(column, UiText.PLAY_AGAIN, retry_requested.emit)
	menu_button = UiBuilder.button(column, UiText.MAIN_MENU, menu_requested.emit)


## `best` is the stored best time before this run (-1 = none).
func show_stats(stats: LevelStats, best: float, new_record: bool, has_next: bool) -> void:
	_time_label.text = UiText.TIME_LINE % UiText.seconds(stats.time)
	if new_record:
		_best_label.text = UiText.NEW_RECORD
		_best_label.add_theme_color_override(&"font_color", RECORD_COLOR)
	else:
		_best_label.text = UiText.BEST_LINE % UiText.seconds(best)
		_best_label.remove_theme_color_override(&"font_color")
	_damage_label.text = UiText.DAMAGE_LINE % stats.damage
	_stomps_label.text = UiText.STOMPS_LINE % stats.stomps
	_stardust_label.text = UiText.STARDUST_LINE % [stats.collected, stats.total]
	next_button.text = UiText.NEXT_LEVEL if has_next else UiText.FINISH


func focus_default() -> void:
	next_button.grab_focus()
