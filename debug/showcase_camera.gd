class_name ShowcaseCamera
extends Camera3D
## Fixed camera for dev gallery scenes: takes over from the player rig after
## the level has set everything up, so screenshots frame a whole layout.


func _ready() -> void:
	make_current.call_deferred()
