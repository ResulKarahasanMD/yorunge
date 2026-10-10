class_name OrbitCameraRig
extends Node3D
## Third-person camera for spherical worlds.
## The rig keeps its own orthonormal frame (Y = smoothed player up, -Z = yaw
## forward). When the up vector changes the frame is parallel-transported by the
## shortest-arc rotation, so walking over a planet or jumping between planets
## never snaps the yaw. The boom (pivot -> camera) is shape-cast against the
## world every frame; its length eases toward the cast result with a speed cap,
## fast inward and slow outward, so occluders never pop the zoom in one frame.
## Runs in _process on the player's interpolated pose.

const LOG_TAG := "Camera"
const ANTIPARALLEL_DOT := -0.999
## Auto-align ignores travel that would need a turn larger than this
## (running toward the camera should not spin it around).
const AUTO_ALIGN_MAX_ANGLE := deg_to_rad(120.0)
## Smoothing never integrates over more than this, so a frame hitch cannot
## turn into a zoom jump.
const MAX_SMOOTH_DT := 1.0 / 30.0
## Arm length changes smaller than this do not count as an occlusion.
const OCCLUSION_EPSILON := 0.05

@export var target: PlayerController

@export_group("Framing")
@export var distance: float = 8.0
@export var pivot_height: float = 1.3
## Pitch is the boom angle; negative = camera above the pivot looking down.
@export var default_pitch_deg: float = -22.0
## Highest camera (steepest look-down).
@export var min_pitch_deg: float = -65.0
## Lowest camera. Kept below zero so the camera never dips under the pivot,
## where it would hit the ground and lose the horizon (see tests/test_camera.gd).
@export var max_pitch_deg: float = -5.0

@export_group("Boom collision")
@export var collision_radius: float = 0.3
@export var min_arm_length: float = 1.0
@export var zoom_in_sharpness: float = 25.0
@export var zoom_in_max_speed: float = 30.0
@export var zoom_out_sharpness: float = 8.0
@export var zoom_out_max_speed: float = 18.0

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

## Current (smoothed) boom length — what the player sees.
var arm_length: float = 0.0
## Unsmoothed length the shape cast allowed this frame.
var arm_target_length: float = 0.0
## Largest single-frame change of arm_length since the rig started, the raw
## frame delta it happened on, and the largest step/delta ratio (m/s).
var max_arm_step: float = 0.0
var max_arm_step_frame_dt: float = 0.0
var max_arm_speed: float = 0.0
var occlusion_events: int = 0

var _frame: Basis = Basis.IDENTITY
var _pitch: float = 0.0
var _pending_mouse: Vector2 = Vector2.ZERO
var _time_since_look: float = INF
var _occluded: bool = false
var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pitch = deg_to_rad(clampf(default_pitch_deg, min_pitch_deg, max_pitch_deg))
	arm_length = distance
	arm_target_length = distance
	var probe := SphereShape3D.new()
	probe.radius = collision_radius
	_query.shape = probe
	_query.collision_mask = PhysicsLayers.WORLD
	if target != null:
		set_target(target)


func set_target(new_target: PlayerController) -> void:
	target = new_target
	_query.exclude = [target.get_rid()]
	snap_to_target()


## Places the rig directly behind the target with no smoothing (spawn/respawn).
func snap_to_target() -> void:
	_frame = target.global_basis.orthonormalized()
	global_position = target.global_position + _frame.y * pivot_height
	arm_length = _cast_arm_length()
	arm_target_length = arm_length
	_apply_transform()


## Yaw frame (Y = up, -Z = forward on the ground plane) used by HumanInput.
func get_yaw_basis() -> Basis:
	return _frame


## Angle (degrees) of the forward horizon relative to the camera's view axis,
## for a player standing on a sphere of `planet_radius`; negative = below the
## screen centre. Returns -90 when the camera would be inside the planet.
static func horizon_offset_deg(planet_radius: float, pivot_h: float, arm: float, pitch_deg: float) -> float:
	var elevation := deg_to_rad(-pitch_deg)
	var cam_up := planet_radius + pivot_h + arm * sin(elevation)
	var cam_back := arm * cos(elevation)
	var cam_dist := sqrt(cam_up * cam_up + cam_back * cam_back)
	if cam_dist <= planet_radius:
		return -90.0
	var to_center := -atan2(cam_up, cam_back)
	var horizon := to_center + asin(planet_radius / cam_dist)
	return rad_to_deg(horizon + elevation)


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
	_update_arm_length(delta)
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


func _boom_basis() -> Basis:
	return _frame * Basis(Vector3.RIGHT, _pitch)


func _cast_arm_length() -> float:
	var direction := _boom_basis().z
	_query.transform = Transform3D(Basis.IDENTITY, global_position)
	_query.motion = direction * distance
	var fractions := get_world_3d().direct_space_state.cast_motion(_query)
	return clampf(distance * fractions[0], min_arm_length, distance)


## One frame of boom easing: exponential approach toward `target`, with the
## per-frame change capped at speed * min(delta, MAX_SMOOTH_DT). Pure, so the
## bound is unit-tested in tests/test_camera.gd.
static func step_arm_length(current: float, target_length: float, delta: float,
		in_sharpness: float, in_speed: float, out_sharpness: float, out_speed: float) -> float:
	var dt := minf(delta, MAX_SMOOTH_DT)
	var zooming_in := target_length < current
	var sharpness := in_sharpness if zooming_in else out_sharpness
	var max_step := (in_speed if zooming_in else out_speed) * dt
	var eased := lerpf(current, target_length, 1.0 - exp(-sharpness * dt))
	return current + clampf(eased - current, -max_step, max_step)


func _update_arm_length(delta: float) -> void:
	arm_target_length = _cast_arm_length()
	var next := step_arm_length(arm_length, arm_target_length, delta,
		zoom_in_sharpness, zoom_in_max_speed, zoom_out_sharpness, zoom_out_max_speed)
	var step := absf(next - arm_length)
	if step > max_arm_step:
		max_arm_step = step
		max_arm_step_frame_dt = delta
	if delta > 0.0:
		max_arm_speed = maxf(max_arm_speed, step / delta)
	arm_length = next

	var occluded := arm_target_length < distance - OCCLUSION_EPSILON
	if occluded and not _occluded:
		occlusion_events += 1
		GameLog.info(LOG_TAG, "occluded: target=%.2f current=%.2f" % [arm_target_length, arm_length])
	elif not occluded and _occluded:
		GameLog.info(LOG_TAG, "clear: current=%.2f max_step=%.3f (frame dt %.1f ms) max_speed=%.1f m/s" % [
			arm_length, max_arm_step, max_arm_step_frame_dt * 1000.0, max_arm_speed])
	_occluded = occluded


func _apply_transform() -> void:
	global_basis = _frame
	var boom := Basis(Vector3.RIGHT, _pitch)
	camera.transform = Transform3D(boom, boom.z * arm_length)
