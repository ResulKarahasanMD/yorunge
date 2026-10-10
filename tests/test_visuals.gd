extends TestSuite
## Visual building blocks that can be checked without a GPU: decoration counts
## and determinism, toon material wiring, planet shader parameters, and the
## load-frame savings (shared meshes, decorations spread over later frames).

const GRASS := preload("res://world/styles/grass.tres")
const LAVA := preload("res://world/styles/lava.tres")
const PLANET_SCENE := preload("res://world/planet.tscn")
const RADIUS := 10.0
const HUGE_RADIUS := 60.0
const SEED := 12345
const SPIKE_SCENE := preload("res://world/spike_ball.tscn")
const SMALL_RADIUS := 4.0
const SPREAD_PLANETS := 3
## Frames a deferred decoration may need (the request frame is skipped).
const DECORATION_FRAMES := 3
const SIZE_EPSILON := 0.01


func _decorator(radius: float, style: PlanetStyle, seed_value: int) -> SurfaceDecorator:
	var decorator := SurfaceDecorator.new()
	spawn(decorator)
	decorator.build(radius, style, seed_value)
	return decorator


func _layout(seed_value: int) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SurfaceDecorator.scatter_transforms(50, RADIUS, 1.0, 0.4, 0.1, rng)


func test_counts_follow_surface_area() -> void:
	var decorator := _decorator(RADIUS, GRASS, SEED)
	var area := 4.0 * PI * RADIUS * RADIUS
	var expected := int(area * 0.55) + int(area * 0.05)
	check(decorator.instance_total == expected, "grass R10 places %d props (got %d)" % [expected, decorator.instance_total])
	check(decorator.get_child_count() == 2, "grass has tufts and flowers")
	var huge := _decorator(HUGE_RADIUS, GRASS, SEED)
	var tufts := (huge.get_child(0) as MultiMeshInstance3D).multimesh.instance_count
	check(tufts == SurfaceDecorator.MAX_INSTANCES, "huge planet is capped at %d per prop (got %d)" % [SurfaceDecorator.MAX_INSTANCES, tufts])


func test_props_sit_on_the_surface() -> void:
	var worst := 0.0
	var up_error := 0.0
	for xform: Transform3D in _layout(SEED):
		worst = maxf(worst, absf(xform.origin.length() - RADIUS))
		up_error = maxf(up_error, xform.basis.y.normalized().angle_to(xform.origin.normalized()))
	check(worst < 0.2, "every prop origin within 0.2 m of the surface (worst %.3f)" % worst)
	check(up_error < 0.001, "props stand along the local up (worst %.5f rad)" % up_error)
	var decorator := _decorator(RADIUS, LAVA, SEED)
	var ember := decorator.get_child(1) as MultiMeshInstance3D
	var material := ember.material_override as ShaderMaterial
	check(material.get_shader_parameter(&"emission_energy") > 0.0, "lava embers glow")


func test_decoration_is_deterministic() -> void:
	var a := _layout(SEED)
	var b := _layout(SEED)
	var c := _layout(SEED + 1)
	check(a[0].is_equal_approx(b[0]) and a[49].is_equal_approx(b[49]), "same seed, same layout")
	check(not a[0].is_equal_approx(c[0]), "different seed, different layout")


func test_toon_material_outline() -> void:
	var outlined := ToonMaterials.make(Color.RED)
	check(outlined.next_pass is ShaderMaterial, "outline pass attached by default")
	check(ToonMaterials.make(Color.RED, 0.5, 0.2, 0.0).next_pass == null, "zero width skips the outline")
	check(outlined.get_shader_parameter(&"albedo") == Color.RED, "albedo forwarded")


func test_planet_applies_style_to_shader() -> void:
	var planet := PLANET_SCENE.instantiate() as Planet
	planet.radius = 7.0
	planet.style = LAVA
	spawn(planet)
	var surface := (planet.get_node(^"Surface") as MeshInstance3D).material_override as ShaderMaterial
	check(surface.get_shader_parameter(&"surface_type") == int(PlanetStyle.Surface.LAVA), "surface type forwarded")
	check(surface.get_shader_parameter(&"color_accent") == LAVA.color_accent, "accent colour forwarded")
	var glow := (planet.get_node(^"Atmosphere") as MeshInstance3D).material_override as ShaderMaterial
	check_near(glow.get_shader_parameter(&"shell_radius"), 7.0 * planet.atmosphere_scale, "atmosphere shell radius forwarded")
	check(planet.decoration_pending(), "decoration waits for a later frame")
	for i in DECORATION_FRAMES:
		await tree.process_frame
	check(planet.decoration_count() > 0, "planet decorated")


## Every planet draws the same unit spheres, scaled by the instance: no ground
## or atmosphere mesh is generated (and uploaded) per planet on the load frame.
func test_planets_share_unit_spheres() -> void:
	var small := _planet(Vector3.ZERO, SMALL_RADIUS, GRASS)
	var big := _planet(Vector3(40.0, 0.0, 0.0), RADIUS, LAVA)
	var small_ground := small.get_node(^"Surface") as MeshInstance3D
	var big_ground := big.get_node(^"Surface") as MeshInstance3D
	var small_air := small.get_node(^"Atmosphere") as MeshInstance3D
	var big_air := big.get_node(^"Atmosphere") as MeshInstance3D
	check(small_ground.mesh == big_ground.mesh, "ground mesh shared")
	check(small_air.mesh == big_air.mesh, "atmosphere mesh shared")
	check_near(big_ground.get_aabb().size.y * big_ground.scale.y, RADIUS * 2.0, "ground spans the planet diameter (pole to pole)", SIZE_EPSILON)
	check_near(big_air.get_aabb().size.y * big_air.scale.y, RADIUS * 2.0 * big.atmosphere_scale, "atmosphere spans the shell (pole to pole)", SIZE_EPSILON)
	var ground := big_ground.material_override as ShaderMaterial
	check_near(ground.get_shader_parameter(&"object_scale"), RADIUS, "surface noise stays in metres")


## A level's planets decorate after the load frame, at most one per frame.
func test_decorations_follow_the_load_frame_one_planet_per_frame() -> void:
	var planets: Array[Planet] = []
	for i in SPREAD_PLANETS:
		planets.append(_planet(Vector3(40.0 * i, 0.0, 0.0), SMALL_RADIUS, GRASS))
	var decorated: Array[int] = [_decorated(planets)]
	for i in SPREAD_PLANETS + DECORATION_FRAMES:
		await tree.process_frame
		decorated.append(_decorated(planets))
	var largest_step := 0
	for i in range(1, decorated.size()):
		largest_step = maxi(largest_step, decorated[i] - decorated[i - 1])
	check(decorated[0] == 0, "nothing decorated on the load frame (%s)" % [decorated])
	check(largest_step == 1, "one planet per frame (%s)" % [decorated])
	check(decorated[-1] == SPREAD_PLANETS, "every planet decorated in the end (%s)" % [decorated])


## Spike balls of the same look share their meshes and materials.
func test_spike_balls_share_visuals() -> void:
	var planet := _planet(Vector3.ZERO, RADIUS, GRASS)
	var balls: Array[SpikeBall] = []
	for i in 2:
		var ball := SPIKE_SCENE.instantiate() as SpikeBall
		planet.add_child(ball)
		balls.append(ball)
	var first := balls[0].get_node(^"Body/Visual")
	var second := balls[1].get_node(^"Body/Visual")
	check(first.get_child_count() == SpikeBall.SPIKE_DIRECTIONS.size() + 1, "core plus one cone per spike")
	check((first.get_child(0) as MeshInstance3D).mesh == (second.get_child(0) as MeshInstance3D).mesh, "core mesh shared")
	check((first.get_child(1) as MeshInstance3D).mesh == (second.get_child(1) as MeshInstance3D).mesh, "spike mesh shared")


func _planet(at: Vector3, radius: float, style: PlanetStyle) -> Planet:
	var planet := PLANET_SCENE.instantiate() as Planet
	planet.radius = radius
	planet.style = style
	planet.position = at
	spawn(planet)
	return planet


static func _decorated(planets: Array[Planet]) -> int:
	return planets.filter(func(planet: Planet) -> bool: return planet.decoration_count() > 0).size()
