class_name ExitPortal
extends Area3D
## Level exit. Dormant until every stardust is collected; then it lights up
## and entering it completes the level.

signal entered

const GROUP := &"exit_portal"
const LOG_TAG := "Portal"

@export var hover_altitude: float = 1.35
@export var spin_speed_deg: float = 60.0
## Seconds for the membrane to fade from dormant to active.
@export var open_time: float = 0.8

var is_active: bool = false
var host_planet: Planet = null

var _disc_material: ShaderMaterial

@onready var _ring: Node3D = $Visual/Ring
@onready var _disc: MeshInstance3D = $Visual/Disc


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.PICKUP
	collision_mask = PhysicsLayers.PLAYER
	host_planet = SurfaceAnchor.snap(self, hover_altitude)
	_disc_material = (_disc.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_disc.material_override = _disc_material
	_disc_material.set_shader_parameter(&"active", 0.0)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if is_active:
		_ring.rotate_object_local(Vector3.FORWARD, deg_to_rad(spin_speed_deg) * delta)


func activate() -> void:
	if is_active:
		return
	is_active = true
	create_tween().tween_method(func(value: float) -> void:
		_disc_material.set_shader_parameter(&"active", value), 0.0, 1.0, open_time)
	GameLog.info(LOG_TAG, "activated on %s" % (host_planet.name if host_planet != null else "?"))
	for body: Node3D in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node3D) -> void:
	if not is_active or not (body is PlayerController):
		return
	is_active = false
	set_deferred(&"monitoring", false)
	GameLog.info(LOG_TAG, "entered")
	entered.emit()
