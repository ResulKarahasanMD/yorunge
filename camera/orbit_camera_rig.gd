class_name OrbitCameraRig
extends Node3D
## Third-person camera for spherical worlds.
## The rig keeps its own orthonormal frame (Y = smoothed player up, -Z = yaw
## forward). When the up vector changes the frame is parallel-transported by the
## shortest-arc rotation, so walking over a planet or jumping between planets
## never snaps the yaw. Pitch lives on the SpringArm3D, which also keeps the
## camera out of planets. Runs in _process on the player's interpolated pose.

const LOG_TAG := "Camera"
const ANTIPARALLEL_DOT := -0.999
## Auto-align ignores travel that would need a turn larger than this
## (running toward the camera should not spin it around).
const AUTO_ALIGN_MAX_ANGLE := deg_to_rad(120.0)

@export var target: PlayerController

@export_group("Framing")
@export var distance: float = 8.0
@export var pivot_height: float = 1.3
@export var default_pitch_deg: float = -20.0
@export var min_pitch_deg: float = -75.0
@export var max_pitch_deg: float = 30.0

@export_group("Smoothing")
@export var follow_sharpness: float = 14.0
@export var up_sharpness: float = 5.0

@export_group("Look")
## Radians per mouse pixel at sensitivity_scale = 1.
@export var mouse_radians_per_pixel: float = 0.0025
@export var stick_speed_deg: float = 160.0
## User setting multiplier (Settings > Sensitivity).
@export var sensitivity_scale: float = 1.0
@export var invert_y: bool = false

@export_group("Auto align")
@export var auto_align_delay: float = 1.2
@export var auto_align_sharpness: float = 1.8
@export var auto_align_min_speed: float = 1.0

var _frame: Basis = Basis.IDENTITY
var _pitch: float = 0.0
var _pending_mouse: Vector2 = Vector2.ZERO
var _time_since_look: float = INF

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pitch = deg_to_rad(default_pitch_deg)
	_spring_arm.collision_mask = PhysicsLayers.WORLD
	if target != null:
		set_target(target)


func set_target(new_target: PlayerController) -> void:
	target = new_target
	_spring_arm.clear_excluded_objects()
	_spring_arm.add_excluded_object(target.get_rid())
	snap_to_target()


## Places the rig directly behind the target with no smoothing (spawn/respawn).
func snap_to_target() -> void:
	_frame = target.global_basis.orthonormalized()
	global_position = target.global_position + _frame.y * pivot_height
	_apply_transform()


## Yaw frame (Y = up, -Z = forward on the ground plane) used by HumanInput.
func get_yaw_basis() -> Basis:
	return _frame


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pending_mouse += motion.relative


func _process(delta: float) -> void:
	if target == null:
		return
	var look := _consume_look(delta)
	var pose := target.get_global_transform_interpolated()

	_transport_frame(target.current_up, delta)
	if not is_zero_approx(look.x):
		_frame = _frame.rotated(_frame.y, -look.x).orthonormalized()
	_auto_align(delta)
	_pitch = clampf(_pitch - look.y, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

	var pivot := pose.origin + _frame.y * pivot_height
	global_position = global_position.lerp(pivot, 1.0 - exp(-follow_sharpness * delta))
	_apply_transform()


func _consume_look(delta: float) -> Vector2:
	var look := _pending_mouse * mouse_radians_per_pixel
	_pending_mouse = Vector2.ZERO
	var stick := Input.get_vector(
		InputBindings.LOOK_LEFT, InputBindings.LOOK_RIGHT,
		InputBindings.LOOK_UP, InputBindings.LOOK_DOWN)
	look += stick * deg_to_rad(stick_speed_deg) * delta
	look *= sensitivity_scale
	if invert_y:
		look.y = -look.y
	if look.length_squared() > 0.0:
		_time_since_look = 0.0
	else:
		_time_since_look += delta
	return look


func _transport_frame(target_up: Vector3, delta: float) -> void:
	var old_up := _frame.y
	if target_up.dot(old_up) < ANTIPARALLEL_DOT:
		return
	var new_up := old_up.slerp(target_up, 1.0 - exp(-up_sharpness * delta)).normalized()
	_frame = (Basis(Quaternion(old_up, new_up)) * _frame).orthonormalized()


func _auto_align(delta: float) -> void:
	if _time_since_look < auto_align_delay:
		return
	var travel := target.tangential_velocity()
	travel -= _frame.y * travel.dot(_frame.y)
	if travel.length() < auto_align_min_speed:
		return
	var forward := -_frame.z
	var angle := forward.signed_angle_to(travel.normalized(), _frame.y)
	if absf(angle) > AUTO_ALIGN_MAX_ANGLE:
		return
	var step := angle * (1.0 - exp(-auto_align_sharpness * delta))
	_frame = _frame.rotated(_frame.y, step).orthonormalized()


func _apply_transform() -> void:
	global_basis = _frame
	_spring_arm.rotation = Vector3(_pitch, 0.0, 0.0)
	_spring_arm.spring_length = distance
