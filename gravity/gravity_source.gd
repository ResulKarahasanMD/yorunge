class_name GravitySource
extends Node3D
## Spherical gravity well centred on this node.
## Pull is full strength up to `surface_radius + core_margin`, then fades with a
## smoothstep to zero at `influence_radius`. Overlapping wells are summed by
## GravityResolver, which is what makes inter-planet jumps blend smoothly.

const GROUP := &"gravity_sources"
const MIN_DISTANCE := 0.001

## Acceleration in m/s² at full weight.
@export var strength: float = 24.0
@export var surface_radius: float = 10.0
## Extra distance above the surface that still gets full-strength pull.
@export var core_margin: float = 1.5
## Distance from the centre where the pull reaches zero.
@export var influence_radius: float = 20.0
@export var enabled: bool = true


func _enter_tree() -> void:
	add_to_group(GROUP)


func weight_at(point: Vector3) -> float:
	var full_until := surface_radius + core_margin
	var distance := global_position.distance_to(point)
	if distance <= full_until:
		return 1.0
	if distance >= influence_radius or influence_radius <= full_until:
		return 0.0
	return 1.0 - smoothstep(full_until, influence_radius, distance)


func acceleration_at(point: Vector3) -> Vector3:
	var to_center := global_position - point
	var distance := to_center.length()
	if distance < MIN_DISTANCE:
		return Vector3.ZERO
	return to_center / distance * strength * weight_at(point)


## Height of `point` above this body's surface (negative = inside).
func altitude_of(point: Vector3) -> float:
	return global_position.distance_to(point) - surface_radius


## Outward unit normal of the sphere under `point`.
func up_at(point: Vector3) -> Vector3:
	var offset := point - global_position
	if offset.length_squared() < MIN_DISTANCE * MIN_DISTANCE:
		return Vector3.UP
	return offset.normalized()
