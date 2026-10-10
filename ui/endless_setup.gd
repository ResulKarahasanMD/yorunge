class_name EndlessSetup
extends Control
## Endless mode start screen: type a seed (a number, or any word, which is
## hashed) or roll a random one; shows the deepest level reached so far.

signal start_requested(base_seed: int)
signal back_requested

const TITLE_SIZE := 44
const SEED_MASK := 0x7fffffff
const RANDOM_SEED_MAX := 999999

var seed_field: LineEdit
var start_button: Button

var _best_label: Label
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var column := UiBuilder.centered_column(self, 460.0)
	UiBuilder.label(column, UiText.ENDLESS_TITLE, TITLE_SIZE)
	UiBuilder.label(column, UiText.SEED_LABEL)
	seed_field = LineEdit.new()
	seed_field.placeholder_text = UiText.SEED_PLACEHOLDER
	seed_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_field.text_submitted.connect(func(_text: String) -> void: _start())
	column.add_child(seed_field)
	UiBuilder.button(column, UiText.RANDOM_SEED, _roll)
	start_button = UiBuilder.button(column, UiText.START, _start)
	_best_label = UiBuilder.label(column, "")
	UiBuilder.button(column, UiText.BACK, back_requested.emit)
	_rng.randomize()


func refresh(best_depth: int) -> void:
	_best_label.text = UiText.BEST_DEPTH % best_depth
	if seed_field.text.strip_edges().is_empty():
		_roll()


func focus_default() -> void:
	start_button.grab_focus()


## Numbers are used as typed; any other text is hashed to a seed.
static func parse_seed(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_valid_int():
		return absi(trimmed.to_int()) & SEED_MASK
	return hash(trimmed) & SEED_MASK


func _roll() -> void:
	seed_field.text = str(_rng.randi_range(1, RANDOM_SEED_MAX))


func _start() -> void:
	start_requested.emit(parse_seed(seed_field.text))
