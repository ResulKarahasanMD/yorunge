extends TestSuite
## LevelGenerator over many seeds: every rule, determinism, depth scaling.

const SEED_COUNT := 500
const MAX_DEPTH := 10


func test_many_seeds_are_valid() -> void:
	var started := Time.get_ticks_usec()
	var invalid := 0
	var first_errors := PackedStringArray()
	var planets_min := 99
	var planets_max := 0
	var gap_max := 0.0
	var styles := {}
	for i in SEED_COUNT:
		var depth := 1 + i % MAX_DEPTH
		var spec := LevelGenerator.generate(i * 7919 + 13, depth)
		var errors := LevelGenerator.validate(spec)
		if not errors.is_empty():
			invalid += 1
			if first_errors.size() < 5:
				first_errors.append("seed %d depth %d: %s" % [i * 7919 + 13, depth, errors[0]])
		planets_min = mini(planets_min, spec.planets.size())
		planets_max = maxi(planets_max, spec.planets.size())
		for planet: LevelSpec.PlanetSpec in spec.planets:
			styles[planet.style] = int(styles.get(planet.style, 0)) + 1
			if planet.parent >= 0:
				var parent := spec.planets[planet.parent]
				gap_max = maxf(gap_max, PlanetGraph.surface_gap(planet.center, planet.radius, parent.center, parent.radius))
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	check(invalid == 0, "%d of %d specs break a rule: %s" % [invalid, SEED_COUNT, "; ".join(first_errors)])
	check(gap_max <= JumpReach.design_gap() + 0.001, "largest parent gap %.2f within design gap %.2f" % [gap_max, JumpReach.design_gap()])
	print("[Test]   %d specs (depth 1-%d): invalid %d, planets %d-%d, largest link gap %.2f m, styles %s, %.2f ms/spec" % [
		SEED_COUNT, MAX_DEPTH, invalid, planets_min, planets_max, gap_max, styles, elapsed_ms / SEED_COUNT])


func test_deterministic_and_varied() -> void:
	var a := LevelGenerator.generate(424242, 3).to_text()
	var b := LevelGenerator.generate(424242, 3).to_text()
	check(a == b, "same seed and depth give the same level")
	var distinct := {}
	for i in 50:
		distinct[LevelGenerator.generate(1000 + i, 3).to_text()] = true
	check(distinct.size() == 50, "50 seeds give 50 different levels (got %d)" % distinct.size())
	check(LevelGenerator.generate(424242, 3).to_text() != LevelGenerator.generate(424242, 4).to_text(), "depth changes the level")


func test_depth_scaling() -> void:
	var enemies_shallow := 0
	var enemies_deep := 0
	var planets_shallow := 0
	var planets_deep := 0
	for i in 50:
		var shallow := LevelGenerator.generate(i, 1)
		var deep := LevelGenerator.generate(i, 9)
		enemies_shallow += shallow.enemies.size()
		enemies_deep += deep.enemies.size()
		planets_shallow += shallow.planets.size()
		planets_deep += deep.planets.size()
	check(enemies_shallow == 0, "depth 1 has no enemies (got %d)" % enemies_shallow)
	check(enemies_deep > enemies_shallow and planets_deep > planets_shallow, "deeper levels have more planets and enemies")
	check(LevelGenerator.max_gap(1) < LevelGenerator.max_gap(9), "gaps widen with depth")
	check_near(LevelGenerator.max_gap(99), JumpReach.design_gap(), "gaps never exceed the design gap")
	print("[Test]   avg planets d1 %.1f / d9 %.1f, avg enemies d1 %.1f / d9 %.1f" % [
		planets_shallow / 50.0, planets_deep / 50.0, enemies_shallow / 50.0, enemies_deep / 50.0])


func test_level_seed_chain() -> void:
	check(LevelGenerator.level_seed(7, 1) == LevelGenerator.level_seed(7, 1), "derived seed is stable")
	check(LevelGenerator.level_seed(7, 1) != LevelGenerator.level_seed(7, 2), "each depth gets its own seed")
	check(LevelGenerator.level_seed(7, 1) >= 0, "derived seed is non-negative")


func test_builder_matches_spec() -> void:
	var spec := LevelGenerator.generate(31337, 5)
	var level := LevelBuilder.build(spec)
	spawn(level)
	check(level.planets().size() == spec.planets.size(), "built %d planets (spec %d)" % [level.planets().size(), spec.planets.size()])
	check(level.stats.total == LevelGenerator.STARDUST_COUNT, "5 stardust wired into the level")
	check(level.portal != null and not level.portal.is_active, "dormant portal present")
	check(level.demo_threats().size() == spec.enemies.size(), "enemies wired (%d)" % spec.enemies.size())
	var home := level.planets()[0]
	check_near(home.global_position.distance_to(level.player.global_position), home.radius + LevelBuilder.SPAWN_LIFT,
		"player spawns on the start planet surface", 0.001)
	check(level.level_id == spec.level_id(), "level id from spec")
	check(EndlessSetup.parse_seed("2026") == 2026 and EndlessSetup.parse_seed(" yörünge ") == EndlessSetup.parse_seed("yörünge"),
		"seed parsing: numbers as typed, words hashed")
