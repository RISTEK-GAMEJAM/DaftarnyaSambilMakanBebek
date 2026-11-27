extends Node

const SETTINGS_FILE := "user://settings.cfg"
const MUSIC_PATH := "res://assets/audio/bgm.ogg"
const BUS_NAMES := [&"Master", &"Music", &"SFX"]
const SOUNDS := {
	"roll": [320.0, 450.0, 590.0],
	"step": [180.0, 255.0],
	"handoff": [415.0, 550.0],
	"victory": [392.0, 523.0, 659.0, 784.0],
	"defeat": [392.0, 311.0, 196.0],
}

var volumes := [1.0, 0.8, 0.75]
var muted := false
var selected_stage := 0
var _sfx: AudioStreamPlayer
var _clips: Dictionary = {}


func _ready() -> void:
	for bus in BUS_NAMES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")

	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		for index in range(BUS_NAMES.size()):
			volumes[index] = clampf(float(config.get_value("audio", BUS_NAMES[index], volumes[index])), 0.0, 1.0)
		muted = bool(config.get_value("audio", "mute", false))
	_apply_audio()

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	add_child(_sfx)
	if ResourceLoader.exists(MUSIC_PATH):
		var music := AudioStreamPlayer.new()
		music.stream = load(MUSIC_PATH)
		music.bus = &"Music"
		add_child(music)
		music.finished.connect(music.play)
		music.play()


func _exit_tree() -> void:
	if is_instance_valid(_sfx):
		_sfx.stop()


func set_volume(index: int, value: float) -> void:
	volumes[index] = value
	_apply_audio()


func set_mute(value: bool) -> void:
	muted = value
	_apply_audio()


func save_audio() -> void:
	var config := ConfigFile.new()
	for index in range(BUS_NAMES.size()):
		config.set_value("audio", BUS_NAMES[index], volumes[index])
	config.set_value("audio", "mute", muted)
	config.save(SETTINGS_FILE)


func play_sound(sound: String) -> void:
	if not _clips.has(sound):
		if sound == "jumpscare":
			_clips[sound] = _make_jumpscare_clip()
		else:
			_clips[sound] = _make_clip(SOUNDS[sound])
	_sfx.stream = _clips[sound]
	_sfx.play()


func _apply_audio() -> void:
	for index in range(BUS_NAMES.size()):
		var bus := AudioServer.get_bus_index(BUS_NAMES[index])
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volumes[index], 0.0001)))
		AudioServer.set_bus_mute(bus, volumes[index] == 0.0 or (index == 0 and muted))


func _make_clip(notes: Array) -> AudioStreamWAV:
	const RATE := 22050
	const NOTE_FRAMES := 1050
	var data := PackedByteArray()
	data.resize(notes.size() * NOTE_FRAMES * 2)
	for note in range(notes.size()):
		for frame in range(NOTE_FRAMES):
			var progress := float(frame) / NOTE_FRAMES
			var envelope := minf(progress * 16.0, 1.0) * (1.0 - progress)
			var tone := sin(TAU * float(notes[note]) * frame / RATE)
			data.encode_s16((note * NOTE_FRAMES + frame) * 2, int(tone * envelope * 5300.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


func _make_jumpscare_clip() -> AudioStreamWAV:
	const RATE := 22050
	const TOTAL_FRAMES := 11500 # ~0.52s sharp horror screech + sub-bass slam
	var data := PackedByteArray()
	data.resize(TOTAL_FRAMES * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 66613
	for frame in range(TOTAL_FRAMES):
		var t := float(frame) / float(RATE)
		var progress := float(frame) / float(TOTAL_FRAMES)
		var env := minf(progress * 45.0, 1.0) * pow(1.0 - progress, 0.65)
		# Sub-bass drop + dissonant tritone screech + sharp noise crack
		var bass := sin(TAU * lerpf(82.0, 32.0, progress) * t) * 0.55
		var fm := sin(TAU * 42.0 * t) * 35.0
		var screech := (sin(TAU * (610.0 + fm) * t) + sin(TAU * (862.0 - fm) * t) + sin(TAU * 1290.0 * t) * 0.5) * 0.28
		var crack := rng.randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - progress * 5.0) * 0.55
		var sample := clampf((bass + screech + crack) * env, -1.0, 1.0)
		data.encode_s16(frame * 2, int(sample * 19000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
