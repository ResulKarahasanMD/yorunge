class_name LevelStats
extends RefCounted
## Outcome of one level attempt (shown on the level-complete screen, saved as
## best times, and tabulated by the end-to-end demo report).

var level_id: String = ""
var title: String = ""
var time: float = 0.0
var damage: int = 0
var deaths: int = 0
var stomps: int = 0
var collected: int = 0
var total: int = 0
var completed: bool = false


func to_dict() -> Dictionary:
	return {
		"level_id": level_id, "title": title, "time": snappedf(time, 0.01), "damage": damage,
		"deaths": deaths, "stomps": stomps, "collected": collected, "total": total, "completed": completed,
	}
