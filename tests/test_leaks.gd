extends TestSuite
## Loading and unloading a level must leave nothing behind (nodes, resources,
## timers, tweens, coroutines): endless mode does it for as long as you play.

const CYCLES := 6
## Transient objects (timers, tweens) alive at the moment of counting make the
## total wobble by one or two; a leak of even one object per reload grows by
## CYCLES - 1 and still fails.
const NOISE := 2
## Frames with the level in the tree (~1 s of play) and after freeing it.
const PLAY_FRAMES := 60
const SETTLE_FRAMES := 10
const LEAK_SEED := 2026
const LEAK_DEPTH := 6


func test_level_reload_does_not_leak() -> void:
	var spec := LevelGenerator.generate(LevelGenerator.level_seed(LEAK_SEED, LEAK_DEPTH), LEAK_DEPTH)
	# The first load fills the static caches (particle materials, shaders), so
	# counting starts after it.
	await _load_and_unload(spec)
	var objects := PackedInt32Array()
	var first := Vector3i.ZERO
	var last := Vector3i.ZERO
	for i in CYCLES:
		await _load_and_unload(spec)
		last = _counts()
		if i == 0:
			first = last
		objects.append(last.x)
	print("[Test]   %d reloads of %s: objects %s, resources %d -> %d, nodes in tree %d -> %d" % [
		CYCLES, spec.level_id(), objects, first.y, last.y, first.z, last.z])
	check(last.x - first.x <= NOISE, "objects grew over %d reloads: %s" % [CYCLES, objects])
	check(last.y - first.y <= NOISE, "resources grew: %d -> %d" % [first.y, last.y])
	check(last.z - first.z <= NOISE, "nodes in tree grew: %d -> %d" % [first.z, last.z])
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "no orphan nodes")


## Same steps as GameMain: add under a host, play, remove_child + queue_free.
func _load_and_unload(spec: LevelSpec) -> void:
	var level := LevelBuilder.build(spec)
	tree.root.add_child(level)
	for i in PLAY_FRAMES:
		await tree.physics_frame
	tree.root.remove_child(level)
	level.queue_free()
	for i in SETTLE_FRAMES:
		await tree.process_frame


## (objects, resources, nodes)
static func _counts() -> Vector3i:
	return Vector3i(
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
