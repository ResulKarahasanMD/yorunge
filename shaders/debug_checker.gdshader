// Temporary speed-reference surface (milestone a fix). Replaced by
// planet_surface.gdshader in milestone (d).
// 3D checkerboard in object space: uniform cells everywhere on a sphere (no
// pole pinching) and it rotates with spinning moons. Box-filtered with fwidth
// so distant cells fade to grey instead of shimmering.
shader_type spatial;

uniform vec3 color_a : source_color = vec3(0.2, 0.45, 0.22);
uniform vec3 color_b : source_color = vec3(0.32, 0.66, 0.3);
uniform float cell_size = 1.5;
uniform float roughness_value = 0.85;

varying vec3 object_position;

void vertex() {
	object_position = VERTEX;
}

// Integral of a square wave, box-filtered over the pixel footprint `w`
// (Inigo Quilez, "filtered checkerboard").
float filtered_checker(vec3 p) {
	vec3 w = fwidth(p) + 0.0001;
	vec3 i = 2.0 * (abs(fract((p - 0.5 * w) * 0.5) - 0.5) - abs(fract((p + 0.5 * w) * 0.5) - 0.5)) / w;
	return 0.5 - 0.5 * i.x * i.y * i.z;
}

void fragment() {
	float checker = filtered_checker(object_position / cell_size);
	ALBEDO = mix(color_a, color_b, checker);
	ROUGHNESS = roughness_value;
}
