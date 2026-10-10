class_name FrameCapture
extends Node
## Command-line screenshot helper for measurements without the editor:
##   Godot --path . <scene.tscn> -- --capture=/abs/out.png [--capture-frame=90]
##   Godot --path . <scene.tscn> -- --capture=/abs/shot_{frame}.png --capture-frame=120,300,2280
## Saves the root viewport at each listed frame (`{frame}` is replaced by the
## frame number) and quits after the last one (exit 0 on success).
## GameState adds it only when --capture= is present.

const LOG_TAG := "Capture"
const PATH_PREFIX := "--capture="
const FRAME_PREFIX := "--capture-frame="
const FRAME_TOKEN := "{frame}"
const DEFAULT_FRAME := 90

var _path: String = ""
var _frames: PackedInt32Array = PackedInt32Array([DEFAULT_FRAME])
var _frame: int = 0
var _failed: bool = false


static func requested_path() -> String:
	return _arg_value(PATH_PREFIX)


static func _arg_value(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_path = requested_path()
	var frames := _arg_value(FRAME_PREFIX)
	if not frames.is_empty():
		_frames = PackedInt32Array()
		for part: String in frames.split(","):
			_frames.append(part.to_int())
		_frames.sort()


func _process(_delta: float) -> void:
	_frame += 1
	if _frames.is_empty() or _frame != _frames[0]:
		return
	var requested := _frames[0]
	_frames.remove_at(0)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var target := _path.replace(FRAME_TOKEN, str(requested))
	var error := image.save_png(target)
	_failed = _failed or error != OK
	GameLog.info(LOG_TAG, "saved %s (%dx%d) error=%d" % [target, image.get_width(), image.get_height(), error])
	if _frames.is_empty():
		get_tree().quit(1 if _failed else 0)
