// Toon lighting shared by every lit stylised material. Call from light():
//   toon_lighting(NORMAL, VIEW, LIGHT, LIGHT_COLOR, ATTENUATION, rim, spec, shininess, DIFFUSE_LIGHT, SPECULAR_LIGHT);
// Diffuse comes in two soft steps (shadow / mid / lit); a light-facing rim and
// a hard specular band sell the cartoon look. LIGHT_COLOR is premultiplied by
// PI in Godot 4, hence the divisions.

const float TOON_SOFTNESS = 0.04;
const float TOON_MID_STEP = 0.45;
const float TOON_SHADOW_SHARE = 0.55;
const float TOON_RIM_POWER = 3.0;
const float TOON_SPEC_THRESHOLD = 0.5;

void toon_lighting(vec3 normal, vec3 view, vec3 light, vec3 light_color, float attenuation,
		float rim_strength, float spec_strength, float shininess,
		inout vec3 diffuse, inout vec3 specular) {
	float ndl = dot(normal, light);
	float lit = ndl * attenuation;
	float band = smoothstep(0.0, TOON_SOFTNESS, lit) * TOON_SHADOW_SHARE
		+ smoothstep(TOON_MID_STEP, TOON_MID_STEP + TOON_SOFTNESS, lit) * (1.0 - TOON_SHADOW_SHARE);
	diffuse += light_color * band / PI;
	float rim = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), TOON_RIM_POWER);
	rim *= smoothstep(-0.1, 0.3, ndl) * attenuation;
	diffuse += light_color * rim * rim_strength / PI;
	vec3 half_vector = normalize(light + view);
	float highlight = pow(clamp(dot(normal, half_vector), 0.0, 1.0), shininess);
	specular += light_color * smoothstep(TOON_SPEC_THRESHOLD, TOON_SPEC_THRESHOLD + TOON_SOFTNESS, highlight)
		* spec_strength * attenuation / PI;
}
