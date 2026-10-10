class_name ToonMaterials
extends RefCounted
## Builds toon ShaderMaterials (optionally with the inverted-hull outline pass)
## for props created in code.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const OUTLINE_COLOR := Color(0.07, 0.05, 0.12)
const DEFAULT_OUTLINE_WIDTH := 0.022


static func make(albedo: Color, rim_strength: float = 0.6, spec_strength: float = 0.3,
		outline_width: float = DEFAULT_OUTLINE_WIDTH) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TOON_SHADER
	material.set_shader_parameter(&"albedo", albedo)
	material.set_shader_parameter(&"rim_strength", rim_strength)
	material.set_shader_parameter(&"spec_strength", spec_strength)
	if outline_width > 0.0:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter(&"outline_color", OUTLINE_COLOR)
		outline.set_shader_parameter(&"outline_width", outline_width)
		material.next_pass = outline
	return material
