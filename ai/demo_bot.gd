class_name DemoBot
extends PlayerInput
## AI driver for self-testing (Beckett Lite cannot inject input).
## GREAT_CIRCLE: walk a great circle and hop periodically (sandbox A).
## SEEK: follow Level.demo_goals(). On the goal's planet it walks the great
## circle to the goal (jumping for floating pickups and onto enemies); on other
## planets it walks to the launch point facing the next planet of a PlanetGraph
## path, slows down, jumps straight at it and steers in the air. When every
## goal is a Planet (no pickups in the level) it tours them in order.
## Hazards: hops off burning ground before it hurts, and jumps at enemies ahead,
## steering onto them in the air to stomp.

enum Behavior { GREAT_CIRCLE, SEEK }
enum Phase { IDLE, WALK, LAUNCH, AIRBORNE }

const LOG_TAG := "DemoBot"
const MIN_LENGTH_SQ := 0.000001

@export var behavior: Behavior = Behavior.SEEK
@export var log_interval: float = 1.0

@export_group("Great circle")
@export var hop_interval: float = 3.0

@export_group("Seek")
## Jump when the local up is within this angle of the direction to the next planet.
@export var launch_angle_deg: float = 4.0
## Start slowing down this far (angle) from the launch point.
@export var launch_slowdown_deg: float = 20.0
@export var launch_max_speed: float = 1.5
## Floating goals at least this high above the feet need a jump when close.
@export var pickup_jump_altitude: float = 1.6
@export var pickup_jump_distance: float = 1.4
@export var enemy_jump_distance: float = 2.4
## Hop off burning ground once the player's heat passes this (0..1).
@export var heat_hop_threshold: float = 0.4
## Launch angle allowed when leaving burning ground (no slow approach there).
@export var hot_launch_angle_deg: float = 8.0
@export var jump_hold_time: float = 0.6
@export var stuck_jump_time: float = 2.0
@export var stuck_skip_time: float = 7.0
@export var max_hop_failures: int = 4

## Exposed for runtime_get_property verification.
var level: Level = null
var state: StringName = &"idle"
var goal: Node3D = null
var hop_target: Planet = null
var hops: int = 0
var hops_landed: int = 0
var hop_failures: int = 0
var goals_reached: int = 0
var goals_skipped: int = 0
var stomp_attempts: int = 0
var elapsed: float = 0.0

var _phase: Phase = Phase.IDLE
var _wish: Vector3 = Vector3.ZERO
var _heading: Vector3 = Vector3.ZERO
var _jump_queued: bool = false
var _hold_timer: float = 0.0
var _log_timer: float = 0.0
var _hop_timer: float = 0.0
var _launch_from: Planet = null
var _tour_index: int = -1
var _skipped: Array[Node3D] = []
var _best_distance: float = INF
var _stuck_timer: float = 0.0
var _stomp_target: Node3D = null


func bind(target: PlayerController) -> void:
	super.bind(target)
	_heading = -target.global_basis.z
	GameLog.info(LOG_TAG, "bound to %s, behavior=%s" % [target.name, Behavior.keys()[behavior]])


func get_move_direction() -> Vector3:
	return _wish


func consume_jump_pressed() -> bool:
	var queued := _jump_queued
	_jump_queued = false
	return queued


func is_jump_held() -> bool:
	return _hold_timer > 0.0


func _physics_process(delta: float) -> void:
	if player == null:
		return
	elapsed += delta
	_hold_timer -= delta
	if behavior == Behavior.GREAT_CIRCLE or level == null:
		_great_circle(delta)
	else:
		_seek(delta)
	_log_timer += delta
	if _log_timer >= log_interval:
		_log_timer = 0.0
		_log_status()


# --- Great circle (milestone a) ------------------------------------------------

func _great_circle(delta: float) -> void:
	var flat := VectorMath.flatten(_heading, player.current_up)
	if flat.length_squared() > MIN_LENGTH_SQ:
		_heading = flat.normalized()
	_wish = _heading
	_hop_timer += delta
	if _hop_timer >= hop_interval and player.is_on_floor():
		_hop_timer = 0.0
		hops += 1
		_press_jump()
	state = &"walk" if player.is_on_floor() else &"air"


# --- Seek ------------------------------------------------------------------------

func _seek(delta: float) -> void:
	if goal == null or not is_instance_valid(goal) or not level.is_goal_active(goal):
		_pick_goal()
	if goal == null:
		_wish = Vector3.ZERO
		state = &"idle"
		return
	var goal_planet := level.planet_of(goal)
	if not player.is_on_floor():
		if _phase != Phase.AIRBORNE and _phase != Phase.LAUNCH:
			_phase = Phase.AIRBORNE
		_steer_in_air(goal_planet)
		state = &"air"
		return
	if _phase == Phase.LAUNCH or _phase == Phase.AIRBORNE:
		_on_landed()
	_phase = Phase.WALK
	_stomp_target = null
	var here := player.current_planet
	if here == null:
		_wish = Vector3.ZERO
		return
	if here == goal_planet:
		hop_target = null
		_walk_to_goal(delta)
	else:
		_walk_to_launch(here, goal_planet)


func _pick_goal() -> void:
	var candidates: Array[Node3D] = []
	for node: Node3D in level.demo_goals():
		if not _skipped.has(node):
			candidates.append(node)
	if candidates.is_empty() and not _skipped.is_empty():
		_skipped.clear()
		candidates = level.demo_goals()
	goal = null
	if candidates.is_empty():
		return
	if candidates.all(func(node: Node3D) -> bool: return node is Planet):
		goal = _next_tour_planet(candidates)
	else:
		goal = _cheapest(candidates)
	_best_distance = INF
	_stuck_timer = 0.0
	hop_failures = 0
	if goal != null:
		GameLog.info(LOG_TAG, "goal -> %s on %s" % [goal.name, level.planet_of(goal).name])


func _next_tour_planet(planets: Array[Node3D]) -> Node3D:
	for step in planets.size():
		_tour_index = (_tour_index + 1) % planets.size()
		if planets[_tour_index] != player.current_planet:
			return planets[_tour_index]
	return null


func _cheapest(candidates: Array[Node3D]) -> Node3D:
	var here := player.current_planet
	var best: Node3D = null
	var best_cost := INF
	for node: Node3D in candidates:
		var hops_needed := maxi(level.planet_path(here, level.planet_of(node)).size() - 1, 0) if here != null else 0
		var cost := hops_needed * 100.0 + player.global_position.distance_to(node.global_position)
		if cost < best_cost:
			best_cost = cost
			best = node
	return best


func _walk_to_goal(delta: float) -> void:
	state = &"walk"
	if goal is Planet:
		_goal_reached()
		return
	var up := player.current_up
	var to_goal := goal.global_position - player.global_position
	var flat := VectorMath.flatten(to_goal, up)
	if flat.length_squared() < MIN_LENGTH_SQ:
		flat = player.facing
	_wish = flat.normalized()
	if flat.length() < pickup_jump_distance and to_goal.dot(up) > pickup_jump_altitude:
		_press_jump()
	_avoid_hazards(up)
	_update_stuck(delta, to_goal.length())


func _walk_to_launch(here: Planet, goal_planet: Planet) -> void:
	var path := level.planet_path(here, goal_planet)
	hop_target = path[1] if path.size() > 1 else goal_planet
	var up := player.current_up
	var hop_dir := (hop_target.global_position - here.global_position).normalized()
	var angle := rad_to_deg(up.angle_to(hop_dir))
	var flat := VectorMath.flatten(hop_dir, up)
	var scale := clampf(angle / launch_slowdown_deg, 0.15, 1.0)
	_wish = flat.normalized() * scale if flat.length_squared() > MIN_LENGTH_SQ else Vector3.ZERO
	state = &"to_launch"
	var burning := player.heat > 0.0
	var ready_to_launch := angle <= hot_launch_angle_deg if burning else (
		angle <= launch_angle_deg and player.tangential_velocity().length() <= launch_max_speed)
	if ready_to_launch:
		hops += 1
		_launch_from = here
		_phase = Phase.LAUNCH
		state = &"launch"
		_press_jump()
		GameLog.info(LOG_TAG, "hop #%d %s -> %s (gap %.2f m)" % [
			hops, here.name, hop_target.name, PlanetGraph.surface_gap(
				here.global_position, here.radius, hop_target.global_position, hop_target.radius)])
	else:
		_avoid_hazards(up)


func _steer_in_air(goal_planet: Planet) -> void:
	var aim: Vector3
	if _stomp_target != null and is_instance_valid(_stomp_target):
		aim = _stomp_target.global_position
	elif player.current_planet == goal_planet and not (goal is Planet):
		aim = goal.global_position
	elif hop_target != null:
		aim = hop_target.global_position
	else:
		aim = goal_planet.global_position
	var flat := VectorMath.flatten(aim - player.global_position, player.current_up)
	_wish = flat.normalized() if flat.length_squared() > 0.01 else Vector3.ZERO


func _on_landed() -> void:
	if _launch_from == null:
		return
	var landed_on := player.current_planet
	if landed_on == hop_target:
		hops_landed += 1
		hop_failures = 0
		GameLog.info(LOG_TAG, "hop landed on %s" % landed_on.name)
	elif landed_on != _launch_from or hop_target != null:
		hop_failures += 1
		GameLog.info(LOG_TAG, "hop missed: aimed %s, landed on %s (failures %d)" % [
			hop_target.name if hop_target != null else "?", landed_on.name if landed_on != null else "none", hop_failures])
		if hop_failures >= max_hop_failures:
			_skip_goal("too many missed hops")
	_launch_from = null


func _goal_reached() -> void:
	goals_reached += 1
	GameLog.info(LOG_TAG, "reached %s (%d)" % [goal.name, goals_reached])
	goal = null


func _skip_goal(reason: String) -> void:
	if goal == null:
		return
	goals_skipped += 1
	GameLog.warn(LOG_TAG, "skipping %s: %s" % [goal.name, reason])
	_skipped.append(goal)
	goal = null


func _update_stuck(delta: float, distance: float) -> void:
	if distance < _best_distance - 0.3:
		_best_distance = distance
		_stuck_timer = 0.0
		return
	_stuck_timer += delta
	if _stuck_timer >= stuck_skip_time:
		_skip_goal("no progress for %.0f s" % stuck_skip_time)
	elif _stuck_timer >= stuck_jump_time and player.is_on_floor():
		_press_jump()


func _avoid_hazards(up: Vector3) -> void:
	if player.heat > heat_hop_threshold:
		_press_jump()
		return
	var enemy := _enemy_ahead(up, _wish)
	if enemy != null and player.is_on_floor():
		_stomp_target = enemy
		stomp_attempts += 1
		_press_jump()


func _enemy_ahead(up: Vector3, direction: Vector3) -> Node3D:
	if direction.length_squared() < MIN_LENGTH_SQ:
		return null
	for enemy: Node3D in level.demo_threats():
		var to_enemy := enemy.global_position - player.global_position
		var flat := VectorMath.flatten(to_enemy, up)
		if flat.length() < enemy_jump_distance and flat.normalized().dot(direction.normalized()) > 0.6:
			return enemy
	return null


func _press_jump() -> void:
	if not player.is_on_floor() or _hold_timer > 0.0:
		return
	_jump_queued = true
	_hold_timer = jump_hold_time


func _log_status() -> void:
	var p := player.global_position
	var planet_name := String(player.current_planet.name) if player.current_planet != null else "none"
	var goal_label := String(goal.name) if goal != null and is_instance_valid(goal) else "-"
	GameLog.info(LOG_TAG, "t=%.1f state=%s planet=%s goal=%s hops=%d/%d pos=(%.2f, %.2f, %.2f) alt=%.3f speed=%.2f" % [
		elapsed, state, planet_name, goal_label, hops_landed, hops, p.x, p.y, p.z,
		player.surface_altitude, player.tangential_velocity().length()])
