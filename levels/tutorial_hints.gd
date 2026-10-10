class_name TutorialHints
extends Node
## Shows a level's tutorial lines in order. Each hint waits for its trigger;
## triggers that fire early are remembered, so a player who jumps before being
## told to never gets stuck on an old line. A hint stays up at least
## MIN_DISPLAY_TIME before a remembered trigger replaces it.

signal hint_changed(text: String)

const LOG_TAG := "Hint"
## Walking faster than this (m/s) for MOVE_TIME counts as "moved".
const MOVE_SPEED := 1.0
const MOVE_TIME := 1.0
const MIN_DISPLAY_TIME := 3.5

@export var hints: Array[TutorialHint] = []

var current_index: int = -1
var current_text: String = ""

var _fired: Dictionary = {}
var _move_time: float = 0.0
var _player: PlayerController = null
var _first_planet: Planet = null
var _shown_for: float = 0.0


func setup(level: Level) -> void:
	_player = level.player
	_player.jumped.connect(_fire.bind(TutorialHint.Trigger.JUMPED))
	_player.dominant_source_changed.connect(_on_dominant_changed)
	_player.health.damaged.connect(func(_amount: int, _hearts: int, _cause: String) -> void:
		_fire(TutorialHint.Trigger.DAMAGED))
	level.stardust_changed.connect(func(collected: int, _total: int) -> void:
		if collected > 0:
			_fire(TutorialHint.Trigger.STARDUST))
	level.portal_opened.connect(_fire.bind(TutorialHint.Trigger.PORTAL_OPEN))
	level.enemy_defeated.connect(_fire.bind(TutorialHint.Trigger.ENEMY_DEFEATED))
	_fire(TutorialHint.Trigger.START)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_shown_for += delta
	_try_advance()
	if _fired.has(TutorialHint.Trigger.MOVED):
		return
	if _player.is_on_floor() and _player.tangential_velocity().length() > MOVE_SPEED:
		_move_time += delta
		if _move_time >= MOVE_TIME:
			_fire(TutorialHint.Trigger.MOVED)


func _on_dominant_changed(_source: GravitySource) -> void:
	var planet := _player.current_planet
	if planet == null:
		return
	if _first_planet == null:
		_first_planet = planet
	elif planet != _first_planet:
		_fire(TutorialHint.Trigger.PLANET_CHANGED)


func _fire(trigger: TutorialHint.Trigger) -> void:
	_fired[trigger] = true
	_try_advance()


func _try_advance() -> void:
	if current_index >= 0 and _shown_for < MIN_DISPLAY_TIME:
		return
	if current_index + 1 >= hints.size() or not _fired.has(hints[current_index + 1].trigger):
		return
	current_index += 1
	_shown_for = 0.0
	current_text = hints[current_index].text
	GameLog.info(LOG_TAG, "#%d %s" % [current_index, current_text.replace("\n", " ")])
	hint_changed.emit(current_text)
