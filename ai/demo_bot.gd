class_name DemoBot
extends PlayerInput
## AI driver for self-testing (Beckett Lite cannot inject input).
## Milestone (a) behaviour: walk a great circle around the current planet and
## hop at a fixed interval. Target seeking (stardust / planets / portal) is
## added in milestone (c) as a new Behavior.

enum Behavior { GREAT_CIRCLE }

const LOG_TAG := "DemoBot"

@export var behavior: Behavior = Behavior.GREAT_CIRCLE
@export var hop_interval: float = 3.0
## Jump is held this long, so hops use the full jump height.
@export var hop_hold_time: float = 0.3
@export var log_interval: float = 1.0

## Exposed for runtime_get_property verification.
var state: StringName = &"idle"
var heading: Vector3 = Vector3.ZERO
var hops: int = 0
var elapsed: float = 0.0

var _hop_timer: float = 0.0
var _hold_timer: float = 0.0
var _jump_queued: bool = false
var _log_timer: float = 0.0


func bind(target: PlayerController) -> void:
	super.bind(target)
	heading = -target.global_basis.z
	GameLog.info(LOG_TAG, "bound to %s, behavior=%s" % [target.name, Behavior.keys()[behavior]])


func _physics_process(delta: float) -> void:
	if player == null:
		return
	elapsed += delta
	_update_heading()
	_update_hops(delta)
	state = &"walk" if player.is_on_floor() else &"air"
	_log_timer += delta
	if _log_timer >= log_interval:
		_log_timer = 0.0
		_log_status()


func get_move_direction() -> Vector3:
	return heading


func consume_jump_pressed() -> bool:
	var queued := _jump_queued
	_jump_queued = false
	return queued


func is_jump_held() -> bool:
	return _hold_timer > 0.0


func _update_heading() -> void:
	# Re-projecting the heading onto the tangent plane every tick is a discrete
	# parallel transport, i.e. the path follows a great circle.
	var up := player.current_up
	var flat := heading - up * heading.dot(up)
	if flat.length_squared() > 0.000001:
		heading = flat.normalized()


func _update_hops(delta: float) -> void:
	_hold_timer -= delta
	_hop_timer += delta
	if _hop_timer >= hop_interval and player.is_on_floor():
		_hop_timer = 0.0
		_jump_queued = true
		_hold_timer = hop_hold_time
		hops += 1


func _log_status() -> void:
	var p := player.global_position
	GameLog.info(LOG_TAG, "t=%.1f state=%s pos=(%.2f, %.2f, %.2f) alt=%.3f speed=%.2f hops=%d" % [
		elapsed, state, p.x, p.y, p.z, player.surface_altitude,
		player.tangential_velocity().length(), hops])
