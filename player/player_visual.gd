class_name PlayerVisual
extends Node3D
## The explorer's mesh rig. Milestone (c): blinks while invulnerable.
## Squash & stretch joins in milestone (e).

@export var health: PlayerHealth
@export var blink_frequency: float = 12.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	visible = health == null or not health.is_invulnerable() or fmod(_time * blink_frequency, 1.0) < 0.5
