class_name GameStateManager
extends Node
## Global session state, autoloaded as `GameState`: which level sequence is
## being played and the stats of every finished level. Scene switching itself
## lives in GameMain.

signal level_recorded(stats: LevelStats)

enum Mode { TUTORIAL, ENDLESS }

const LOG_TAG := "Game"
const TUTORIAL_LEVELS: Array[String] = [
	"res://levels/tutorial_01.tscn",
	"res://levels/tutorial_02.tscn",
	"res://levels/tutorial_03.tscn",
]

var mode: Mode = Mode.TUTORIAL
var tutorial_index: int = 0
var endless_base_seed: int = 0
var endless_depth: int = 0
var history: Array[LevelStats] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.register_defaults()
	GameLog.info(LOG_TAG, "boot: demo_mode=%s" % DemoMode.is_active())
	if not FrameCapture.requested_path().is_empty():
		add_child(FrameCapture.new())


func start_tutorial(index: int) -> void:
	mode = Mode.TUTORIAL
	tutorial_index = clampi(index, 0, TUTORIAL_LEVELS.size() - 1)


func start_endless(base_seed: int) -> void:
	mode = Mode.ENDLESS
	endless_base_seed = base_seed
	endless_depth = 1


func current_level_path() -> String:
	return TUTORIAL_LEVELS[tutorial_index]


## The generated level for the current endless depth.
func current_endless_spec() -> LevelSpec:
	return LevelGenerator.generate(LevelGenerator.level_seed(endless_base_seed, endless_depth), endless_depth)


func has_next_level() -> bool:
	if mode == Mode.ENDLESS:
		return true
	return tutorial_index + 1 < TUTORIAL_LEVELS.size()


func advance() -> void:
	if mode == Mode.ENDLESS:
		endless_depth += 1
	else:
		tutorial_index += 1


func record(stats: LevelStats) -> void:
	history.append(stats)
	GameLog.info(LOG_TAG, "recorded %s" % stats.to_dict())
	level_recorded.emit(stats)
