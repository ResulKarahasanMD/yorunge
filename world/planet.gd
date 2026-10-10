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
const UNIT_RADIUS := 1.0

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
## Non-zero overrides the name-based decoration seed (generated levels).
@export var decoration_seed: int = 0

## Unit spheres shared by every planet and scaled per instance: a SphereMesh
## per planet was generated and uploaded to the GPU on the level-load frame
## (about 1 ms each in a window).
static var _unit_surface: SphereMesh = null
static var _unit_shell: SphereMesh = null

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


## Decorations requested but not built yet (they follow the load frame).
func decoration_pending() -> bool:
	return _decorator != null and _decorator.is_pending()


func _build_children() -> void:
	_collision = CollisionShape3D.new()
	_collision.name = "Collision"
	_collision.shape = SphereShape3D.new()
	add_child(_collision)

	if _unit_surface == null:
		_unit_surface = _unit_sphere(MESH_RADIAL_SEGMENTS, MESH_RINGS)
		_unit_shell = _unit_sphere(ATMOSPHERE_SEGMENTS, ATMOSPHERE_RINGS)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Surface"
	_mesh_instance.mesh = _unit_surface
	add_child(_mesh_instance)

	_atmosphere = MeshInstance3D.new()
	_atmosphere.name = "Atmosphere"
	_atmosphere.mesh = _unit_shell
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


static func _unit_sphere(segments: int, rings: int) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = UNIT_RADIUS
	sphere.height = UNIT_RADIUS * 2.0
	sphere.radial_segments = segments
	sphere.rings = rings
	return sphere


func _apply_radius() -> void:
	(_collision.shape as SphereShape3D).radius = radius
	_mesh_instance.scale = Vector3.ONE * (radius / UNIT_RADIUS)
	var shell_radius := radius * atmosphere_scale
	_atmosphere.scale = Vector3.ONE * (shell_radius / UNIT_RADIUS)
	var glow := _atmosphere.material_override as ShaderMaterial
	glow.set_shader_parameter(&"planet_radius", radius)
	glow.set_shader_parameter(&"shell_radius", shell_radius)
	if gravity_source != null:
		gravity_source.strength = gravity_strength
		gravity_source.surface_radius = radius
		gravity_source.core_margin = gravity_core_margin
		gravity_source.influence_radius = radius + influence_margin


func _apply_style() -> void:
	var surface := ShaderMaterial.new()
	surface.shader = SURFACE_SHADER
	surface.set_shader_parameter(&"object_scale", radius / UNIT_RADIUS)
	if style != null:
		surface.set_shader_parameter(&"surface_type", int(style.surface))
		surface.set_shader_parameter(&"color_low", style.color_low)
		surface.set_shader_parameter(&"color_mid", style.color_mid)
		surface.set_shader_parameter(&"color_high", style.color_high)
		surface.set_shader_parameter(&"color_accent", style.color_accent)
		(_atmosphere.material_override as ShaderMaterial).set_shader_parameter(&"glow_color", style.atmosphere_color)
	_mesh_instance.material_override = surface
	if decorate:
		if Engine.is_editor_hint():
			_decorator.build(radius, style, _decoration_seed())
		else:
			_decorator.build_deferred(radius, style, _decoration_seed())


## Stable per planet: name and size, so tutorial levels look the same every run.
func _decoration_seed() -> int:
	if decoration_seed != 0:
		return decoration_seed
	return hash([String(name), snappedf(radius, 0.01)])
