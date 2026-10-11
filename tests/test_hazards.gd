extends TestSuite
## SpikeBall stomp rule and PlayerHealth damage / invulnerability.

const RADIUS := 0.6
const FRACTION := 0.35
const MAX_RISE := 0.5
## Ball radius + player capsule radius (player.tscn).
const LATERAL_REACH := 1.0
const PREV_FEET := 0.5
const LATE_FEET := 0.1
const FAST_FALL := -12.0
const RISING := 4.0
const WALK_SIDE := 0.9
const WALK_STEP := 0.12
const PASS_PREV_SIDE := 1.5
const PASS_LATE_SIDE := 0.95
const PLANET_SCENE := preload("res://world/planet.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")
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


## Contact is noticed a physics step late on a fast fall: the step before
## decides when the feet were above the threshold and over the ball.
func test_stomp_rule_forgives_late_contact() -> void:
	var up := Vector3(0, 0.6, 0.8)
	var side := up.cross(Vector3.RIGHT).normalized()
	check(SpikeBall.is_stomp(up * LATE_FEET, up, FAST_FALL, RADIUS, FRACTION, MAX_RISE, up * PREV_FEET, LATERAL_REACH),
		"(a) fast fall: feet +0.5 m a step earlier, +0.1 m at contact, -12 m/s is a stomp")
	check(not SpikeBall.is_stomp(side * WALK_SIDE + up * LATE_FEET, up, 0.0, RADIUS, FRACTION, MAX_RISE,
			side * (WALK_SIDE + WALK_STEP) + up * LATE_FEET, LATERAL_REACH),
		"(b) walking into its side is a hit")
	check(not SpikeBall.is_stomp(up * LATE_FEET, up, RISING, RADIUS, FRACTION, MAX_RISE, up * PREV_FEET, LATERAL_REACH),
		"(c) rising through it is a hit even with the feet above it a step earlier")
	check(not SpikeBall.is_stomp(side * PASS_LATE_SIDE + up * LATE_FEET, up, FAST_FALL, RADIUS, FRACTION, MAX_RISE,
			side * PASS_PREV_SIDE + up * PREV_FEET, LATERAL_REACH),
		"(d) falling past its side (1.5 m out a step earlier) is a hit")


## The same fast fall through SpikeBall's contact handler: the player's
## pre-slide position and the ball's position a step back decide it.
func test_late_contact_on_a_fast_fall_stomps_the_ball() -> void:
	var planet := PLANET_SCENE.instantiate() as Planet
	planet.radius = PLANET_RADIUS
	planet.decorate = false
	spawn(planet)
	var ball := SPIKE_SCENE.instantiate() as SpikeBall
	ball.patrol_speed_deg = PATROL_SPEED
	planet.add_child(ball)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	spawn(player)
	await tree.physics_frame
	var up := ball.ball_up()
	var step := 1.0 / Engine.physics_ticks_per_second
	var ball_before := ball.predicted_body_position(-step)
	player.global_position = ball.body.global_position + up * LATE_FEET
	player.previous_global_position = ball_before + up * PREV_FEET
	player.velocity = up * FAST_FALL
	ball._on_body_entered(player)
	check(ball.is_defeated, "late contact on a fast fall defeats the ball")
	check(player.health.damage_taken == 0, "and costs no heart (took %d)" % player.health.damage_taken)
	check(player.vertical_speed() > 0.0, "and bounces the player up (%.2f m/s)" % player.vertical_speed())


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
