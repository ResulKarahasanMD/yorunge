extends TestSuite
## VectorMath helpers, especially the opposite-vector case gravity flips hit.

const WEIGHTS: Array[float] = [0.0, 0.25, 0.5, 1.0]


func test_rotate_toward_partial_and_full() -> void:
	var from := Vector3.UP
	var to := Vector3.RIGHT
	check_vec_near(VectorMath.rotate_toward(from, to, 1.0, Vector3.FORWARD), to, "weight 1 reaches target")
	var half := VectorMath.rotate_toward(from, to, 0.5, Vector3.FORWARD)
	check_near(rad_to_deg(from.angle_to(half)), 45.0, "weight 0.5 covers half the angle", 0.001)
	check_vec_near(VectorMath.rotate_toward(from, to, 0.0, Vector3.FORWARD), from, "weight 0 keeps start")


func test_rotate_toward_opposite_uses_fallback_axis() -> void:
	var from := Vector3.RIGHT
	var to := Vector3.LEFT
	for weight: float in WEIGHTS:
		var result := VectorMath.rotate_toward(from, to, weight, Vector3.BACK)
		check_near(result.length(), 1.0, "unit result for opposite vectors (w=%.2f)" % weight)
		check_near(rad_to_deg(from.angle_to(result)), 180.0 * weight, "progress along the flip (w=%.2f)" % weight, 0.01)
		check_near(result.dot(Vector3.BACK), 0.0, "rotation plane is perpendicular to the fallback axis (w=%.2f)" % weight)


func test_rotate_toward_degenerate_fallback() -> void:
	# Fallback axis parallel to `from` must still produce a valid flip.
	var result := VectorMath.rotate_toward(Vector3.UP, Vector3.DOWN, 0.5, Vector3.UP)
	check_near(result.length(), 1.0, "unit result with a parallel fallback axis")
	check_near(result.dot(Vector3.UP), 0.0, "halfway through the flip", 0.0001)


func test_flatten_and_perpendicular() -> void:
	check_vec_near(VectorMath.flatten(Vector3(1, 2, 3), Vector3.UP), Vector3(1, 0, 3), "flatten removes the normal part")
	for v: Vector3 in [Vector3.UP, Vector3.RIGHT, Vector3(0.95, 0.1, 0.0).normalized()]:
		var p := VectorMath.any_perpendicular(v)
		check_near(p.dot(v), 0.0, "perpendicular to %s" % v)
		check_near(p.length(), 1.0, "unit perpendicular to %s" % v)
