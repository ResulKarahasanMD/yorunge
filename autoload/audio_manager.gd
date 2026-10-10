class_name AudioSystem
extends Node
## Autoloaded as `AudioManager`; code reaches it through the typed
## `AudioSystem.current` (no dependency on the editor's autoload list).
## Synthesises every SfxLibrary sound once on a worker thread at boot
## (effects first, then the ambient pad) and plays them through a fixed pool of
## voices on the SFX bus with a small random pitch spread; the pad loops on the
## Music bus. Calls made before the effects are ready are counted and dropped.

const LOG_TAG := "Audio"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const VOICE_COUNT := 8
## Random playback pitch spread (±) so repeated sounds do not sound canned.
const PITCH_SPREAD := 0.05
const MUSIC_VOLUME_DB := -12.0
const SILENT_DB := -60.0
## Headless runs use this driver: it never mixes, so playbacks it starts are
## never released and leak at exit. Plays are counted but not started there.
const DUMMY_DRIVER := "Dummy"
const MUSIC_FADE_TIME := 2.5

static var current: AudioSystem = null

## Verification counters (runtime_get_property).
var plays_total: int = 0
var plays_dropped: int = 0
var voice_steals: int = 0
var busiest_voices: int = 0
var render_ms: float = 0.0
var ready_for_playback: bool = false
var output_available: bool = true

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_started: Array[int] = []
var _music: AudioStreamPlayer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _task_id: int = -1


func _ready() -> void:
	current = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	output_available = AudioServer.get_driver_name() != DUMMY_DRIVER
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for i in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
		_voice_started.append(0)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	_music.volume_db = SILENT_DB
	add_child(_music)
	_task_id = WorkerThreadPool.add_task(_render_all, false, "synth")


func _exit_tree() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
	stop_all()


## Stops every voice and the music. The audio server releases playbacks on its
## next mix step, so call this a few frames before quitting (GameMain does).
func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
	_music.stop()


func play(sfx: SfxLibrary.Sfx, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not ready_for_playback:
		plays_dropped += 1
		return
	plays_total += 1
	if not output_available:
		return
	var voice := _free_voice()
	voice.stream = _streams[sfx]
	voice.volume_db = volume_db
	voice.pitch_scale = pitch * (1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD))
	voice.play()
	busiest_voices = maxi(busiest_voices, _busy_count())


## Linear 0..1 volume for "Master", "Music" or "SFX" (settings menu).
func set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


func _render_all() -> void:
	var started := Time.get_ticks_usec()
	var streams := {}
	for sfx: int in SfxLibrary.Sfx.values():
		streams[sfx] = Synth.render(SfxLibrary.patch(sfx))
	_install_effects.call_deferred(streams, float(Time.get_ticks_usec() - started) / 1000.0)
	var pad := Synth.render_pad(PackedFloat32Array(SfxLibrary.PAD_CHORD), SfxLibrary.PAD_LOOP_SECONDS, SfxLibrary.PAD_VOLUME)
	_install_pad.call_deferred(pad, float(Time.get_ticks_usec() - started) / 1000.0)


func _install_effects(streams: Dictionary, elapsed_ms: float) -> void:
	_streams = streams
	render_ms = elapsed_ms
	ready_for_playback = true
	GameLog.info(LOG_TAG, "rendered %d effects in %.0f ms (worker thread)" % [streams.size(), elapsed_ms])


func _install_pad(pad: AudioStreamWAV, elapsed_ms: float) -> void:
	_task_id = -1
	GameLog.info(LOG_TAG, "pad ready after %.0f ms" % elapsed_ms)
	_music.stream = pad
	if not output_available:
		return
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_TIME)


func _free_voice() -> AudioStreamPlayer:
	var oldest := 0
	for i in _voices.size():
		if not _voices[i].playing:
			_voice_started[i] = Time.get_ticks_msec()
			return _voices[i]
		if _voice_started[i] < _voice_started[oldest]:
			oldest = i
	voice_steals += 1
	_voice_started[oldest] = Time.get_ticks_msec()
	return _voices[oldest]


func _busy_count() -> int:
	var busy := 0
	for voice: AudioStreamPlayer in _voices:
		if voice.playing:
			busy += 1
	return busy


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")
