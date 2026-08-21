class_name MusicGen
extends RefCounted
## Renders the game's looping room tracks out of SfxSynth primitives.
## Every song is a short mono loop; AudioBus crossfades between them.


## chords: Array of Arrays of MIDI notes, one chord per `beats_per_chord` beats.
static func chords(bpm: float, beats_per_chord: float, chord_list: Array, wave := "tri", vol := 0.12, vibrato := 0.0, stab := false) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var dur := beat * beats_per_chord
	var parts: Array = []
	for chord in chord_list:
		var voices: Array = []
		for note in chord:
			# stab = short staccato hits on each beat instead of a held pad
			if stab:
				var hits: Array = []
				for b in int(beats_per_chord):
					hits.append(SfxSynth.tone(SfxSynth.midi_hz(note), beat * 0.45, wave, vol, 0.004, beat * 0.2))
					hits.append(SfxSynth.silence(beat * 0.55))
				voices.append(SfxSynth.seq(hits))
			else:
				voices.append(SfxSynth.tone(SfxSynth.midi_hz(note), dur, wave, vol, 0.05, 0.2, vibrato, 4.0))
		parts.append(SfxSynth.mix(voices))
	return SfxSynth.seq(parts)


## notes: Array of [midi_note_or_0, beats]; 0 = rest.
static func line(bpm: float, notes: Array, wave := "square", vol := 0.1, release := 0.04) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var parts: Array = []
	for n in notes:
		var dur: float = beat * n[1]
		if n[0] <= 0:
			parts.append(SfxSynth.silence(dur))
		else:
			parts.append(SfxSynth.tone(SfxSynth.midi_hz(n[0]), dur, wave, vol, 0.004, min(release, dur * 0.4)))
	return SfxSynth.seq(parts)


static func song(name: String) -> AudioStreamWAV:
	var samples: PackedFloat32Array
	match name:
		"orange":
			# Lazy warm chords; the sound of an afternoon that isn't going anywhere.
			samples = SfxSynth.mix([
				chords(66.0, 4.0, [[48, 55, 60, 64, 71], [45, 52, 57, 64], [41, 48, 57, 65], [43, 50, 59, 65]], "tri", 0.10, 0.008),
				line(66.0, [[76, 3], [74, 1], [72, 4], [0, 2], [69, 2], [71, 8]], "sine", 0.05, 0.3),
			])
		"living":
			# Sitcom muzak parody: bouncy staccato chords over a walking square bass.
			samples = SfxSynth.mix([
				chords(118.0, 4.0, [[60, 64, 67], [57, 60, 65], [59, 62, 67], [60, 64, 69]], "tri", 0.09, 0.0, true),
				line(118.0, [[36, 1], [43, 1], [40, 1], [43, 1], [33, 1], [40, 1], [36, 1], [40, 1],
					[35, 1], [43, 1], [38, 1], [43, 1], [36, 1], [40, 1], [45, 1], [43, 1]], "square", 0.07),
			])
		"kitchen":
			# Same muzak but the fridge sings along (a constant low hum).
			var base := SfxSynth.mix([
				chords(118.0, 4.0, [[60, 64, 67], [57, 60, 65], [59, 62, 67], [60, 64, 69]], "tri", 0.08, 0.0, true),
				line(118.0, [[36, 1], [43, 1], [40, 1], [43, 1], [33, 1], [40, 1], [36, 1], [40, 1],
					[35, 1], [43, 1], [38, 1], [43, 1], [36, 1], [40, 1], [45, 1], [43, 1]], "square", 0.06),
			])
			var hum := SfxSynth.tone(49.0, float(base.size()) / SfxSynth.RATE, "sine", 0.06, 0.5, 0.5, 0.02, 0.7)
			samples = SfxSynth.mix([base, hum])
		"basement":
			# Slow synth pad with tape warble (vibrato that's slightly seasick).
			samples = SfxSynth.mix([
				chords(56.0, 4.0, [[45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59], [45, 52, 57, 60]], "saw", 0.05, 0.018),
				SfxSynth.noise(60.0 / 56.0 * 16.0, 0.015, 0.15, 1.0, 1.0, 11),
			])
		"turquoise":
			# A single patient drone. It has been humming since before you arrived.
			samples = SfxSynth.mix([
				SfxSynth.tone(110.0, 8.0, "sine", 0.10, 1.0, 1.0),
				SfxSynth.tone(110.8, 8.0, "sine", 0.08, 1.0, 1.0),
				SfxSynth.tone(165.0, 8.0, "sine", 0.05, 1.5, 1.5),
				SfxSynth.tone(330.0, 8.0, "sine", 0.02, 2.0, 2.0, 0.01, 0.2),
			])
		"battle":
			# Upbeat brass-ish chiptune for a fight that will not last long enough.
			samples = SfxSynth.mix([
				line(142.0, [[57, 0.5], [57, 0.5], [60, 0.5], [62, 0.5], [64, 1.0], [62, 0.5], [60, 0.5],
					[57, 0.5], [57, 0.5], [60, 0.5], [62, 0.5], [64, 1.5], [67, 0.5],
					[69, 0.5], [67, 0.5], [64, 0.5], [62, 0.5], [60, 1.0], [62, 0.5], [64, 0.5],
					[57, 1.0], [55, 1.0], [57, 2.0]], "square", 0.09),
				line(142.0, [[33, 0.5], [33, 0.5], [45, 0.5], [33, 0.5], [36, 0.5], [36, 0.5], [48, 0.5], [36, 0.5],
					[31, 0.5], [31, 0.5], [43, 0.5], [31, 0.5], [33, 0.5], [33, 0.5], [45, 0.5], [33, 0.5]], "saw", 0.06),
			])
		"hold":
			# The hold music. Cheerful in the way fluorescent lights are.
			samples = SfxSynth.mix([
				chords(96.0, 4.0, [[53, 60, 65, 69], [55, 62, 67, 71], [48, 60, 64, 67], [50, 57, 62, 65]], "tri", 0.08),
				line(96.0, [[77, 1], [76, 1], [74, 1], [76, 1], [79, 2], [74, 2],
					[72, 1], [74, 1], [76, 1], [72, 1], [69, 2], [67, 2]], "sine", 0.09, 0.15),
			])
		_:
			samples = SfxSynth.tone(220.0, 2.0, "sine", 0.05)
	return SfxSynth.to_wav(samples, true)
