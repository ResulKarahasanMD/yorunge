class_name EndlessProbe
extends Node
## Builds one generated level and lets the DemoBot play it, with a compact
## per-interval trace. For investigating generator/bot problems headless:
##   Godot --headless --path . --fixed-fps 60 res://debug/endless_probe.tscn -- --seed=N --depth=D [--trace=0.5] [--time=120]

const LOG_TAG := "EndlessProbe"
const DEFAULT_TIME := 120.0
const DEFAULT_TRACE := 1.0

## Used when no --seed/--depth is given (e.g. Beckett play_scene).
@export var default_seed: int = 2026
@export var default_depth: int = 5

var _seed: int = 0
var _depth: int = 1
var _trace: float = DEFAULT_TRACE
var _limit: float = DEFAULT_TIME


func _ready() -> void:
	DemoMode.forced = true
	_seed = default_seed
	_depth = default_depth
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--seed="):
			_seed = value.to_int()
		elif arg.begins_with("--depth="):
			_depth = value.to_int()
		elif arg.begins_with("--trace="):
			_trace = value.to_float()
		elif arg.begins_with("--time="):
			_limit = value.to_float()
	var spec := LevelGenerator.generate(_seed, _depth)
	for i in spec.planets.size():
		var planet := spec.planets[i]
		GameLog.info(LOG_TAG, "planet %d: %s r=%.2f spin=%.1f parent=%d" % [
			i, PlanetStyle.Surface.keys()[planet.style], planet.radius, planet.spin_deg, planet.parent])
	var level := LevelBuilder.build(spec)
	add_child(level)
	var player := level.player
	var bot := level.input_source as DemoBot
	var time := 0.0
	var next_trace := 0.0
	var completed := [false]
	var failed := [false]
	level.completed.connect(func(_stats: LevelStats) -> void: completed[0] = true)
	# Listening also stops Level from reloading the scene on death (a loop here).
	level.failed.connect(func(_stats: LevelStats) -> void: failed[0] = true)
	while time < _limit and not completed[0] and not failed[0]:
		await get_tree().physics_frame
		time += get_physics_process_delta_time()
		if time >= next_trace:
			next_trace += _trace
			GameLog.info(LOG_TAG, "t=%.2f planet=%s floor=%s alt=%.3f vel=%.2f platform=%.2f up=%s goal=%s state=%s heat=%.2f" % [
				time, player.current_planet.name if player.current_planet != null else "none", player.is_on_floor(),
				player.surface_altitude, player.velocity.length(), player.get_platform_velocity().length(),
				player.current_up, bot.goal.name if bot.goal != null and is_instance_valid(bot.goal) else "-", bot.state, player.heat])
	GameLog.info(LOG_TAG, "result: completed=%s died=%s time=%.1f collected=%d/%d enemies=%d stomps=%d stomp_attempts=%d damage=%d hops=%d/%d skipped=%d evade_hops=%d" % [
		completed[0], failed[0], time, level.stats.collected, level.stats.total, spec.enemies.size(), level.stats.stomps,
		bot.stomp_attempts, player.health.damage_taken, bot.hops_landed, bot.hops, bot.goals_skipped, bot.evade_hops])
	get_tree().quit()
