class_name PlanetGraph
extends RefCounted
## Jump-reachability between spheres. Two planets are linked when the gap
## between their surfaces is at most `max_gap`. Works on plain arrays so the
## level generator (specs) and the DemoBot (live Planet nodes) share it.


static func surface_gap(center_a: Vector3, radius_a: float, center_b: Vector3, radius_b: float) -> float:
	return center_a.distance_to(center_b) - radius_a - radius_b


## Adjacency lists: result[i] = indices reachable from i in one jump.
static func build(centers: PackedVector3Array, radii: PackedFloat32Array, max_gap: float) -> Array[PackedInt32Array]:
	var links: Array[PackedInt32Array] = []
	for i in centers.size():
		var row := PackedInt32Array()
		for j in centers.size():
			if i != j and surface_gap(centers[i], radii[i], centers[j], radii[j]) <= max_gap:
				row.append(j)
		links.append(row)
	return links


## Breadth-first path of indices from `start` to `goal` (both included);
## empty when unreachable.
static func path(links: Array[PackedInt32Array], start: int, goal: int) -> PackedInt32Array:
	if start == goal:
		return PackedInt32Array([start])
	var previous := {start: -1}
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for next: int in links[current]:
			if previous.has(next):
				continue
			previous[next] = current
			if next == goal:
				return _unwind(previous, goal)
			queue.append(next)
	return PackedInt32Array()


## Hop count from `start` to every index (-1 = unreachable).
static func hop_counts(links: Array[PackedInt32Array], start: int) -> PackedInt32Array:
	var hops := PackedInt32Array()
	hops.resize(links.size())
	hops.fill(-1)
	hops[start] = 0
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for next: int in links[current]:
			if hops[next] < 0:
				hops[next] = hops[current] + 1
				queue.append(next)
	return hops


static func _unwind(previous: Dictionary, goal: int) -> PackedInt32Array:
	var reversed := PackedInt32Array()
	var node := goal
	while node != -1:
		reversed.append(node)
		node = previous[node]
	reversed.reverse()
	return reversed
