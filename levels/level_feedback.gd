class_name LevelFeedback
extends Node
## Turns a level's gameplay events into "juice": synthesised sound, particle
## bursts, camera shake and hit-stop. Gameplay code only emits signals; every
## reaction and its tuning lives here. (Squash & stretch is in PlayerVisual,
## HUD pops/flashes in Hud.)

@export_group("Sound")
## Landings slower than this (m/s) are silent.
@export var land_sound_min_impact: float = 2.0
## Landing volume reaches 0 dB at this impact speed.
@export var land_full_volume_impact: float = 14.0
@export var land_min_volume_db: float = -18.0
## Each stardust in a level plays a little higher.
@export var collect_pitch_step: float = 0.06
@export_group("Shake")
@export var land_shake_min_impact: float = 9.0
@export var land_shake: float = 0.25
@export var collect_shake: float = 0.12
@export var stomp_shake: float = 0.45
@export var damage_shake: float = 0.6
@export var portal_shake: float = 0.3
@export_group("Hit-stop")
@export var stomp_hit_stop: float = 0.06
@export var damage_hit_stop: float = 0.09
@export var hit_stop_scale: float = 0.05

var _level: Level = null
var _player: PlayerController = null


func setup(level: Level) -> void:
	_level = level
	_player = level.player
	_player.jumped.connect(_on_jumped)
	_player.landed.connect(_on_landed)
	_player.burned.connect(_on_burned)
	_player.respawned.connect(_on_respawned)
	_player.health.damaged.connect(_on_damaged)
	level.stardust_collected_at.connect(_on_stardust)
	level.enemy_defeated_at.connect(_on_enemy_defeated)
	level.portal_opened.connect(_on_portal_opened)
	level.completed.connect(_on_completed)
	Vfx.prewarm(level)


func _on_jumped() -> void:
	_play(SfxLibrary.Sfx.JUMP)


func _on_landed(impact: float) -> void:
	if impact < land_sound_min_impact:
		return
	var loudness := clampf(impact / land_full_volume_impact, 0.0, 1.0)
	_play(SfxLibrary.Sfx.LAND, lerpf(land_min_volume_db, 0.0, loudness))
	Vfx.burst(_level, _player.global_position, _player.current_up, Vfx.Kind.DUST)
	if impact >= land_shake_min_impact:
		_level.camera_rig.add_trauma(land_shake * loudness)


func _on_burned() -> void:
	_play(SfxLibrary.Sfx.HOT_FOOT)
	Vfx.burst(_level, _player.global_position, _player.current_up, Vfx.Kind.EMBERS)


func _on_respawned() -> void:
	_play(SfxLibrary.Sfx.RESPAWN)


func _on_damaged(_amount: int, _hearts: int, _cause: String) -> void:
	_play(SfxLibrary.Sfx.HURT)
	Vfx.burst(_level, _player.global_position + _player.current_up, _player.current_up, Vfx.Kind.HURT)
	_level.camera_rig.add_trauma(damage_shake)
	_hit_stop(damage_hit_stop, hit_stop_scale)


func _on_stardust(position: Vector3, up: Vector3) -> void:
	_play(SfxLibrary.Sfx.COLLECT, 0.0, 1.0 + collect_pitch_step * _level.stats.collected)
	Vfx.burst(_level, position, up, Vfx.Kind.COLLECT)
	_level.camera_rig.add_trauma(collect_shake)


func _on_enemy_defeated(position: Vector3, up: Vector3) -> void:
	_play(SfxLibrary.Sfx.STOMP)
	Vfx.burst(_level, position, up, Vfx.Kind.STOMP)
	_level.camera_rig.add_trauma(stomp_shake)
	_hit_stop(stomp_hit_stop, hit_stop_scale)


func _on_portal_opened() -> void:
	_play(SfxLibrary.Sfx.PORTAL_OPEN)
	if _level.portal != null:
		Vfx.burst(_level, _level.portal.global_position, _level.portal.global_basis.y, Vfx.Kind.PORTAL)
	_level.camera_rig.add_trauma(portal_shake)


func _on_completed(_stats: LevelStats) -> void:
	_play(SfxLibrary.Sfx.PORTAL_ENTER)
	Vfx.burst(_level, _player.global_position + _player.current_up, _player.current_up, Vfx.Kind.PORTAL)


func _play(sfx: SfxLibrary.Sfx, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if AudioSystem.current != null:
		AudioSystem.current.play(sfx, volume_db, pitch)


func _hit_stop(duration: float, time_scale: float) -> void:
	if JuiceSystem.current != null:
		JuiceSystem.current.hit_stop(duration, time_scale)
