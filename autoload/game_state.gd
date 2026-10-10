class_name GameStateManager
extends Node
## Global game-flow state, autoloaded as `GameState`.
## Milestone 0 scope: input registration and demo-mode announcement.
## Level flow, stardust counters and mode selection land here in later milestones.

const LOG_TAG := "Game"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.register_defaults()
	GameLog.info(LOG_TAG, "boot: demo_mode=%s" % DemoMode.is_active())
