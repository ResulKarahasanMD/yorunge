class_name GameLog
extends RefCounted
## Tagged console logging. Every line is "[Tag] message" so runtime logs can be
## filtered by system when verifying a play session (game_logs filter="[Tag]").


static func info(tag: String, message: String) -> void:
	print("[%s] %s" % [tag, message])


static func warn(tag: String, message: String) -> void:
	push_warning("[%s] %s" % [tag, message])


static func error(tag: String, message: String) -> void:
	push_error("[%s] %s" % [tag, message])
