class_name InputBindings
extends RefCounted
## Registers every input action in code at startup, so bindings are reviewable
## in one place and never depend on hand edits to project.godot.

const MOVE_FORWARD := &"move_forward"
const MOVE_BACK := &"move_back"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const JUMP := &"jump"
const PAUSE := &"pause"
## Built-in UI actions. Godot 4.7 binds them to the keyboard only; gamepad B
## (back) and A (confirm) are added below.
const MENU_BACK := &"ui_cancel"
const MENU_CONFIRM := &"ui_accept"
const LOOK_LEFT := &"look_left"
const LOOK_RIGHT := &"look_right"
const LOOK_UP := &"look_up"
const LOOK_DOWN := &"look_down"

const STICK_DEADZONE := 0.2
## InputMap's "any device" id (not exposed to scripts): every gamepad works.
const ALL_DEVICES := -1


static func register_defaults() -> void:
	_add_action(MOVE_FORWARD, [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action(MOVE_BACK, [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action(MOVE_LEFT, [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action(MOVE_RIGHT, [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action(JUMP, [_key(KEY_SPACE), _joy_button(JOY_BUTTON_A)])
	_add_action(PAUSE, [_key(KEY_ESCAPE), _key(KEY_P), _joy_button(JOY_BUTTON_START)])
	_add_action(LOOK_LEFT, [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add_action(LOOK_RIGHT, [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add_action(LOOK_UP, [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add_action(LOOK_DOWN, [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_add_events(MENU_BACK, [_joy_button(JOY_BUTTON_B)])
	_add_events(MENU_CONFIRM, [_joy_button(JOY_BUTTON_A)])


static func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, STICK_DEADZONE)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


## Extra events for an existing (built-in) action; skips ones already bound.
static func _add_events(action: StringName, events: Array[InputEvent]) -> void:
	for event: InputEvent in events:
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


static func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = ALL_DEVICES
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = ALL_DEVICES
	event.axis = axis
	event.axis_value = direction
	return event
