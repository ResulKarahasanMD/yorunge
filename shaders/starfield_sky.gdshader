// Procedural space backdrop: two star layers with twinkle, a faint fbm
// nebula and the sun's glow. The radiance cubemap pass gets a cheap version.
shader_type sky;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 space_color : source_color = vec3(0.008, 0.01, 0.028);
uniform vec3 nebula_color_a : source_color = vec3(0.25, 0.08, 0.35);
uniform vec3 nebula_color_b : source_color = vec3(0.05, 0.18, 0.35);
uniform float nebula_strength = 0.35;
uniform float star_brightness = 4.0;
// Share of grid cells that hold a star, per layer.
uniform float star_density = 0.06;
uniform float sun_glow = 0.6;

float star_layer(vec3 dir, float scale, float size, float phase) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float chance = hash13(cell);
	if (chance > star_density) {
		return 0.0;
	}
	vec3 center = cell + 0.2 + 0.6 * hash33(cell);
	float d = length(p - center);
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.5 + chance * 30.0) + phase + chance * 100.0);
	return smoothstep(size, 0.0, d) * twinkle * (0.4 + 0.6 * hash13(cell + 7.0));
}

void sky() {
	vec3 dir = EYEDIR;
	float nebula = fbm(dir * 2.2 + vec3(3.0, 1.0, 7.0));
	float mask = smoothstep(0.45, 0.85, fbm(dir * 1.1 + vec3(11.0)));
	vec3 color = space_color + mix(nebula_color_a, nebula_color_b, nebula) * mask * nebula_strength;
	if (LIGHT0_ENABLED) {
		float sun = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		color += LIGHT0_COLOR * (pow(sun, 600.0) * 8.0 + pow(sun, 24.0) * sun_glow * 0.25);
	}
	if (!AT_CUBEMAP_PASS) {
		float stars = star_layer(dir, 140.0, 0.12, 0.0) + star_layer(dir, 260.0, 0.1, 2.0) * 0.6;
		color += vec3(0.9, 0.93, 1.0) * stars * star_brightness;
	}
	COLOR = color;
}
