class_name SfxSynth
extends RefCounted
## Procedural audio toolbox. Everything the game plays — SFX, voice blips,
## music — is rendered from these helpers into 16-bit mono AudioStreamWAVs.
## Samples are PackedFloat32Array in [-1, 1]; to_wav() converts at the end.

const RATE := 22050


static func to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clamp(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


static func silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


## One sample of a named waveform at the given phase (phase in cycles, not radians).
static func wave_sample(wave: String, phase: float) -> float:
	var p := fmod(phase, 1.0)
	match wave:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"saw":
			return 2.0 * p - 1.0
		"tri":
			return 4.0 * abs(p - 0.5) - 1.0
		_:
			return sin(p * TAU)


static func tone(freq: float, dur: float, wave := "sine", vol := 0.5, attack := 0.005, release := 0.05, vibrato := 0.0, vib_rate := 5.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := freq
		if vibrato > 0.0:
			f += freq * vibrato * sin(TAU * vib_rate * t)
		phase += f / RATE
		out[i] = wave_sample(wave, phase) * vol * _env(t, dur, attack, release)
	return out


static func sweep(f0: float, f1: float, dur: float, wave := "sine", vol := 0.5, attack := 0.005, release := 0.05) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f: float = lerp(f0, f1, t / dur)
		phase += f / RATE
		out[i] = wave_sample(wave, phase) * vol * _env(t, dur, attack, release)
	return out


## White-ish noise with a crude one-pole lowpass (cutoff 0..1, 1 = no filtering).
static func noise(dur: float, vol := 0.5, cutoff := 1.0, attack := 0.002, release := 0.05, seed_val := 7) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var raw := rng.randf_range(-1.0, 1.0)
		prev += cutoff * (raw - prev)
		out[i] = prev * vol * _env(t, dur, attack, release)
	return out


static func _env(t: float, dur: float, attack: float, release: float) -> float:
	var a := 1.0
	if attack > 0.0 and t < attack:
		a = t / attack
	var rel_start := dur - release
	if release > 0.0 and t > rel_start:
		a *= max(0.0, 1.0 - (t - rel_start) / release)
	return a


## Concatenate sample buffers.
static func seq(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


## Overlay buffers, each starting at the matching offset (seconds). Result is
## as long as the furthest-reaching part.
static func mix(parts: Array, offsets: Array = []) -> PackedFloat32Array:
	var total := 0
	for i in parts.size():
		var off: int = int((offsets[i] if i < offsets.size() else 0.0) * RATE)
		total = max(total, off + parts[i].size())
	var out := PackedFloat32Array()
	out.resize(total)
	for i in parts.size():
		var off: int = int((offsets[i] if i < offsets.size() else 0.0) * RATE)
		var p: PackedFloat32Array = parts[i]
		for j in p.size():
			out[off + j] += p[j]
	return out


static func gain(samples: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	var out := samples.duplicate()
	for i in out.size():
		out[i] *= amount
	return out


static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)
