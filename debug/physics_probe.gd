class_name PhysicsProbe
extends Node
## Headless physics measurements (results feed JumpReach and PROGRESS.md):
##   Godot --headless --path . --fixed-fps 60 res://debug/physics_probe.tscn \
##       [-- --core=1.5 --influence=10 --gaps=2,3,4 --sloppy]
## --sloppy: jump like a hurried human (full speed, 15 deg before the launch point).
## 1) Jump reach: the DemoBot walks from the top of planet A (R=8) to the
##    launch point and hops to planet B (R=6) across each surface gap.
## 2) Moon carry: an idle player on a spinning moon; drift in the moon frame.
## 3) Respawn: a player teleported into empty space returns to safe footing.

const LOG_TAG := "Probe"
const PLANET_SCENE := preload("res://world/planet.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")
const RIG_SCENE := preload("res://camera/camera_rig.tscn")
const RADIUS_A := 8.0
const RADIUS_B := 6.0
const MOON_RADIUS := 4.0
const SPAWN_LIFT := 0.05
const TRIAL_TIMEOUT := 10.0
const CARRY_SETTLE := 1.0
const CARRY_MEASURE := 3.0
const DEFAULT_GAPS: Array[float] = [2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 8.0]
const MOON_SPINS: Array[float] = [30.0, 60.0]
const RESPAWN_SETTLE := 1.5
const RESPAWN_TIMEOUT := 6.0
const LOST_OFFSET := Vector3(0.0, 40.0, 0.0)
const SLOPPY_LAUNCH_ANGLE_DEG := 15.0
const SLOPPY_MAX_SPEED := 10.0

var _core_margin: float = -1.0
var _influence_margin: float = -1.0
var _gaps: Array[float] = DEFAULT_GAPS.duplicate()
var _sloppy: bool = false


func _ready() -> void:
	DemoMode.forced = true
	_parse_args()
	GameLog.info(LOG_TAG, "profile core=%s influence=%s launch=%s" % [
		_core_margin if _core_margin >= 0.0 else "default", _influence_margin if _influence_margin >= 0.0 else "default",
		"sloppy" if _sloppy else "careful"])
	var crossed_all_up_to := 0.0
	var streak := true
	for gap: float in _gaps:
		var result := await _reach_trial(gap)
		GameLog.info(LOG_TAG, "reach gap=%.1f result=%s time=%.2f s hops=%d" % [gap, result["result"], result["time"], result["hops"]])
		if streak and result["result"] == "landed":
			crossed_all_up_to = gap
		else:
			streak = false
	GameLog.info(LOG_TAG, "reach summary: every gap up to %.1f m crossed" % crossed_all_up_to)
	for spin: float in MOON_SPINS:
		var carry := await _carry_trial(spin)
		GameLog.info(LOG_TAG, "carry spin=%.0f deg/s drift=%.3f m floor_ratio=%.2f" % [spin, carry["drift"], carry["floor_ratio"]])
	var respawn := await _respawn_trial()
	GameLog.info(LOG_TAG, "respawn lost_after=%.2f s back_on_floor=%s distance_to_safe=%.3f m losses=%d" % [
		respawn["lost_time"], respawn["on_floor"], respawn["distance"], respawn["losses"]])
	get_tree().quit()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--core="):
			_core_margin = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--influence="):
			_influence_margin = arg.get_slice("=", 1).to_float()
		elif arg == "--sloppy":
			_sloppy = true
		elif arg.begins_with("--gaps="):
			_gaps = []
			for part: String in arg.get_slice("=", 1).split(","):
				_gaps.append(part.to_float())


func _reach_trial(gap: float) -> Dictionary:
	var level := _build_level([
		_planet_spec("A", RADIUS_A, Vector3.ZERO),
		_planet_spec("B", RADIUS_B, Vector3(RADIUS_A + gap + RADIUS_B, 0.0, 0.0)),
	], Transform3D(Basis.IDENTITY, Vector3(0.0, RADIUS_A + SPAWN_LIFT, 0.0)), Level.InputMode.DEMO)
	var bot := level.input_source as DemoBot
	if _sloppy:
		bot.launch_angle_deg = SLOPPY_LAUNCH_ANGLE_DEG
		bot.launch_slowdown_deg = SLOPPY_LAUNCH_ANGLE_DEG
		bot.launch_max_speed = SLOPPY_MAX_SPEED
	var result := "timeout"
	var time := 0.0
	while time < TRIAL_TIMEOUT:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()
		if bot.hops_landed > 0:
			result = "landed"
			break
		if bot.hop_failures > 0:
			result = "missed"
			break
	var hops := bot.hops
	await _dispose(level)
	return {"result": result, "time": time, "hops": hops}


func _carry_trial(spin_deg: float) -> Dictionary:
	var spec := _planet_spec("Moon", MOON_RADIUS, Vector3.ZERO)
	spec["spin"] = spin_deg
	var level := _build_level([spec], Transform3D(Basis.IDENTITY, Vector3(0.0, MOON_RADIUS + SPAWN_LIFT, 0.0)), Level.InputMode.NONE)
	var moon := level.planets()[0]
	var player := level.player
	await _wait(CARRY_SETTLE)
	var start_local := moon.global_transform.affine_inverse() * player.global_position
	var floor_frames := 0
	var frames := 0
	var time := 0.0
	while time < CARRY_MEASURE:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()
		frames += 1
		if player.is_on_floor():
			floor_frames += 1
	var end_local := moon.global_transform.affine_inverse() * player.global_position
	await _dispose(level)
	return {"drift": start_local.distance_to(end_local), "floor_ratio": float(floor_frames) / maxf(frames, 1)}


func _respawn_trial() -> Dictionary:
	var level := _build_level([_planet_spec("Home", RADIUS_A, Vector3.ZERO)],
		Transform3D(Basis.IDENTITY, Vector3(0.0, RADIUS_A + SPAWN_LIFT, 0.0)), Level.InputMode.NONE)
	var player := level.player
	await _wait(RESPAWN_SETTLE)
	var safe := player.respawn_tracker.safe_transform().origin
	player.global_position += LOST_OFFSET
	var time := 0.0
	while time < RESPAWN_TIMEOUT and player.respawn_tracker.losses == 0:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()
	await _wait(0.5)
	var result := {"lost_time": time, "on_floor": player.is_on_floor(),
		"distance": player.global_position.distance_to(safe), "losses": player.respawn_tracker.losses}
	await _dispose(level)
	return result


func _planet_spec(planet_name: String, radius: float, position: Vector3) -> Dictionary:
	return {"name": planet_name, "radius": radius, "position": position, "spin": 0.0}


func _build_level(specs: Array[Dictionary], spawn: Transform3D, mode: Level.InputMode) -> Level:
	var level := Level.new()
	level.name = "ProbeLevel"
	level.input_mode = mode
	for spec: Dictionary in specs:
		var planet := PLANET_SCENE.instantiate() as Planet
		planet.name = spec["name"]
		planet.radius = spec["radius"]
		planet.position = spec["position"]
		planet.spin_speed_deg = spec["spin"]
		planet.spin_axis = Vector3(1.0, 0.0, 0.3)
		if _core_margin >= 0.0:
			planet.gravity_core_margin = _core_margin
		if _influence_margin >= 0.0:
			planet.influence_margin = _influence_margin
		level.add_child(planet)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.transform = spawn
	level.add_child(player)
	var rig := RIG_SCENE.instantiate() as OrbitCameraRig
	level.add_child(rig)
	level.player = player
	level.camera_rig = rig
	add_child(level)
	return level


func _wait(seconds: float) -> void:
	var time := 0.0
	while time < seconds:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()


func _dispose(level: Level) -> void:
	level.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
