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
## Menu autopilot delay override (> 0), set by slow demo entries for screenshots.
static var menu_delay: float = 0.0
## Options set by demo entry scenes, keyed by their command-line prefix.
static var options: Dictionary = {}


static func is_active() -> bool:
	if forced:
		return true
	if bool(ProjectSettings.get_setting(SETTING_PATH, false)):
		return true
	return has_flag(CMDLINE_FLAG)


static func should_exit_on_finish() -> bool:
	return has_flag(EXIT_ON_FINISH_FLAG)


## Demo option: command line `<prefix><value>` first, then `options` set by a
## demo entry scene, else `fallback`.
static func option(prefix: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return str(options.get(prefix, fallback))


static func has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)
