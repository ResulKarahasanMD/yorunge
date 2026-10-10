@tool
class_name Planet
extends AnimatableBody3D
## A walkable spherical world that builds its own collision, mesh, atmosphere,
## surface decorations and gravity well from `radius` and `style`, so levels
## (hand-made or generated) only set exports. Children are created in code and
## never saved into the level scene.
## A non-zero `spin_speed_deg` turns it into a rotating moon; AnimatableBody3D
## with sync_to_physics carries whatever stands on it.

const GROUP := &"planets"
const MESH_RADIAL_SEGMENTS := 64
const MESH_RINGS := 32
const ATMOSPHERE_SEGMENTS := 48
const ATMOSPHERE_RINGS := 24
const SURFACE_SHADER := preload("res://shaders/planet_surface.gdshader")
const ATMOSPHERE_SHADER := preload("res://shaders/atmosphere.gdshader")

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

@export_group("Look")
## Atmosphere shell radius as a multiple of the planet radius.
@export var atmosphere_scale: float = 1.15
@export var decorate: bool = true

var gravity_source: GravitySource
var _collision: CollisionShape3D
var _mesh_instance: MeshInstance3D
var _atmosphere: MeshInstance3D
var _decorator: SurfaceDecorator


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
		_apply_style()


func set_style(value: PlanetStyle) -> void:
	style = value
	if is_node_ready():
		_apply_style()


func surface_type() -> PlanetStyle.Surface:
	return style.surface if style != null else PlanetStyle.Surface.GRASS


## Instances scattered by the decorator (performance reporting).
func decoration_count() -> int:
	return _decorator.instance_total if _decorator != null else 0


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

	_atmosphere = MeshInstance3D.new()
	_atmosphere.name = "Atmosphere"
	var shell := SphereMesh.new()
	shell.radial_segments = ATMOSPHERE_SEGMENTS
	shell.rings = ATMOSPHERE_RINGS
	_atmosphere.mesh = shell
	_atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := ShaderMaterial.new()
	glow.shader = ATMOSPHERE_SHADER
	_atmosphere.material_override = glow
	add_child(_atmosphere)

	_decorator = SurfaceDecorator.new()
	_decorator.name = "Decorations"
	add_child(_decorator)

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
	var shell := _atmosphere.mesh as SphereMesh
	shell.radius = radius * atmosphere_scale
	shell.height = radius * atmosphere_scale * 2.0
	var glow := _atmosphere.material_override as ShaderMaterial
	glow.set_shader_parameter(&"planet_radius", radius)
	glow.set_shader_parameter(&"shell_radius", shell.radius)
	if gravity_source != null:
		gravity_source.strength = gravity_strength
		gravity_source.surface_radius = radius
		gravity_source.core_margin = gravity_core_margin
		gravity_source.influence_radius = radius + influence_margin


func _apply_style() -> void:
	var surface := ShaderMaterial.new()
	surface.shader = SURFACE_SHADER
	if style != null:
		surface.set_shader_parameter(&"surface_type", int(style.surface))
		surface.set_shader_parameter(&"color_low", style.color_low)
		surface.set_shader_parameter(&"color_mid", style.color_mid)
		surface.set_shader_parameter(&"color_high", style.color_high)
		surface.set_shader_parameter(&"color_accent", style.color_accent)
		(_atmosphere.material_override as ShaderMaterial).set_shader_parameter(&"glow_color", style.atmosphere_color)
	_mesh_instance.material_override = surface
	if decorate:
		_decorator.build(radius, style, _decoration_seed())


## Stable per planet: name and size, so tutorial levels look the same every run.
func _decoration_seed() -> int:
	return hash([String(name), snappedf(radius, 0.01)])
