@tool
class_name PlanetStyle
extends Resource
## Look and surface physics of one planet type (grass, ice, lava, moon).
## Shared by hand-made tutorial levels and the procedural generator.

enum Surface { GRASS, ICE, LAVA, ROCK }

@export var display_name: String = ""
@export var surface: Surface = Surface.GRASS

@export_group("Colors")
@export var color_low: Color = Color(0.18, 0.45, 0.2)
@export var color_mid: Color = Color(0.3, 0.65, 0.28)
@export var color_high: Color = Color(0.55, 0.8, 0.35)
@export var color_accent: Color = Color(0.95, 0.85, 0.4)
@export var atmosphere_color: Color = Color(0.5, 0.85, 1.0)

@export_group("Surface physics")
## Scales PlayerController ground acceleration while standing here.
@export var acceleration_multiplier: float = 1.0
## Scales ground deceleration; low values make the surface slippery.
@export var deceleration_multiplier: float = 1.0
## Hearts lost on contact (lava); 0 = harmless.
@export var contact_damage: int = 0
