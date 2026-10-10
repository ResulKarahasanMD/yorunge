@tool
class_name TutorialHint
extends Resource
## One on-screen tutorial line and the event that brings it up.

enum Trigger { START, MOVED, JUMPED, PLANET_CHANGED, STARDUST, PORTAL_OPEN, DAMAGED, ENEMY_DEFEATED }

@export_multiline var text: String = ""
@export var trigger: Trigger = Trigger.START
