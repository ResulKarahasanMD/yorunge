class_name PlayerInput
extends Node
## Strategy interface the PlayerController polls once per physics tick.
## HumanInput reads devices; DemoBot (AI) drives the same API for self-testing.

var player: PlayerController = null


func bind(target: PlayerController) -> void:
	player = target


## Desired move direction in WORLD space, length 0..1. The controller projects
## it onto the local tangent plane, so callers need not.
func get_move_direction() -> Vector3:
	return Vector3.ZERO


## True once per jump press (edge); the controller buffers it.
func consume_jump_pressed() -> bool:
	return false


## Held state, used for variable jump height.
func is_jump_held() -> bool:
	return false
