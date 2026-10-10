extends TestSuite
## SpikeBall stomp rule and PlayerHealth damage / invulnerability.

const RADIUS := 0.6
const FRACTION := 0.35
const MAX_RISE := 0.5


func test_stomp_rule() -> void:
	var up := Vector3(0, 0.6, 0.8)
	check(SpikeBall.is_stomp(up * 0.6, up, -3.0, RADIUS, FRACTION, MAX_RISE), "falling onto the top is a stomp")
	check(SpikeBall.is_stomp(up * 0.25, up, 0.0, RADIUS, FRACTION, MAX_RISE), "feet at 0.25 m with no rise still stomps")
	check(not SpikeBall.is_stomp(up * 0.6, up, 4.0, RADIUS, FRACTION, MAX_RISE), "rising into it from above is not a stomp")
	check(not SpikeBall.is_stomp(up * -0.6, up, -1.0, RADIUS, FRACTION, MAX_RISE), "walking into its side is a hit")
	check(not SpikeBall.is_stomp(Vector3.ZERO, up, -2.0, RADIUS, FRACTION, MAX_RISE), "feet at the centre height is a hit")


func test_health_damage_and_invulnerability() -> void:
	var health := PlayerHealth.new()
	health.max_hearts = 3
	health.invulnerable_time = 1.0
	spawn(health)
	var events: Array[int] = []
	var deaths := [0]
	health.damaged.connect(func(_amount: int, hearts: int, _cause: String) -> void: events.append(hearts))
	health.died.connect(func() -> void: deaths[0] += 1)
	check(health.take_damage(1, "test"), "first hit lands")
	check(not health.take_damage(1, "test"), "second hit inside the window is ignored")
	health._physics_process(1.01)
	check(health.take_damage(1, "test"), "hit after the window lands")
	health._physics_process(1.01)
	check(health.take_damage(5, "test"), "overkill hit lands")
	check(health.hearts == 0 and health.is_dead(), "hearts clamp at zero")
	check(events == [2, 1, 0], "damaged reports remaining hearts (got %s)" % [events])
	check(deaths[0] == 1, "died fires exactly once")
	check(health.damage_taken == 7, "damage_taken counts every heart requested (got %d)" % health.damage_taken)
	health._physics_process(2.0)
	check(not health.take_damage(1, "test"), "no damage once dead")
	check(not health.take_damage(0, "test"), "zero damage is ignored")
