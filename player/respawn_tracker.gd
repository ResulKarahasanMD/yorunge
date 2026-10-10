class_name RespawnTracker
extends Node
## Remembers the player's last safe footing and reports when they are lost in
## space. The safe pose is stored in the planet's local frame, so a spinning
## moon still returns the player to the spot they actually stood on.

signal lost_in_space

const LOG_TAG := "Respawn"

@export var player: PlayerController
## Seconds between safe-pose snapshots while standing on a harmless surface.
@export var snapshot_interval: float = 0.5
## Seconds with no dominant gravity well before the player counts as lost.
@export var lost_after: float = 3.0
## Hard limit: farther than this from every planet surface counts as lost.
@export var max_altitude: float = 60.0

var losses: int = 0

var _safe_planet: Planet = null
var _safe_local: Transform3D = Transform3D.IDENTITY
var _fallback: Transform3D = Transform3D.IDENTITY
var _snapshot_timer: float = 0.0
var _drift_timer: float = 0.0


func _ready() -> void:
	if player == null:
		player = get_parent() as PlayerController
	_fallback = player.global_transform


func _physics_process(delta: float) -> void:
	_snapshot_timer += delta
	if _snapshot_timer >= snapshot_interval and _is_safe_footing():
		_snapshot_timer = 0.0
		_safe_planet = player.current_planet
		_safe_local = _safe_planet.global_transform.affine_inverse() * player.global_transform

	var drifting := player.dominant_source == null
	_drift_timer = _drift_timer + delta if drifting else 0.0
	var too_far := player.dominant_source == null and _nearest_altitude() > max_altitude
	if _drift_timer >= lost_after or too_far:
		_drift_timer = 0.0
		losses += 1
		GameLog.info(LOG_TAG, "lost in space (#%d)" % losses)
		lost_in_space.emit()


## Global transform of the last safe footing (spawn point until one is seen).
func safe_transform() -> Transform3D:
	if _safe_planet != null and is_instance_valid(_safe_planet):
		return _safe_planet.global_transform * _safe_local
	return _fallback


func _is_safe_footing() -> bool:
	var planet := player.current_planet
	return player.is_on_floor() and planet != null and (planet.style == null or planet.style.contact_damage == 0)


func _nearest_altitude() -> float:
	var best := INF
	for node: Node in get_tree().get_nodes_in_group(Planet.GROUP):
		var planet := node as Planet
		best = minf(best, planet.global_position.distance_to(player.global_position) - planet.radius)
	return best
