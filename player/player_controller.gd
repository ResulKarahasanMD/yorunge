class_name PlayerController
extends CharacterBody3D
## Kinematic explorer that walks on spherical worlds.
## Every physics tick: sample gravity -> rotate `up_direction` toward the local
## up -> split velocity into vertical/tangential parts -> steer -> jump -> slide.
## The body's own basis is kept aligned (Y = up, -Z = facing) so the capsule
## always stands on the surface. Origin is at the feet.

signal jumped
signal landed(impact_speed: float)
signal dominant_source_changed(source: GravitySource)
signal respawned
## Hazard / enemy bounce (hot foot, stomp, knockback) — juice hooks in (e).
signal bounced

const LOG_TAG := "Player"
const GRAVITY_LOG_TAG := "Gravity"
const MIN_LENGTH_SQ := 0.000001

@export_group("Movement")
@export var move_speed: float = 7.0
@export var ground_acceleration: float = 55.0
@export var ground_deceleration: float = 45.0
@export var air_acceleration: float = 16.0
## Facing turns toward the travel direction at this exponential rate.
@export var turn_sharpness: float = 14.0
## Below this tangential speed the facing is left alone.
@export var facing_min_speed: float = 0.4

@export_group("Jump")
@export var jump_speed: float = 11.0
## Upward speed is multiplied by this when jump is released early.
@export var jump_cut_multiplier: float = 0.45
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var max_fall_speed: float = 35.0

@export_group("Orientation")
@export var up_sharpness_ground: float = 20.0
@export var up_sharpness_air: float = 4.0
@export var floor_snap: float = 0.4
@export var floor_max_angle_deg: float = 50.0

@export_group("Hazards")
## Seconds of continuous contact with a burning surface before it hurts.
@export var burn_time: float = 0.8
## Seconds off the hot surface to cool from full heat to zero.
@export var cool_time: float = 1.0
@export var hot_foot_speed: float = 8.0
@export var knockback_speed: float = 6.0
@export var knockback_lift: float = 5.0

## Assigned by Level together with PlayerInput.bind(); never self-assigned.
var input_source: PlayerInput = null
## Smoothed local "up"; mirrored into CharacterBody3D.up_direction.
var current_up: Vector3 = Vector3.UP
var facing: Vector3 = Vector3.FORWARD
var gravity_sample: GravitySample = GravitySample.new()
var dominant_source: GravitySource = null
## Height of the feet above the dominant body's surface (verification aid).
var surface_altitude: float = 0.0
## Planet under the player, or null while drifting through free space.
var current_planet: Planet = null

## 0..1; reaching 1 on a burning surface costs a heart and bounces the player.
var heat: float = 0.0

@onready var respawn_tracker: RespawnTracker = $RespawnTracker
@onready var health: PlayerHealth = $PlayerHealth

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_cut_done: bool = true
var _was_on_floor: bool = false


func _ready() -> void:
	current_up = global_basis.y.normalized()
	facing = -global_basis.z.normalized()
	up_direction = current_up
	floor_snap_length = floor_snap
	floor_max_angle = deg_to_rad(floor_max_angle_deg)
	floor_stop_on_slope = true
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD


func _physics_process(delta: float) -> void:
	_update_gravity()
	_update_up(delta)
	_apply_steering(delta)
	_apply_jump(delta)
	var pre_slide_velocity := velocity
	move_and_slide()
	_after_slide(pre_slide_velocity)
	_update_heat(delta)
	_update_orientation(delta)


## Teleports to `xform` (feet origin, Y = up) with zero velocity, e.g. after
## getting lost in space. Interpolation is reset so the camera can snap too.
func respawn_at(xform: Transform3D) -> void:
	global_transform = xform
	velocity = Vector3.ZERO
	current_up = xform.basis.y.normalized()
	up_direction = current_up
	facing = -xform.basis.z.normalized()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	reset_physics_interpolation()
	respawned.emit()


## Replaces the vertical speed with `speed` along local up (stomp, hot foot).
func bounce(speed: float) -> void:
	velocity = tangential_velocity() + current_up * speed
	_jump_cut_done = true
	_coyote_timer = 0.0
	bounced.emit()


## Damage from something at `source` (enemy): lose hearts and get knocked away.
func take_hit(damage: int, source: Vector3, cause: String) -> void:
	if not health.take_damage(damage, cause):
		return
	var away := VectorMath.flatten(global_position - source, current_up)
	if away.length_squared() < MIN_LENGTH_SQ:
		away = -facing
	velocity = away.normalized() * knockback_speed + current_up * knockback_lift
	_jump_cut_done = true
	bounced.emit()


func tangential_velocity() -> Vector3:
	return velocity - current_up * velocity.dot(current_up)


func vertical_speed() -> float:
	return velocity.dot(current_up)


func _update_gravity() -> void:
	gravity_sample = GravityResolver.sample(get_tree(), global_position)
	if gravity_sample.dominant != dominant_source:
		dominant_source = gravity_sample.dominant
		current_planet = dominant_source.get_parent() as Planet if dominant_source != null else null
		var source_name := String(current_planet.name) if current_planet != null else "none"
		GameLog.info(GRAVITY_LOG_TAG, "dominant=%s" % source_name)
		dominant_source_changed.emit(dominant_source)
	if dominant_source != null:
		surface_altitude = dominant_source.altitude_of(global_position)


func _update_up(delta: float) -> void:
	var on_floor := is_on_floor()
	var target_up := current_up
	if on_floor and dominant_source != null:
		target_up = dominant_source.up_at(global_position)
	else:
		target_up = gravity_sample.up_or(current_up)
	var sharpness := up_sharpness_ground if on_floor else up_sharpness_air
	# A jump straight at a neighbouring planet reverses gravity exactly; the
	# fallback axis (body right) turns that into a forward flip, not a stall.
	var right := facing.cross(current_up)
	var new_up := VectorMath.rotate_toward(current_up, target_up, 1.0 - exp(-sharpness * delta), right)
	if on_floor:
		# Parallel-transport the velocity with the frame so walking speed stays
		# tangent to the curved surface instead of leaking into "vertical".
		velocity = Quaternion(current_up, new_up) * velocity
	current_up = new_up
	up_direction = current_up


func _apply_steering(delta: float) -> void:
	var up := current_up
	var vertical := velocity.dot(up)
	var tangential := velocity - up * vertical
	var wish := Vector3.ZERO
	if input_source != null:
		wish = input_source.get_move_direction()
	wish = (wish - up * wish.dot(up)).limit_length(1.0)
	var has_wish := wish.length_squared() > MIN_LENGTH_SQ

	if is_on_floor():
		var rate := ground_acceleration if has_wish else ground_deceleration
		rate *= _surface_multiplier(has_wish)
		tangential = tangential.move_toward(wish * move_speed, rate * delta)
	elif has_wish:
		# Air control steers but never brakes, so jump momentum carries across gaps.
		var target := wish * maxf(move_speed, tangential.length())
		tangential = tangential.move_toward(target, air_acceleration * delta)

	velocity = tangential + up * vertical + gravity_sample.acceleration * delta
	var down_speed := -velocity.dot(up)
	if down_speed > max_fall_speed:
		velocity += up * (down_speed - max_fall_speed)


func _surface_multiplier(accelerating: bool) -> float:
	if current_planet == null or current_planet.style == null:
		return 1.0
	var style := current_planet.style
	return style.acceleration_multiplier if accelerating else style.deceleration_multiplier


func _apply_jump(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
	if input_source != null and input_source.consume_jump_pressed():
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity += current_up * (jump_speed - velocity.dot(current_up))
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_jump_cut_done = false
		jumped.emit()

	var rising_speed := velocity.dot(current_up)
	if rising_speed <= 0.0:
		_jump_cut_done = true
	elif not _jump_cut_done and input_source != null and not input_source.is_jump_held():
		velocity -= current_up * rising_speed * (1.0 - jump_cut_multiplier)
		_jump_cut_done = true


func _after_slide(pre_slide_velocity: Vector3) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(maxf(0.0, -pre_slide_velocity.dot(current_up)))
	_was_on_floor = on_floor


func _update_heat(delta: float) -> void:
	var damage := 0
	if is_on_floor() and current_planet != null and current_planet.style != null:
		damage = current_planet.style.contact_damage
	if damage <= 0:
		heat = maxf(0.0, heat - delta / cool_time)
		return
	heat += delta / burn_time
	if heat >= 1.0:
		heat = 0.0
		health.take_damage(damage, "lava")
		bounce(hot_foot_speed)


func _update_orientation(delta: float) -> void:
	var travel := tangential_velocity()
	var weight := 1.0 - exp(-turn_sharpness * delta) if travel.length() > facing_min_speed else 0.0
	facing = turn_facing(facing, travel, current_up, weight)
	global_basis = Basis.looking_at(facing, current_up)


## Turns `current` toward `desired` about `up` by `weight` (0..1) of the signed
## angle between them, and returns a unit vector in the plane perpendicular to
## `up`. Rotating about `up` stays defined for opposite vectors, where slerp's
## axis is not (that produced a tilted body after head bumps).
static func turn_facing(current: Vector3, desired: Vector3, up: Vector3, weight: float) -> Vector3:
	var flat := current - up * current.dot(up)
	if flat.length_squared() < MIN_LENGTH_SQ:
		flat = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD)
	flat = flat.normalized()
	var flat_desired := desired - up * desired.dot(up)
	if weight <= 0.0 or flat_desired.length_squared() < MIN_LENGTH_SQ:
		return flat
	var angle := flat.signed_angle_to(flat_desired, up)
	return flat.rotated(up, angle * clampf(weight, 0.0, 1.0)).normalized()
