class_name Level
extends Node3D
## Base for every playable level (hand-made tutorials and generated ones).
## Wires the player, camera and input strategy. Stardust/portal flow arrives
## in milestone (c).

## AUTO: DemoBot when DemoMode is active, HumanInput otherwise.
## NONE: nobody drives the player (fixed-pose test scenes; keeps the mouse free).
enum InputMode { AUTO, HUMAN, DEMO, NONE }

const LOG_TAG := "Level"

@export var level_title: String = ""
@export var player: PlayerController
@export var camera_rig: OrbitCameraRig
@export var input_mode: InputMode = InputMode.AUTO

var input_source: PlayerInput = null


func _ready() -> void:
	camera_rig.set_target(player)
	_install_input()
	GameLog.info(LOG_TAG, "ready: %s (input=%s, planets=%d)" % [
		level_title, input_source.name if input_source != null else "none",
		get_tree().get_nodes_in_group(Planet.GROUP).size()])


func _install_input() -> void:
	var mode := input_mode
	if mode == InputMode.AUTO:
		mode = InputMode.DEMO if DemoMode.is_active() else InputMode.HUMAN
	match mode:
		InputMode.DEMO:
			input_source = DemoBot.new()
			input_source.name = "DemoBot"
		InputMode.HUMAN:
			var human := HumanInput.new()
			human.camera_rig = camera_rig
			human.name = "HumanInput"
			input_source = human
		_:
			return
	add_child(input_source)
	player.input_source = input_source
	input_source.bind(player)
