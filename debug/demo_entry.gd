class_name DemoEntry
extends Node
## Entry scene for self-tests: play res://debug/demo_entry.tscn (e.g. with
## Beckett play_scene) and the DemoBot drives the player. Needed because
## play_scene cannot pass `--demo` and Beckett Lite cannot write runtime state.

const LOG_TAG := "Demo"

@export_file("*.tscn") var target_scene: String = "res://main/main.tscn"
## > 0 slows the menu autopilot so screens can be inspected.
@export var menu_delay: float = 0.0
## Endless levels to play after the tutorials (0 = tutorials only).
@export var endless_levels: int = 0
@export var endless_seed: int = 2026
## Where DemoReport writes screenshots and the JSON report ("" = none).
@export var report_dir: String = ""
## Start from a default demo save profile (deterministic progress).
@export var fresh_save: bool = false


func _ready() -> void:
	DemoMode.forced = true
	DemoMode.menu_delay = menu_delay
	DemoMode.options[MenuAutopilot.ENDLESS_LEVELS_PREFIX] = str(endless_levels)
	DemoMode.options[MenuAutopilot.ENDLESS_SEED_PREFIX] = str(endless_seed)
	DemoMode.options[DemoReport.REPORT_DIR_PREFIX] = report_dir
	if SaveSystem.current != null:
		SaveSystem.current.use_path(SaveSystem.DEMO_PATH)
		if fresh_save:
			SaveSystem.current.reset_to_defaults()
	GameLog.info(LOG_TAG, "forced demo mode -> %s" % target_scene)
	get_tree().change_scene_to_file.call_deferred(target_scene)
