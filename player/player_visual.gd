class_name PlayerVisual
extends Node3D
## The explorer's mesh rig: squash & stretch on a damped spring (volume kept:
## horizontal scale = 1/sqrt(vertical)), stretch on jumps and bounces, squash
## scaled by landing impact, and blinking while invulnerable. Pivot is at the
## feet, so squashing keeps the boots on the ground.

@export var health: PlayerHealth
@export var blink_frequency: float = 12.0
@export_group("Squash & stretch")
@export var jump_stretch: float = 0.28
@export var bounce_stretch: float = 0.2
## Squash per m/s of landing speed, capped by max_squash.
@export var squash_per_impact: float = 0.025
@export var max_squash: float = 0.4
@export var spring_stiffness: float = 260.0
@export var spring_damping: float = 15.0

## Verification counters.
var min_scale_y: float = 1.0
var max_scale_y: float = 1.0
var pulses: int = 0

var _time: float = 0.0
var _stretch: float = 0.0
var _stretch_velocity: float = 0.0


func _ready() -> void:
	var player := get_parent() as PlayerController
	if player != null:
		player.jumped.connect(pulse.bind(jump_stretch))
		player.bounced.connect(pulse.bind(bounce_stretch))
		player.landed.connect(func(impact: float) -> void:
			pulse(-minf(impact * squash_per_impact, max_squash)))


## Kicks the spring: positive stretches, negative squashes.
func pulse(amount: float) -> void:
	_stretch = amount
	_stretch_velocity = 0.0
	pulses += 1


func _process(delta: float) -> void:
	_time += delta
	visible = health == null or not health.is_invulnerable() or fmod(_time * blink_frequency, 1.0) < 0.5
	var acceleration := -spring_stiffness * _stretch - spring_damping * _stretch_velocity
	_stretch_velocity += acceleration * delta
	_stretch += _stretch_velocity * delta
	var vertical := maxf(1.0 + _stretch, 0.3)
	var horizontal := 1.0 / sqrt(vertical)
	scale = Vector3(horizontal, vertical, horizontal)
	min_scale_y = minf(min_scale_y, vertical)
	max_scale_y = maxf(max_scale_y, vertical)
