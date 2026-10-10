extends TestSuite
## OrbitCameraRig framing limits and boom easing, checked against the values
## actually configured in res://camera/camera_rig.tscn.

const RIG_SCENE := "res://camera/camera_rig.tscn"
## Planet radii the levels may use (tutorials + generator range).
const PLANET_RADII: Array[float] = [3.0, 4.0, 6.0, 8.0, 10.0, 14.0, 20.0, 25.0]
## Horizon must stay at least this far inside the top/bottom frame edge.
const HORIZON_EDGE_MARGIN_DEG := 5.0
## Extra clearance between the boom probe and the planet surface.
const GROUND_CLEARANCE := 0.2
const FRAME_DT := 1.0 / 60.0
const HITCH_DT := 0.25

var _rig: OrbitCameraRig
var _fov: float


func _load_rig() -> void:
	if _rig != null:
		return
	_rig = (load(RIG_SCENE) as PackedScene).instantiate() as OrbitCameraRig
	_fov = (_rig.get_node("Camera3D") as Camera3D).fov


func test_horizon_always_in_frame() -> void:
	_load_rig()
	var limit := _fov * 0.5 - HORIZON_EDGE_MARGIN_DEG
	var worst_low := INF
	var worst_high := -INF
	var pitch := _rig.min_pitch_deg
	while pitch <= _rig.max_pitch_deg + 0.001:
		for radius: float in PLANET_RADII:
			var offset := OrbitCameraRig.horizon_offset_deg(radius, _rig.pivot_height, _rig.distance, pitch)
			worst_low = minf(worst_low, offset)
			worst_high = maxf(worst_high, offset)
			check(absf(offset) <= limit,
				"horizon at %.1f deg (limit %.1f) for R=%.0f pitch=%.0f" % [offset, limit, radius, pitch])
		pitch += 1.0
	print("[Test]   horizon offset range over pitch [%.0f, %.0f] and R %s: %.1f .. %.1f deg (frame half-height %.1f)" % [
		_rig.min_pitch_deg, _rig.max_pitch_deg, PLANET_RADII, worst_low, worst_high, _fov * 0.5])


func test_default_pitch_horizon_near_centre() -> void:
	_load_rig()
	var offset := OrbitCameraRig.horizon_offset_deg(10.0, _rig.pivot_height, _rig.distance, _rig.default_pitch_deg)
	check(_rig.default_pitch_deg <= -20.0 and _rig.default_pitch_deg >= -25.0, "default pitch looks 20-25 deg down")
	check(absf(offset) < 10.0, "default view puts horizon within 10 deg of centre (got %.1f)" % offset)


func test_camera_never_reaches_own_planet() -> void:
	_load_rig()
	for radius: float in PLANET_RADII:
		var elevation := deg_to_rad(-_rig.max_pitch_deg)
		var up := radius + _rig.pivot_height + _rig.distance * sin(elevation)
		var back := _rig.distance * cos(elevation)
		var clearance := sqrt(up * up + back * back) - radius
		check(clearance >= _rig.collision_radius + GROUND_CLEARANCE,
			"lowest camera clears R=%.0f surface (clearance %.2f m)" % [radius, clearance])


func test_zoom_in_is_fast_but_bounded() -> void:
	_load_rig()
	var result := _simulate(_rig.distance, 1.5, FRAME_DT)
	var bound := _rig.zoom_in_max_speed * FRAME_DT
	check(result["max_step"] <= bound + DEFAULT_EPSILON, "per-frame zoom-in step <= %.3f m (got %.3f)" % [bound, result["max_step"]])
	check(result["settle_time"] <= 0.4, "zoom-in settles within 0.4 s (got %.3f)" % result["settle_time"])
	check(result["first_step"] < (_rig.distance - 1.5) * 0.5, "zoom-in does not jump halfway in one frame")
	print("[Test]   zoom in 8.0->1.5 @60fps: first step %.3f m, max step %.3f m, 95%% at %.3f s" % [
		result["first_step"], result["max_step"], result["settle_time"]])


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
	var next := OrbitCameraRig.step_arm_length(_rig.distance, 1.0, HITCH_DT,
		_rig.zoom_in_sharpness, _rig.zoom_in_max_speed, _rig.zoom_out_sharpness, _rig.zoom_out_max_speed)
	var bound := _rig.zoom_in_max_speed * OrbitCameraRig.MAX_SMOOTH_DT
	check(_rig.distance - next <= bound + DEFAULT_EPSILON,
		"a %.2f s hitch moves the boom at most %.2f m (got %.2f)" % [HITCH_DT, bound, _rig.distance - next])


## Steps the easing from `from` to `to` and reports the largest frame step and
## the time to cover 95% of the distance.
func _simulate(from: float, to: float, dt: float) -> Dictionary:
	var current := from
	var max_step := 0.0
	var first_step := -1.0
	var settle_time := -1.0
	var t := 0.0
	var span := absf(to - from)
	while t < 3.0:
		var next := OrbitCameraRig.step_arm_length(current, to, dt,
			_rig.zoom_in_sharpness, _rig.zoom_in_max_speed, _rig.zoom_out_sharpness, _rig.zoom_out_max_speed)
		var step := absf(next - current)
		if first_step < 0.0:
			first_step = step
		max_step = maxf(max_step, step)
		current = next
		t += dt
		if settle_time < 0.0 and absf(to - current) <= span * 0.05:
			settle_time = t
	return {"max_step": max_step, "first_step": first_step, "settle_time": settle_time}


func teardown_suite() -> void:
	if _rig != null:
		_rig.free()
		_rig = null
