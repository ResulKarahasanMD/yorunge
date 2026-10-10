class_name LevelBuilder
extends RefCounted
## Turns a LevelSpec into a ready-to-add Level, using the same scenes as the
## hand-made tutorials (planet, stardust, portal, spike ball, player, camera).

const PLANET_SCENE := preload("res://world/planet.tscn")
const STARDUST_SCENE := preload("res://world/stardust.tscn")
const PORTAL_SCENE := preload("res://world/exit_portal.tscn")
const SPIKE_SCENE := preload("res://world/spike_ball.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")
const RIG_SCENE := preload("res://camera/camera_rig.tscn")
const BACKDROP_SCENE := preload("res://world/space_backdrop.tscn")
const STYLES: Dictionary = {
	PlanetStyle.Surface.GRASS: preload("res://world/styles/grass.tres"),
	PlanetStyle.Surface.ICE: preload("res://world/styles/ice.tres"),
	PlanetStyle.Surface.LAVA: preload("res://world/styles/lava.tres"),
	PlanetStyle.Surface.ROCK: preload("res://world/styles/moon.tres"),
}
const SPAWN_LIFT := 0.05


static func build(spec: LevelSpec) -> Level:
	var level := Level.new()
	level.name = "Endless%d" % spec.depth
	level.level_id = spec.level_id()
	level.level_title = UiText.ENDLESS_LEVEL_TITLE % [spec.depth, spec.seed_value]
	level.add_child(BACKDROP_SCENE.instantiate())
	var planets_root := Node3D.new()
	planets_root.name = "Planets"
	level.add_child(planets_root)
	var planets: Array[Planet] = []
	for i in spec.planets.size():
		planets.append(_planet(planets_root, spec, i))
	for i in spec.stardust.size():
		_on_surface(planets, spec.stardust[i], STARDUST_SCENE, "Stardust%d" % (i + 1))
	_on_surface(planets, spec.portal, PORTAL_SCENE, "ExitPortal")
	for i in spec.enemies.size():
		var enemy_spec := spec.enemies[i]
		var enemy := SPIKE_SCENE.instantiate() as SpikeBall
		enemy.name = "SpikeBall%d" % (i + 1)
		enemy.patrol_axis = enemy_spec.axis
		enemy.start_direction = enemy_spec.start
		enemy.patrol_speed_deg = enemy_spec.speed_deg
		planets[enemy_spec.planet].add_child(enemy)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	var home := spec.planets[spec.spawn.planet]
	var up := spec.spawn.direction
	player.transform = Transform3D(Basis.looking_at(VectorMath.any_perpendicular(up), up),
		home.center + up * (home.radius + SPAWN_LIFT))
	level.add_child(player)
	var rig := RIG_SCENE.instantiate() as OrbitCameraRig
	rig.name = "CameraRig"
	level.add_child(rig)
	level.player = player
	level.camera_rig = rig
	return level


static func _planet(parent: Node3D, spec: LevelSpec, index: int) -> Planet:
	var planet_spec := spec.planets[index]
	var planet := PLANET_SCENE.instantiate() as Planet
	planet.name = "Planet%d" % index
	planet.position = planet_spec.center
	planet.radius = planet_spec.radius
	planet.style = STYLES[planet_spec.style]
	planet.spin_axis = planet_spec.spin_axis
	planet.spin_speed_deg = planet_spec.spin_deg
	planet.decoration_seed = hash([spec.seed_value, spec.depth, index])
	parent.add_child(planet)
	return planet


static func _on_surface(planets: Array[Planet], point: LevelSpec.SurfacePoint, scene: PackedScene, node_name: String) -> void:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.position = point.direction
	planets[point.planet].add_child(node)
