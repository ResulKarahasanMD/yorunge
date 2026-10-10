class_name FrameCapture
extends Node
## Command-line screenshot helper for measurements without the editor:
##   Godot --path . <scene.tscn> -- --capture=/abs/out.png [--capture-frame=90]
## Renders N frames, saves the root viewport as PNG and quits (exit 0 on success).
## GameState adds it only when --capture= is present.

const LOG_TAG := "Capture"
const PATH_PREFIX := "--capture="
const FRAME_PREFIX := "--capture-frame="
const DEFAULT_FRAMES := 90

var _path: String = ""
var _frames_left: int = DEFAULT_FRAMES


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
	if frames.is_valid_int():
		_frames_left = frames.to_int()


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_path)
	GameLog.info(LOG_TAG, "saved %s (%dx%d) error=%d" % [_path, image.get_width(), image.get_height(), error])
	get_tree().quit(0 if error == OK else 1)
