class_name DemoBot
extends PlayerInput
## AI driver for self-testing (Beckett Lite cannot inject input).
## GREAT_CIRCLE: walk a great circle and hop periodically (sandbox A).
## SEEK: follow Level.demo_goals(). On the goal's planet it walks the great
## circle to the goal (jumping for floating pickups and onto enemies); on other
## planets it walks to the launch point facing the next planet of a PlanetGraph
## path, slows down, jumps straight at it and steers in the air. When every
## goal is a Planet (no pickups in the level) it tours them in order.
## Hazards: hops off burning ground before it hurts. Enemies: plans a stomp
## from the ball's patrol (where it will be when a jump comes down on it),
## jumps once that landing is reachable and steers onto the predicted spot in
## the air; hops when a ball it cannot stomp is about to touch it.

enum Behavior { GREAT_CIRCLE, SEEK }
enum Phase { IDLE, WALK, LAUNCH, AIRBORNE }

const LOG_TAG := "DemoBot"
const MIN_LENGTH_SQ := 0.000001
## Smallest improvement that counts as progress for stuck detection.
const STUCK_PROGRESS := 0.3
## Picking the next goal, one hop costs as much as walking this far (metres).
const HOP_COST := 100.0
## Closer than this (squared, metres) to the aim point in the air: no steering.
const MIN_AIM_DISTANCE_SQ := 0.01

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
## Hop off burning ground once the player's heat passes this (0..1).
@export var heat_hop_threshold: float = 0.4
## Launch angle allowed when leaving burning ground (no slow approach there).
@export var hot_launch_angle_deg: float = 8.0
## Walk at least this much faster than a spinning surface moves under us.
@export var surface_speed_margin: float = 1.0
## When the launch angle stops improving, take a sloppy launch within this angle.
@export var stuck_launch_angle_deg: float = 20.0
## No heat hops while the local up points within this angle of a planet in
## jump reach: such a hop would fling the player back across the gap.
@export var hot_hop_cone_deg: float = 40.0
@export var jump_hold_time: float = 0.6
@export var stuck_jump_time: float = 2.0
@export var stuck_skip_time: float = 7.0
@export var max_hop_failures: int = 4

@export_group("Stomp")
## Enemies further than this along the surface are ignored.
@export var stomp_engage_distance: float = 8.0
## The feet line up over the ball this far above its top, then come down on
## it: contact is seen a tick or two late at falling speed, so it must be square.
@export var stomp_align_height: float = 0.6
## Share of the air acceleration a planned stomp may need (curvature margin).
@export var stomp_control_margin: float = 0.6
## No stomp jumps where a neighbour's pull bends the arc: gravity along up
## at every probe height above the take-off point must keep this share of the
## planet's own pull.
@export var stomp_clean_gravity: float = 0.9
@export var stomp_probe_heights: PackedFloat32Array = PackedFloat32Array([0.5, 1.5, 2.5])
## The landing spot must lie within this angle of the current heading.
@export var stomp_max_turn_deg: float = 50.0
## Steering never divides by less time than this (the needed speed blows up).
@export var stomp_min_steer_time: float = 0.12
## A ball that will come this close (centre to feet) within `evade_time`
## without a stomp in reach makes the bot hop.
@export var evade_distance: float = 1.5
@export var evade_time: float = 0.4

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
## Jumps started to stomp a ball / to hop out of one's way.
var stomp_attempts: int = 0
var evade_hops: int = 0
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
var _stomp_enemy: SpikeBall = null
## What the stuck timer is measuring (goal walk vs a specific launch).
var _progress_key: String = ""


func _ready() -> void:
	if level != null:
		level.completed.connect(_on_level_completed)


## A hop straight into the portal ends the level in the air, before the
## landing is checked: it reached its target, so count it.
func _on_level_completed(_stats: LevelStats) -> void:
	if (_phase == Phase.LAUNCH or _phase == Phase.AIRBORNE) and hop_target != null \
			and level.portal != null and level.planet_of(level.portal) == hop_target:
		hops_landed += 1
		GameLog.info(LOG_TAG, "hop into the portal on %s" % hop_target.name)
	_launch_from = null


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
	_stomp_enemy = null
	var here := player.current_planet
	if here == null:
		_wish = Vector3.ZERO
		return
	if here == goal_planet:
		hop_target = null
		_walk_to_goal(delta)
	else:
		_walk_to_launch(here, goal_planet, delta)


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
		var cost := hops_needed * HOP_COST + player.global_position.distance_to(node.global_position)
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
	_update_stuck(delta, to_goal.length(), "goal:%s" % goal.name)


func _walk_to_launch(here: Planet, goal_planet: Planet, delta: float) -> void:
	var path := level.planet_path(here, goal_planet)
	hop_target = path[1] if path.size() > 1 else goal_planet
	var up := player.current_up
	var hop_dir := (hop_target.global_position - here.global_position).normalized()
	var angle := rad_to_deg(up.angle_to(hop_dir))
	var flat := VectorMath.flatten(hop_dir, up)
	# On a spinning moon the launch point slides away under us: never walk
	# slower than the surface moves, or we settle a few degrees short forever.
	var surface_speed := VectorMath.flatten(player.get_platform_velocity(), up).length()
	var min_scale := clampf((surface_speed + surface_speed_margin) / player.move_speed, 0.15, 1.0)
	var scale := clampf(angle / launch_slowdown_deg, min_scale, 1.0)
	_wish = flat.normalized() * scale if flat.length_squared() > MIN_LENGTH_SQ else Vector3.ZERO
	state = &"to_launch"
	var relative_speed := VectorMath.flatten(player.velocity - player.get_platform_velocity(), up).length()
	var burning := player.heat > 0.0
	var ready_to_launch := angle <= hot_launch_angle_deg if burning else (
		angle <= launch_angle_deg and relative_speed <= launch_max_speed)
	_update_stuck(delta, angle, "launch:%s" % hop_target.name)
	if not ready_to_launch and _stuck_timer >= stuck_jump_time and angle <= stuck_launch_angle_deg:
		ready_to_launch = true
		GameLog.info(LOG_TAG, "launch angle stuck at %.1f deg, launching anyway" % angle)
	if ready_to_launch and _enemy_closing_in() != null:
		# A take-off through a rolling ball costs a heart: deal with it first.
		ready_to_launch = false
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
	if _steer_stomp():
		return
	var aim: Vector3
	if player.current_planet == goal_planet and not (goal is Planet):
		aim = goal.global_position
	elif hop_target != null:
		aim = hop_target.global_position
	else:
		aim = goal_planet.global_position
	var flat := VectorMath.flatten(aim - player.global_position, player.current_up)
	_wish = flat.normalized() if flat.length_squared() > MIN_AIM_DISTANCE_SQ else Vector3.ZERO


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


## `distance` is any progress measure that should shrink (metres to a goal,
## degrees to a launch point).
func _update_stuck(delta: float, distance: float, key: String) -> void:
	if key != _progress_key:
		_progress_key = key
		_best_distance = INF
		_stuck_timer = 0.0
	if distance < _best_distance - STUCK_PROGRESS:
		_best_distance = distance
		_stuck_timer = 0.0
		return
	_stuck_timer += delta
	if _stuck_timer >= stuck_skip_time:
		_skip_goal("no progress for %.0f s" % stuck_skip_time)
	elif _stuck_timer >= stuck_jump_time and player.is_on_floor():
		_press_jump()


func _avoid_hazards(up: Vector3) -> void:
	if player.heat > heat_hop_threshold and not _hop_would_cross(up):
		_press_jump()
		return
	if not player.is_on_floor():
		return
	var enemy := _stompable_enemy(up)
	if enemy != null:
		if _press_jump():
			_stomp_enemy = enemy
			stomp_attempts += 1
			GameLog.info(LOG_TAG, "stomp jump at %s" % enemy.name)
		return
	enemy = _enemy_closing_in()
	if enemy != null and _press_jump():
		_stomp_enemy = enemy
		evade_hops += 1
		GameLog.info(LOG_TAG, "evade hop from %s" % enemy.name)


## True when a straight-up hop here would carry the player to another planet.
func _hop_would_cross(up: Vector3) -> bool:
	for planet: Planet in level.planets():
		if planet == player.current_planet:
			continue
		var to_planet := planet.global_position - player.global_position
		var surface_distance := to_planet.length() - planet.radius
		if surface_distance <= JumpReach.MAX_GAP and rad_to_deg(up.angle_to(to_planet)) < hot_hop_cone_deg:
			return true
	return false


## Seconds until feet at `altitude`, moving at `radial_speed` along up under
## constant `gravity`, pass `target_altitude` on the way down; -1 if never.
static func time_to_descend(altitude: float, radial_speed: float, gravity: float, target_altitude: float) -> float:
	var discriminant := radial_speed * radial_speed - 2.0 * gravity * (target_altitude - altitude)
	if discriminant < 0.0 or gravity <= 0.0:
		return -1.0
	var seconds := (radial_speed + sqrt(discriminant)) / gravity
	return seconds if seconds > 0.0 else -1.0


## Feet altitude of a stomp: on top of the ball.
static func stomp_altitude(enemy: SpikeBall) -> float:
	return enemy.ball_radius * 2.0


## A ball on this planet that a full jump started now can come down on: the
## horizontal velocity that lines up over its predicted spot is within walking
## speed, roughly ahead, and within the air control the flight allows. Only in
## a clean field (a neighbour's pull would bend the arc, or carry the jump across).
func _stompable_enemy(up: Vector3) -> SpikeBall:
	var here := player.current_planet
	if here == null or player.dominant_source == null or _hop_would_cross(up):
		return null
	var gravity := INF
	for height: float in stomp_probe_heights:
		gravity = minf(gravity, _radial_gravity(player.global_position + up * height, up))
	if gravity < player.dominant_source.strength * stomp_clean_gravity:
		return null
	var speed := player.tangential_velocity()
	var min_alignment := cos(deg_to_rad(stomp_max_turn_deg))
	for enemy: SpikeBall in level.demo_enemies():
		if enemy.host_planet != here:
			continue
		var top := stomp_altitude(enemy)
		var contact := time_to_descend(0.0, player.jump_speed, gravity, top)
		var align := time_to_descend(0.0, player.jump_speed, gravity, top + stomp_align_height)
		if align <= 0.0:
			continue
		var offset := _surface_offset(player.global_position, enemy.predicted_body_position(contact), here, up)
		if offset.length() > stomp_engage_distance:
			continue
		var needed := offset / align
		if speed.length() > player.facing_min_speed and needed.normalized().dot(speed.normalized()) < min_alignment:
			continue
		if needed.length() <= player.move_speed and \
				(needed - speed).length() <= player.air_acceleration * align * stomp_control_margin:
			return enemy
	return null


## Gravity along -up at `point` from every source (no ground lock): what a
## jump from here feels.
func _radial_gravity(point: Vector3, up: Vector3) -> float:
	return -GravityResolver.sample(get_tree(), point).acceleration.dot(up)


## Tangent direction from `from` toward `to` with the length of the arc
## between them over `planet` (a point behind the curve is far, not near).
static func _surface_offset(from: Vector3, to: Vector3, planet: Planet, up: Vector3) -> Vector3:
	var center := planet.global_position
	var arc := (from - center).angle_to(to - center) * planet.radius
	var direction := VectorMath.flatten(to - from, up)
	return direction.normalized() * arc if direction.length_squared() > MIN_LENGTH_SQ else Vector3.ZERO


## A ball on this planet about to touch the player (within evade_time).
func _enemy_closing_in() -> SpikeBall:
	for enemy: SpikeBall in level.demo_enemies():
		if enemy.host_planet != player.current_planet:
			continue
		var ahead := player.global_position + player.velocity * evade_time
		if enemy.predicted_body_position(evade_time).distance_to(ahead) < evade_distance \
				or enemy.body.global_position.distance_to(player.global_position) < evade_distance:
			return enemy
	return null


## In the air near a ball (stomp or evade hop): line up over where the ball
## will be when the feet reach its top, by `stomp_align_height` above it, and
## follow it down. Once below its top, keep clear of it instead. Returns false
## when there is nothing to steer for (no ball, or another planet's ball).
func _steer_stomp() -> bool:
	var enemy := _stomp_enemy
	if enemy == null or not is_instance_valid(enemy) or enemy.is_defeated or enemy.host_planet != player.current_planet:
		return false
	var up := player.current_up
	var gravity := -player.gravity_sample.acceleration.dot(up)
	var top := stomp_altitude(enemy)
	var contact := time_to_descend(player.surface_altitude, player.vertical_speed(), gravity, top)
	if contact <= 0.0:
		var away := VectorMath.flatten(player.global_position - enemy.body.global_position, up)
		_wish = away.normalized() if away.length_squared() > MIN_LENGTH_SQ else Vector3.ZERO
		return true
	var align := time_to_descend(player.surface_altitude, player.vertical_speed(), gravity, top + stomp_align_height)
	var target := enemy.predicted_body_position(contact)
	var offset := _surface_offset(player.global_position, target, enemy.host_planet, up)
	var steer_time := maxf(align if align > 0.0 else contact, stomp_min_steer_time)
	var needed := offset / steer_time
	var speed := player.tangential_velocity()
	if (needed - speed).length() > player.air_acceleration * steer_time:
		# Out of reach now: a near miss would land on the spikes; keep clear.
		var away := VectorMath.flatten(player.global_position - target, up)
		_wish = away.normalized() if away.length_squared() > MIN_LENGTH_SQ else -speed.normalized()
		return true
	# The controller's air target is wish * max(move_speed, speed): a wish
	# shorter than 1 sets the horizontal velocity exactly, braking included.
	var scale := maxf(player.move_speed, speed.length())
	_wish = (needed / scale).limit_length(1.0)
	return true


## Queues a jump; false when it cannot start now (in the air, or still held).
func _press_jump() -> bool:
	if not player.is_on_floor() or _hold_timer > 0.0:
		return false
	_jump_queued = true
	_hold_timer = jump_hold_time
	return true


func _log_status() -> void:
	var p := player.global_position
	var planet_name := String(player.current_planet.name) if player.current_planet != null else "none"
	var goal_label := String(goal.name) if goal != null and is_instance_valid(goal) else "-"
	GameLog.info(LOG_TAG, "t=%.1f state=%s planet=%s goal=%s hops=%d/%d pos=(%.2f, %.2f, %.2f) alt=%.3f speed=%.2f" % [
		elapsed, state, planet_name, goal_label, hops_landed, hops, p.x, p.y, p.z,
		player.surface_altitude, player.tangential_velocity().length()])
