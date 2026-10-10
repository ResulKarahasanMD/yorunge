class_name SettingsPanel
extends Control
## Volume, camera sensitivity, invert-Y and fullscreen. Every change applies at
## once through SaveSystem, which writes it to disk debounced (and when the
## screen closes).

signal back_requested

const TITLE_SIZE := 40
const VOLUME_STEP := 0.05
const SENSITIVITY_STEP := 0.05

var sensitivity_slider: HSlider
var back_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var save := SaveSystem.current
	var column := UiBuilder.centered_column(self, 620.0)
	UiBuilder.label(column, UiText.SETTINGS_TITLE, TITLE_SIZE)
	UiBuilder.slider_row(column, UiText.MASTER_VOLUME, 0.0, 1.0, VOLUME_STEP,
		float(save.get_setting("master_volume")), _setter("master_volume"))
	UiBuilder.slider_row(column, UiText.MUSIC_VOLUME, 0.0, 1.0, VOLUME_STEP,
		float(save.get_setting("music_volume")), _setter("music_volume"))
	UiBuilder.slider_row(column, UiText.SFX_VOLUME, 0.0, 1.0, VOLUME_STEP,
		float(save.get_setting("sfx_volume")), _setter("sfx_volume"))
	sensitivity_slider = UiBuilder.slider_row(column, UiText.SENSITIVITY, SaveSystem.MIN_SENSITIVITY,
		SaveSystem.MAX_SENSITIVITY, SENSITIVITY_STEP, float(save.get_setting("sensitivity")), _setter("sensitivity"))
	UiBuilder.check_row(column, UiText.INVERT_Y, bool(save.get_setting("invert_y")), _setter("invert_y"))
	var fullscreen_allowed := DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()
	var fullscreen := UiBuilder.check_row(column, UiText.FULLSCREEN if fullscreen_allowed else UiText.FULLSCREEN_UNAVAILABLE,
		bool(save.get_setting("fullscreen")), _setter("fullscreen"))
	fullscreen.disabled = not fullscreen_allowed
	back_button = UiBuilder.button(column, UiText.BACK, back_requested.emit)


func focus_default() -> void:
	sensitivity_slider.grab_focus()


func _setter(key: String) -> Callable:
	return func(value: Variant) -> void: SaveSystem.current.set_setting(key, value)
