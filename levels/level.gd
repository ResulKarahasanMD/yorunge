class_name Level
extends Node3D
## Base for every playable level (hand-made tutorials and generated ones).
## Wires the player, camera and input strategy, keeps the jump graph of the
## level's planets, answers the DemoBot's questions (goals, threats, paths)
## and respawns a player lost in space. Stardust/portal flow arrives in (c).

## AUTO: DemoBot when DemoMode is active, HumanInput otherwise.
## NONE: nobody drives the player (fixed-pose test scenes; keeps the mouse free).
enum InputMode { AUTO, HUMAN, DEMO, NONE }

const LOG_TAG := "Level"

@export var level_title: String = ""
@export var player: PlayerController
@export var camera_rig: OrbitCameraRig
@export var input_mode: InputMode = InputMode.AUTO
@export var demo_behavior: DemoBot.Behavior = DemoBot.Behavior.SEEK

var input_source: PlayerInput = null

var _planets: Array[Planet] = []
var _links: Array[PackedInt32Array] = []


func _ready() -> void:
	_collect_planets()
	camera_rig.set_target(player)
	_install_input()
	player.respawn_tracker.lost_in_space.connect(_on_player_lost)
	GameLog.info(LOG_TAG, "ready: %s (input=%s, planets=%d, links=%s)" % [
		level_title, input_source.name if input_source != null else "none",
		_planets.size(), _describe_links()])


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


## What the DemoBot should go for, nearest first. Without pickups the planets
## themselves are the goals (planet tour).
func demo_goals() -> Array[Node3D]:
	var goals: Array[Node3D] = []
	for planet: Planet in _planets:
		goals.append(planet)
	return goals


func is_goal_active(node: Node3D) -> bool:
	return is_instance_valid(node)


## Hazards the DemoBot should jump over or onto.
func demo_threats() -> Array[Node3D]:
	return []


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


func _on_player_lost() -> void:
	player.respawn_at(player.respawn_tracker.safe_transform())
	camera_rig.snap_to_target()


func _describe_links() -> String:
	var parts := PackedStringArray()
	for i in _links.size():
		parts.append("%s->%s" % [_planets[i].name, ",".join(Array(_links[i]).map(func(j: int) -> String: return String(_planets[j].name)))])
	return "; ".join(parts)
