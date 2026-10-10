extends TestSuite
## Level objective flow on a tiny built-in level: stardust -> portal -> completed.

const PLANET_SCENE := preload("res://world/planet.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")
const RIG_SCENE := preload("res://camera/camera_rig.tscn")
const STARDUST_SCENE := preload("res://world/stardust.tscn")
const PORTAL_SCENE := preload("res://world/exit_portal.tscn")
const LAVA_STYLE := preload("res://world/styles/lava.tres")
const RADIUS := 6.0
## 1.5 s at 60 Hz: well past the 0.8 s lava burn time.
const BURN_FRAMES := 90
const STARDUST_DIRECTIONS: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1)]


func _build(with_portal: bool, style: PlanetStyle = null) -> Level:
	var level := Level.new()
	level.level_id = "test_level"
	level.input_mode = Level.InputMode.NONE
	var planet := PLANET_SCENE.instantiate() as Planet
	planet.radius = RADIUS
	if style != null:
		planet.style = style
	level.add_child(planet)
	for direction: Vector3 in STARDUST_DIRECTIONS:
		var stardust := STARDUST_SCENE.instantiate() as Stardust
		stardust.position = direction
		planet.add_child(stardust)
	if with_portal:
		var portal := PORTAL_SCENE.instantiate() as ExitPortal
		portal.position = Vector3(0, -1, 0)
		planet.add_child(portal)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.position = Vector3(0, RADIUS + 0.05, 0)
	level.add_child(player)
	var rig := RIG_SCENE.instantiate() as OrbitCameraRig
	level.add_child(rig)
	level.player = player
	level.camera_rig = rig
	spawn(level)
	return level


func test_stardust_opens_portal_and_completes() -> void:
	var level := _build(true)
	var counts: Array[int] = []
	var completed: Array[LevelStats] = []
	level.stardust_changed.connect(func(collected: int, _total: int) -> void: counts.append(collected))
	level.completed.connect(func(stats: LevelStats) -> void: completed.append(stats))
	check(level.stats.total == 2, "two stardust found")
	check(not level.portal.is_active, "portal starts dormant")
	check(level.demo_goals().size() == 2, "demo goals are the stardust")
	var first := level.demo_goals()[0] as Stardust
	check_near(first.global_position.length(), RADIUS + first.hover_altitude, "stardust snapped to its hover altitude")
	for goal: Node3D in level.demo_goals():
		(goal as Stardust).collect()
	check(counts == [1, 2], "stardust_changed counts up (got %s)" % [counts])
	check(level.portal.is_active, "portal opens after the last stardust")
	check(level.demo_goals() == [level.portal as Node3D], "demo goal switches to the portal")
	level.portal._on_body_entered(level.player)
	check(completed.size() == 1 and completed[0].completed and completed[0].collected == 2, "completed fires once with stats")
	check(level.is_finished(), "level reports finished")


func test_level_without_stardust_opens_portal_immediately() -> void:
	var level := _build(true)
	for goal: Node3D in level.demo_goals():
		(goal as Stardust).collect()
	var empty := Level.new()
	check(empty.demo_goals().is_empty(), "a level outside the tree has no goals")
	empty.free()
	check(level.portal.is_active, "portal active once no stardust remains")


## Control for the next test: standing still on lava does burn.
func test_standing_on_lava_burns() -> void:
	var level := _build(true, LAVA_STYLE)
	for i in BURN_FRAMES:
		await tree.physics_frame
	check(level.player.health.damage_taken >= 1, "lava burns a heart within %d frames (damage %d)" % [
		BURN_FRAMES, level.player.health.damage_taken])


func test_portal_makes_the_explorer_safe() -> void:
	var level := _build(true, LAVA_STYLE)
	for goal: Node3D in level.demo_goals():
		(goal as Stardust).collect()
	level.portal._on_body_entered(level.player)
	check(level.is_finished(), "level finished through the portal")
	check(not level.player.health.take_damage(1, "spike ball"), "no damage once the portal is entered")
	for i in BURN_FRAMES:
		await tree.physics_frame
	check(level.player.health.damage_taken == 0, "standing on lava after the portal costs nothing (damage %d)" % [
		level.player.health.damage_taken])
	check(level.player.heat == 0.0, "no heat builds up after the portal (heat %.2f)" % level.player.heat)
	check(level.player.is_on_floor(), "explorer is standing on the lava planet")
