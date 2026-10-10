class_name Vfx
extends RefCounted
## One-shot particle bursts built in code (no assets). Each burst is oriented
## so its +Y is the local planet up; particles use local coordinates, so
## "gravity" pulls toward the planet. Bursts free themselves on a timer.
## Process materials and draw meshes are built once per kind and shared, so a
## burst spawned from a physics callback allocates only the emitter node.

enum Kind { COLLECT, DUST, STOMP, HURT, PORTAL, EMBERS }

const FREE_MARGIN := 0.5
const QUAD_SIZE := 0.22
const SPRITE_RESOLUTION := 64
const PREWARM_POSITION := Vector3(0.0, -10000.0, 0.0)

## Verification counter.
static var bursts_spawned: int = 0

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _settings: Dictionary = {}


static func burst(parent: Node, position: Vector3, up: Vector3, kind: Kind) -> GPUParticles3D:
	if not _materials.has(kind):
		_build(kind)
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = true
	var setting: Vector2 = _settings[kind]
	particles.amount = int(setting.x)
	particles.lifetime = setting.y
	particles.process_material = _materials[kind]
	particles.draw_pass_1 = _meshes[kind]
	parent.add_child(particles)
	var right := VectorMath.any_perpendicular(up)
	particles.global_transform = Transform3D(Basis.looking_at(right, up), position)
	particles.emitting = true
	parent.get_tree().create_timer(particles.lifetime + FREE_MARGIN).timeout.connect(particles.queue_free)
	bursts_spawned += 1
	return particles


## Spawns one burst of every kind far out of view, so particle shaders compile
## while the level loads instead of hitching on the first landing or pickup.
static func prewarm(parent: Node) -> void:
	for kind: int in Kind.values():
		burst(parent, PREWARM_POSITION, Vector3.UP, kind)
	bursts_spawned -= Kind.size()


static func _build(kind: Kind) -> void:
	var particles := GPUParticles3D.new()
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	var color := Color.WHITE
	match kind:
		Kind.COLLECT:
			particles.amount = 36
			particles.lifetime = 0.8
			material.spread = 180.0
			_velocity(material, 2.5, 5.5)
			material.gravity = Vector3(0, -3.0, 0)
			color = Color(1.0, 0.85, 0.35)
		Kind.DUST:
			particles.amount = 14
			particles.lifetime = 0.5
			material.spread = 85.0
			_velocity(material, 1.0, 2.2)
			material.gravity = Vector3(0, -2.0, 0)
			material.damping_min = 3.0
			material.damping_max = 4.0
			color = Color(0.85, 0.82, 0.75, 0.8)
		Kind.STOMP:
			particles.amount = 28
			particles.lifetime = 0.55
			material.direction = Vector3.RIGHT
			material.spread = 180.0
			material.flatness = 1.0
			_velocity(material, 4.0, 7.0)
			material.gravity = Vector3.ZERO
			material.damping_min = 6.0
			material.damping_max = 8.0
			color = Color(1.0, 0.55, 0.5)
		Kind.HURT:
			particles.amount = 20
			particles.lifetime = 0.45
			material.spread = 180.0
			_velocity(material, 3.0, 6.0)
			material.gravity = Vector3(0, -8.0, 0)
			color = Color(1.0, 0.25, 0.3)
		Kind.PORTAL:
			particles.amount = 48
			particles.lifetime = 1.1
			material.spread = 180.0
			_velocity(material, 1.5, 4.0)
			material.gravity = Vector3(0, 1.5, 0)
			color = Color(0.7, 0.6, 1.0)
		Kind.EMBERS:
			particles.amount = 16
			particles.lifetime = 0.6
			material.spread = 40.0
			_velocity(material, 2.0, 4.5)
			material.gravity = Vector3(0, -4.0, 0)
			color = Color(1.0, 0.5, 0.1)
	material.scale_min = 0.6
	material.scale_max = 1.2
	material.color = color
	material.color_ramp = _fade_ramp()
	_materials[kind] = material
	_meshes[kind] = _quad(color)
	_settings[kind] = Vector2(particles.amount, particles.lifetime)
	particles.free()


static func _velocity(material: ParticleProcessMaterial, low: float, high: float) -> void:
	material.initial_velocity_min = low
	material.initial_velocity_max = high


static func _fade_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


## Soft round sprite: radial gradient from opaque centre to clear edge.
static func _soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = SPRITE_RESOLUTION
	texture.height = SPRITE_RESOLUTION
	return texture


static func _quad(color: Color) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _soft_dot()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_SIZE, QUAD_SIZE)
	quad.material = material
	return quad
