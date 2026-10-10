class_name DemoMode
extends RefCounted
## Decides whether the AI DemoBot drives the player instead of a human.
## Three switches, any of which turns demo mode on:
##   * project setting `yorunge/demo_mode = true`
##   * the `--demo` command-line flag (after `--` for user args)
##   * `DemoMode.forced = true`, set by res://debug/demo_entry.tscn

const SETTING_PATH := "yorunge/demo_mode"
const CMDLINE_FLAG := "--demo"
const EXIT_ON_FINISH_FLAG := "--demo-exit-on-finish"

static var forced: bool = false


static func is_active() -> bool:
	if forced:
		return true
	if bool(ProjectSettings.get_setting(SETTING_PATH, false)):
		return true
	return has_flag(CMDLINE_FLAG)


static func should_exit_on_finish() -> bool:
	return has_flag(EXIT_ON_FINISH_FLAG)


static func has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)
