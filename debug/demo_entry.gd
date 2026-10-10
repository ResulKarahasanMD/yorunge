class_name DemoEntry
extends Node
## Entry scene for self-tests: play res://debug/demo_entry.tscn (e.g. with
## Beckett play_scene) and the DemoBot drives the player. Needed because
## play_scene cannot pass `--demo` and Beckett Lite cannot write runtime state.

const LOG_TAG := "Demo"

@export_file("*.tscn") var target_scene: String = "res://main/main.tscn"


func _ready() -> void:
	DemoMode.forced = true
	GameLog.info(LOG_TAG, "forced demo mode -> %s" % target_scene)
	get_tree().change_scene_to_file.call_deferred(target_scene)
