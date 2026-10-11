class_name SpikeBall
extends Node3D
## Spiked enemy that rolls a great circle around its planet. The node sits at
## the planet centre (parent it directly under a Planet) and spins about
## `patrol_axis`; its Body child rides the surface. Landing on top (feet above
## the ball centre while falling) destroys it and bounces the player; any other
## contact costs a heart.

signal defeated(enemy: SpikeBall)

const GROUP := &"enemies"
const LOG_TAG := "Enemy"
const GOLDEN_RATIO := 1.618034
## Icosahedron vertex directions for the spikes.
const SPIKE_DIRECTIONS: Array[Vector3] = [
	Vector3(0, 1, GOLDEN_RATIO), Vector3(0, 1, -GOLDEN_RATIO), Vector3(0, -1, GOLDEN_RATIO), Vector3(0, -1, -GOLDEN_RATIO),
	Vector3(1, GOLDEN_RATIO, 0), Vector3(1, -GOLDEN_RATIO, 0), Vector3(-1, GOLDEN_RATIO, 0), Vector3(-1, -GOLDEN_RATIO, 0),
	Vector3(GOLDEN_RATIO, 0, 1), Vector3(GOLDEN_RATIO, 0, -1), Vector3(-GOLDEN_RATIO, 0, 1), Vector3(-GOLDEN_RATIO, 0, -1),
]
const SPIKE_LENGTH := 0.4
const SPIKE_BASE_RADIUS := 0.11
## Spike centre above the core surface as a share of its length (0.5 would
## rest the base on the surface; less sinks it in a little).
const SPIKE_CENTER_OFFSET := 0.4
const CORE_RADIUS_FRACTION := 0.8
const CORE_RIM := 0.7
const CORE_SPEC := 0.4
const SPIKE_RIM := 0.5
const SPIKE_SPEC := 0.6
## The visual spins this many times faster than the patrol (reads as rolling).
const ROLL_SPIN_FACTOR := 3.0
const DEFEAT_TIME := 0.25
const SQUASHED_SCALE := Vector3(1.6, 0.15, 1.6)

@export var patrol_axis: Vector3 = Vector3.RIGHT
@export var start_direction: Vector3 = Vector3.UP
@export var patrol_speed_deg: float = 18.0
@export var ball_radius: float = 0.6
## Stomp when the player's feet are at least this share of the radius above the centre.
@export var stomp_height_fraction: float = 0.35
## Largest upward player speed (m/s, along the ball's up) still counted as landing on it.
@export var stomp_max_rise_speed: float = 0.5
@export var stomp_bounce_speed: float = 9.0
@export var contact_damage: int = 1
@export var core_color: Color = Color(0.55, 0.12, 0.18)
@export var spike_color: Color = Color(0.92, 0.9, 0.85)

## Core and spike meshes (with materials) shared by every ball of the same
## look: built once instead of per ball on the level-load frame.
static var _visual_cache: Dictionary = {}

var host_planet: Planet = null
var is_defeated: bool = false

@onready var body: Area3D = $Body
@onready var _visual: Node3D = $Body/Visual


## Pure stomp test: `feet_offset` = player feet minus ball centre, `ball_up` =
## outward unit normal under the ball, `rise_speed` = player velocity · ball_up.
## A fast fall is noticed a physics step late, with the feet already below the
## threshold: `prev_feet_offset` (the same offset one step earlier) also counts
## when the feet were above the threshold then and no further out sideways
## (perpendicular to `ball_up`) than `lateral_reach`, so a player falling past
## the ball's side still gets hit. Without it only the contact step counts.
static func is_stomp(feet_offset: Vector3, ball_up: Vector3, rise_speed: float,
		radius: float, height_fraction: float, max_rise: float,
		prev_feet_offset: Vector3 = Vector3.INF, lateral_reach: float = 0.0) -> bool:
	if rise_speed > max_rise:
		return false
	var threshold := radius * height_fraction
	if feet_offset.dot(ball_up) >= threshold:
		return true
	if not prev_feet_offset.is_finite():
		return false
	var prev_height := prev_feet_offset.dot(ball_up)
	var prev_lateral := (prev_feet_offset - ball_up * prev_height).length()
	return prev_height >= threshold and prev_lateral <= lateral_reach


func _ready() -> void:
	add_to_group(GROUP)
	host_planet = SurfaceAnchor.host_planet(self)
	position = Vector3.ZERO
	var axis := patrol_axis.normalized()
	var start := VectorMath.flatten(start_direction, axis)
	start = start.normalized() if start.length_squared() > VectorMath.MIN_LENGTH_SQ else VectorMath.any_perpendicular(axis)
	var radius := host_planet.radius if host_planet != null else 0.0
	body.position = start * (radius + ball_radius)
	body.basis = Basis.looking_at(axis.cross(start), start)
	body.collision_layer = PhysicsLayers.ENEMY
	body.collision_mask = PhysicsLayers.PLAYER
	(body.get_node(^"CollisionShape3D") as CollisionShape3D).shape = _sphere_shape()
	body.body_entered.connect(_on_body_entered)
	_build_visual()


func _physics_process(delta: float) -> void:
	if is_defeated:
		return
	rotate_object_local(patrol_axis.normalized(), deg_to_rad(patrol_speed_deg) * delta)
	_visual.rotate_object_local(Vector3.RIGHT, deg_to_rad(patrol_speed_deg) * delta * ROLL_SPIN_FACTOR)


## World position of the body `seconds` from now: the node turns about its
## own `patrol_axis` (fixed in world space) at a constant rate, so the body
## sweeps a great circle around the planet centre.
func predicted_body_position(seconds: float) -> Vector3:
	var center := global_position
	var axis := (global_basis * patrol_axis).normalized()
	var turned := (body.global_position - center).rotated(axis, deg_to_rad(patrol_speed_deg) * seconds)
	return center + turned


func ball_up() -> Vector3:
	if host_planet == null:
		return body.global_basis.y
	return (body.global_position - host_planet.global_position).normalized()


func defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	body.set_deferred(&"monitoring", false)
	GameLog.info(LOG_TAG, "%s defeated" % name)
	defeated.emit(self)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", SQUASHED_SCALE, DEFEAT_TIME)
	tween.tween_callback(queue_free)


func _on_body_entered(other: Node3D) -> void:
	var player := other as PlayerController
	if player == null or is_defeated:
		return
	var up := ball_up()
	var feet_offset := player.global_position - body.global_position
	var step := 1.0 / Engine.physics_ticks_per_second
	var prev_feet_offset := player.previous_global_position - predicted_body_position(-step)
	if is_stomp(feet_offset, up, player.velocity.dot(up), ball_radius, stomp_height_fraction, stomp_max_rise_speed,
			prev_feet_offset, ball_radius + player.collision_radius()):
		player.bounce(stomp_bounce_speed)
		defeat()
	else:
		player.take_hit(contact_damage, body.global_position, "spike ball")


func _sphere_shape() -> SphereShape3D:
	var shape := SphereShape3D.new()
	shape.radius = ball_radius
	return shape


func _build_visual() -> void:
	var meshes := _visual_meshes()
	var core := MeshInstance3D.new()
	core.mesh = meshes[0]
	_visual.add_child(core)
	var core_radius := ball_radius * CORE_RADIUS_FRACTION
	for direction: Vector3 in SPIKE_DIRECTIONS:
		var dir := direction.normalized()
		var spike := MeshInstance3D.new()
		spike.mesh = meshes[1]
		spike.transform = Transform3D(Basis.looking_at(VectorMath.any_perpendicular(dir), dir),
			dir * (core_radius + SPIKE_LENGTH * SPIKE_CENTER_OFFSET))
		_visual.add_child(spike)


## [core sphere, spike cone] for this ball's size and colours (cached).
func _visual_meshes() -> Array[Mesh]:
	var key := "%s|%s|%s" % [ball_radius, core_color.to_html(), spike_color.to_html()]
	if _visual_cache.has(key):
		return _visual_cache[key]
	var core_mesh := SphereMesh.new()
	core_mesh.radius = ball_radius * CORE_RADIUS_FRACTION
	core_mesh.height = core_mesh.radius * 2.0
	core_mesh.material = ToonMaterials.make(core_color, CORE_RIM, CORE_SPEC)
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = SPIKE_BASE_RADIUS
	spike_mesh.height = SPIKE_LENGTH
	spike_mesh.material = ToonMaterials.make(spike_color, SPIKE_RIM, SPIKE_SPEC, ToonMaterials.NO_OUTLINE)
	var meshes: Array[Mesh] = [core_mesh, spike_mesh]
	_visual_cache[key] = meshes
	return meshes

