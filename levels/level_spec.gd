class_name LevelSpec
extends RefCounted
## Plain description of a generated level (no nodes): what LevelGenerator
## produces, LevelBuilder turns into a Level, and tests validate.

## Every generated level id starts with this (SaveSystem keeps them out of best times).
const ID_PREFIX := "endless_"

class PlanetSpec:
	var center: Vector3
	var radius: float
	var style: PlanetStyle.Surface
	var spin_axis: Vector3 = Vector3.UP
	var spin_deg: float = 0.0
	var parent: int = -1


class SurfacePoint:
	var planet: int
	## Direction from the planet centre, in the planet's local frame.
	var direction: Vector3


class EnemySpec:
	var planet: int
	var axis: Vector3
	var start: Vector3
	var speed_deg: float


var seed_value: int = 0
var depth: int = 1
var planets: Array[PlanetSpec] = []
var stardust: Array[SurfacePoint] = []
var enemies: Array[EnemySpec] = []
var portal: SurfacePoint = null
var spawn: SurfacePoint = null


func level_id() -> String:
	return "%s%d_%d" % [ID_PREFIX, seed_value, depth]


func centers() -> PackedVector3Array:
	var result := PackedVector3Array()
	for planet: PlanetSpec in planets:
		result.append(planet.center)
	return result


func radii() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for planet: PlanetSpec in planets:
		result.append(planet.radius)
	return result


## Canonical text form; two specs are identical iff their texts match.
func to_text() -> String:
	var lines := PackedStringArray(["seed %d depth %d" % [seed_value, depth]])
	for planet: PlanetSpec in planets:
		lines.append("planet %s r%.3f s%d spin %.2f %s p%d" % [
			_v(planet.center), planet.radius, planet.style, planet.spin_deg, _v(planet.spin_axis), planet.parent])
	for point: SurfacePoint in stardust:
		lines.append("stardust %d %s" % [point.planet, _v(point.direction)])
	for enemy: EnemySpec in enemies:
		lines.append("enemy %d %s %s %.2f" % [enemy.planet, _v(enemy.axis), _v(enemy.start), enemy.speed_deg])
	lines.append("portal %d %s" % [portal.planet, _v(portal.direction)])
	lines.append("spawn %d %s" % [spawn.planet, _v(spawn.direction)])
	return "\n".join(lines)


static func _v(v: Vector3) -> String:
	return "(%.3f,%.3f,%.3f)" % [v.x, v.y, v.z]
