extends TestSuite
## PlayerController pure helpers.

const UPS: Array[Vector3] = [Vector3.UP, Vector3(0, 0.66, 0.75), Vector3(0.3, -0.9, 0.2), Vector3(-1, 0, 0)]
const WEIGHTS: Array[float] = [0.0, 0.1, 0.5, 1.0]


func test_turn_facing_stays_tangent_and_unit() -> void:
	for raw_up: Vector3 in UPS:
		var up := raw_up.normalized()
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		for weight: float in WEIGHTS:
			# Opposite directions: the case slerp cannot handle.
			var turned := PlayerController.turn_facing(side, -side, up, weight)
			check_near(turned.length(), 1.0, "unit length (up=%s w=%.1f)" % [up, weight])
			check_near(turned.dot(up), 0.0, "tangent to up (up=%s w=%.1f)" % [up, weight])
			var body := Basis.looking_at(turned, up)
			check_vec_near(body.y, up, "body Y equals up (up=%s w=%.1f)" % [up, weight], 0.001)


func test_turn_facing_reaches_target() -> void:
	var up := Vector3(0, 0.66, 0.75).normalized()
	var a := up.cross(Vector3.RIGHT).normalized()
	var b := a.rotated(up, deg_to_rad(90.0))
	check_vec_near(PlayerController.turn_facing(a, b, up, 1.0), b, "weight 1 reaches target")
	var half := PlayerController.turn_facing(a, b, up, 0.5)
	check_near(rad_to_deg(a.angle_to(half)), 45.0, "weight 0.5 turns half the angle", 0.01)
	check_vec_near(PlayerController.turn_facing(a, b, up, 0.0), a, "weight 0 keeps facing")


func test_turn_facing_projects_off_plane_input() -> void:
	var up := Vector3.UP
	var tilted := Vector3(0, 0.8, -0.6)
	var turned := PlayerController.turn_facing(tilted, Vector3(1, 5, 0), up, 1.0)
	check_vec_near(turned, Vector3.RIGHT, "inputs off the tangent plane are flattened first")
