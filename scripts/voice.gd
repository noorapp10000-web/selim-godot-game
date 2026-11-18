extends Node
# Voice-over player (autoload "Voice").
# Every spoken line in the game has its own clip in assets/voice/<key>.ogg, where
# key = md5("<speaker>|<text>")[0..12]. VoiceData holds the clip length and per-word timing
# (char index the word ends at, start and end in seconds) measured by forced alignment, so
# the dialog text can be revealed exactly as the words are spoken.
#   main   – story / dialog lines (one at a time, ducks the music)
#   world  – NPC hints and boss barks inside a level
#   bark   – short enemy taunts (never stacks)

const VoiceData = preload("res://scripts/voice_data.gd")

var main: AudioStreamPlayer
var world: AudioStreamPlayer
var bark_p: AudioStreamPlayer
var cur_key := ""
var cur_marks: Array = []
var cur_len := 0.0
var _duck := 0.0
var world_owner: Object = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = _player(0.0)
	world = _player(-2.0)
	bark_p = _player(-5.0)

func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	p.set_meta("base_db", db)
	add_child(p)
	return p

static func key_for(speaker: String, text: String) -> String:
	return (speaker + "|" + text).md5_text().substr(0, 12)

func has_line(speaker: String, text: String) -> bool:
	return VoiceData.LINES.has(key_for(speaker, text))

func length_of(speaker: String, text: String) -> float:
	var d: Array = VoiceData.LINES.get(key_for(speaker, text), [0.0, []])
	return float(d[0])

func _stream(key: String) -> AudioStream:
	var path := "res://assets/voice/%s.ogg" % key
	if not ResourceLoader.exists(path):
		return null
	return load(path)

# Plays a story/dialog line. Returns true when a clip exists and voices are enabled.
func play_line(speaker: String, text: String) -> bool:
	stop()
	if not Game.voice_on:
		return false
	var key := key_for(speaker, text)
	if not VoiceData.LINES.has(key):
		return false
	var s := _stream(key)
	if s == null:
		return false
	var d: Array = VoiceData.LINES[key]
	cur_key = key
	cur_len = float(d[0])
	cur_marks = d[1]
	main.stream = s
	main.play()
	return true

func stop() -> void:
	if main.playing:
		main.stop()
	cur_key = ""
	cur_marks = []

func is_playing() -> bool:
	return main.playing

# Seconds into the current clip, compensated for the mix buffer so text lands on the word.
func position() -> float:
	if not main.playing:
		return cur_len if cur_key != "" else 0.0
	return maxf(0.0, main.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())

# Number of characters that should be visible right now for the playing line.
func visible_chars(total: int) -> int:
	if cur_key == "" or cur_marks.is_empty():
		return total
	if not main.playing:
		return total
	var t := position()
	var prev_end := 0
	var i := 0
	while i + 2 < cur_marks.size():
		var c_end: int = int(cur_marks[i])
		var t0: float = float(cur_marks[i + 1])
		var t1: float = float(cur_marks[i + 2])
		if t < t0:
			return prev_end
		if t < t1:
			var k := clampf((t - t0) / maxf(0.04, t1 - t0), 0.0, 1.0)
			return prev_end + int(round((c_end - prev_end) * k))
		prev_end = c_end
		i += 3
	return total

# One-shot line inside a level (NPC hint / boss bark). Returns the clip length (0 = no clip).
func play_world(speaker: String, text: String, interrupt := true) -> float:
	if not Game.voice_on:
		return 0.0
	if world.playing and not interrupt:
		return 0.0
	var key := key_for(speaker, text)
	if not VoiceData.LINES.has(key):
		return 0.0
	var s := _stream(key)
	if s == null:
		return 0.0
	world_owner = null
	world.stream = s
	world.play()
	return float(VoiceData.LINES[key][0])

func stop_world() -> void:
	world_owner = null
	if world.playing:
		world.stop()

func play_bark(speaker: String, text: String) -> void:
	if not Game.voice_on or bark_p.playing or main.playing:
		return
	var key := key_for(speaker, text)
	var s := _stream(key) if VoiceData.LINES.has(key) else null
	if s == null:
		return
	bark_p.stream = s
	bark_p.pitch_scale = randf_range(0.96, 1.04)
	bark_p.play()

func set_paused(p: bool) -> void:
	for pl in [main, world, bark_p]:
		pl.stream_paused = p

func _process(delta: float) -> void:
	# duck the music under any voice so every word stays clear
	var target := 1.0 if (main.playing or world.playing) else 0.0
	_duck = move_toward(_duck, target, delta * (6.0 if target > _duck else 1.6))
	Audio.set_duck(_duck)
