class_name Synth
extends RefCounted
## Offline synthesiser: renders SynthPatch recipes and an ambient pad to mono
## 16-bit PCM AudioStreamWAV at startup (no audio files in the project).

const MIX_RATE := 44100
const PAD_MIX_RATE := 22050
const PCM_MAX := 32767.0
const BYTES_PER_SAMPLE := 2
const NOISE_SEED := 7919
## Pad voices per chord note: detuned this many Hz around it.
const PAD_DETUNE_HZ: Array[float] = [-0.35, 0.0, 0.35]
## Pad tremolo: gain swings between BASE - DEPTH and BASE + DEPTH.
const PAD_TREMOLO_BASE := 0.6
const PAD_TREMOLO_DEPTH := 0.4
## Per-voice tremolo phase offset (cycles), so the voices never pulse together.
const PAD_TREMOLO_PHASE_STEP := 0.13


## Renders `patch` with all frequencies scaled by `pitch_scale`.
static func render(patch: SynthPatch, pitch_scale: float = 1.0) -> AudioStreamWAV:
	return to_stream(render_samples(patch, pitch_scale), MIX_RATE)


## Float samples in [-1, 1] (kept separate so tests can inspect them).
static func render_samples(patch: SynthPatch, pitch_scale: float = 1.0) -> PackedFloat32Array:
	var count := maxi(int(patch.duration * MIX_RATE), 1)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var phase := 0.0
	var filtered := 0.0
	var log_start := log(patch.freq_start * pitch_scale)
	var log_end := log(patch.freq_end * pitch_scale)
	for i in count:
		var t := float(i) / MIX_RATE
		var progress := pow(t / patch.duration, patch.sweep_curve)
		var semitones := patch.vibrato_depth * sin(TAU * patch.vibrato_rate * t)
		if not patch.arpeggio.is_empty():
			var step := mini(int(t / patch.arpeggio_step), patch.arpeggio.size() - 1)
			semitones += patch.arpeggio[step]
		var frequency := exp(lerpf(log_start, log_end, progress)) * pow(2.0, semitones / 12.0)
		phase = fmod(phase + frequency / MIX_RATE, 1.0)
		var noise := rng.randf_range(-1.0, 1.0)
		var tone := noise if patch.waveform == SynthPatch.Waveform.NOISE else _oscillator(patch, phase)
		var raw := lerpf(tone, noise, patch.noise_mix)
		filtered += (raw - filtered) * patch.lowpass
		samples[i] = filtered * _envelope(patch, t) * patch.volume
	return samples


## Seamless ambient loop: each chord note is a cluster of slightly detuned
## sines with slow tremolo. Every frequency is rounded to a whole number of
## cycles per loop, so the last sample flows into the first.
static func render_pad_samples(chord_hz: PackedFloat32Array, loop_seconds: float, volume: float) -> PackedFloat32Array:
	var count := int(loop_seconds * PAD_MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var voices: Array[Vector3] = []
	for note: float in chord_hz:
		for detune: float in PAD_DETUNE_HZ:
			var cycles := roundf((note + detune) * loop_seconds)
			var tremolo_cycles := float(1 + voices.size() % 3)
			voices.append(Vector3(cycles, tremolo_cycles, float(voices.size())))
	var gain := volume / voices.size()
	for i in count:
		var phase := float(i) / count
		var sum := 0.0
		for voice: Vector3 in voices:
			var tremolo := PAD_TREMOLO_BASE + PAD_TREMOLO_DEPTH * sin(TAU * (voice.y * phase + voice.z * PAD_TREMOLO_PHASE_STEP))
			sum += sin(TAU * voice.x * phase + voice.z) * tremolo
		samples[i] = sum * gain
	return samples


static func render_pad(chord_hz: PackedFloat32Array, loop_seconds: float, volume: float) -> AudioStreamWAV:
	var stream := to_stream(render_pad_samples(chord_hz, loop_seconds, volume), PAD_MIX_RATE)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(loop_seconds * PAD_MIX_RATE)
	return stream


static func to_stream(samples: PackedFloat32Array, mix_rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * BYTES_PER_SAMPLE)
	for i in samples.size():
		data.encode_s16(i * BYTES_PER_SAMPLE, int(clampf(samples[i], -1.0, 1.0) * PCM_MAX))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


static func _oscillator(patch: SynthPatch, phase: float) -> float:
	match patch.waveform:
		SynthPatch.Waveform.SQUARE:
			return 1.0 if phase < patch.duty else -1.0
		SynthPatch.Waveform.TRIANGLE:
			return 1.0 - 4.0 * absf(phase - 0.5)
		SynthPatch.Waveform.SAW:
			return 2.0 * phase - 1.0
	return sin(TAU * phase)


static func _envelope(patch: SynthPatch, t: float) -> float:
	var release_start := patch.duration - patch.release
	var level: float
	if t < patch.attack:
		level = t / maxf(patch.attack, 0.0001)
	elif t < patch.attack + patch.decay:
		level = lerpf(1.0, patch.sustain_level, (t - patch.attack) / maxf(patch.decay, 0.0001))
	else:
		level = patch.sustain_level
	if t > release_start:
		level *= clampf((patch.duration - t) / maxf(patch.release, 0.0001), 0.0, 1.0)
	return level
