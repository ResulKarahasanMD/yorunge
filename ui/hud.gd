class_name Hud
extends Control
## In-level overlay: stardust counter, hearts, level title, tutorial hint and
## a short banner for events. Bound to the active Level by GameMain.

const BANNER_IN := 0.15
const BANNER_HOLD := 1.4
const BANNER_OUT := 0.45
const POP_SCALE := 1.35
const POP_TIME := 0.18
const HEART_SIZE := Vector2(30, 28)
const FLASH_ALPHA := 0.35
const FLASH_TIME := 0.4
const TITLE_OUTLINE := 10
const TITLE_OUTLINE_COLOR := Color(0.02, 0.02, 0.08, 1.0)

var _level: Level = null
var _banner_tween: Tween = null

@onready var _stardust_box: Control = %StardustBox
@onready var _stardust_label: Label = %StardustLabel
@onready var _hearts: HBoxContainer = %Hearts
@onready var _title: Label = %Title
@onready var _hint_panel: PanelContainer = %HintPanel
@onready var _hint_label: Label = %HintLabel
@onready var _banner: Label = %Banner
@onready var _damage_flash: ColorRect = %DamageFlash


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Readable over bright lava and ice behind the title.
	_title.add_theme_constant_override(&"outline_size", TITLE_OUTLINE)
	_title.add_theme_color_override(&"font_outline_color", TITLE_OUTLINE_COLOR)
	_banner.modulate.a = 0.0
	_hint_panel.hide()


func bind(level: Level) -> void:
	_level = level
	level.stardust_changed.connect(_on_stardust_changed)
	level.portal_opened.connect(_show_banner.bind(UiText.PORTAL_OPEN))
	level.enemy_defeated.connect(_show_banner.bind(UiText.ENEMY_DEFEATED))
	level.completed.connect(func(_stats: LevelStats) -> void: _show_banner(UiText.LEVEL_COMPLETE))
	level.failed.connect(func(_stats: LevelStats) -> void: _show_banner(UiText.LEVEL_FAILED))
	level.player.health.damaged.connect(_on_damaged)
	if level.hints != null:
		level.hints.hint_changed.connect(_set_hint)
		_set_hint(level.hints.current_text)
	else:
		_set_hint("")
	_title.text = level.level_title
	_build_hearts(level.player.health.max_hearts)
	_update_hearts(level.player.health.hearts)
	_stardust_label.text = UiText.STARDUST_COUNT % [level.stats.collected, level.stats.total]
	_stardust_box.visible = level.stats.total > 0


func _on_stardust_changed(collected: int, total: int) -> void:
	_stardust_label.text = UiText.STARDUST_COUNT % [collected, total]
	_pop(_stardust_box)


func _on_damaged(_amount: int, hearts: int, _cause: String) -> void:
	_update_hearts(hearts)
	_pop(_hearts)
	_damage_flash.color.a = FLASH_ALPHA
	create_tween().tween_property(_damage_flash, "color:a", 0.0, FLASH_TIME)


func _build_hearts(count: int) -> void:
	for child: Node in _hearts.get_children():
		child.queue_free()
	for i in count:
		var heart := HeartIcon.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hearts.add_child(heart)


func _update_hearts(hearts: int) -> void:
	var index := 0
	for child: Node in _hearts.get_children():
		var heart := child as HeartIcon
		if heart != null and not heart.is_queued_for_deletion():
			heart.filled = index < hearts
			index += 1


func _set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_panel.visible = not text.is_empty()


func _show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, BANNER_IN)
	_banner_tween.tween_interval(BANNER_HOLD)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, BANNER_OUT)


func _pop(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * POP_SCALE, POP_TIME * 0.4)
	tween.tween_property(control, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
