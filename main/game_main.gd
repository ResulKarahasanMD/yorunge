class_name GameMain
extends Node
## Persistent root scene: hosts the active Level under LevelHost, binds the HUD
## and moves through the level sequence (milestone c: tutorials back to back;
## menus and the level-complete screen join in milestone f).

const LOG_TAG := "Main"

@export var next_level_delay: float = 2.5
@export var retry_delay: float = 1.5

var level: Level = null

var _deaths: int = 0

@onready var level_host: Node3D = $LevelHost
@onready var hud: Hud = $UI/Hud


func _ready() -> void:
	GameState.start_tutorial(0)
	load_level(GameState.current_level_path())


func load_level(path: String) -> void:
	var scene := load(path) as PackedScene
	_spawn(scene.instantiate() as Level)


func _spawn(next_level: Level) -> void:
	if level != null:
		level_host.remove_child(level)
		level.queue_free()
	level = next_level
	level_host.add_child(level)
	level.completed.connect(_on_level_completed)
	level.failed.connect(_on_level_failed)
	hud.bind(level)
	GameLog.info(LOG_TAG, "loaded %s" % level.level_id)


func _on_level_completed(stats: LevelStats) -> void:
	stats.deaths = _deaths
	_deaths = 0
	GameState.record(stats)
	await get_tree().create_timer(next_level_delay).timeout
	if GameState.has_next_level():
		GameState.advance()
		load_level(GameState.current_level_path())
	else:
		_finish_run()


func _on_level_failed(_stats: LevelStats) -> void:
	_deaths += 1
	await get_tree().create_timer(retry_delay).timeout
	load_level(GameState.current_level_path())


func _finish_run() -> void:
	GameLog.info(LOG_TAG, "run finished: %d levels" % GameState.history.size())
	for stats: LevelStats in GameState.history:
		GameLog.info(LOG_TAG, "  %s" % stats.to_dict())
	if DemoMode.should_exit_on_finish():
		get_tree().quit()
