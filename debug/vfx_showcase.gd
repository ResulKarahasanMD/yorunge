class_name VfxShowcase
extends Node3D
## Dev scene: fires every Vfx burst kind side by side in front of a fixed
## camera on a loop, for screenshots of the particle effects.

const SPACING := 2.4
const INTERVAL := 0.8

var _timer: float = INTERVAL


func _process(delta: float) -> void:
	_timer += delta
	if _timer < INTERVAL:
		return
	_timer = 0.0
	var kinds := Vfx.Kind.values()
	for i in kinds.size():
		var x := (float(i) - (kinds.size() - 1) * 0.5) * SPACING
		Vfx.burst(self, Vector3(x, 0.0, 0.0), Vector3.UP, kinds[i])
