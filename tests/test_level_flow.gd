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
## Half a second at 60 Hz: long enough for a held stick to reach full speed.
const HOLD_FRAMES := 30
const LOOK_STEP := 1.0 / 60.0
const STILL_SPEED := 0.1
const HELD_ACTIONS: Array[StringName] = [InputBindings.MOVE_FORWARD, InputBindings.LOOK_RIGHT, InputBindings.JUMP]


func _build(with_portal: bool, style: PlanetStyle = null, mode: Level.InputMode = Level.InputMode.NONE) -> Level:
	var level := Level.new()
	level.level_id = "test_level"
	level.input_mode = mode
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


## Menus over a level (summary, pause) must not let the stick walk the
## explorer or turn the camera, and a jump held from the menu must not fire.
func test_menus_take_devices_away_from_explorer_and_camera() -> void:
	var level := _build(false, null, Level.InputMode.HUMAN)
	var human := level.input_source as HumanInput
	await tree.physics_frame
	Input.action_press(InputBindings.MOVE_FORWARD)
	Input.action_press(InputBindings.LOOK_RIGHT)
	check(human.get_move_direction() != Vector3.ZERO, "control: the stick moves the explorer while playing")
	check(level.camera_rig._consume_look(LOOK_STEP) != Vector2.ZERO, "control: the right stick turns the camera while playing")
	level.set_player_control(false)
	check(human.get_move_direction() == Vector3.ZERO, "no movement while a menu is open")
	check(level.camera_rig._consume_look(LOOK_STEP) == Vector2.ZERO, "no camera look while a menu is open")
	for i in HOLD_FRAMES:
		await tree.physics_frame
	var speed := level.player.tangential_velocity().length()
	check(speed < STILL_SPEED, "explorer stands still under a menu with the stick held (%.2f m/s)" % speed)
	# Outside the physics step, so "just pressed" refers to this frame.
	await tree.process_frame
	Input.action_press(InputBindings.JUMP)
	check(not human.consume_jump_pressed(), "no jump while a menu is open")
	level.set_player_control(true)
	check(not human.consume_jump_pressed(), "a jump pressed on the menu does not fire on resume")
	Input.action_release(InputBindings.JUMP)
	# The controller polls every physics tick and sees the release there.
	await tree.physics_frame
	await tree.process_frame
	Input.action_press(InputBindings.JUMP)
	check(human.consume_jump_pressed(), "a fresh press jumps again")
	for action: StringName in HELD_ACTIONS:
		Input.action_release(action)
