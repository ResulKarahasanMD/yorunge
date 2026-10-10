class_name Stardust
extends Area3D
## Collectible star shard floating above a planet. Five per level open the
## exit portal. Parent it under a Planet; SurfaceAnchor sets its altitude.

signal collected(stardust: Stardust)

const GROUP := &"stardust"
const LOG_TAG := "Stardust"

@export var hover_altitude: float = 1.1
@export var bob_amplitude: float = 0.15
@export var bob_frequency: float = 0.8
@export var spin_speed_deg: float = 120.0

var is_collected: bool = false
var host_planet: Planet = null

var _time: float = 0.0

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.PICKUP
	collision_mask = PhysicsLayers.PLAYER
	host_planet = SurfaceAnchor.snap(self, hover_altitude)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_visual.position.y = sin(_time * TAU * bob_frequency) * bob_amplitude
	_visual.rotate_y(deg_to_rad(spin_speed_deg) * delta)


func collect() -> void:
	if is_collected:
		return
	is_collected = true
	set_deferred(&"monitoring", false)
	GameLog.info(LOG_TAG, "collected %s" % name)
	collected.emit(self)
	queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		collect()
