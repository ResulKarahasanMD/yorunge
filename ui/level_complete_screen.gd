class_name LevelCompleteScreen
extends Control
## End-of-level summary: time (with best / new record, or the depth in endless
## mode), hearts lost, enemies stomped, stardust; next / retry / menu.

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


## Tutorial summary. `best` is the stored best time before this run (-1 = none).
func show_stats(stats: LevelStats, best: float, new_record: bool, has_next: bool) -> void:
	_show_common(stats, has_next)
	if new_record:
		_set_best_line(UiText.NEW_RECORD, true)
	else:
		_set_best_line(UiText.BEST_LINE % UiText.seconds(best), false)


## Endless summary: depth instead of a best time (every seed is a new level).
## `deepest_before` is the deepest level reached before this one.
func show_endless_stats(stats: LevelStats, depth: int, deepest_before: int) -> void:
	_show_common(stats, true)
	_set_best_line(UiText.DEPTH_LINE % [depth, maxi(depth, deepest_before)], depth > deepest_before)


func best_line() -> String:
	return _best_label.text


func _show_common(stats: LevelStats, has_next: bool) -> void:
	_time_label.text = UiText.TIME_LINE % UiText.seconds(stats.time)
	_damage_label.text = UiText.DAMAGE_LINE % stats.damage
	_stomps_label.text = UiText.STOMPS_LINE % stats.stomps
	_stardust_label.text = UiText.STARDUST_LINE % [stats.collected, stats.total]
	next_button.text = UiText.NEXT_LEVEL if has_next else UiText.FINISH


func _set_best_line(text: String, highlight: bool) -> void:
	_best_label.text = text
	if highlight:
		_best_label.add_theme_color_override(&"font_color", RECORD_COLOR)
	else:
		_best_label.remove_theme_color_override(&"font_color")


func focus_default() -> void:
	next_button.grab_focus()
