@tool
class_name SurfaceDecorator
extends Node3D
## Scatters non-colliding props over a planet (grass tufts and flowers, ice
## crystals, lava boulders and embers, moon rocks) as one MultiMesh per prop.
## Deterministic per seed, scaled by surface area, capped for performance.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
## Hard cap per prop kind so a huge planet cannot flood the GPU.
const MAX_INSTANCES := 1500

## kind -> [mesh builder name, instances per m², base scale, scale jitter, sink depth]
const GRASS_PROPS := {
	"tuft": ["_tuft_mesh", 0.55, 1.0, 0.45, 0.05],
	"flower": ["_flower_mesh", 0.05, 1.0, 0.3, 0.0],
}
const ICE_PROPS := {
	"crystal": ["_crystal_mesh", 0.06, 1.0, 0.6, 0.15],
}
const LAVA_PROPS := {
	"boulder": ["_boulder_mesh", 0.04, 1.0, 0.6, 0.2],
	"ember": ["_ember_mesh", 0.05, 1.0, 0.4, 0.0],
}
const ROCK_PROPS := {
	"rock": ["_boulder_mesh", 0.035, 0.8, 0.7, 0.25],
}

## Total instances placed by the last build (performance report).
var instance_total: int = 0


func build(radius: float, style: PlanetStyle, seed_value: int) -> void:
	for child: Node in get_children():
		child.queue_free()
	instance_total = 0
	if style == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var area := 4.0 * PI * radius * radius
	for kind: String in _props_for(style.surface):
		var spec: Array = _props_for(style.surface)[kind]
		var count := mini(int(area * float(spec[1])), MAX_INSTANCES)
		if count <= 0:
			continue
		var mesh: Mesh = call(spec[0])
		add_child(_scatter(kind, mesh, count, radius, spec, style, rng))
		instance_total += count


## Uniformly distributed props on a sphere: random direction, random yaw,
## scale = base * (1 ± jitter), sunk `sink` × scale below the surface.
## Pure (MultiMesh data lives in the RenderingServer, so tests check this).
static func scatter_transforms(count: int, radius: float, base_scale: float, jitter: float,
		sink: float, rng: RandomNumberGenerator) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for i in count:
		var up := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var heading := VectorMath.any_perpendicular(up).rotated(up, rng.randf() * TAU)
		var scale := base_scale * (1.0 + rng.randf_range(-1.0, 1.0) * jitter)
		var basis := Basis.looking_at(heading, up).scaled(Vector3.ONE * scale)
		transforms.append(Transform3D(basis, up * (radius - sink * scale)))
	return transforms


func _props_for(surface: PlanetStyle.Surface) -> Dictionary:
	match surface:
		PlanetStyle.Surface.ICE:
			return ICE_PROPS
		PlanetStyle.Surface.LAVA:
			return LAVA_PROPS
		PlanetStyle.Surface.ROCK:
			return ROCK_PROPS
	return GRASS_PROPS


func _scatter(kind: String, mesh: Mesh, count: int, radius: float, spec: Array,
		style: PlanetStyle, rng: RandomNumberGenerator) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var transforms := scatter_transforms(count, radius, float(spec[2]), float(spec[3]), float(spec[4]), rng)
	for i in count:
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, _tint(kind, style, rng))
	var instance := MultiMeshInstance3D.new()
	instance.name = kind.capitalize()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.material_override = _material(kind, style)
	return instance


func _tint(kind: String, style: PlanetStyle, rng: RandomNumberGenerator) -> Color:
	match kind:
		"tuft":
			return style.color_low.lerp(style.color_mid, rng.randf()).darkened(rng.randf_range(0.0, 0.2))
		"flower":
			return style.color_accent.lerp(Color(1.0, 0.55, 0.75), rng.randf() * 0.7)
		"crystal":
			return style.color_high.lerp(style.color_accent, rng.randf() * 0.6)
		"ember":
			return style.color_accent
	return style.color_low.lerp(style.color_mid, rng.randf()).darkened(0.2)


func _material(kind: String, style: PlanetStyle) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TOON_SHADER
	material.set_shader_parameter(&"use_vertex_color", true)
	material.set_shader_parameter(&"rim_strength", 0.15)
	# Flat prism faces flash white under the toon specular band; keep props matte.
	material.set_shader_parameter(&"spec_strength", 0.0)
	if kind == "ember":
		material.set_shader_parameter(&"emission_color", style.color_accent)
		material.set_shader_parameter(&"emission_energy", 3.0)
	if kind == "crystal":
		material.set_shader_parameter(&"spec_strength", 0.9)
	return material


func _tuft_mesh() -> Mesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.14, 0.42, 0.06)
	return mesh


func _flower_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh


func _crystal_mesh() -> Mesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.28, 0.9, 0.28)
	return mesh


func _boulder_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.6
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh


func _ember_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh
