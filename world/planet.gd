@tool
class_name Planet
extends AnimatableBody3D
## A walkable spherical world that builds its own collision, mesh and gravity
## well from `radius`, so levels (hand-made or generated) only set exports.
## Children are created in code and never saved into the level scene.
## A non-zero `spin_speed_deg` turns it into a rotating moon; AnimatableBody3D
## with sync_to_physics carries whatever stands on it.

const GROUP := &"planets"
const MESH_RADIAL_SEGMENTS := 64
const MESH_RINGS := 32

@export_range(1.0, 60.0, 0.1, "or_greater") var radius: float = 10.0:
	set = set_radius
@export var style: PlanetStyle:
	set = set_style

@export_group("Gravity")
@export var gravity_strength: float = 24.0
## Full-strength pull extends this far above the surface.
@export var gravity_core_margin: float = 1.5
## Pull fades to zero this far above the surface.
@export var influence_margin: float = 10.0

@export_group("Spin")
@export var spin_axis: Vector3 = Vector3.UP
@export var spin_speed_deg: float = 0.0

var gravity_source: GravitySource
var _collision: CollisionShape3D
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	sync_to_physics = true
	_build_children()
	_apply_radius()
	_apply_style()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_zero_approx(spin_speed_deg):
		return
	rotate(spin_axis.normalized(), deg_to_rad(spin_speed_deg) * delta)


func set_radius(value: float) -> void:
	radius = value
	if is_node_ready():
		_apply_radius()


func set_style(value: PlanetStyle) -> void:
	style = value
	if is_node_ready():
		_apply_style()


func surface_type() -> PlanetStyle.Surface:
	return style.surface if style != null else PlanetStyle.Surface.GRASS


func _build_children() -> void:
	_collision = CollisionShape3D.new()
	_collision.name = "Collision"
	_collision.shape = SphereShape3D.new()
	add_child(_collision)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Surface"
	var sphere := SphereMesh.new()
	sphere.radial_segments = MESH_RADIAL_SEGMENTS
	sphere.rings = MESH_RINGS
	_mesh_instance.mesh = sphere
	add_child(_mesh_instance)

	# GravitySource is not a tool script; only the running game needs it.
	if not Engine.is_editor_hint():
		gravity_source = GravitySource.new()
		gravity_source.name = "GravitySource"
		add_child(gravity_source)


func _apply_radius() -> void:
	(_collision.shape as SphereShape3D).radius = radius
	var sphere := _mesh_instance.mesh as SphereMesh
	sphere.radius = radius
	sphere.height = radius * 2.0
	if gravity_source != null:
		gravity_source.strength = gravity_strength
		gravity_source.surface_radius = radius
		gravity_source.core_margin = gravity_core_margin
		gravity_source.influence_radius = radius + influence_margin


func _apply_style() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = style.color_mid if style != null else Color.GRAY
	material.roughness = 0.85
	_mesh_instance.material_override = material
