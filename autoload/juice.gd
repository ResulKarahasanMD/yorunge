class_name JuiceSystem
extends Node
## Autoloaded as `Juice` (typed access: `JuiceSystem.current`): global
## hit-stop, a brief slow-motion on impacts.
## Every request gets a generation number; only the newest request's timer
## restores normal time, so overlapping stops extend instead of cutting each
## other short. (Comparing wall-clock times failed under --fixed-fps, where
## frames outrun real time, and left the game stuck in slow motion.)

const LOG_TAG := "Juice"
const NORMAL_TIME_SCALE := 1.0
const MSEC_PER_SECOND := 1000.0

static var current: JuiceSystem = null

## Verification counters.
var hit_stops: int = 0
var restores: int = 0
var min_time_scale_seen: float = NORMAL_TIME_SCALE
var last_hit_stop_ms: float = 0.0

var _generation: int = 0
var _started_msec: int = 0


func _ready() -> void:
	current = self
	process_mode = Node.PROCESS_MODE_ALWAYS


## Slows the game to `time_scale` for `duration` unscaled seconds.
func hit_stop(duration: float, time_scale: float) -> void:
	hit_stops += 1
	_generation += 1
	var generation := _generation
	if Engine.time_scale >= NORMAL_TIME_SCALE:
		_started_msec = Time.get_ticks_msec()
	Engine.time_scale = minf(Engine.time_scale, time_scale)
	min_time_scale_seen = minf(min_time_scale_seen, Engine.time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	if generation == _generation:
		Engine.time_scale = NORMAL_TIME_SCALE
		restores += 1
		last_hit_stop_ms = float(Time.get_ticks_msec() - _started_msec)
