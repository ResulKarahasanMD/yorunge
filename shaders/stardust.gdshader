// Glowing star shard: gold core, pale rim, slow pulse (bloom does the halo).
shader_type spatial;
render_mode unshaded;

uniform vec3 core_color : source_color = vec3(1.0, 0.78, 0.3);
uniform vec3 rim_color : source_color = vec3(1.0, 0.97, 0.85);
uniform float energy : hint_range(0.0, 8.0) = 2.6;
uniform float pulse_speed = 3.0;

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
	ALBEDO = mix(core_color, rim_color, rim) * energy * pulse;
}
