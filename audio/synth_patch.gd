@tool
class_name SynthPatch
extends Resource
## Recipe for one procedural sound effect, rendered to PCM by Synth.

enum Waveform { SINE, SQUARE, TRIANGLE, SAW, NOISE }

@export var waveform: Waveform = Waveform.SQUARE
@export var duration: float = 0.2
@export var freq_start: float = 440.0
@export var freq_end: float = 440.0
## 1 = linear sweep in log-frequency; >1 bends late, <1 bends early.
@export var sweep_curve: float = 1.0
@export var attack: float = 0.005
@export var decay: float = 0.05
@export var sustain_level: float = 0.7
@export var release: float = 0.05
## Peak amplitude, 0..1.
@export var volume: float = 0.5
@export var vibrato_rate: float = 0.0
## Vibrato depth in semitones.
@export var vibrato_depth: float = 0.0
## Semitone offsets stepped through every `arpeggio_step` seconds.
@export var arpeggio: PackedFloat32Array = PackedFloat32Array()
@export var arpeggio_step: float = 0.06
## Share of white noise mixed into a tonal waveform.
@export var noise_mix: float = 0.0
## Square-wave duty cycle.
@export var duty: float = 0.5
## One-pole low-pass coefficient (1 = off, smaller = darker).
@export var lowpass: float = 1.0
