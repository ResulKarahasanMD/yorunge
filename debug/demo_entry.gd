class_name DemoEntry
extends Node
## Entry scene for self-tests: play res://debug/demo_entry.tscn (e.g. with
## Beckett play_scene) and the DemoBot drives the player. Needed because
## play_scene cannot pass `--demo` and Beckett Lite cannot write runtime state.

const LOG_TAG := "Demo"

@export_file("*.tscn") var target_scene: String = "res://main/main.tscn"
## > 0 slows the menu autopilot so screens can be inspected.
@export var menu_delay: float = 0.0


func _ready() -> void:
	DemoMode.forced = true
	DemoMode.menu_delay = menu_delay
	if SaveSystem.current != null:
		SaveSystem.current.use_path(SaveSystem.DEMO_PATH)
	GameLog.info(LOG_TAG, "forced demo mode -> %s" % target_scene)
	get_tree().change_scene_to_file.call_deferred(target_scene)
