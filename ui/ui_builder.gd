class_name UiBuilder
extends RefCounted
## Small helpers that assemble menu screens in code, so every screen script
## reads as a list of rows. Buttons get click/focus sounds here.

const PANEL_MIN_WIDTH := 520.0
const ROW_SEPARATION := 14
const SLIDER_WIDTH := 260.0


## Full-screen centring container holding a themed panel; returns the panel's column.
static func centered_column(parent: Control, min_width: float = PANEL_MIN_WIDTH) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0.0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", ROW_SEPARATION)
	panel.add_child(column)
	return column


static func label(parent: Control, text: String, font_size: int = 0, color: Color = UiTheme.TEXT_COLOR) -> Label:
	var item := Label.new()
	item.text = text
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		item.add_theme_font_size_override(&"font_size", font_size)
	item.add_theme_color_override(&"font_color", color)
	parent.add_child(item)
	return item


static func button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.pressed.connect(_click)
	item.pressed.connect(on_pressed)
	item.focus_entered.connect(_hover)
	parent.add_child(item)
	return item


## "Label ........ [slider]" row; `on_changed` receives the new value.
static func slider_row(parent: Control, text: String, minimum: float, maximum: float, step: float,
		value: float, on_changed: Callable) -> HSlider:
	var row := _row(parent, text)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 0.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_changed)
	row.add_child(slider)
	return slider


static func check_row(parent: Control, text: String, value: bool, on_toggled: Callable) -> CheckButton:
	var row := _row(parent, text)
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.toggled.connect(on_toggled)
	toggle.toggled.connect(func(_on: bool) -> void: _click())
	row.add_child(toggle)
	return toggle


static func _row(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	parent.add_child(row)
	return row


static func _click() -> void:
	if AudioSystem.current != null:
		AudioSystem.current.play(SfxLibrary.Sfx.UI_CLICK)


static func _hover() -> void:
	if AudioSystem.current != null:
		AudioSystem.current.play(SfxLibrary.Sfx.UI_MOVE, -8.0)
