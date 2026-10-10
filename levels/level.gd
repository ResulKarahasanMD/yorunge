class_name Level
extends Node3D
## Base for every playable level (hand-made tutorials and generated ones).
## Wires the player, camera and input strategy: DemoBot when DemoMode is
## active, HumanInput otherwise. Stardust/portal flow arrives in milestone (c).

const LOG_TAG := "Level"

@export var level_title: String = ""
@export var player: PlayerController
@export var camera_rig: OrbitCameraRig

var input_source: PlayerInput = null


func _ready() -> void:
	camera_rig.set_target(player)
	_install_input()
	GameLog.info(LOG_TAG, "ready: %s (input=%s, planets=%d)" % [
		level_title, input_source.name, get_tree().get_nodes_in_group(Planet.GROUP).size()])


func _install_input() -> void:
	if DemoMode.is_active():
		input_source = DemoBot.new()
		input_source.name = "DemoBot"
	else:
		var human := HumanInput.new()
		human.camera_rig = camera_rig
		human.name = "HumanInput"
		input_source = human
	add_child(input_source)
	player.input_source = input_source
	input_source.bind(player)
