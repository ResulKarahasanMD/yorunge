// Planet ground: object-space fractal noise mapped onto the style's colour
// ramp, plus one feature layer per surface type, lit with the toon model.
// Object space keeps patterns glued to spinning moons. No vertex displacement,
// so the sphere collider matches what you see.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/toon_light.gdshaderinc"

const int SURFACE_GRASS = 0;
const int SURFACE_ICE = 1;
const int SURFACE_LAVA = 2;
const int SURFACE_ROCK = 3;

uniform int surface_type = 0;
uniform vec3 color_low : source_color = vec3(0.16, 0.42, 0.22);
uniform vec3 color_mid : source_color = vec3(0.32, 0.66, 0.30);
uniform vec3 color_high : source_color = vec3(0.60, 0.84, 0.38);
uniform vec3 color_accent : source_color = vec3(1.0, 0.86, 0.42);
// Size of the large colour patches in metres.
uniform float patch_size = 3.5;
// Size of feature cells (flowers, ice plates, lava crust, craters) in metres.
uniform float feature_size = 1.6;
uniform float rim_strength = 0.35;
uniform float lava_glow = 3.0;
uniform float lava_flow_speed = 0.12;

varying vec3 object_position;
varying float spec_strength;

void vertex() {
	object_position = VERTEX;
}

vec3 ramp(float n) {
	vec3 color = mix(color_low, color_mid, smoothstep(0.32, 0.5, n));
	return mix(color, color_high, smoothstep(0.6, 0.78, n));
}

void fragment() {
	vec3 p = object_position;
	float n = fbm(p / patch_size);
	vec3 color = ramp(n);
	vec3 emission = vec3(0.0);
	float spec = 0.0;
	vec3 cells = voronoi(p / feature_size);
	float edge = cells.y - cells.x;

	if (surface_type == SURFACE_GRASS) {
		// Darker blades between patches and small flowers in accent colour.
		color *= 0.85 + 0.15 * smoothstep(0.05, 0.25, edge);
		float flower = step(0.82, cells.z) * smoothstep(0.16, 0.1, cells.x);
		color = mix(color, color_accent, flower);
	} else if (surface_type == SURFACE_ICE) {
		// Pale cracks between ice plates and slow glints.
		color = mix(color_high, color, smoothstep(0.0, 0.08, edge));
		float glint = step(0.93, hash13(floor(p * 3.0))) * (0.5 + 0.5 * sin(TIME * 4.0 + cells.z * 40.0));
		emission += vec3(0.8, 0.95, 1.0) * glint * 0.6;
		spec = 0.45;
	} else if (surface_type == SURFACE_LAVA) {
		// Dark crust plates drifting over glowing seams.
		vec3 flow = p / feature_size + vec3(0.0, TIME * lava_flow_speed, 0.0);
		vec3 lava_cells = voronoi(flow + fbm(flow * 0.7) * 0.8);
		float seam = 1.0 - smoothstep(0.0, 0.18, lava_cells.y - lava_cells.x);
		float pulse = 0.75 + 0.25 * sin(TIME * 2.0 + n * 12.0);
		color = mix(color, color_accent, seam * 0.6);
		emission += color_accent * seam * lava_glow * pulse;
	} else {
		// Craters: dark floor, bright rim.
		float crater = smoothstep(0.42, 0.28, cells.x) * step(0.45, cells.z);
		float rim = smoothstep(0.30, 0.42, cells.x) * smoothstep(0.55, 0.42, cells.x) * step(0.45, cells.z);
		color *= 1.0 - crater * 0.35;
		color += vec3(0.12) * rim;
	}

	ALBEDO = color;
	EMISSION = emission;
	ROUGHNESS = 1.0;
	spec_strength = spec;
}

void light() {
	toon_lighting(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, rim_strength, spec_strength, 96.0,
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
