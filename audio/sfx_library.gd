class_name SfxLibrary
extends RefCounted
## Every sound effect recipe in one place. Tweak numbers here, not in callers.

enum Sfx { JUMP, LAND, COLLECT, PORTAL_OPEN, PORTAL_ENTER, HURT, STOMP, HOT_FOOT, RESPAWN, UI_CLICK, UI_MOVE }

## A minor-ish pad chord (A2, E3, A3, C4) in Hz.
const PAD_CHORD: Array[float] = [110.0, 164.81, 220.0, 261.63]
const PAD_LOOP_SECONDS := 6.0
const PAD_VOLUME := 0.45


static func patch(sfx: Sfx) -> SynthPatch:
	var p := SynthPatch.new()
	match sfx:
		Sfx.JUMP:
			_tone(p, SynthPatch.Waveform.SQUARE, 0.16, 260.0, 560.0, 0.35)
			p.duty = 0.25
			p.sweep_curve = 0.7
			p.lowpass = 0.5
		Sfx.LAND:
			_tone(p, SynthPatch.Waveform.NOISE, 0.12, 100.0, 100.0, 0.5)
			p.lowpass = 0.12
			p.decay = 0.06
			p.sustain_level = 0.2
			p.release = 0.04
		Sfx.COLLECT:
			_tone(p, SynthPatch.Waveform.TRIANGLE, 0.34, 880.0, 880.0, 0.35)
			p.arpeggio = PackedFloat32Array([0.0, 4.0, 7.0, 12.0])
			p.arpeggio_step = 0.05
			p.release = 0.16
			p.vibrato_rate = 7.0
			p.vibrato_depth = 0.08
		Sfx.PORTAL_OPEN:
			_tone(p, SynthPatch.Waveform.SAW, 0.9, 220.0, 220.0, 0.3)
			p.arpeggio = PackedFloat32Array([0.0, 7.0, 12.0, 19.0, 24.0])
			p.arpeggio_step = 0.09
			p.lowpass = 0.2
			p.vibrato_rate = 5.0
			p.vibrato_depth = 0.15
			p.release = 0.4
		Sfx.PORTAL_ENTER:
			_tone(p, SynthPatch.Waveform.SINE, 0.6, 200.0, 1600.0, 0.35)
			p.sweep_curve = 2.0
			p.vibrato_rate = 9.0
			p.vibrato_depth = 0.3
			p.noise_mix = 0.1
			p.release = 0.2
		Sfx.HURT:
			_tone(p, SynthPatch.Waveform.SQUARE, 0.28, 440.0, 110.0, 0.4)
			p.noise_mix = 0.25
			p.lowpass = 0.35
		Sfx.STOMP:
			_tone(p, SynthPatch.Waveform.TRIANGLE, 0.18, 300.0, 90.0, 0.5)
			p.noise_mix = 0.15
			p.lowpass = 0.6
		Sfx.HOT_FOOT:
			_tone(p, SynthPatch.Waveform.SQUARE, 0.2, 180.0, 260.0, 0.35)
			p.noise_mix = 0.6
			p.lowpass = 0.3
		Sfx.RESPAWN:
			_tone(p, SynthPatch.Waveform.SINE, 0.35, 1200.0, 300.0, 0.3)
			p.vibrato_rate = 12.0
			p.vibrato_depth = 0.5
		Sfx.UI_CLICK:
			_tone(p, SynthPatch.Waveform.SQUARE, 0.05, 1200.0, 900.0, 0.2)
			p.lowpass = 0.4
			p.release = 0.02
		Sfx.UI_MOVE:
			_tone(p, SynthPatch.Waveform.SINE, 0.04, 700.0, 700.0, 0.15)
			p.release = 0.02
	return p


static func _tone(p: SynthPatch, waveform: SynthPatch.Waveform, duration: float,
		freq_start: float, freq_end: float, volume: float) -> void:
	p.waveform = waveform
	p.duration = duration
	p.freq_start = freq_start
	p.freq_end = freq_end
	p.volume = volume
