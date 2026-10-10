extends TestSuite
## GravitySource falloff and GravityResolver blending/dominance.

const STRENGTH := 24.0
const RADIUS := 10.0
const CORE := 1.5
const INFLUENCE := 20.0


func _make_source(center: Vector3, radius: float, influence: float, strength: float = STRENGTH) -> GravitySource:
	var source := GravitySource.new()
	source.strength = strength
	source.surface_radius = radius
	source.core_margin = CORE
	source.influence_radius = influence
	spawn(source)
	source.global_position = center
	return source


func test_weight_profile() -> void:
	var source := _make_source(Vector3.ZERO, RADIUS, INFLUENCE)
	check_near(source.weight_at(Vector3(0, RADIUS, 0)), 1.0, "full weight on the surface")
	check_near(source.weight_at(Vector3(0, RADIUS + CORE, 0)), 1.0, "full weight at core edge")
	check_near(source.weight_at(Vector3(0, INFLUENCE, 0)), 0.0, "zero at influence radius")
	check_near(source.weight_at(Vector3(0, INFLUENCE + 5.0, 0)), 0.0, "zero beyond influence")
	var mid := (RADIUS + CORE + INFLUENCE) * 0.5
	check_near(source.weight_at(Vector3(0, mid, 0)), 0.5, "smoothstep midpoint is 0.5")
	var previous := 1.0
	var monotonic := true
	for i in range(0, 41):
		var d := RADIUS + CORE + (INFLUENCE - RADIUS - CORE) * float(i) / 40.0
		var w := source.weight_at(Vector3(d, 0, 0))
		monotonic = monotonic and w <= previous + DEFAULT_EPSILON
		previous = w
	check(monotonic, "weight never increases with distance")


func test_acceleration_points_to_center() -> void:
	var source := _make_source(Vector3(3, -2, 5), RADIUS, INFLUENCE)
	var point := Vector3(3, -2, 5) + Vector3(1, 1, 1).normalized() * RADIUS
	var accel := source.acceleration_at(point)
	check_near(accel.length(), STRENGTH, "surface pull equals strength")
	check_vec_near(accel.normalized(), -Vector3(1, 1, 1).normalized(), "pull aims at centre")
	check_vec_near(source.up_at(point), Vector3(1, 1, 1).normalized(), "up_at is the outward normal")
	check_near(source.altitude_of(point + source.up_at(point) * 2.0), 2.0, "altitude above surface")


func test_resolver_dominance_and_blend() -> void:
	var big := _make_source(Vector3.ZERO, 10.0, 20.0)
	var small := _make_source(Vector3(30, 0, 0), 6.0, 16.0)
	var near_big := GravityResolver.sample(tree, Vector3(11, 0, 0))
	check(near_big.dominant == big, "big planet dominates near its surface")
	var near_small := GravityResolver.sample(tree, Vector3(23, 0, 0))
	check(near_small.dominant == small, "small planet dominates near its surface")
	var between := GravityResolver.sample(tree, Vector3(17, 0, 0))
	var expected := big.acceleration_at(Vector3(17, 0, 0)) + small.acceleration_at(Vector3(17, 0, 0))
	check_vec_near(between.acceleration, expected, "overlap sums both wells")
	check(between.acceleration.length() < STRENGTH, "blend zone is weaker than either surface")
	var empty := GravityResolver.sample(tree, Vector3(0, 200, 0))
	check(not empty.has_gravity() and empty.dominant == null, "free space has no gravity")
	check_vec_near(empty.up_or(Vector3.FORWARD), Vector3.FORWARD, "free space keeps fallback up")


func test_disabled_source_is_ignored() -> void:
	var source := _make_source(Vector3.ZERO, RADIUS, INFLUENCE)
	source.enabled = false
	var sample := GravityResolver.sample(tree, Vector3(0, RADIUS, 0))
	check(sample.dominant == null and not sample.has_gravity(), "disabled source contributes nothing")
