class_name PlayerHealth
extends Node
## Hearts, damage and the invulnerability window after a hit.

signal damaged(amount: int, hearts: int, cause: String)
signal died

const LOG_TAG := "Health"

@export var max_hearts: int = 3
@export var invulnerable_time: float = 1.5

var hearts: int = 0
## Total hearts lost since the level started (level stats).
var damage_taken: int = 0
## Set once the level is won: nothing hurts the explorer any more.
var immune: bool = false

var _invulnerable_left: float = 0.0


func _ready() -> void:
	hearts = max_hearts


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func is_dead() -> bool:
	return hearts <= 0


## Applies damage unless immune, invulnerable or already dead. Returns true when it hit.
func take_damage(amount: int, cause: String) -> bool:
	if amount <= 0 or immune or is_dead() or is_invulnerable():
		return false
	hearts = maxi(hearts - amount, 0)
	damage_taken += amount
	_invulnerable_left = invulnerable_time
	GameLog.info(LOG_TAG, "-%d (%s) hearts=%d" % [amount, cause, hearts])
	damaged.emit(amount, hearts, cause)
	if hearts == 0:
		died.emit()
	return true
