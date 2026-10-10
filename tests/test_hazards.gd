extends TestSuite
## SpikeBall stomp rule and PlayerHealth damage / invulnerability.

const RADIUS := 0.6
const FRACTION := 0.35
const MAX_RISE := 0.5
const PLANET_SCENE := preload("res://world/planet.tscn")
const SPIKE_SCENE := preload("res://world/spike_ball.tscn")
const PLANET_RADIUS := 7.0
const PATROL_SPEED := 20.0
const PREDICT_FRAMES := 48
## One tick of patrol at 20 deg/s on R 7.6: 0.044 m.
const PREDICT_TOLERANCE := 0.05


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


## The DemoBot plans stomps from SpikeBall.predicted_body_position(): it must
## match where the ball actually is that many physics ticks later.
func test_spike_ball_prediction_matches_its_patrol() -> void:
	var planet := PLANET_SCENE.instantiate() as Planet
	planet.radius = PLANET_RADIUS
	planet.decorate = false
	spawn(planet)
	var ball := SPIKE_SCENE.instantiate() as SpikeBall
	ball.patrol_axis = Vector3(0.3, 0.2, 1.0)
	ball.start_direction = Vector3(0.0, 1.0, 0.2)
	ball.patrol_speed_deg = PATROL_SPEED
	planet.add_child(ball)
	await tree.physics_frame
	var predicted := ball.predicted_body_position(PREDICT_FRAMES / 60.0)
	for i in PREDICT_FRAMES:
		await tree.physics_frame
	var actual := ball.body.global_position
	check(actual.distance_to(predicted) < PREDICT_TOLERANCE, "prediction %.1f s ahead is within %.2f m (off by %.3f m)" % [
		PREDICT_FRAMES / 60.0, PREDICT_TOLERANCE, actual.distance_to(predicted)])
	check_near(predicted.distance_to(planet.global_position), PLANET_RADIUS + ball.ball_radius, "predicted body stays on the surface", 0.001)


## DemoBot stomp planning maths.
func test_bot_fall_time_and_surface_offset() -> void:
	# 11 m/s jump under 24 m/s²: feet pass 1.2 m going down at (11 + sqrt(121 - 57.6)) / 24.
	check_near(DemoBot.time_to_descend(0.0, 11.0, 24.0, 1.2), (11.0 + sqrt(63.4)) / 24.0, "fall time to the ball's top", 0.0001)
	check(DemoBot.time_to_descend(0.0, 2.0, 24.0, 1.2) < 0.0, "a hop that never reaches 1.2 m never comes down through it")
	check_near(DemoBot.time_to_descend(2.0, 0.0, 24.0, 0.0), sqrt(2.0 * 2.0 / 24.0), "free fall from 2 m", 0.0001)
	var planet := PLANET_SCENE.instantiate() as Planet
	planet.radius = PLANET_RADIUS
	planet.decorate = false
	spawn(planet)
	var top := Vector3(0.0, PLANET_RADIUS, 0.0)
	var side := Vector3(PLANET_RADIUS, 0.0, 0.0)
	var offset := DemoBot._surface_offset(top, side, planet, Vector3.UP)
	check_near(offset.length(), PLANET_RADIUS * PI / 2.0, "a quarter turn away is a quarter of the circumference, not the chord")
	check_vec_near(offset.normalized(), Vector3.RIGHT, "offset points along the surface toward it")
