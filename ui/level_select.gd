class_name LevelSelect
extends Control
## Tutorial list with lock state and best times. Titles are read from each
## level scene's own `level_title`, so there is a single source for them.

signal level_chosen(index: int)
signal back_requested

const TITLE_SIZE := 40
const LEVEL_TITLE_PROPERTY := &"level_title"

var _column: VBoxContainer
var _level_buttons: Array[Button] = []
var _back_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_column = UiBuilder.centered_column(self)
	UiBuilder.label(_column, UiText.LEVEL_SELECT_TITLE, TITLE_SIZE)
	for index in GameStateManager.TUTORIAL_LEVELS.size():
		_level_buttons.append(UiBuilder.button(_column, "", level_chosen.emit.bind(index)))
	_back_button = UiBuilder.button(_column, UiText.BACK, back_requested.emit)


func refresh(unlocked: int, best_times: Array[float]) -> void:
	for index in _level_buttons.size():
		var title := scene_title(GameStateManager.TUTORIAL_LEVELS[index])
		var button := _level_buttons[index]
		button.disabled = index >= unlocked
		if button.disabled:
			button.text = UiText.LEVEL_LOCKED % title
		elif best_times[index] >= 0.0:
			button.text = UiText.LEVEL_BEST % [title, UiText.seconds(best_times[index])]
		else:
			button.text = title


func level_button(index: int) -> Button:
	return _level_buttons[index]


func focus_default() -> void:
	_level_buttons[0].grab_focus()


## Reads `level_title` from a level scene without instantiating it.
static func scene_title(path: String) -> String:
	var state := (load(path) as PackedScene).get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == LEVEL_TITLE_PROPERTY:
			return String(state.get_node_property_value(0, i))
	return path.get_file().get_basename()
