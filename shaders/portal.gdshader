// Exit portal membrane: a dim disc while dormant; a turning spiral once active.
// Uses object-space coordinates of the disc (cylinder cap lies in local XZ).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float active : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dormant_color : source_color = vec3(0.14, 0.12, 0.22);
uniform vec3 swirl_color_a : source_color = vec3(0.35, 0.65, 1.0);
uniform vec3 swirl_color_b : source_color = vec3(0.85, 0.5, 1.0);
uniform float swirl_arms = 3.0;
uniform float swirl_twist = 7.0;
uniform float swirl_speed = 3.5;
uniform float energy = 2.2;

varying vec3 object_position;

void vertex() {
	object_position = VERTEX;
}

void fragment() {
	vec2 uv = object_position.xz;
	float radius = length(uv);
	float angle = atan(uv.y, uv.x);
	float spiral = 0.5 + 0.5 * sin(angle * swirl_arms + radius * swirl_twist - TIME * swirl_speed);
	vec3 swirl = mix(swirl_color_a, swirl_color_b, smoothstep(0.25, 0.75, spiral));
	float core = 1.0 - smoothstep(0.0, 1.0, radius);
	vec3 lit = swirl * (energy + core * energy);
	ALBEDO = mix(dormant_color, lit, active);
}
