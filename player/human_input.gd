class_name HumanInput
extends PlayerInput
## Reads keyboard / mouse / gamepad and turns the stick into a world-space move
## direction relative to the camera's yaw frame, re-projected onto the player's
## tangent plane so "forward" stays meaningful anywhere on a planet.
## While `enabled` is false (a menu is over the level) it reports no movement
## and no jump: the controller polls devices directly, so turning processing
## off is not enough.

@export var camera_rig: OrbitCameraRig

var enabled: bool = true

## A jump still held when control comes back (the button that confirmed a
## menu, e.g. gamepad A) waits for its release instead of jumping at once.
var _jump_latched: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_enabled(value: bool) -> void:
	if value and not enabled:
		_jump_latched = Input.is_action_pressed(InputBindings.JUMP)
	enabled = value
	set_process_unhandled_input(value)


func _unhandled_input(event: InputEvent) -> void:
	# In GameMain the pause menu owns Esc and the mouse; this fallback only
	# matters for dev scenes played on their own: Esc frees the mouse, a click
	# takes it back.
	if event.is_action_pressed(InputBindings.PAUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_move_direction() -> Vector3:
	if not enabled:
		return Vector3.ZERO
	var stick := Input.get_vector(
		InputBindings.MOVE_LEFT, InputBindings.MOVE_RIGHT,
		InputBindings.MOVE_FORWARD, InputBindings.MOVE_BACK)
	if stick == Vector2.ZERO or player == null or camera_rig == null:
		return Vector3.ZERO
	var up := player.current_up
	var yaw := camera_rig.get_yaw_basis()
	var forward := -yaw.z
	forward = (forward - up * forward.dot(up)).normalized()
	var right := forward.cross(up)
	return (right * stick.x - forward * stick.y).limit_length(1.0)


func consume_jump_pressed() -> bool:
	if not enabled or _jump_held_from_menu():
		return false
	return Input.is_action_just_pressed(InputBindings.JUMP)


func is_jump_held() -> bool:
	return enabled and not _jump_held_from_menu() and Input.is_action_pressed(InputBindings.JUMP)


func _jump_held_from_menu() -> bool:
	if _jump_latched and not Input.is_action_pressed(InputBindings.JUMP):
		_jump_latched = false
	return _jump_latched
