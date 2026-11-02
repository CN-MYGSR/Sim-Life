extends Node
## Original synthesized audio; no external samples or commercial game recordings.
## Fixed voice pool bounds allocations during automatic fire and UI activity.

const RATE := 22050
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var _voice := 0
var ambience: AudioStreamPlayer

func _ready() -> void:
	sounds["step"] = _synth(0.08, 95, 0.55)
	sounds["shot"] = _synth(0.19, 78, 0.85)
	sounds["reload"] = _synth(0.22, 550, 0.30)
	sounds["ui"] = _synth(0.06, 880, 0.05)
	sounds["horn"] = _synth(0.35, 260, 0.03)
	sounds["engine"] = _synth(0.5, 60, 0.05, true)
	sounds["city"] = _synth(3.0, 44, 0.65, true)
	for i in range(12):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -14
		add_child(voice)
		voices.append(voice)
	ambience = AudioStreamPlayer.new()
	ambience.stream = sounds["city"]
	ambience.volume_db = -38
	add_child(ambience)
	if DisplayServer.get_name() != "headless":
		ambience.play()

func play(cue: String, volume_db := -14.0, pitch := 1.0) -> void:
	if not sounds.has(cue):
		return
	var voice := voices[_voice]
	_voice = (_voice + 1) % voices.size()
	voice.stream = sounds[cue]
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()

func engine_player(parent: Node3D) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = sounds["engine"]
	audio.volume_db = -20
	audio.max_distance = 55
	parent.add_child(audio)
	return audio

func _synth(duration: float, frequency: float, noise: float, loop := false) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(duration) + str(frequency))
	var count := int(RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var filtered := 0.0
	for i in range(count):
		var t := float(i) / RATE
		var phase := float(i) / count
		filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.35)
		var wave := sin(TAU * frequency * t) * 0.6 + sin(TAU * frequency * 2 * t) * 0.2
		var envelope := 0.35 if loop else pow(1.0 - phase, 3.0) * minf(1.0, t * 400)
		var sample := clampf(lerpf(wave, filtered, noise) * envelope, -1, 1)
		bytes.encode_s16(i * 2, int(sample * 28000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream
