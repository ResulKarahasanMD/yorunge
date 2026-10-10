// Stylised material for characters, enemies and props.
shader_type spatial;

#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.6;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.35;
uniform float shininess : hint_range(1.0, 256.0) = 48.0;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;
// MultiMesh decorations pass a per-instance tint through COLOR.
uniform bool use_vertex_color = false;

void fragment() {
	ALBEDO = albedo.rgb * (use_vertex_color ? COLOR.rgb : vec3(1.0));
	EMISSION = emission_color * emission_energy;
	ROUGHNESS = 1.0;
}

void light() {
	toon_lighting(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, rim_strength, spec_strength, shininess,
		DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
