// Additive atmosphere shell around a planet. Glow = length of the view ray's
// path through the shell (minus the part hidden behind the planet), divided by
// the longest possible path (a grazing chord). From outside that is a soft
// limb halo fading to nothing at the shell edge; from inside it is a horizon
// haze while looking up stays clear. Back faces only, so each pixel is shaded
// once whether the camera is inside the shell or not.
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(0.55, 0.9, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 0.55;
uniform float falloff : hint_range(0.5, 8.0) = 2.6;
// Set by Planet, in metres (the shared unit-sphere mesh is scaled by the instance;
// the maths here is in world space).
uniform float planet_radius = 10.0;
uniform float shell_radius = 11.5;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 camera = CAMERA_POSITION_WORLD;
	vec3 ray = normalize(world_position - camera);
	vec3 offset = camera - center;
	float b = dot(offset, ray);
	float shell_disc = b * b - (dot(offset, offset) - shell_radius * shell_radius);
	float path = 0.0;
	if (shell_disc > 0.0) {
		float root = sqrt(shell_disc);
		float enter = max(-b - root, 0.0);
		float leave = -b + root;
		float planet_disc = b * b - (dot(offset, offset) - planet_radius * planet_radius);
		if (planet_disc > 0.0) {
			float hit = -b - sqrt(planet_disc);
			if (hit > 0.0) {
				leave = min(leave, hit);
			}
		}
		path = max(leave - enter, 0.0);
	}
	float longest = 2.0 * sqrt(shell_radius * shell_radius - planet_radius * planet_radius);
	ALBEDO = glow_color * pow(clamp(path / longest, 0.0, 1.0), falloff) * intensity;
}
