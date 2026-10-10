class_name Level
extends Node3D
## Base for every playable level (hand-made tutorials and generated ones).
## Wires the player, camera and input strategy; tracks stardust, the exit
## portal and enemies; reports completion/failure with LevelStats; keeps the
## jump graph of its planets and answers the DemoBot (goals, threats, paths).
## When nobody listens to `failed` (a dev scene played on its own) a death
## reloads the scene directly.

signal stardust_changed(collected: int, total: int)
signal portal_opened
signal enemy_defeated
## Positional twins of the signals above, for effects (position, local up).
signal stardust_collected_at(position: Vector3, up: Vector3)
signal enemy_defeated_at(position: Vector3, up: Vector3)
signal completed(stats: LevelStats)
signal failed(stats: LevelStats)

## AUTO: DemoBot when DemoMode is active, HumanInput otherwise.
## NONE: nobody drives the player (fixed-pose test scenes; keeps the mouse free).
enum InputMode { AUTO, HUMAN, DEMO, NONE }

const LOG_TAG := "Level"
const LOST_IN_SPACE_DAMAGE := 1

@export var level_id: String = ""
@export var level_title: String = ""
@export var player: PlayerController
@export var camera_rig: OrbitCameraRig
@export var input_mode: InputMode = InputMode.AUTO
@export var demo_behavior: DemoBot.Behavior = DemoBot.Behavior.SEEK

var input_source: PlayerInput = null
var stats: LevelStats = LevelStats.new()
var portal: ExitPortal = null
var hints: TutorialHints = null
var feedback: LevelFeedback = null
var elapsed: float = 0.0

var _planets: Array[Planet] = []
var _links: Array[PackedInt32Array] = []
var _stardust: Array[Stardust] = []
var _enemies: Array[SpikeBall] = []
var _finished: bool = false


func _ready() -> void:
	_collect_planets()
	_collect_objectives()
	camera_rig.set_target(player)
	_install_input()
	player.respawn_tracker.lost_in_space.connect(_on_player_lost)
	player.health.died.connect(_on_player_died)
	stats.level_id = level_id
	stats.title = level_title
	stats.total = _stardust.size()
	for child: Node in get_children():
		if child is TutorialHints:
			hints = child as TutorialHints
			hints.setup(self)
	feedback = LevelFeedback.new()
	feedback.name = "Feedback"
	add_child(feedback)
	feedback.setup(self)
	if _stardust.is_empty() and portal != null:
		_open_portal()
	GameLog.info(LOG_TAG, "ready: %s (input=%s, planets=%d, stardust=%d, enemies=%d, links=%s)" % [
		level_title, input_source.name if input_source != null else "none",
		_planets.size(), _stardust.size(), _enemies.size(), _describe_links()])


func _process(delta: float) -> void:
	if not _finished:
		elapsed += delta


## GameMain hands control to the player only while the level is on screen
## and unpaused: menus must not recapture the mouse, walk the explorer or turn
## the camera (both read devices directly). The DemoBot keeps driving.
func set_player_control(enabled: bool) -> void:
	if input_source is HumanInput:
		(input_source as HumanInput).set_enabled(enabled)
	if camera_rig != null:
		camera_rig.look_enabled = enabled


func is_finished() -> bool:
	return _finished


func planets() -> Array[Planet]:
	return _planets


## Planet a node belongs to: itself, or the one whose surface is nearest.
func planet_of(node: Node3D) -> Planet:
	if node is Planet:
		return node as Planet
	var best: Planet = null
	var best_altitude := INF
	for planet: Planet in _planets:
		var altitude := planet.global_position.distance_to(node.global_position) - planet.radius
		if altitude < best_altitude:
			best_altitude = altitude
			best = planet
	return best


## Planets to visit from `from` to `to` along jumpable gaps (both included).
## Falls back to a direct attempt when the graph has no route.
func planet_path(from: Planet, to: Planet) -> Array[Planet]:
	var direct: Array[Planet] = [from, to]
	var start := _planets.find(from)
	var goal := _planets.find(to)
	if start < 0 or goal < 0:
		return direct
	var indices := PlanetGraph.path(_links, start, goal)
	if indices.is_empty():
		return direct
	var route: Array[Planet] = []
	for index: int in indices:
		route.append(_planets[index])
	return route


## What the DemoBot should go for: remaining stardust, then the open portal.
## A level without objectives offers its planets (planet tour).
func demo_goals() -> Array[Node3D]:
	var goals: Array[Node3D] = []
	for stardust: Stardust in _stardust:
		goals.append(stardust)
	if goals.is_empty() and portal != null and portal.is_active:
		goals.append(portal)
	if goals.is_empty() and portal == null:
		for planet: Planet in _planets:
			goals.append(planet)
	return goals


func is_goal_active(node: Node3D) -> bool:
	if not is_instance_valid(node):
		return false
	if node is Stardust:
		return not (node as Stardust).is_collected
	if node is ExitPortal:
		return (node as ExitPortal).is_active
	return true


## Enemy bodies the DemoBot should jump onto or over.
func demo_threats() -> Array[Node3D]:
	var threats: Array[Node3D] = []
	for enemy: SpikeBall in _enemies:
		if is_instance_valid(enemy) and not enemy.is_defeated:
			threats.append(enemy.body)
	return threats


func _collect_planets() -> void:
	_planets.clear()
	var centers := PackedVector3Array()
	var radii := PackedFloat32Array()
	for node: Node in get_tree().get_nodes_in_group(Planet.GROUP):
		var planet := node as Planet
		if planet != null and is_ancestor_of(planet):
			_planets.append(planet)
			centers.append(planet.global_position)
			radii.append(planet.radius)
	_links = PlanetGraph.build(centers, radii, JumpReach.MAX_GAP)


func _collect_objectives() -> void:
	for node: Node in get_tree().get_nodes_in_group(Stardust.GROUP):
		if is_ancestor_of(node):
			var stardust := node as Stardust
			_stardust.append(stardust)
			stardust.collected.connect(_on_stardust_collected)
	for node: Node in get_tree().get_nodes_in_group(ExitPortal.GROUP):
		if is_ancestor_of(node) and portal == null:
			portal = node as ExitPortal
			portal.entered.connect(_on_portal_entered)
	for node: Node in get_tree().get_nodes_in_group(SpikeBall.GROUP):
		if is_ancestor_of(node):
			var enemy := node as SpikeBall
			_enemies.append(enemy)
			enemy.defeated.connect(_on_enemy_defeated)


func _install_input() -> void:
	var mode := input_mode
	if mode == InputMode.AUTO:
		mode = InputMode.DEMO if DemoMode.is_active() else InputMode.HUMAN
	match mode:
		InputMode.DEMO:
			var bot := DemoBot.new()
			bot.name = "DemoBot"
			bot.level = self
			bot.behavior = demo_behavior
			input_source = bot
		InputMode.HUMAN:
			var human := HumanInput.new()
			human.camera_rig = camera_rig
			human.name = "HumanInput"
			input_source = human
		_:
			return
	add_child(input_source)
	player.input_source = input_source
	input_source.bind(player)


func _on_stardust_collected(stardust: Stardust) -> void:
	_stardust.erase(stardust)
	stats.collected += 1
	stardust_collected_at.emit(stardust.global_position, stardust.global_basis.y)
	GameLog.info(LOG_TAG, "stardust %d/%d" % [stats.collected, stats.total])
	stardust_changed.emit(stats.collected, stats.total)
	if _stardust.is_empty() and portal != null:
		_open_portal()


func _open_portal() -> void:
	portal.activate()
	portal_opened.emit()


func _on_enemy_defeated(enemy: SpikeBall) -> void:
	_enemies.erase(enemy)
	stats.stomps += 1
	enemy_defeated.emit()
	enemy_defeated_at.emit(enemy.body.global_position, enemy.ball_up())


func _on_portal_entered() -> void:
	if _finished:
		return
	_finished = true
	_fill_stats(true)
	# The summary screen follows after the portal effects; lava or an enemy
	# must not take a heart in between.
	player.health.immune = true
	GameLog.info(LOG_TAG, "completed %s: %s" % [level_id, stats.to_dict()])
	completed.emit(stats)


func _on_player_lost() -> void:
	player.health.take_damage(LOST_IN_SPACE_DAMAGE, "lost in space")
	if player.health.is_dead():
		return
	player.respawn_at(player.respawn_tracker.safe_transform())
	camera_rig.snap_to_target()


func _on_player_died() -> void:
	if _finished:
		return
	_finished = true
	_fill_stats(false)
	GameLog.info(LOG_TAG, "failed %s: %s" % [level_id, stats.to_dict()])
	if failed.get_connections().is_empty():
		get_tree().reload_current_scene.call_deferred()
	else:
		failed.emit(stats)


func _fill_stats(success: bool) -> void:
	stats.completed = success
	stats.time = elapsed
	stats.damage = player.health.damage_taken


func _describe_links() -> String:
	var parts := PackedStringArray()
	for i in _links.size():
		parts.append("%s->%s" % [_planets[i].name, ",".join(Array(_links[i]).map(func(j: int) -> String: return String(_planets[j].name)))])
	return "; ".join(parts)
