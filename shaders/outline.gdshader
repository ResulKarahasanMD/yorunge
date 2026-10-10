// Inverted-hull outline, used as next_pass of toon materials.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.07, 0.05, 0.12, 1.0);
// Object-space thickness in metres.
uniform float outline_width : hint_range(0.0, 0.2) = 0.025;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
