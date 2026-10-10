class_name OrbitCameraRig
extends Node3D
## Third-person camera for spherical worlds.
## The rig keeps its own orthonormal frame (Y = smoothed player up, -Z = yaw
## forward). When the up vector changes the frame is parallel-transported by the
## shortest-arc rotation, so walking over a planet or jumping between planets
## never snaps the yaw.
##
## Placement: the ideal camera point hangs off a smoothed pivot on a boom of
## `distance`. The camera sits on the line from the player's head to that point.
## A probe sphere is swept along it (from a head point made safe by a sweep up
## from the chest, which is inside the capsule and therefore always free), and
## the distance is shortened further until the chest is also in plain sight.
## An occluder pulls the camera in on the same frame, so the view is never
## blocked; when it clears, the distance eases back out with a speed cap.
##
## Pitch: one user value from steep look-down to look-up. The boom itself never
## rises above a per-planet ceiling (computed so the whole boom keeps
## `ground_clearance` over the sphere); pitch beyond that ceiling tilts the
## camera instead of lowering it further. tests/test_camera.gd proves the
## horizon and the player stay in frame over the full range.
## Runs in _process on the player's interpolated pose.

const LOG_TAG := "Camera"
## Auto-align ignores travel that would need a turn larger than this
## (running toward the camera should not spin it around).
const AUTO_ALIGN_MAX_ANGLE := deg_to_rad(120.0)
## Outward easing never integrates over more than this, so a frame hitch
## cannot turn into a zoom jump.
const MAX_SMOOTH_DT := 1.0 / 30.0
## Distance changes smaller than this do not count as an occlusion.
const OCCLUSION_EPSILON := 0.05
const CEILING_SEARCH_MIN_DEG := -5.0
const CEILING_SEARCH_MAX_DEG := 89.0
const CEILING_SEARCH_STEPS := 32
## Height above the feet of the chest point: inside the capsule (always free)
## and the second sight line the camera keeps clear.
const CHEST_HEIGHT := 0.75
const SIGHT_SEARCH_STEPS := 10

@export var target: PlayerController

@export_group("Framing")
@export var distance: float = 8.0
@export var pivot_height: float = 1.3
## View pitch; negative = looking down (camera above the pivot), positive = looking up.
@export var default_pitch_deg: float = -22.0
@export var min_pitch_deg: float = -65.0
@export var max_pitch_deg: float = 25.0
## Boom ceiling used while no planet is dominant (free fall between worlds).
@export var free_space_boom_ceiling_deg: float = -5.0
## How fast the boom ceiling follows a change of planet.
@export var ceiling_sharpness: float = 3.0

@export_group("Collision")
@export var collision_radius: float = 0.3
## Extra distance the boom keeps from the planet surface beyond collision_radius.
@export var ground_clearance: float = 0.2
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

@export_group("Debug")
## Ray-tests camera -> player head and chest every frame and counts blocked frames.
@export var track_visibility: bool = false

## Current anchor -> camera distance (what the player sees).
var view_distance: float = 0.0
## Unobstructed anchor -> ideal-camera distance this frame.
var allowed_distance: float = 0.0
## Anchor -> ideal-camera distance if nothing were in the way.
var full_distance: float = 0.0
var occlusion_events: int = 0
## Largest single-frame outward step while easing back after an occlusion.
var max_ease_out_step: float = 0.0
## Largest single-frame increase of view_distance for any reason.
var max_distance_increase: float = 0.0
## Visibility statistics (only while track_visibility is on).
var view_frames: int = 0
var occluded_frames: int = 0
var blocked_head_frames: int = 0
var blocked_body_frames: int = 0

var _frame: Basis = Basis.IDENTITY
var _smoothed_pivot: Vector3 = Vector3.ZERO
var _pitch: float = 0.0
var _boom_ceiling_deg: float = 0.0
var _ceiling_radius: float = -1.0
var _ceiling_for_radius: float = 0.0
var _pending_mouse: Vector2 = Vector2.ZERO
var _time_since_look: float = INF
var _occluded: bool = false
var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pitch = deg_to_rad(clampf(default_pitch_deg, min_pitch_deg, max_pitch_deg))
	_boom_ceiling_deg = free_space_boom_ceiling_deg
	var probe := SphereShape3D.new()
	probe.radius = collision_radius
	_query.shape = probe
	_query.collision_mask = PhysicsLayers.WORLD
	if target != null:
		set_target(target)


func _exit_tree() -> void:
	if track_visibility:
		GameLog.info(LOG_TAG, "visibility: frames=%d occluded_frames=%d blocked_head=%d blocked_body=%d occlusions=%d max_ease_out_step=%.3f max_distance_increase=%.3f" % [
			view_frames, occluded_frames, blocked_head_frames, blocked_body_frames,
			occlusion_events, max_ease_out_step, max_distance_increase])


func set_target(new_target: PlayerController) -> void:
	target = new_target
	_query.exclude = [target.get_rid()]
	snap_to_target()


## Places the rig directly behind the target with no smoothing (spawn/respawn).
func snap_to_target() -> void:
	_frame = target.global_basis.orthonormalized()
	_smoothed_pivot = target.global_position + _frame.y * pivot_height
	_boom_ceiling_deg = _target_ceiling_deg()
	view_distance = INF
	_place_camera(target.global_transform, 0.0)


## Yaw frame (Y = up, -Z = forward on the ground plane) used by HumanInput.
func get_yaw_basis() -> Basis:
	return _frame


# --- Pure geometry (unit-tested) -------------------------------------------
# All angles in degrees. A camera orbits a pivot `pivot_h` above the top of a
# sphere of radius `radius`; boom pitch < 0 puts it above the pivot.

## Smallest distance between the boom segment (pivot -> camera) and the sphere surface.
static func boom_clearance(radius: float, pivot_h: float, arm: float, boom_pitch_deg: float) -> float:
	var elevation := deg_to_rad(-boom_pitch_deg)
	var pivot := Vector2(radius + pivot_h, 0.0)
	var cam := Vector2(radius + pivot_h + arm * sin(elevation), arm * cos(elevation))
	var seg := cam - pivot
	var t := clampf(-pivot.dot(seg) / seg.length_squared(), 0.0, 1.0)
	return (pivot + seg * t).length() - radius


## Highest boom pitch whose whole segment stays `required` above the sphere.
static func boom_ceiling_deg(radius: float, pivot_h: float, arm: float, required: float) -> float:
	var low := CEILING_SEARCH_MIN_DEG
	var high := CEILING_SEARCH_MAX_DEG
	if boom_clearance(radius, pivot_h, arm, high) >= required:
		return high
	for i in CEILING_SEARCH_STEPS:
		var mid := (low + high) * 0.5
		if boom_clearance(radius, pivot_h, arm, mid) >= required:
			low = mid
		else:
			high = mid
	return low


## Forward horizon relative to the view axis for a camera whose boom pitch is
## `boom_pitch_deg` and whose view pitch is `view_pitch_deg` (the difference is
## camera tilt). Negative = below screen centre; -90 when inside the planet.
static func horizon_offset_deg(radius: float, pivot_h: float, arm: float,
		boom_pitch_deg: float, view_pitch_deg: float) -> float:
	var elevation := deg_to_rad(-boom_pitch_deg)
	var cam_up := radius + pivot_h + arm * sin(elevation)
	var cam_back := arm * cos(elevation)
	var cam_dist := sqrt(cam_up * cam_up + cam_back * cam_back)
	if cam_dist <= radius:
		return -90.0
	var horizon := -atan2(cam_up, cam_back) + asin(radius / cam_dist)
	return rad_to_deg(horizon) - view_pitch_deg


## One frame of camera distance: snap in to an occluder immediately, ease out
## with an exponential approach capped at out_speed * min(delta, MAX_SMOOTH_DT).
static func step_arm_length(current: float, target_length: float, delta: float,
		out_sharpness: float, out_speed: float) -> float:
	if target_length <= current:
		return target_length
	var dt := minf(delta, MAX_SMOOTH_DT)
	var eased := lerpf(current, target_length, 1.0 - exp(-out_sharpness * dt))
	return current + minf(eased - current, out_speed * dt)


# --- Runtime -----------------------------------------------------------------

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
	# Mouse/stick "up" (negative y) raises the view.
	_pitch = clampf(_pitch - look.y, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	_boom_ceiling_deg = lerpf(_boom_ceiling_deg, _target_ceiling_deg(), 1.0 - exp(-ceiling_sharpness * delta))

	var pivot := pose.origin + _frame.y * pivot_height
	_smoothed_pivot = _smoothed_pivot.lerp(pivot, 1.0 - exp(-follow_sharpness * delta))
	_place_camera(pose, delta)
	if track_visibility:
		_track_visibility(pose)


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
	# Fallback axis = frame right, so a full gravity flip swings the camera over
	# the top instead of freezing.
	var new_up := VectorMath.rotate_toward(old_up, target_up, 1.0 - exp(-up_sharpness * delta), _frame.x)
	if old_up.is_equal_approx(new_up):
		return
	var axis := old_up.cross(new_up)
	if axis.length_squared() < VectorMath.MIN_LENGTH_SQ:
		axis = _frame.x
	_frame = (Basis(axis.normalized(), old_up.angle_to(new_up)) * _frame).orthonormalized()


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


func _target_ceiling_deg() -> float:
	var planet := target.current_planet if target != null else null
	if planet == null:
		return free_space_boom_ceiling_deg
	if not is_equal_approx(planet.radius, _ceiling_radius):
		_ceiling_radius = planet.radius
		_ceiling_for_radius = boom_ceiling_deg(planet.radius, pivot_height, distance,
			collision_radius + ground_clearance)
	return _ceiling_for_radius


func _place_camera(pose: Transform3D, delta: float) -> void:
	global_position = _smoothed_pivot
	global_basis = _frame
	# Position follows the (ceiling-limited) boom; orientation follows the full
	# view pitch, so pitch above the ceiling becomes a camera tilt.
	var boom_pitch := minf(_pitch, deg_to_rad(_boom_ceiling_deg))
	var ideal := _smoothed_pivot + _frame * (Basis(Vector3.RIGHT, boom_pitch).z * distance)
	var up := pose.basis.y.normalized()
	var chest := pose.origin + up * CHEST_HEIGHT
	var head_motion := up * (pivot_height - CHEST_HEIGHT)
	var anchor := chest + head_motion * _sweep_fraction(chest, head_motion)
	var ray := ideal - anchor
	var previous_full := full_distance
	full_distance = ray.length()
	var direction := ray / full_distance if full_distance > 0.0 else _frame.z
	allowed_distance = _chest_visible_distance(chest, anchor, direction,
		full_distance * _sweep_fraction(anchor, ray))

	var previous := view_distance
	if allowed_distance < view_distance or view_distance >= previous_full - OCCLUSION_EPSILON:
		# Occluder: snap in. In sync with the boom: follow it rigidly.
		view_distance = allowed_distance
	else:
		view_distance = step_arm_length(view_distance, allowed_distance, delta, zoom_out_sharpness, zoom_out_max_speed)
		max_ease_out_step = maxf(max_ease_out_step, view_distance - previous)
	if is_finite(previous) and view_distance > previous:
		max_distance_increase = maxf(max_distance_increase, view_distance - previous)
	_update_occlusion_state()

	camera.global_transform = Transform3D(_frame * Basis(Vector3.RIGHT, _pitch), anchor + direction * view_distance)


## Longest distance <= `limit` along `direction` from `anchor` at which the
## chest is still in plain sight (binary search; only runs when blocked).
func _chest_visible_distance(chest: Vector3, anchor: Vector3, direction: Vector3, limit: float) -> float:
	var space := get_world_3d().direct_space_state
	if not _ray_blocked(space, anchor + direction * limit, chest):
		return limit
	var low := 0.0
	var high := limit
	for i in SIGHT_SEARCH_STEPS:
		var mid := (low + high) * 0.5
		if _ray_blocked(space, anchor + direction * mid, chest):
			high = mid
		else:
			low = mid
	return low


## Fraction (0..1) of `motion` the probe sphere can travel from `from` unblocked.
func _sweep_fraction(from: Vector3, motion: Vector3) -> float:
	if motion.length_squared() < 0.000001:
		return 1.0
	_query.transform = Transform3D(Basis.IDENTITY, from)
	_query.motion = motion
	return get_world_3d().direct_space_state.cast_motion(_query)[0]


func _update_occlusion_state() -> void:
	var occluded := allowed_distance < full_distance - OCCLUSION_EPSILON
	if occluded and not _occluded:
		occlusion_events += 1
		GameLog.info(LOG_TAG, "occluded: %.2f of %.2f m" % [allowed_distance, full_distance])
	_occluded = occluded


func _track_visibility(pose: Transform3D) -> void:
	view_frames += 1
	if _occluded:
		occluded_frames += 1
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var up := pose.basis.y.normalized()
	if _ray_blocked(space, from, pose.origin + up * pivot_height):
		blocked_head_frames += 1
	if _ray_blocked(space, from, pose.origin + up * CHEST_HEIGHT):
		blocked_body_frames += 1


func _ray_blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD, [target.get_rid()])
	return not space.intersect_ray(ray).is_empty()
