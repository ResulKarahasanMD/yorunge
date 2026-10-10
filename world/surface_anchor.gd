class_name SurfaceAnchor
extends RefCounted
## Places things that live on a planet. A node parented (directly or deeper)
## under a Planet keeps only the DIRECTION of its position from the planet
## centre; snap() moves it to a given altitude on that ray and turns its +Y
## outward while keeping its own heading. Level designers can therefore drop
## pickups anywhere along the right direction.

const MIN_LENGTH_SQ := 0.000001


static func host_planet(node: Node) -> Planet:
	var current := node.get_parent()
	while current != null:
		var planet := current as Planet
		if planet != null:
			return planet
		current = current.get_parent()
	return null


static func snap(node: Node3D, altitude: float) -> Planet:
	var planet := host_planet(node)
	if planet == null:
		return null
	var local := planet.to_local(node.global_position)
	var up := local.normalized() if local.length_squared() > MIN_LENGTH_SQ else Vector3.UP
	var heading := VectorMath.flatten(planet.global_basis.inverse() * -node.global_basis.z, up)
	if heading.length_squared() < MIN_LENGTH_SQ:
		heading = VectorMath.any_perpendicular(up)
	var local_xform := Transform3D(Basis.looking_at(heading.normalized(), up), up * (planet.radius + altitude))
	node.global_transform = planet.global_transform * local_xform
	return planet
