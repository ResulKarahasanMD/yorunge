class_name UiTheme
extends RefCounted
## The game's interface theme, built in code (no theme or font files):
## dark navy panels, rounded buttons with a gold focus ring.

const FONT_SIZE := 24
const BUTTON_FONT_SIZE := 26
const CORNER := 14
const BORDER := 2
const MARGIN_X := 22.0
const MARGIN_Y := 12.0
const PANEL_COLOR := Color(0.06, 0.07, 0.16, 0.9)
const PANEL_BORDER := Color(0.55, 0.75, 1.0, 0.55)
const BUTTON_NORMAL := Color(0.16, 0.2, 0.42)
const BUTTON_HOVER := Color(0.25, 0.32, 0.62)
const BUTTON_PRESSED := Color(0.36, 0.46, 0.86)
const BUTTON_DISABLED := Color(0.12, 0.12, 0.18)
const FOCUS_COLOR := Color(1.0, 0.85, 0.4)
const TEXT_COLOR := Color(0.93, 0.95, 1.0)
const TEXT_DISABLED := Color(0.5, 0.52, 0.6)

static var _cached: Theme = null


static func get_theme() -> Theme:
	if _cached == null:
		_cached = _build()
	return _cached


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_font_size(&"font_size", &"Button", BUTTON_FONT_SIZE)
	theme.set_color(&"font_color", &"Label", TEXT_COLOR)
	for type: StringName in [&"Button", &"CheckButton"]:
		theme.set_color(&"font_color", type, TEXT_COLOR)
		theme.set_color(&"font_hover_color", type, Color.WHITE)
		theme.set_color(&"font_focus_color", type, Color.WHITE)
		theme.set_color(&"font_pressed_color", type, Color.WHITE)
		theme.set_color(&"font_disabled_color", type, TEXT_DISABLED)
	theme.set_stylebox(&"normal", &"Button", _box(BUTTON_NORMAL, PANEL_BORDER))
	theme.set_stylebox(&"hover", &"Button", _box(BUTTON_HOVER, PANEL_BORDER))
	theme.set_stylebox(&"pressed", &"Button", _box(BUTTON_PRESSED, FOCUS_COLOR))
	theme.set_stylebox(&"disabled", &"Button", _box(BUTTON_DISABLED, Color(0, 0, 0, 0)))
	theme.set_stylebox(&"focus", &"Button", _focus_ring())
	theme.set_stylebox(&"focus", &"CheckButton", _focus_ring())
	theme.set_stylebox(&"focus", &"HSlider", _focus_ring())
	theme.set_stylebox(&"panel", &"PanelContainer", _box(PANEL_COLOR, PANEL_BORDER))
	return theme


static func _box(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(CORNER)
	box.content_margin_left = MARGIN_X
	box.content_margin_right = MARGIN_X
	box.content_margin_top = MARGIN_Y
	box.content_margin_bottom = MARGIN_Y
	return box


static func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = FOCUS_COLOR
	ring.set_border_width_all(BORDER + 1)
	ring.set_corner_radius_all(CORNER)
	ring.expand_margin_left = 3.0
	ring.expand_margin_right = 3.0
	ring.expand_margin_top = 3.0
	ring.expand_margin_bottom = 3.0
	return ring
