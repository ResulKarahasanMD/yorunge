extends TestSuite
## Synthesised sound quality checks (no audio device needed) and hit-stop.

const PEAK_LIMIT := 1.0
const SILENCE_FLOOR := 0.05
const SEAM_PERCENTILE := 0.99


func test_every_sfx_renders_clean() -> void:
	var started := Time.get_ticks_usec()
	var report := PackedStringArray()
	for sfx: int in SfxLibrary.Sfx.values():
		var patch := SfxLibrary.patch(sfx)
		var samples := Synth.render_samples(patch)
		var label: String = SfxLibrary.Sfx.keys()[sfx]
		check(samples.size() == int(patch.duration * Synth.MIX_RATE), "%s length matches duration" % label)
		var peak := 0.0
		var finite := true
		for value: float in samples:
			peak = maxf(peak, absf(value))
			finite = finite and is_finite(value)
		check(finite, "%s has no NaN/inf" % label)
		check(peak <= PEAK_LIMIT, "%s does not clip (peak %.3f)" % [label, peak])
		check(peak >= SILENCE_FLOOR, "%s is audible (peak %.3f)" % [label, peak])
		var stream := Synth.to_stream(samples, Synth.MIX_RATE)
		check(stream.format == AudioStreamWAV.FORMAT_16_BITS and stream.data.size() == samples.size() * 2,
			"%s encodes to 16-bit PCM" % label)
		report.append("%s %.2fs peak %.2f" % [label, patch.duration, peak])
	print("[Test]   sfx: %s; rendered in %.0f ms" % [", ".join(report), float(Time.get_ticks_usec() - started) / 1000.0])


func test_pitch_variants_and_determinism() -> void:
	var patch := SfxLibrary.patch(SfxLibrary.Sfx.JUMP)
	var a := Synth.render_samples(patch)
	var b := Synth.render_samples(patch)
	var higher := Synth.render_samples(patch, 1.06)
	check(a == b, "rendering is deterministic")
	check(a.size() == higher.size(), "pitch variants keep the duration")
	check(a != higher, "pitch variant differs")


func test_pad_loops_without_click() -> void:
	var samples := Synth.render_pad_samples(PackedFloat32Array(SfxLibrary.PAD_CHORD), SfxLibrary.PAD_LOOP_SECONDS, SfxLibrary.PAD_VOLUME)
	var steps := PackedFloat32Array()
	for i in samples.size() - 1:
		steps.append(absf(samples[i + 1] - samples[i]))
	steps.sort()
	var typical := steps[int(steps.size() * SEAM_PERCENTILE)]
	var seam := absf(samples[0] - samples[samples.size() - 1])
	check(seam <= typical, "loop seam step %.5f is within the 99th percentile step %.5f" % [seam, typical])
	var peak := 0.0
	for value: float in samples:
		peak = maxf(peak, absf(value))
	check(peak <= PEAK_LIMIT and peak >= SILENCE_FLOOR, "pad level sane (peak %.3f)" % peak)
	var stream := Synth.render_pad(PackedFloat32Array(SfxLibrary.PAD_CHORD), SfxLibrary.PAD_LOOP_SECONDS, SfxLibrary.PAD_VOLUME)
	check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == samples.size(), "pad stream loops over all samples")
	print("[Test]   pad: %d samples @ %d Hz, seam step %.5f vs p99 step %.5f, peak %.3f" % [
		samples.size(), Synth.PAD_MIX_RATE, seam, typical, peak])


func test_hit_stop_slows_time() -> void:
	var juice := JuiceSystem.new()
	spawn(juice)
	juice.hit_stop(0.1, 0.05)
	check_near(Engine.time_scale, 0.05, "time scale drops immediately")
	check(juice.hit_stops == 1 and juice.min_time_scale_seen <= 0.05, "hit-stop counted")
	Engine.time_scale = 1.0
