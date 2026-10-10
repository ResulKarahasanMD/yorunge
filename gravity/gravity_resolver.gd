class_name GravityResolver
extends RefCounted
## Sums every enabled GravitySource at a point and picks the dominant one
## (largest strength * weight). Stateless: callers keep their own smoothing.


static func sample(tree: SceneTree, point: Vector3) -> GravitySample:
	var result := GravitySample.new()
	var best_pull := 0.0
	for node: Node in tree.get_nodes_in_group(GravitySource.GROUP):
		var source := node as GravitySource
		if source == null or not source.enabled:
			continue
		var weight := source.weight_at(point)
		if weight <= 0.0:
			continue
		result.acceleration += source.acceleration_at(point)
		var pull := source.strength * weight
		if pull > best_pull:
			best_pull = pull
			result.dominant = source
			result.dominant_weight = weight
	return result
