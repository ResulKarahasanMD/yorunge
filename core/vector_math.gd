class_name VectorMath
extends RefCounted
## Small vector helpers shared by the player, camera and AI.

const MIN_LENGTH_SQ := 0.000001


## Rotates unit vector `from` toward unit vector `to` by `weight` (0..1) of the
## angle between them. Unlike Vector3.slerp this stays defined when the two are
## opposite (gravity flipping between planets): the rotation axis then falls
## back to `fallback_axis`, made perpendicular to `from`.
static func rotate_toward(from: Vector3, to: Vector3, weight: float, fallback_axis: Vector3) -> Vector3:
	var angle := from.angle_to(to)
	if angle < 0.00001:
		return to
	var axis := from.cross(to)
	if axis.length_squared() < MIN_LENGTH_SQ:
		axis = fallback_axis - from * fallback_axis.dot(from)
		if axis.length_squared() < MIN_LENGTH_SQ:
			axis = any_perpendicular(from)
	return from.rotated(axis.normalized(), angle * clampf(weight, 0.0, 1.0)).normalized()


## Some unit vector perpendicular to `v`.
static func any_perpendicular(v: Vector3) -> Vector3:
	var helper := Vector3.RIGHT if absf(v.x) < 0.9 else Vector3.FORWARD
	return v.cross(helper).normalized()


## `v` with its component along unit `normal` removed.
static func flatten(v: Vector3, normal: Vector3) -> Vector3:
	return v - normal * v.dot(normal)
