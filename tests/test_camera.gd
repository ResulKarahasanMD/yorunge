extends TestSuite
## OrbitCameraRig framing limits and boom easing, checked against the values
## actually configured in res://camera/camera_rig.tscn.

const RIG_SCENE := "res://camera/camera_rig.tscn"
## Planet radii the levels may use (tutorials + generator range).
const PLANET_RADII: Array[float] = [3.0, 4.0, 6.0, 8.0, 10.0, 14.0, 20.0, 25.0]
## Horizon and player must stay at least this far inside the frame edge.
const EDGE_MARGIN_DEG := 5.0
const PITCH_STEP_DEG := 1.0
const FRAME_DT := 1.0 / 60.0
const HITCH_DT := 0.25

var _rig: OrbitCameraRig
var _fov: float


func _load_rig() -> void:
	if _rig != null:
		return
	_rig = (load(RIG_SCENE) as PackedScene).instantiate() as OrbitCameraRig
	_fov = (_rig.get_node("Camera3D") as Camera3D).fov


func _required_clearance() -> float:
	return _rig.collision_radius + _rig.ground_clearance


func _ceiling(radius: float) -> float:
	return OrbitCameraRig.boom_ceiling_deg(radius, _rig.pivot_height, _rig.distance, _required_clearance())


func test_pitch_range_includes_look_up() -> void:
	_load_rig()
	check(_rig.max_pitch_deg >= 25.0, "can look up at least 25 deg (max %.0f)" % _rig.max_pitch_deg)
	check(_rig.default_pitch_deg <= -20.0 and _rig.default_pitch_deg >= -25.0, "default pitch looks 20-25 deg down")


func test_horizon_and_player_in_frame_over_full_range() -> void:
	_load_rig()
	var limit := _fov * 0.5 - EDGE_MARGIN_DEG
	var horizon_low := INF
	var horizon_high := -INF
	var max_tilt := 0.0
	for radius: float in PLANET_RADII:
		var ceiling := _ceiling(radius)
		var pitch := _rig.min_pitch_deg
		while pitch <= _rig.max_pitch_deg + 0.001:
			var boom := minf(pitch, ceiling)
			var offset := OrbitCameraRig.horizon_offset_deg(radius, _rig.pivot_height, _rig.distance, boom, pitch)
			# The pivot sits on the boom axis; tilt moves it below screen centre.
			var tilt := pitch - boom
			horizon_low = minf(horizon_low, offset)
			horizon_high = maxf(horizon_high, offset)
			max_tilt = maxf(max_tilt, tilt)
			check(absf(offset) <= limit, "horizon %.1f deg (limit %.1f) R=%.0f pitch=%.0f" % [offset, limit, radius, pitch])
			check(tilt <= limit, "player %.1f deg below centre (limit %.1f) R=%.0f pitch=%.0f" % [tilt, limit, radius, pitch])
			pitch += PITCH_STEP_DEG
	print("[Test]   pitch [%.0f, %.0f], R %s: horizon %.1f .. %.1f deg, max camera tilt %.1f deg (frame half-height %.1f)" % [
		_rig.min_pitch_deg, _rig.max_pitch_deg, PLANET_RADII, horizon_low, horizon_high, max_tilt, _fov * 0.5])


func test_boom_keeps_clear_of_planet() -> void:
	_load_rig()
	var required := _required_clearance()
	var ceilings := PackedStringArray()
	for radius: float in PLANET_RADII:
		var ceiling := _ceiling(radius)
		ceilings.append("R%.0f:%+.1f" % [radius, ceiling])
		var worst := INF
		var pitch := _rig.min_pitch_deg
		while pitch <= _rig.max_pitch_deg + 0.001:
			worst = minf(worst, OrbitCameraRig.boom_clearance(radius, _rig.pivot_height, _rig.distance, minf(pitch, ceiling)))
			pitch += PITCH_STEP_DEG
		check(worst >= required - 0.01, "boom clears R=%.0f by %.2f m (need %.2f)" % [radius, worst, required])
	check(_rig.free_space_boom_ceiling_deg <= -5.0, "free-space ceiling keeps the camera above the pivot")
	print("[Test]   boom ceiling per radius: %s" % " ".join(ceilings))


func test_zoom_in_snaps_same_frame() -> void:
	_load_rig()
	var next := OrbitCameraRig.step_arm_length(_rig.distance, 1.5, FRAME_DT, _rig.zoom_out_sharpness, _rig.zoom_out_max_speed)
	check_near(next, 1.5, "occluder pulls the boom in on the same frame")


func test_zoom_out_is_slow() -> void:
	_load_rig()
	var result := _simulate(1.5, _rig.distance, FRAME_DT)
	var bound := _rig.zoom_out_max_speed * FRAME_DT
	check(result["max_step"] <= bound + DEFAULT_EPSILON, "per-frame zoom-out step <= %.3f m (got %.3f)" % [bound, result["max_step"]])
	check(result["settle_time"] >= 0.3 and result["settle_time"] <= 0.5,
		"zoom-out 95%% settle in 0.3-0.5 s (got %.3f)" % result["settle_time"])
	print("[Test]   zoom out 1.5->8.0 @60fps: max step %.3f m, 95%% at %.3f s" % [result["max_step"], result["settle_time"]])


func test_frame_hitch_is_capped() -> void:
	_load_rig()
	var next := OrbitCameraRig.step_arm_length(1.5, _rig.distance, HITCH_DT, _rig.zoom_out_sharpness, _rig.zoom_out_max_speed)
	var bound := _rig.zoom_out_max_speed * OrbitCameraRig.MAX_SMOOTH_DT
	check(next - 1.5 <= bound + DEFAULT_EPSILON,
		"a %.2f s hitch eases the boom out at most %.2f m (got %.2f)" % [HITCH_DT, bound, next - 1.5])


## Steps the easing from `from` to `to` and reports the largest frame step and
## the time to cover 95% of the distance.
func _simulate(from: float, to: float, dt: float) -> Dictionary:
	var current := from
	var max_step := 0.0
	var settle_time := -1.0
	var t := 0.0
	var span := absf(to - from)
	while t < 3.0:
		var next := OrbitCameraRig.step_arm_length(current, to, dt, _rig.zoom_out_sharpness, _rig.zoom_out_max_speed)
		max_step = maxf(max_step, absf(next - current))
		current = next
		t += dt
		if settle_time < 0.0 and absf(to - current) <= span * 0.05:
			settle_time = t
	return {"max_step": max_step, "settle_time": settle_time}


func teardown_suite() -> void:
	if _rig != null:
		_rig.free()
		_rig = null
