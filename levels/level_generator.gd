class_name LevelGenerator
extends RefCounted
## Seed-based level generator for endless mode. Deterministic: the same
## (seed, depth) always yields the same LevelSpec. Planets grow as a tree
## (mostly chaining off the newest planet, sometimes branching off an older
## one) with surface gaps that widen with depth but never exceed
## JumpReach.design_gap(); validate() checks every rule the tests rely on.

const STARDUST_COUNT := 5
const MIN_PLANETS := 3
const MAX_PLANETS := 8
const START_RADIUS_MIN := 8.0
const START_RADIUS_MAX := 10.0
const RADIUS_MIN := 4.5
const RADIUS_MAX := 9.0
const MOON_RADIUS_MIN := 3.5
const MOON_RADIUS_MAX := 5.0
const MOON_SPIN_MIN := 18.0
const MOON_SPIN_MAX := 35.0
const GAP_MIN := 3.0
const GAP_BASE_MAX := 3.5
const GAP_GROWTH := 0.35
## Any two planets keep at least this much empty space between surfaces.
## Below ~3 m the 1.5 m explorer reaches the next planet head first before
## the gravity flip completes (physics_probe: 2.5 m misses, 3.0 m lands).
const MIN_SEPARATION := 3.0
## Chance that a new planet hangs off the newest one (else a random older one).
const CHAIN_BIAS := 0.65
## Vertical squash of random directions, keeps layouts readable from a camera.
const FLATTEN_Y := 0.45
const PLACEMENT_TRIES := 40
const MAX_ENEMIES := 4
const ENEMY_MIN_RADIUS := 5.0
const ENEMY_SPEED_MIN := 14.0
const ENEMY_SPEED_MAX := 22.0
## Style weights: grass, ice, lava (grows with depth), moon.
const WEIGHT_GRASS := 35.0
const WEIGHT_ICE := 25.0
const WEIGHT_LAVA_BASE := 8.0
const WEIGHT_LAVA_GROWTH := 2.5
const WEIGHT_LAVA_MAX := 30.0
const WEIGHT_MOON := 20.0
## Stardust sharing a planet are at least this far apart (radians).
const STARDUST_MIN_ANGLE := 0.9
## Seed derivation for the next endless level.
const SEED_MASK := 0x7fffffff


## Seed of the level at `depth` in a run started from `base_seed`.
static func level_seed(base_seed: int, depth: int) -> int:
	return hash([base_seed, depth]) & SEED_MASK


static func max_gap(depth: int) -> float:
	return minf(GAP_BASE_MAX + GAP_GROWTH * depth, JumpReach.design_gap())


static func planet_count(depth: int, rng: RandomNumberGenerator) -> int:
	return clampi(MIN_PLANETS + depth / 2 + rng.randi_range(0, 1), MIN_PLANETS, MAX_PLANETS)


static func generate(seed_value: int, depth: int) -> LevelSpec:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, depth, "yorunge"])
	var spec := LevelSpec.new()
	spec.seed_value = seed_value
	spec.depth = depth
	_place_planets(spec, rng, planet_count(depth, rng))
	_place_stardust(spec, rng)
	_place_portal(spec, rng)
	_place_enemies(spec, rng)
	spec.spawn = _point(0, Vector3.UP)
	return spec


## Every rule a generated level must satisfy; empty when valid.
static func validate(spec: LevelSpec) -> PackedStringArray:
	var errors := PackedStringArray()
	var centers := spec.centers()
	var radii := spec.radii()
	for i in spec.planets.size():
		for j in range(i + 1, spec.planets.size()):
			var gap := PlanetGraph.surface_gap(centers[i], radii[i], centers[j], radii[j])
			if gap < MIN_SEPARATION - 0.001:
				errors.append("planets %d and %d too close (%.2f m)" % [i, j, gap])
		var parent := spec.planets[i].parent
		if parent >= 0:
			var link := PlanetGraph.surface_gap(centers[i], radii[i], centers[parent], radii[parent])
			if link > JumpReach.design_gap() + 0.001:
				errors.append("planet %d is %.2f m from its parent (design max %.2f)" % [i, link, JumpReach.design_gap()])
	var links := PlanetGraph.build(centers, radii, JumpReach.design_gap())
	var hops := PlanetGraph.hop_counts(links, 0)
	for i in hops.size():
		if hops[i] < 0:
			errors.append("planet %d unreachable" % i)
	if spec.stardust.size() != STARDUST_COUNT:
		errors.append("%d stardust instead of %d" % [spec.stardust.size(), STARDUST_COUNT])
	for point: LevelSpec.SurfacePoint in spec.stardust:
		if point.planet == 0 and spec.planets.size() > STARDUST_COUNT:
			errors.append("stardust on the start planet despite enough planets")
	if spec.portal == null or spec.portal.planet == 0:
		errors.append("portal missing or on the start planet")
	for enemy: LevelSpec.EnemySpec in spec.enemies:
		if enemy.planet == 0:
			errors.append("enemy on the start planet")
	return errors


static func _place_planets(spec: LevelSpec, rng: RandomNumberGenerator, count: int) -> void:
	var start := LevelSpec.PlanetSpec.new()
	start.center = Vector3.ZERO
	start.radius = rng.randf_range(START_RADIUS_MIN, START_RADIUS_MAX)
	start.style = PlanetStyle.Surface.GRASS
	spec.planets.append(start)
	var gap_limit := max_gap(spec.depth)
	while spec.planets.size() < count:
		var planet := _new_planet(spec.depth, rng)
		if not _attach(spec, planet, rng, gap_limit):
			break
		spec.planets.append(planet)


static func _new_planet(depth: int, rng: RandomNumberGenerator) -> LevelSpec.PlanetSpec:
	var planet := LevelSpec.PlanetSpec.new()
	var lava_weight := minf(WEIGHT_LAVA_BASE + WEIGHT_LAVA_GROWTH * depth, WEIGHT_LAVA_MAX)
	var roll := rng.randf() * (WEIGHT_GRASS + WEIGHT_ICE + lava_weight + WEIGHT_MOON)
	if roll < WEIGHT_GRASS:
		planet.style = PlanetStyle.Surface.GRASS
	elif roll < WEIGHT_GRASS + WEIGHT_ICE:
		planet.style = PlanetStyle.Surface.ICE
	elif roll < WEIGHT_GRASS + WEIGHT_ICE + lava_weight:
		planet.style = PlanetStyle.Surface.LAVA
	else:
		planet.style = PlanetStyle.Surface.ROCK
	if planet.style == PlanetStyle.Surface.ROCK:
		planet.radius = rng.randf_range(MOON_RADIUS_MIN, MOON_RADIUS_MAX)
		planet.spin_deg = rng.randf_range(MOON_SPIN_MIN, MOON_SPIN_MAX)
		planet.spin_axis = _random_direction(rng, 1.0)
	else:
		planet.radius = rng.randf_range(RADIUS_MIN, RADIUS_MAX)
	return planet


## Tries parents (newest first, with a branching chance) and directions until
## the new planet sits `gap` from its parent and clear of every other planet.
static func _attach(spec: LevelSpec, planet: LevelSpec.PlanetSpec, rng: RandomNumberGenerator, gap_limit: float) -> bool:
	for attempt in PLACEMENT_TRIES:
		var newest := spec.planets.size() - 1
		var parent := newest if rng.randf() < CHAIN_BIAS else rng.randi_range(0, newest)
		var gap := rng.randf_range(GAP_MIN, gap_limit)
		var direction := _random_direction(rng, FLATTEN_Y)
		var anchor := spec.planets[parent]
		var center := anchor.center + direction * (anchor.radius + gap + planet.radius)
		if _clear_of_others(spec, center, planet.radius, parent):
			planet.center = center
			planet.parent = parent
			return true
	return false


static func _clear_of_others(spec: LevelSpec, center: Vector3, radius: float, parent: int) -> bool:
	for i in spec.planets.size():
		if i == parent:
			continue
		var other := spec.planets[i]
		if PlanetGraph.surface_gap(center, radius, other.center, other.radius) < MIN_SEPARATION:
			return false
	return true


static func _place_stardust(spec: LevelSpec, rng: RandomNumberGenerator) -> void:
	var hosts: Array[int] = []
	for i in range(1, spec.planets.size()):
		hosts.append(i)
	_shuffle(hosts, rng)
	while hosts.size() < STARDUST_COUNT:
		hosts.append(rng.randi_range(0, spec.planets.size() - 1))
	for k in STARDUST_COUNT:
		var planet := hosts[k]
		var direction := _random_direction(rng, 1.0)
		for attempt in PLACEMENT_TRIES:
			if _far_from_stardust(spec, planet, direction):
				break
			direction = _random_direction(rng, 1.0)
		spec.stardust.append(_point(planet, direction))


static func _far_from_stardust(spec: LevelSpec, planet: int, direction: Vector3) -> bool:
	for point: LevelSpec.SurfacePoint in spec.stardust:
		if point.planet == planet and point.direction.angle_to(direction) < STARDUST_MIN_ANGLE:
			return false
	if planet == 0 and direction.angle_to(Vector3.UP) < STARDUST_MIN_ANGLE:
		return false
	return true


static func _place_portal(spec: LevelSpec, rng: RandomNumberGenerator) -> void:
	var links := PlanetGraph.build(spec.centers(), spec.radii(), JumpReach.design_gap())
	var hops := PlanetGraph.hop_counts(links, 0)
	var farthest := 1 if spec.planets.size() > 1 else 0
	for i in hops.size():
		if hops[i] > hops[farthest]:
			farthest = i
	spec.portal = _point(farthest, _random_direction(rng, 1.0))


static func _place_enemies(spec: LevelSpec, rng: RandomNumberGenerator) -> void:
	var candidates: Array[int] = []
	for i in range(1, spec.planets.size()):
		if spec.planets[i].radius >= ENEMY_MIN_RADIUS:
			candidates.append(i)
	if candidates.is_empty():
		return
	var count := mini(clampi(spec.depth - 1, 0, MAX_ENEMIES), candidates.size() * 2)
	for k in count:
		var enemy := LevelSpec.EnemySpec.new()
		enemy.planet = candidates[rng.randi_range(0, candidates.size() - 1)]
		enemy.axis = _random_direction(rng, 1.0)
		enemy.start = VectorMath.any_perpendicular(enemy.axis).rotated(enemy.axis, rng.randf() * TAU)
		enemy.speed_deg = rng.randf_range(ENEMY_SPEED_MIN, ENEMY_SPEED_MAX)
		spec.enemies.append(enemy)


static func _random_direction(rng: RandomNumberGenerator, flatten_y: float) -> Vector3:
	var v := Vector3(rng.randfn(), rng.randfn() * flatten_y, rng.randfn())
	return v.normalized() if v.length_squared() > VectorMath.MIN_LENGTH_SQ else Vector3.RIGHT


static func _point(planet: int, direction: Vector3) -> LevelSpec.SurfacePoint:
	var point := LevelSpec.SurfacePoint.new()
	point.planet = planet
	point.direction = direction.normalized()
	return point


static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := values[i]
		values[i] = values[j]
		values[j] = swap
