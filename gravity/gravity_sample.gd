class_name GravitySample
extends RefCounted
## Result of GravityResolver.sample(): the summed acceleration at a point plus
## the single source pulling hardest there.

const MIN_ACCELERATION_SQ := 0.0001

var acceleration: Vector3 = Vector3.ZERO
var dominant: GravitySource = null
## Weight (0..1) of the dominant source at the sampled point.
var dominant_weight: float = 0.0


func has_gravity() -> bool:
	return acceleration.length_squared() > MIN_ACCELERATION_SQ


## Direction opposite to the pull; falls back to `fallback` in free space.
func up_or(fallback: Vector3) -> Vector3:
	if has_gravity():
		return -acceleration.normalized()
	return fallback
