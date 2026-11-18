extends Node
# Music + sound effects player (autoload "Audio").
# v9: two music decks with smooth cross-fades, music ducking under voice-over, round-robin
# sound variants (name_1.wav .. name_N.wav) with slight pitch drift so repeated hits never
# sound copy-pasted, and a dedicated UI channel so menu clicks never steal combat voices.

const MUSIC_DB := -9.0
const DUCK_DB := -9.0
# sounds that ship several takes: name -> number of files (name_1 .. name_N)
const VARIANTS := {
	#VARIANTS_BEGIN
	"swing": 3,
	"swing_stick": 3,
	"swing_saber": 3,
	"swing_spear": 3,
	"swing_hammer": 3,
	"swing_khopesh": 3,
	"throw": 2,
	"dash": 2,
	"dodge": 2,
	"jump": 3,
	"hit": 3,
	"hit_stick": 3,
	"hit_saber": 3,
	"hit_spear": 3,
	"hit_hammer": 3,
	"hit_khopesh": 3,
	"hurt": 3,
	"enemy_die": 2,
	"clang": 2,
	"slam": 2,
	"bomb_boom": 2,
	"grenade_boom": 2,
	"coin": 3,
	"select": 2,
	"page": 3,
	#VARIANTS_END
}

var music: AudioStreamPlayer
var music_b: AudioStreamPlayer
var current := ""
var players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []
var cache := {}
var _duck := 0.0
var _fade_tw: Tween
var _last := {}
var _lp: AudioEffectLowPassFilter
var _muffle_tw: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# music runs through its own bus so the pause menu can muffle it (low-pass sweep)
	var bi := AudioServer.get_bus_index("Music")
	if bi < 0:
		AudioServer.add_bus()
		bi = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, "Music")
		AudioServer.set_bus_send(bi, "Master")
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(bi, _lp)
		AudioServer.set_bus_effect_enabled(bi, 0, false)
	music = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	for m in [music, music_b]:
		m.volume_db = -80.0
		m.bus = "Music"
		add_child(m)
	for i in range(14):
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		players.append(p)
	for i in range(3):
		var u := AudioStreamPlayer.new()
		add_child(u)
		ui_players.append(u)

func _music_db() -> float:
	return (MUSIC_DB + DUCK_DB * _duck) if Game.music_on else -80.0

func play_music(name: String, fade := 1.2) -> void:
	if name == current and music.playing:
		return
	var s = load("res://assets/audio/music/%s.ogg" % name)
	if s == null:
		return
	current = name
	if s is AudioStreamOggVorbis:
		s.loop = true
	# swap decks: the new track rises while the old one fades out
	var old := music
	music = music_b
	music_b = old
	music.stream = s
	music.volume_db = -40.0
	music.play()
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween().set_parallel(true)
	_fade_tw.tween_property(music, "volume_db", _music_db(), fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if old.playing:
		_fade_tw.tween_property(old, "volume_db", -60.0, fade * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_fade_tw.chain().tween_callback(old.stop)

func stop_music(fade := 0.8) -> void:
	current = ""
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	if music.playing:
		_fade_tw = create_tween()
		_fade_tw.tween_property(music, "volume_db", -60.0, fade)
		_fade_tw.tween_callback(music.stop)
	music_b.stop()

# One-shot musical sting (victory, chapter start...) that plays over a silenced track.
func sting(name: String, vol := 0.0) -> void:
	if not Game.music_on:
		return
	var s = load("res://assets/audio/music/%s.ogg" % name)
	if s == null:
		return
	if s is AudioStreamOggVorbis:
		s.loop = false
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = MUSIC_DB + 3.0 + vol
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func set_muffle(on: bool) -> void:
	if _lp == null:
		return
	var bi := AudioServer.get_bus_index("Music")
	if _muffle_tw != null and _muffle_tw.is_valid():
		_muffle_tw.kill()
	if on:
		AudioServer.set_bus_effect_enabled(bi, 0, true)
	_muffle_tw = create_tween()
	_muffle_tw.tween_property(_lp, "cutoff_hz", 700.0 if on else 20000.0, 0.35 if on else 0.5).set_trans(Tween.TRANS_SINE)
	if not on:
		_muffle_tw.tween_callback(func(): AudioServer.set_bus_effect_enabled(bi, 0, false))

func refresh() -> void:
	if _fade_tw == null or not _fade_tw.is_valid():
		music.volume_db = _music_db()

func set_duck(v: float) -> void:
	if absf(v - _duck) < 0.001:
		return
	_duck = v
	refresh()

func _load_sfx(name: String) -> AudioStream:
	var n: int = int(VARIANTS.get(name, 0))
	var file := name
	if n > 0:
		# never repeat the same take twice in a row
		var last: int = int(_last.get(name, -1))
		var pick := randi() % n
		if n > 1 and pick == last:
			pick = (pick + 1) % n
		_last[name] = pick
		file = "%s_%d" % [name, pick + 1]
	var s = cache.get(file)
	if s == null:
		s = load("res://assets/audio/sfx/%s.wav" % file)
		if s == null:
			return null
		cache[file] = s
	return s

func sfx(name: String, pitch_var := 0.0, vol := 0.0) -> void:
	if not Game.sfx_on:
		return
	var s := _load_sfx(name)
	if s == null:
		return
	var pool := ui_players if name.begins_with("ui_") or name == "select" or name == "blip" else players
	var pick: AudioStreamPlayer = null
	for p in pool:
		if not p.playing:
			pick = p
			break
	if pick == null:
		# steal the oldest voice instead of dropping the sound
		pick = pool[0]
		pool.erase(pick)
		pool.append(pick)
	pick.stream = s
	pick.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var) + randf_range(-0.015, 0.015)
	pick.volume_db = -3.0 + vol
	pick.play()
