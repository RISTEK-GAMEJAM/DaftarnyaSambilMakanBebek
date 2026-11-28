extends Node

const SETTINGS_FILE := "user://settings.cfg"
const MUSIC_PATHS := [
	"res://assets/audio/bgm.ogg",
	"res://assets/audio/bgm.mp3",
	"res://assets/audio/bgm.wav",
]
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
var pending_run_seed := -1
var _sfx: AudioStreamPlayer
var _music: AudioStreamPlayer
var _clips: Dictionary = {}
var _web_music_pending := false


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
	_sfx.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_sfx)
	for mpath in MUSIC_PATHS:
		if ResourceLoader.exists(mpath):
			var stream := load(mpath)
			if stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			elif stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			_music = AudioStreamPlayer.new()
			_music.stream = stream
			_music.bus = &"Music"
			_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			add_child(_music)
			_music.finished.connect(_music.play)
			if OS.has_feature("web"):
				# Browsers block Web Audio until the first click/keypress.
				_web_music_pending = true
			else:
				_music.play()
			break
	set_process_input(_web_music_pending)


func _input(event: InputEvent) -> void:
	if not _web_music_pending:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_web_music_pending = false
		set_process_input(false)
		if is_instance_valid(_music) and not _music.playing:
			_music.play()


func _exit_tree() -> void:
	if is_instance_valid(_sfx):
		_sfx.stop()
	if is_instance_valid(_music):
		_music.stop()


func set_music_paused(paused: bool) -> void:
	if is_instance_valid(_music):
		_music.stream_paused = paused


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
		var found := false
		for ext in ["ogg", "mp3", "wav"]:
			var p := "res://assets/audio/%s.%s" % [sound, ext]
			if ResourceLoader.exists(p):
				_clips[sound] = load(p)
				found = true
				break
		if not found:
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
