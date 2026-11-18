extends Node
# Global game state, chapter data, saving, scene flow and shared helpers.

const Catalog = preload("res://scripts/catalog.gd")
const CHAPTER_COUNT := 12
const SAVE_PATH := "user://save.cfg"
const ADV_PATH := "user://adventure_%d.cfg"
const LEGACY_DIR := "سليم- الطريق لأبويا"
const MAX_ADVENTURES := 8
const NAME_MAX := 20
const TILE := 16
const StoryData = preload("res://scripts/story_data.gd")

const CHAPTERS := {
	1: {"num": "الفصل الأول", "name": "حارة السيدة", "place": "القاهرة القديمة", "music": "ch1", "decor": [0, 3, 4, 7, 2, 0], "tint": Color(1, 1, 1), "sky": Color(0.95, 0.55, 0.3)},
	2: {"num": "الفصل التاني", "name": "خان الخليلي", "place": "القاهرة الفاطمية", "music": "ch2", "decor": [2, 4, 3, 2, 7], "tint": Color(0.95, 0.92, 1.0), "sky": Color(0.1, 0.12, 0.35)},
	3: {"num": "الفصل التالت", "name": "كورنيش النيل", "place": "القاهرة بالليل", "music": "ch3", "decor": [0, 1, 9, 0], "tint": Color(0.82, 0.86, 1.0), "sky": Color(0.06, 0.08, 0.25)},
	4: {"num": "الفصل الرابع", "name": "قلعة قايتباي", "place": "إسكندرية", "music": "ch4", "decor": [3, 8, 102, 104, 4, 105], "tint": Color(1, 1, 1), "sky": Color(0.25, 0.55, 0.95)},
	5: {"num": "الفصل الخامس", "name": "معبد الكرنك", "place": "الأقصر", "music": "ch5", "decor": [5, 1, 4, 6, 5], "tint": Color(1.0, 0.97, 0.9), "sky": Color(0.95, 0.75, 0.4)},
	6: {"num": "الفصل السادس", "name": "أسرار الأهرامات", "place": "الجيزة — إنقاذ منصور", "music": "ch6", "decor": [6, 5, 4, 6], "tint": Color(0.92, 0.8, 0.84), "sky": Color(0.3, 0.05, 0.08)},
	7: {"num": "الفصل السابع", "name": "ليلة المتحف", "place": "الجيزة — بداية المطاردة", "music": "ch7", "decor": [10, 5, 10, 6, 5], "tint": Color(0.86, 0.88, 1.0), "sky": Color(0.05, 0.1, 0.33), "haze": Color(0.05, 0.03, 0.12), "ambience": "museum"},
	8: {"num": "الفصل الثامن", "name": "درب العقرب", "place": "الصحراء البيضاء", "music": "ch8", "decor": [11, 1, 4, 11], "tint": Color(1.0, 0.94, 0.84), "sky": Color(0.68, 0.66, 0.56), "haze": Color(0.72, 0.6, 0.42), "ambience": "sandstorm"},
	9: {"num": "الفصل التاسع", "name": "مراكب النوبة", "place": "أسوان", "music": "ch9", "decor": [12, 104, 105, 102, 12, 104, 101], "decor_rate": 0.24, "tint": Color(1.0, 0.98, 0.94), "sky": Color(0.03, 0.46, 0.8), "haze": Color(0.06, 0.24, 0.36), "ambience": "river"},
	10: {"num": "الفصل العاشر", "name": "عين الشمس", "place": "أبو سمبل", "music": "ch10", "decor": [13, 5, 6, 13, 1], "tint": Color(1.0, 0.92, 0.8), "sky": Color(0.18, 0.3, 0.3), "haze": Color(0.55, 0.28, 0.08), "ambience": "sunrise"},
	11: {"num": "الفصل الحادي عشر", "name": "قطار الخطر", "place": "الصعيد — طريق العودة", "music": "ch11", "decor": [100, 101, 102, 103, 100, 104, 14], "decor_rate": 0.26, "tint": Color(1.0, 0.86, 0.84), "sky": Color(0.28, 0.17, 0.42), "haze": Color(0.45, 0.16, 0.2), "ambience": "dusk"},
	12: {"num": "الفصل الثاني عشر", "name": "ساعة الحقيقة", "place": "قلعة صلاح الدين", "music": "ch12", "decor": [15, 5, 2, 15, 6], "tint": Color(0.82, 0.9, 1.0), "sky": Color(0.02, 0.12, 0.22), "haze": Color(0.02, 0.1, 0.14), "ambience": "citadel"},
}

const BOSSES := {
	1: {"name": "عتريس — بلطجي الحارة", "sheet": "boss1", "hp": 30, "speed": 70.0, "attacks": ["melee", "charge", "slam", "melee"], "proj": "stone", "minions": ["thug", "dog"]},
	2: {"name": "زعزوع الحاوي", "sheet": "boss2", "hp": 34, "speed": 62.0, "attacks": ["throw", "snakes", "melee", "slam"], "proj": "pot", "minions": ["thrower", "dog"]},
	3: {"name": "المعلم بلية", "sheet": "boss3", "hp": 38, "speed": 92.0, "attacks": ["knives", "charge", "melee", "teleport"], "proj": "knife", "minions": ["knife", "thug2"]},
	4: {"name": "القرش — ملك الميناء", "sheet": "boss4", "hp": 42, "speed": 78.0, "attacks": ["charge", "slam", "summon", "melee", "throw"], "proj": "stone", "minions": ["thug2", "knife"]},
	5: {"name": "الملثم", "sheet": "boss5", "hp": 46, "speed": 82.0, "attacks": ["teleport", "fireball", "slam", "knives"], "proj": "fire", "minions": ["knife", "dog"]},
	6: {"name": "الكابو — عم فتحي", "sheet": "boss6", "hp": 74, "speed": 92.0, "attacks": ["melee", "knives", "summon", "charge"], "phase2": ["fireball", "slam", "teleport", "charge", "knives", "summon", "melee"], "proj": "knife", "minions": ["knife", "thug", "dog"]},
	7: {"name": "الثعلب — سارق المفتاح", "sheet": "boss7", "hp": 78, "speed": 110.0, "attacks": ["decoy", "smoke_tp", "knives", "melee"], "phase2": ["decoy", "smoke_tp", "charge", "knives", "summon"], "proj": "knife", "minions": ["thief", "secguard"], "dodge": 0.35},
	8: {"name": "العقرب — زعيم المهربين", "sheet": "boss8", "hp": 84, "speed": 85.0, "attacks": ["burrow", "venom", "melee", "summon"], "phase2": ["burrow", "venom", "sandrain", "charge", "summon"], "proj": "stone", "minions": ["smuggler", "scorpion"]},
	9: {"name": "التمساح — قرصان النيل", "sheet": "boss9", "hp": 90, "speed": 82.0, "attacks": ["hook", "barrels", "slam", "melee"], "phase2": ["hook", "barrels", "charge", "summon", "slam"], "proj": "stone", "minions": ["pirate", "croc"]},
	10: {"name": "الكاهن — حارس السر", "sheet": "boss10", "hp": 98, "speed": 90.0, "attacks": ["beams", "scarabs", "fireball", "teleport"], "phase2": ["beams", "scarabs", "fireball", "snakes", "summon"], "proj": "fire", "orb": "sunorb", "minions": ["jackal", "cultist"]},
	11: {"name": "الجنرال — قائد الحراس", "sheet": "boss11", "hp": 106, "speed": 112.0, "attacks": ["grenades", "shield", "charge", "knives"], "phase2": ["grenades", "shield", "charge", "summon", "knives"], "proj": "knife", "minions": ["trainguard", "bandit"]},
	12: {"name": "الأفعى — الدكتور رفعت", "sheet": "boss12", "hp": 120, "speed": 115.0, "attacks": ["illusion", "venom", "melee", "teleport"], "phase2": ["illusion", "snakerain", "venom", "teleport", "summon"], "proj": "knife", "minions": ["viperman", "bodyguard"], "dodge": 0.25},
}

# Sprite sheets are hi-bit pixel art drawn at 2 texels per world unit (see tools/gen_chars.py).
const SPR := 0.5
# Visual size of every character relative to the world (tiles stay the same size).
const CHAR_SCALE := 1.3
const FOOT := 4.0
# [name, row, frames, fps, loop]
const PLAYER_ANIMS := [["idle", 0, 6, 8.0, true], ["run", 1, 8, 14.0, true], ["jump", 2, 2, 8.0, true], ["fall", 3, 2, 8.0, true],
	["atk1", 4, 5, 22.0, false], ["atk2", 5, 5, 22.0, false], ["atk3", 6, 6, 17.0, false], ["hurt", 7, 2, 10.0, false],
	["dash", 8, 2, 14.0, true], ["die", 9, 4, 7.0, false], ["land", 10, 2, 16.0, false]]
const PLAYER_GRID := Vector2i(8, 11)
const ENEMY_ANIMS := [["idle", 0, 4, 6.0, true], ["run", 1, 8, 13.0, true], ["smash", 2, 5, 13.0, false], ["hurt", 3, 2, 8.0, false],
	["throw", 4, 4, 12.0, false], ["die", 5, 4, 8.0, false], ["jump", 6, 2, 6.0, true], ["cast", 7, 4, 9.0, false], ["stab", 8, 4, 14.0, false]]
const ENEMY_GRID := Vector2i(8, 9)
const DOG_ANIMS := [["idle", 0, 4, 6.0, true], ["run", 1, 6, 15.0, true], ["atk", 2, 3, 10.0, false], ["hurt", 3, 1, 1.0, false]]
const DOG_GRID := Vector2i(6, 4)
const NPC_ANIMS := [["idle", 0, 4, 4.0, true]]
const NPC_GRID := Vector2i(4, 1)

# Hi-res AI-drawn sheets (tools/build_chars.py). Per sheet: grid, texels-per-unit, foot row (texels from cell top).
# Sheets listed here override the legacy grid/anim layout passed by callers.
const ENEMY6_ANIMS := [["idle", 0, 4, 6.0, true], ["run", 1, 6, 12.0, true], ["smash", 2, 5, 13.0, false], ["hurt", 3, 2, 8.0, false],
	["throw", 4, 4, 12.0, false], ["die", 5, 4, 8.0, false], ["jump", 6, 2, 6.0, true], ["cast", 7, 4, 9.0, false], ["stab", 8, 4, 14.0, false]]
const HIRES := {
	#HIRES_BEGIN
	"boss1": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84, 72)},
	"boss2": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84, 72)},
	"boss3": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84, 72)},
	"boss4": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84, 72)},
	"boss5": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84, 72)},
	"boss6": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84, 72)},
	"dog": {"grid": Vector2i(6, 4), "tpu": 4.0, "foot": 116, "anims": DOG_ANIMS},
	"father": {"grid": Vector2i(4, 1), "tpu": 4.0, "foot": 148, "anims": NPC_ANIMS},
	"hassan": {"grid": Vector2i(4, 1), "tpu": 4.0, "foot": 148, "anims": NPC_ANIMS},
	"knife": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"npc": {"grid": Vector2i(4, 1), "tpu": 4.0, "foot": 148, "anims": NPC_ANIMS},
	"player_saber": {"grid": Vector2i(8,11), "tpu": 4.0, "foot": 204},
"player_spear": {"grid": Vector2i(8,11), "tpu": 4.0, "foot": 204},
"player_hammer": {"grid": Vector2i(8,11), "tpu": 4.0, "foot": 204},
"player_khopesh": {"grid": Vector2i(8,11), "tpu": 4.0, "foot": 204},
	"player": {"grid": Vector2i(8, 11), "tpu": 4.0, "foot": 204},
	"thrower": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"thug": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"thug2": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"boss7": {"grid": Vector2i(6,9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84,72)},
	"boss8": {"grid": Vector2i(6,9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84,72)},
	"boss9": {"grid": Vector2i(6,9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84,72)},
	"boss10": {"grid": Vector2i(6,9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84,72)},
	"boss11": {"grid": Vector2i(6,9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84,72)},
	"boss12": {"grid": Vector2i(6,9), "tpu": 4.0, "foot": 256, "anims": ENEMY6_ANIMS, "body": Vector2(84,72)},
	"fetewa": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"charmer": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"boatman": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"sailor": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"robber": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"brute": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"thief": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"secguard": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"smuggler": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"slinger": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"pirate": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"jackal": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"cultist": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"trainguard": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"bandit": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"bodyguard": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"viperman": {"grid": Vector2i(6, 9), "tpu": 4.0, "foot": 196, "anims": ENEMY6_ANIMS},
	"scorpion": {"grid": Vector2i(6, 4), "tpu": 4.0, "foot": 116, "anims": DOG_ANIMS},
	"croc": {"grid": Vector2i(6, 4), "tpu": 4.0, "foot": 116, "anims": DOG_ANIMS},
	#HIRES_END
}

# AI-drawn chapter enemies: sheet -> behaviour archetype (thug / thug2 / thrower / knife / dog).
const ENEMY_TYPES := {
	"thug": "thug", "thug2": "thug2", "thrower": "thrower", "knife": "knife", "dog": "dog",
	"fetewa": "thug2", "charmer": "thrower", "boatman": "thug", "sailor": "thug2", "robber": "knife", "brute": "thug",
	"thief": "thug", "secguard": "thug2", "smuggler": "thug", "slinger": "thrower", "scorpion": "dog",
	"pirate": "thug", "croc": "dog", "jackal": "thug", "cultist": "thrower", "trainguard": "thug",
	"bandit": "knife", "bodyguard": "thug2", "viperman": "knife",
}
# Map letter -> sheet, per chapter. Every chapter fields its own mix of fighters.
const ROSTER := {
	1: {"T": "thug", "U": "fetewa", "R": "thrower", "J": "knife", "D": "dog"},
	2: {"T": "thug", "U": "thug2", "R": "charmer", "J": "knife", "D": "dog"},
	3: {"T": "boatman", "U": "thug2", "R": "thrower", "J": "knife", "D": "dog"},
	4: {"T": "thug", "U": "sailor", "R": "thrower", "J": "knife", "D": "dog"},
	5: {"T": "thug", "U": "thug2", "R": "thrower", "J": "robber", "D": "dog"},
	6: {"T": "brute", "U": "thug2", "R": "thrower", "J": "knife", "D": "dog"},
	7: {"T": "thief", "U": "secguard", "R": "thrower", "J": "knife", "D": "dog"},
	8: {"T": "smuggler", "U": "thug2", "R": "slinger", "J": "robber", "D": "scorpion"},
	9: {"T": "pirate", "U": "boatman", "R": "thrower", "J": "knife", "D": "croc"},
	10: {"T": "jackal", "U": "jackal", "R": "cultist", "J": "knife", "D": "dog"},
	11: {"T": "trainguard", "U": "thug2", "R": "slinger", "J": "bandit", "D": "dog"},
	12: {"T": "bodyguard", "U": "brute", "R": "cultist", "J": "viperman", "D": "dog"},
}

# Difficulty presets (chosen in the title-screen settings). Easy is the original balance.
# extra = chance per map enemy of a second copy (1.0 = always one more), boss_* scale the boss fight,
# summon/minion_cap = followers per summon and alive at once, auto_summon = seconds between free summons
# (0 = never), stagger = boss hits needed to stagger him (0 = never flinches), wave/waves = ambush size.
const DIFFICULTY := [
	{"id": "easy", "name": "سهل", "desc": "الرحلة الأصلية: أعداء أقل وزعيم بيتأثر بالضرب.", "enemy_hp": 1.0, "enemy_spd": 1.0, "windup": 1.0, "recover": 1.0, "throw": 1.0, "sight": 1.0, "extra": 0.0, "boss_hp": 1.0, "boss_spd": 1.0, "boss_idle": 1.0, "summon": 2, "minion_cap": 3, "auto_summon": 0.0, "stagger": 6, "boss_dmg": 1, "wave": 3, "waves": 2, "reward": 1.0, "ferocity": 0.0, "leap": false, "color": Color(0.62, 0.86, 0.66)},
	{"id": "medium", "name": "متوسط", "desc": "أعداء أكتر بكتير، والزعيم سريع وبيستحمل ومعاه أتباع كتير.", "enemy_hp": 1.35, "enemy_spd": 1.12, "windup": 0.82, "recover": 0.75, "throw": 0.8, "sight": 1.3, "extra": 0.55, "boss_hp": 1.7, "boss_spd": 1.25, "boss_idle": 0.6, "summon": 3, "minion_cap": 5, "auto_summon": 9.0, "stagger": 16, "boss_dmg": 1, "wave": 4, "waves": 2, "reward": 1.25, "ferocity": 0.35, "leap": true, "color": Color(0.95, 0.76, 0.44)},
	{"id": "hard", "name": "صعب", "desc": "جيوش بتهجم بشراسة، والزعيم مبيتهزش ولا بيوقف وأتباعه مالهمش آخر.", "enemy_hp": 1.75, "enemy_spd": 1.25, "windup": 0.68, "recover": 0.55, "throw": 0.62, "sight": 1.7, "extra": 1.0, "boss_hp": 2.0, "boss_spd": 1.4, "boss_idle": 0.4, "summon": 3, "minion_cap": 6, "auto_summon": 7.0, "stagger": 0, "boss_dmg": 2, "wave": 5, "waves": 3, "reward": 1.5, "ferocity": 0.75, "leap": true, "color": Color(0.94, 0.52, 0.46)},
]

const GOLD := Color(0.95, 0.76, 0.44)
const CREAM := Color(1.0, 0.95, 0.84)
const INK := Color(0.07, 0.03, 0.05)

var wallet := 0
var owned: Array = ["stick"]
var equipped := "stick"
# Only two weapons are carried into a chapter; the weapon button swaps between them.
var loadout: Array = ["stick", ""]
var upgrades := {"health": 0, "power": 0, "armor": 0, "boots": 0, "magnet": 0}
var difficulty := 0
var inventory := {"potion": 0, "bomb": 0}
var shop_next := 0
var completed: Array = []
var unlocked := 1
var chapter := 1
var checkpoint_active := false
# 1 = mid-chapter lantern, 2 = lantern just before the boss gate.
var checkpoint_idx := 0
# Enemies (map ids) already beaten and ambushes already cleared when the checkpoint was lit.
var cp_killed: Array = []
var cp_waves: Array = []
var coins := 0
var coins_at_checkpoint := 0
var total_coins := 0
var deaths := 0
var music_on := true
var sfx_on := true
var voice_on := true
var story_auto := false
var story_id := ""
var story_next := ""
var force_touch := false
var autotest := ""
# true while the big dialog box is open: world speech bubbles stay hidden so nothing overlaps it
var dialog_open := false
# active adventure (0 = none yet) and the list of saved adventure ids
var adv_id := 0
var adv_name := ""
var adv_created := 0
var adventures: Array = []
var next_adv_id := 1

var _frames_cache := {}
var _fade: ColorRect
var _changing := false
var font_title: Font    # Lalezar – big display titles, numbers
var font_body: Font     # Changa SemiBold – dialogue / descriptions (theme default)
var font_button: Font   # Reem Kufi Bold – buttons, menu items
var font_callig: Font   # Aref Ruqaa Bold – speaker names, chapter subtitles, cinematic captions

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_game()
	font_title = load("res://assets/fonts/Lalezar.ttf")
	font_body = load("res://assets/fonts/changa_semibold.tres")
	font_button = load("res://assets/fonts/reemkufi_bold.tres")
	font_callig = load("res://assets/fonts/ArefRuqaa-Bold.ttf")
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	for a in OS.get_cmdline_user_args():
		if a == "--touch":
			force_touch = true
		if a.begins_with("--autotest="):
			autotest = a.substr(11)

func _setup_input() -> void:
	var map := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"jump": [KEY_SPACE, KEY_UP, KEY_W, KEY_Z],
		"attack": [KEY_J, KEY_X, KEY_F],
		"dash": [KEY_K, KEY_SHIFT, KEY_C],
		"pause": [KEY_ESCAPE, KEY_P],
		"potion": [KEY_H], "bomb": [KEY_L], "weapon": [KEY_TAB],
		"accept": [KEY_ENTER, KEY_KP_ENTER],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# gamepad
	var pad := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "dash": JOY_BUTTON_B, "pause": JOY_BUTTON_START,
		"potion": JOY_BUTTON_Y, "bomb": JOY_BUTTON_RIGHT_SHOULDER, "weapon": JOY_BUTTON_LEFT_SHOULDER,
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT}
	for action in pad:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)

# ---------------------------------------------------------------- save
# save.cfg holds the shared settings and the list of adventures. Every adventure (its own name,
# difficulty, chapters, checkpoint, wallet and shop items) lives in its own user://adventure_<id>.cfg,
# so several adventures can run side by side and the player picks which one to continue.
func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("settings", "music", music_on)
	cf.set_value("settings", "sfx", sfx_on)
	cf.set_value("settings", "voice", voice_on)
	cf.set_value("settings", "story_auto", story_auto)
	cf.set_value("meta", "version", 10)
	cf.set_value("meta", "adventures", adventures)
	cf.set_value("meta", "active", adv_id)
	cf.set_value("meta", "next_id", next_adv_id)
	cf.save(SAVE_PATH)
	if adv_id > 0:
		_save_adventure()

func _adv_path(id: int) -> String:
	return ADV_PATH % id

func _save_adventure() -> void:
	var cf := ConfigFile.new()
	cf.set_value("adventure", "name", adv_name)
	cf.set_value("adventure", "difficulty", difficulty)
	cf.set_value("adventure", "created", adv_created)
	cf.set_value("adventure", "updated", int(Time.get_unix_time_from_system()))
	cf.set_value("game", "unlocked", unlocked)
	cf.set_value("game", "chapter", chapter)
	cf.set_value("game", "checkpoint", checkpoint_active)
	cf.set_value("game", "checkpoint_idx", checkpoint_idx)
	cf.set_value("game", "cp_killed", cp_killed)
	cf.set_value("game", "cp_waves", cp_waves)
	cf.set_value("game", "coins_cp", coins_at_checkpoint)
	cf.set_value("game", "total_coins", total_coins)
	cf.set_value("game", "deaths", deaths)
	for key in ["wallet", "owned", "equipped", "loadout", "upgrades", "inventory", "completed", "shop_next"]:
		cf.set_value("shop", key, get(key))
	cf.save(_adv_path(adv_id))

func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		# the game used to be called "سليم: الطريق لأبويا": desktop builds kept their saves in a folder
		# named after the old title, so bring that save over once.
		var legacy := OS.get_user_data_dir().get_base_dir().path_join(LEGACY_DIR).path_join("save.cfg")
		if legacy == ProjectSettings.globalize_path(SAVE_PATH) or cf.load(legacy) != OK:
			return
	music_on = bool(cf.get_value("settings", "music", true))
	sfx_on = bool(cf.get_value("settings", "sfx", true))
	voice_on = bool(cf.get_value("settings", "voice", true))
	story_auto = bool(cf.get_value("settings", "story_auto", false))
	if cf.has_section("meta"):
		adventures = []
		for v in cf.get_value("meta", "adventures", []):
			if FileAccess.file_exists(_adv_path(int(v))) and int(v) not in adventures:
				adventures.append(int(v))
		next_adv_id = maxi(1, int(cf.get_value("meta", "next_id", 1)))
		for id in adventures:
			next_adv_id = maxi(next_adv_id, int(id) + 1)
		var act := int(cf.get_value("meta", "active", 0))
		if act not in adventures:
			act = int(adventures.back()) if not adventures.is_empty() else 0
		if act > 0:
			select_adventure(act)
		return
	# v9 and older: one progress block inside save.cfg -> becomes the first adventure.
	_reset_progress()
	_read_progress(cf)
	difficulty = clampi(int(cf.get_value("settings", "difficulty", 0)), 0, DIFFICULTY.size() - 1)
	if has_progress() or wallet > 0 or owned.size() > 1:
		adventures = [1]
		next_adv_id = 2
		adv_id = 1
		adv_name = "مغامرتي"
		adv_created = int(Time.get_unix_time_from_system())
	else:
		_reset_progress()
	save_game()

# Reads the progress sections ("game" + "shop") of a ConfigFile into the live state.
func _read_progress(cf: ConfigFile) -> void:
	unlocked = int(cf.get_value("game", "unlocked", 1))
	chapter = int(cf.get_value("game", "chapter", 1))
	checkpoint_active = bool(cf.get_value("game", "checkpoint", false))
	coins_at_checkpoint = int(cf.get_value("game", "coins_cp", 0))
	total_coins = int(cf.get_value("game", "total_coins", 0))
	deaths = int(cf.get_value("game", "deaths", 0))
	wallet = maxi(0, int(cf.get_value("shop", "wallet", total_coins)))
	owned = cf.get_value("shop", "owned", ["stick"])
	equipped = str(cf.get_value("shop", "equipped", "stick"))
	loadout = cf.get_value("shop", "loadout", [equipped, ""])
	for key in upgrades:
		upgrades[key] = clampi(int(cf.get_value("shop", "upgrades", {}).get(key, 0)), 0, upgrade_max(key))
	checkpoint_idx = int(cf.get_value("game", "checkpoint_idx", 1 if checkpoint_active else 0))
	cp_killed = cf.get_value("game", "cp_killed", [])
	cp_waves = cf.get_value("game", "cp_waves", [])
	_fix_loadout()
	for key in inventory:
		inventory[key] = clampi(int(cf.get_value("shop", "inventory", {}).get(key, 0)), 0, 5)
	completed = cf.get_value("shop", "completed", [])
	shop_next = int(cf.get_value("shop", "shop_next", 0))
	unlocked = clampi(unlocked, 1, CHAPTER_COUNT)
	chapter = clampi(chapter, 1, CHAPTER_COUNT)

# Fresh progress for a brand-new (or restarted) adventure. Name and difficulty are kept.
func _reset_progress() -> void:
	unlocked = 1
	chapter = 1
	clear_checkpoint()
	coins = 0
	total_coins = 0
	deaths = 0
	wallet = 0
	owned = ["stick"]
	equipped = "stick"
	loadout = ["stick", ""]
	upgrades = {"health": 0, "power": 0, "armor": 0, "boots": 0, "magnet": 0}
	inventory = {"potion": 0, "bomb": 0}
	completed = []
	shop_next = 0

func has_progress() -> bool:
	return unlocked > 1 or checkpoint_active or chapter > 1

func has_adventure() -> bool:
	return adv_id > 0

# ---------------------------------------------------------------- adventures (save slots)
func default_adventure_name() -> String:
	var n := 1
	var names := []
	for a in list_adventures():
		names.append(str(a["name"]))
	while ("مغامرة %d" % n) in names:
		n += 1
	return "مغامرة %d" % n

func clean_name(n: String) -> String:
	var s := n.strip_edges().replace("\n", " ")
	if s.length() > NAME_MAX:
		s = s.substr(0, NAME_MAX)
	return s

func can_add_adventure() -> bool:
	return adventures.size() < MAX_ADVENTURES

# Summary of every saved adventure, most recently played first.
func list_adventures() -> Array:
	var out: Array = []
	for id in adventures:
		var cf := ConfigFile.new()
		if cf.load(_adv_path(int(id))) != OK:
			continue
		var ch := clampi(int(cf.get_value("game", "chapter", 1)), 1, CHAPTER_COUNT)
		out.append({
			"id": int(id),
			"name": str(cf.get_value("adventure", "name", "مغامرة")),
			"difficulty": clampi(int(cf.get_value("adventure", "difficulty", 0)), 0, DIFFICULTY.size() - 1),
			"chapter": ch,
			"unlocked": int(cf.get_value("game", "unlocked", 1)),
			"completed": (cf.get_value("shop", "completed", []) as Array).size(),
			"wallet": int(cf.get_value("shop", "wallet", 0)),
			"updated": int(cf.get_value("adventure", "updated", 0)),
		})
	out.sort_custom(func(a, b): return int(a["updated"]) > int(b["updated"]))
	return out

# Starts a brand-new adventure with its own name and difficulty and plays the prologue.
func create_adventure(name: String, diff_idx: int) -> bool:
	if not can_add_adventure():
		return false
	if adv_id > 0:
		_save_adventure()
	_reset_progress()
	adv_id = next_adv_id
	next_adv_id += 1
	adventures.append(adv_id)
	var nm := clean_name(name)
	adv_name = nm if nm != "" else default_adventure_name()
	adv_created = int(Time.get_unix_time_from_system())
	difficulty = clampi(diff_idx, 0, DIFFICULTY.size() - 1)
	new_game()
	return true

# Makes a saved adventure the active one (its progress becomes the live state).
func select_adventure(id: int) -> bool:
	var cf := ConfigFile.new()
	if id not in adventures or cf.load(_adv_path(id)) != OK:
		return false
	if adv_id > 0 and adv_id != id:
		_save_adventure()
	_reset_progress()
	_read_progress(cf)
	adv_id = id
	adv_name = str(cf.get_value("adventure", "name", "مغامرة"))
	adv_created = int(cf.get_value("adventure", "created", 0))
	difficulty = clampi(int(cf.get_value("adventure", "difficulty", 0)), 0, DIFFICULTY.size() - 1)
	return true

func play_adventure(id: int) -> void:
	if select_adventure(id):
		save_game()
		continue_game()

func rename_adventure(id: int, name: String) -> void:
	var nm := clean_name(name)
	if nm == "":
		return
	if id == adv_id:
		adv_name = nm
		save_game()
		return
	var cf := ConfigFile.new()
	if cf.load(_adv_path(id)) == OK:
		cf.set_value("adventure", "name", nm)
		cf.save(_adv_path(id))

func delete_adventure(id: int) -> void:
	if id not in adventures:
		return
	adventures.erase(id)
	DirAccess.remove_absolute(_adv_path(id))
	if id == adv_id:
		adv_id = 0
		adv_name = ""
		_reset_progress()
		difficulty = 0
		var rest := list_adventures()
		if not rest.is_empty():
			select_adventure(int(rest[0]["id"]))
	save_game()

# Changing the difficulty of a running adventure restarts it from chapter 1 (progress is wiped,
# name stays). The title screen asks for confirmation before calling this.
func restart_with_difficulty(d: int) -> void:
	if adv_id <= 0:
		return
	_reset_progress()
	difficulty = clampi(d, 0, DIFFICULTY.size() - 1)
	save_game()

# ---------------------------------------------------------------- flow
func new_game() -> void:
	chapter = 1
	clear_checkpoint()
	coins = 0
	coins_at_checkpoint = 0
	save_game()
	play_story("prologue", "intro")

func continue_game() -> void:
	if shop_next > 0:
		open_shop(shop_next)
		return
	if checkpoint_active:
		goto_level()
	else:
		start_chapter(chapter)

func start_chapter(n: int) -> void:
	shop_next = 0
	chapter = clampi(n, 1, CHAPTER_COUNT)
	clear_checkpoint()
	coins = 0
	coins_at_checkpoint = 0
	save_game()
	play_story("ch%d_intro" % chapter, "level")

func play_story(id: String, next: String) -> void:
	story_id = id
	story_next = next
	change_scene("res://scenes/Story.tscn")

func story_finished() -> void:
	match story_next:
		"intro":
			play_story("ch%d_intro" % chapter, "level")
		"level":
			goto_level()
		"next":
			if chapter < CHAPTER_COUNT:
				shop_next = chapter + 1
				chapter = shop_next
				save_game()
				open_shop(shop_next)
			else:
				play_story("credits", "title")
		_:
			change_scene("res://scenes/Title.tscn")

func goto_level() -> void:
	change_scene("res://scenes/Level.tscn")

func reload_level() -> void:
	change_scene("res://scenes/Level.tscn")

func goto_title() -> void:
	change_scene("res://scenes/Title.tscn")

func chapter_complete() -> void:
	total_coins += coins
	wallet += coins + clear_reward()
	if chapter not in completed:
		completed.append(chapter)
	coins = 0
	unlocked = maxi(unlocked, mini(chapter + 1, CHAPTER_COUNT))
	clear_checkpoint()
	coins_at_checkpoint = 0
	if chapter < CHAPTER_COUNT:
		save_game()
	else:
		unlocked = CHAPTER_COUNT
		save_game()
	play_story("ch%d_outro" % chapter, "next")
	if chapter < CHAPTER_COUNT:
		# next chapter becomes the "continue" target
		pass

func set_checkpoint(idx := 1, killed: Array = [], waves: Array = []) -> void:
	checkpoint_active = true
	checkpoint_idx = idx
	cp_killed = killed.duplicate()
	cp_waves = waves.duplicate()
	coins_at_checkpoint = coins
	save_game()

# Fighters beaten and ambushes cleared after a lantern was lit stay beaten: the save is updated on
# every kill, so quitting or dying never brings them back.
func checkpoint_progress(killed: Array, waves: Array) -> void:
	if not checkpoint_active:
		return
	cp_killed = killed.duplicate()
	cp_waves = waves.duplicate()
	save_game()

func clear_checkpoint() -> void:
	checkpoint_active = false
	checkpoint_idx = 0
	cp_killed = []
	cp_waves = []
	coins_at_checkpoint = 0

# Coins banked on top of the picked-up ones when a chapter is cleared (first clear only; replays pay 10).
func clear_reward() -> int:
	if chapter in completed:
		return 10
	return int(round((30 + chapter * 5) * float(diff()["reward"])))

func diff() -> Dictionary:
	return DIFFICULTY[clampi(difficulty, 0, DIFFICULTY.size() - 1)]

func set_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, DIFFICULTY.size() - 1)
	save_game()

func change_scene(path: String) -> void:
	if _changing:
		return
	_changing = true
	Engine.time_scale = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
	_changing = false

# ---------------------------------------------------------------- helpers
func frames(sheet: String, anims: Array, cols: int, rows: int) -> SpriteFrames:
	# returns cached SpriteFrames; meta fw/fh are texel sizes, ww/wh world sizes
	if _frames_cache.has(sheet):
		return _frames_cache[sheet]
	var tpu := 1.0 / SPR
	if HIRES.has(sheet):
		var hi: Dictionary = HIRES[sheet]
		cols = hi["grid"].x
		rows = hi["grid"].y
		tpu = hi["tpu"]
		if hi.has("anims"):
			anims = hi["anims"]
	var tex: Texture2D = load("res://assets/sprites/%s.png" % sheet)
	var fw := int(tex.get_width() / cols)
	var fh := int(tex.get_height() / rows)
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for a in anims:
		var nm: String = a[0]
		sf.add_animation(nm)
		sf.set_animation_speed(nm, a[3])
		sf.set_animation_loop(nm, a[4])
		for i in range(int(a[2])):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, int(a[1]) * fh, fw, fh)
			sf.add_frame(nm, at)
	if sheet.begins_with("player") and ResourceLoader.exists("res://assets/sprites/moves_%s.png" % sheet):
		_add_moves(sf, tex, load("res://assets/sprites/moves_%s.png" % sheet), fw, fh)
	sf.set_meta("fw", fw)
	sf.set_meta("fh", fh)
	sf.set_meta("tpu", tpu)
	sf.set_meta("ww", fw / tpu)
	sf.set_meta("wh", fh / tpu)
	if HIRES.has(sheet) and HIRES[sheet].has("body"):
		# legacy frame size used by bosses to derive their hitbox
		sf.set_meta("ww", HIRES[sheet]["body"].x)
		sf.set_meta("wh", HIRES[sheet]["body"].y)
	_frames_cache[sheet] = sf
	return sf

# Extra hero moves drawn per weapon (moves_player*.png: 6 cells, same cell size and foot line as the base
# sheet): front kick, roundhouse, flying kick, rising uppercut, overhead smash, slide sweep.
# Frame refs: [-1, n] = moves cell n, [row, col] = base sheet cell (wind-up / follow-through frames).
const MOVE_ANIMS := [
	["kick", [[4, 0], [-1, 0], [-1, 0], [-1, 0]], 15.0],
	["rhkick", [[5, 0], [-1, 1], [-1, 1], [-1, 1], [-1, 1]], 15.0],
	["fkick", [[-1, 2]], 1.0],
	["upper", [[10, 1], [-1, 3], [-1, 3], [-1, 3]], 14.0],
	["slam", [[-1, 4], [6, 3], [6, 4], [6, 5]], 12.0],
	["sweep", [[10, 0], [-1, 5], [-1, 5], [-1, 5], [-1, 5]], 15.0],
]

func _add_moves(sf: SpriteFrames, base: Texture2D, mv: Texture2D, fw: int, fh: int) -> void:
	for a in MOVE_ANIMS:
		var nm: String = a[0]
		sf.add_animation(nm)
		sf.set_animation_speed(nm, a[2])
		sf.set_animation_loop(nm, false)
		for ref in a[1]:
			var at := AtlasTexture.new()
			if int(ref[0]) < 0:
				at.atlas = mv
				at.region = Rect2(int(ref[1]) * fw, 0, fw, fh)
			else:
				at.atlas = base
				at.region = Rect2(int(ref[1]) * fw, int(ref[0]) * fh, fw, fh)
			sf.add_frame(nm, at)

func region_sprite(path: String, rect: Rect2, world_scale := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.region_enabled = true
	s.region_rect = rect
	if world_scale:
		s.scale = Vector2(SPR, SPR)
	return s

# Attach a sprite-sheet character sprite whose feet sit on the node origin.
func char_sprite(parent: Node, sheet: String, anims: Array, grid: Vector2i) -> AnimatedSprite2D:
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = frames(sheet, anims, grid.x, grid.y)
	var fh: int = sp.sprite_frames.get_meta("fh")
	if HIRES.has(sheet):
		var tpu: float = HIRES[sheet]["tpu"]
		sp.scale = Vector2(1.0 / tpu, 1.0 / tpu) * CHAR_SCALE
		sp.offset = Vector2(0, -(float(HIRES[sheet]["foot"]) - fh / 2.0))
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		sp.scale = Vector2(SPR, SPR) * CHAR_SCALE
		sp.offset = Vector2(0, -(fh / 2.0 - FOOT))
	parent.add_child(sp)
	return sp

func spawn_fx(parent: Node, kind: String, pos: Vector2, flip := false, scale_f := 1.0) -> void:
	if parent == null:
		return
	var s := AnimatedSprite2D.new()
	var key := "fx_" + kind
	var sf: SpriteFrames
	if _frames_cache.has(key):
		sf = _frames_cache[key]
	else:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % kind)
		var n := 3 if kind == "slash" else 4
		var fw := int(tex.get_width() / n)
		sf = SpriteFrames.new()
		sf.set_animation_loop("default", false)
		sf.set_animation_speed("default", 18.0)
		for i in range(n):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, fw, tex.get_height())
			sf.add_frame("default", at)
		_frames_cache[key] = sf
	s.sprite_frames = sf
	s.position = pos
	if kind == "dust":
		s.offset = Vector2(0, -10)
	s.flip_h = flip
	s.scale = Vector2(scale_f, scale_f) * SPR
	s.z_index = 20
	parent.add_child(s)
	s.play("default")
	s.animation_finished.connect(s.queue_free)

func hitstop(t := 0.05) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.08
	await get_tree().create_timer(t, true, false, true).timeout
	Engine.time_scale = 1.0

func style_box(bg: Color, border: Color, bw := 2, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

# ---------------------------------------------------------------- UI kit (v9: "Cairo nights")
# Every menu, panel, button and dialog box goes through kit(): deep night-glass panels with a
# warm gold hairline, vector ornaments (scripts/ornate.gd) on the important panels, one sand-gold
# accent for the main action and for selection, crimson for villains.
const Ornate = preload("res://scripts/ornate.gd")
const UI_BG := Color(0.055, 0.04, 0.055, 0.93)
const UI_CARD := Color(0.11, 0.085, 0.10, 0.95)
const UI_LINE := Color(0.95, 0.76, 0.44, 0.22)
const UI_ACCENT := Color(0.95, 0.76, 0.44)
const UI_GOLD_HI := Color(1.0, 0.88, 0.6)
const UI_TEXT := Color(0.97, 0.94, 0.88)
const UI_DIM := Color(0.70, 0.64, 0.58)
const UI_INK := Color(0.12, 0.07, 0.04)
const UI_GOOD := Color(0.62, 0.86, 0.66)
const UI_BAD := Color(0.94, 0.52, 0.46)
const UI_CRIMSON := Color(0.55, 0.10, 0.10)

func _flat(bg: Color, border: Color, bw: int, radius: int, pad: Vector4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 0.7
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	return sb

# Ornamented panel: glass box + gold frame/studs (+ star crest on the top edge).
func ornate(pad := Vector4(24, 18, 24, 18), crest := false, bg := UI_BG, gold := Color(0.95, 0.76, 0.44, 0.9)) -> StyleBox:
	var b := _flat(bg, Color(gold, 0.42), 1, 12, pad)
	b.shadow_color = Color(0, 0, 0, 0.5)
	b.shadow_size = 18
	b.shadow_offset = Vector2(0, 4)
	return Ornate.new().setup(b, gold, crest)

func kit(name: String, pad := Vector4(14, 8, 14, 8)) -> StyleBox:
	var n := name.trim_prefix("v6/")
	var sb: StyleBoxFlat
	match n:
		"panel", "panel_dark", "panel_glass":
			return ornate(pad, false)
		"panel_crest":
			return ornate(pad, true)
		"panel_dialog":
			var d := _flat(Color(0.045, 0.03, 0.045, 0.9), Color(UI_ACCENT, 0.38), 1, 14, pad)
			d.border_width_top = 2
			d.border_color = Color(UI_ACCENT, 0.5)
			d.shadow_color = Color(0, 0, 0, 0.55)
			d.shadow_size = 16
			d.shadow_offset = Vector2(0, 3)
			var o: StyleBox = Ornate.new().setup(d, Color(UI_ACCENT, 0.75), false, 5.0)
			o.ray = 30.0
			return o
		"panel_small":
			sb = _flat(Color(UI_BG, 0.82), UI_LINE, 1, 9, pad)
			sb.shadow_color = Color(0, 0, 0, 0.3)
			sb.shadow_size = 6
		"btn", "btn_buy", "btn_green":
			sb = _flat(UI_ACCENT, UI_ACCENT.darkened(0.35), 0, 9, pad)
			sb.border_width_bottom = 3
			sb.border_width_top = 1
			sb.border_color = UI_ACCENT.darkened(0.3)
			sb.shadow_color = Color(0.95, 0.7, 0.3, 0.18)
			sb.shadow_size = 6
		"btn_hi", "btn_buy_hi", "btn_green_hi":
			sb = _flat(UI_GOLD_HI, UI_ACCENT.darkened(0.25), 0, 9, pad)
			sb.border_width_bottom = 3
			sb.shadow_color = Color(1.0, 0.75, 0.35, 0.45)
			sb.shadow_size = 12
		"btn_press":
			sb = _flat(UI_ACCENT.darkened(0.1), UI_ACCENT.darkened(0.4), 0, 9, pad)
			sb.border_width_top = 2
		"btn_blue", "btn_red", "slot", "tab_off", "card_t0", "card_t1", "card_t2", "card_t3":
			sb = _flat(Color(0.09, 0.07, 0.085, 0.78) if not n.begins_with("card") else UI_CARD, Color(UI_ACCENT, 0.2), 1, 9, pad)
		"btn_blue_hi", "btn_red_hi", "slot_on", "tab_on", "card_t0_sel", "card_t1_sel", "card_t2_sel", "card_t3_sel":
			sb = _flat(Color(0.17, 0.12, 0.11, 0.9) if not n.begins_with("card") else UI_CARD.lightened(0.06), Color(UI_ACCENT, 0.85), 2 if n.begins_with("card") or n == "slot_on" else 1, 9, pad)
			sb.shadow_color = Color(0.95, 0.7, 0.3, 0.18)
			sb.shadow_size = 8
		"btn_red_press", "btn_blue_press":
			sb = _flat(Color(0.22, 0.15, 0.12, 0.95), UI_ACCENT, 1, 9, pad)
		"btn_off":
			sb = _flat(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.06), 1, 9, pad)
		"price":
			sb = _flat(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 0, 6, pad)
		"plate":
			sb = _flat(UI_ACCENT, UI_ACCENT.darkened(0.35), 0, 7, pad)
			sb.border_width_bottom = 2
			sb.shadow_color = Color(0, 0, 0, 0.45)
			sb.shadow_size = 5
			sb.skew = Vector2(0.18, 0)
		"plate_villain":
			sb = _flat(UI_CRIMSON, Color(1.0, 0.6, 0.45, 0.55), 1, 7, pad)
			sb.border_width_bottom = 2
			sb.shadow_color = Color(0, 0, 0, 0.45)
			sb.shadow_size = 5
			sb.skew = Vector2(0.18, 0)
		"ribbon":
			sb = _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, pad)
			sb.border_color = Color(UI_ACCENT, 0.45)
			sb.border_width_bottom = 1
		"bar_bg":
			sb = _flat(Color(0, 0, 0, 0.6), Color(UI_ACCENT, 0.35), 1, 4, pad)
		"bar_fill":
			sb = _flat(UI_BAD, Color(0, 0, 0, 0), 0, 3, pad)
		"portrait":
			sb = _flat(Color(0.08, 0.06, 0.07, 0.95), Color(UI_ACCENT, 0.9), 2, 12, pad)
			sb.shadow_color = Color(0.95, 0.7, 0.3, 0.28)
			sb.shadow_size = 10
		"portrait_villain":
			sb = _flat(Color(0.09, 0.04, 0.05, 0.95), Color(1.0, 0.45, 0.35, 0.9), 2, 12, pad)
			sb.shadow_color = Color(0.9, 0.15, 0.1, 0.35)
			sb.shadow_size = 12
		"pill":
			sb = _flat(Color(0.06, 0.045, 0.06, 0.72), Color(UI_ACCENT, 0.3), 1, 20, pad)
		_:
			sb = _flat(UI_BG, UI_LINE, 1, 8, pad)
	return sb

# Kept for older call sites: all boxes now come from the kit.
func tex_box(name: String, _margin := 8, pad := Vector4(14, 8, 14, 8)) -> StyleBox:
	return kit(name, pad)

func ui_box(name: String, pad := Vector4(14, 8, 14, 8), _scale_mul := 1.0) -> StyleBox:
	return kit(name, pad)

# kind: "green" / "primary" = the one main action (sand-gold fill, dark text);
#       "red" (default) = regular action; "blue" = quiet secondary. Both are dark glass.
func make_button(text: String, size := 18, kind := "red") -> Button:
	var b := Button.new()
	b.text = text
	var primary := kind == "green" or kind == "primary"
	b.add_theme_font_override("font", font_button)
	b.add_theme_font_size_override("font_size", size)
	var fc := UI_INK if primary else UI_TEXT
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", UI_INK if primary else UI_GOLD_HI)
	b.add_theme_color_override("font_pressed_color", UI_INK if primary else UI_ACCENT)
	b.add_theme_color_override("font_focus_color", UI_INK if primary else UI_GOLD_HI)
	b.add_theme_color_override("font_disabled_color", Color(UI_DIM, 0.6))
	b.add_theme_constant_override("outline_size", 0)
	var pad := Vector4(18, 4, 18, 6)
	if primary:
		b.add_theme_stylebox_override("normal", kit("btn", pad))
		b.add_theme_stylebox_override("hover", kit("btn_hi", pad))
		b.add_theme_stylebox_override("pressed", kit("btn_press", pad))
		b.add_theme_stylebox_override("focus", kit("btn_hi", pad))
	else:
		var k := "btn_blue" if kind == "blue" else "btn_red"
		b.add_theme_stylebox_override("normal", kit(k, pad))
		b.add_theme_stylebox_override("hover", kit(k + "_hi", pad))
		b.add_theme_stylebox_override("pressed", kit(k + "_press", pad))
		b.add_theme_stylebox_override("focus", kit(k + "_hi", pad))
	b.add_theme_stylebox_override("disabled", kit("btn_off", pad))
	b.custom_minimum_size = Vector2(0, 36)
	b.focus_mode = Control.FOCUS_ALL
	juice_button(b)
	return b

# Hover/focus lift + sound and a soft press squash for any button.
func juice_button(b: BaseButton) -> void:
	b.button_down.connect(func():
		Audio.sfx("select", 0.04, -5)
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(0.96, 0.96), 0.06))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	var lift := func():
		if b.disabled:
			return
		Audio.sfx("ui_hover", 0.03, -10)
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var drop := func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12)
	b.mouse_entered.connect(lift)
	b.mouse_exited.connect(drop)
	b.focus_entered.connect(func():
		if not touch_enabled():
			lift.call())
	b.focus_exited.connect(drop)

func make_label(text: String, size := 15, color := CREAM, title := false) -> Label:
	var l := Label.new()
	l.text = text
	if title:
		l.add_theme_font_override("font", font_title)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", clampi(size / 7, 2, 5))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	return l

# True for story speakers drawn with the villain (crimson) styling.
func is_villain(speaker: String) -> bool:
	return speaker.begins_with("boss") and speaker != "boss5u" or speaker in ["fathi", "taunt"]

# World-space speech bubble (NPC hints / enemy taunts): rounded box, soft shadow, gold rim and a
# tail that points at the speaker. dark = villain style (maroon with cream text).
func make_bubble(dark := false) -> PanelContainer:
	var b := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.08, 0.92) if dark else Color(0.98, 0.96, 0.92, 0.97)
	sb.border_color = Color(UI_BAD, 0.8) if dark else Color(0, 0, 0, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 1.5)
	sb.anti_aliasing_size = 0.6
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	b.add_theme_stylebox_override("panel", sb)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_to_group("speech_bubble")
	if dialog_open:
		b.visible = false
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-4.5, -1.5), Vector2(4.5, -1.5), Vector2(0, 6)])
	tail.color = sb.bg_color
	tail.name = "Tail"
	var rim := Line2D.new()
	rim.points = PackedVector2Array([Vector2(-4.5, -0.5), Vector2(0, 6), Vector2(4.5, -0.5)])
	rim.width = 1.0
	rim.default_color = sb.border_color
	tail.add_child(rim)
	b.add_child(tail)
	return b

# keep the tail under the speaker even when the bubble is pushed back on-screen
func bubble_tail(b: PanelContainer, speaker_local_x: float) -> void:
	var tail := b.get_node_or_null("Tail") as Polygon2D
	if tail != null:
		tail.position = Vector2(clampf(speaker_local_x, 9.0, maxf(9.0, b.size.x - 9.0)), b.size.y - 0.5)

# Notch / rounded-corner insets in viewport units: x=left, y=top, z=right, w=bottom.
func safe_inset() -> Vector4:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector4.ZERO
	var scr := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var vp := get_viewport().get_visible_rect().size
	if scr.x <= 0.0 or scr.y <= 0.0 or safe.size.x <= 0.0:
		return Vector4.ZERO
	var k := vp.x / scr.x
	return Vector4(safe.position.x * k, safe.position.y * k, (scr.x - safe.end.x) * k, (scr.y - safe.end.y) * k)

func touch_enabled() -> bool:
	return force_touch or DisplayServer.is_touchscreen_available()

# Wallet is banked only once on chapter completion; checkpoints never mint coins.
func item_price(id: String) -> int:
	var base := int(Catalog.ITEMS[id]["price"])
	if upgrades.has(id):
		return int(round(base * (1.0 + Catalog.UPGRADE_STEP * int(upgrades[id])) / 10.0)) * 10
	return base

func upgrade_max(id: String) -> int:
	return int(Catalog.ITEMS.get(id, {}).get("max", 3))

func purchase(id: String) -> String:
	if not Catalog.ITEMS.has(id): return "الاختيار غير متاح"
	var item: Dictionary = Catalog.ITEMS[id]
	if unlocked < int(item["unlock"]): return "لسه مقفول"
	if id in Catalog.WEAPONS and id in owned:
		equip_weapon(id)
		return "تم التجهيز"
	if upgrades.has(id) and int(upgrades[id]) >= upgrade_max(id): return "وصلت لأقصى تطوير"
	if inventory.has(id) and int(inventory[id]) >= 5: return "الحقيبة مليانة"
	var price := item_price(id)
	if wallet < price: return "الجنيهات مش كفاية"
	wallet -= price
	if id in Catalog.WEAPONS:
		owned.append(id)
		equip_weapon(id)
	elif upgrades.has(id): upgrades[id] += 1
	else: inventory[id] += 1
	save_game()
	return "تم الشراء"

# Put an owned weapon in hand: it takes the free second slot, otherwise replaces the weapon in hand.
func equip_weapon(id: String) -> void:
	if id not in owned:
		return
	if id not in loadout:
		var slot := 1 if str(loadout[1]) == "" else maxi(0, loadout.find(equipped))
		loadout[slot] = id
	equipped = id
	_fix_loadout()
	save_game()

# Assign an owned weapon to loadout slot 0/1 (swaps if it already sits in the other slot).
func set_loadout_slot(slot: int, id: String) -> void:
	if id not in owned or slot < 0 or slot >= Catalog.LOADOUT_SIZE:
		return
	var other := 1 - slot
	if str(loadout[other]) == id:
		loadout[other] = loadout[slot]
	loadout[slot] = id
	if equipped not in loadout:
		equipped = id
	_fix_loadout()
	save_game()

func clear_loadout_slot(slot: int) -> void:
	if slot != 1:
		return
	loadout[1] = ""
	if equipped not in loadout:
		equipped = str(loadout[0])
	save_game()

func _fix_loadout() -> void:
	if typeof(loadout) != TYPE_ARRAY:
		loadout = [equipped, ""]
	while loadout.size() < Catalog.LOADOUT_SIZE:
		loadout.append("")
	loadout = loadout.slice(0, Catalog.LOADOUT_SIZE)
	if "stick" not in owned:
		owned.insert(0, "stick")
	for i in range(loadout.size()):
		if str(loadout[i]) not in owned:
			loadout[i] = ""
	if str(loadout[0]) == "":
		loadout[0] = str(loadout[1]) if str(loadout[1]) != "" else "stick"
		loadout[1] = ""
	if str(loadout[1]) == str(loadout[0]):
		loadout[1] = ""
	if equipped not in owned:
		equipped = "stick"
	if equipped not in loadout:
		if str(loadout[1]) == "":
			loadout[1] = equipped
		else:
			equipped = str(loadout[0])

func can_switch() -> bool:
	return str(loadout[1]) != "" and str(loadout[1]) != str(loadout[0])

func weapon_data() -> Dictionary:
	return Catalog.ITEMS[equipped]

func cycle_weapon() -> void:
	if not can_switch():
		return
	equipped = str(loadout[1]) if equipped == str(loadout[0]) else str(loadout[0])
	save_game()
	Audio.sfx("weapon_switch", 0.05)

# Per-weapon sound: "swing"/"hit" for the stick, "swing_saber"/"hit_saber"... for the others.
func weapon_sfx(base: String, id := "") -> String:
	var w := equipped if id == "" else id
	var tag: String = str(Catalog.ITEMS.get(w, {}).get("sfx", ""))
	return base if tag == "" else "%s_%s" % [base, tag]

func player_sheet(id := "") -> String:
	var w := equipped if id == "" else id
	return "player" if w == "stick" else "player_" + w

func roster_sheet(ch: int, letter: String) -> String:
	return str(ROSTER.get(ch, ROSTER[1]).get(letter, ""))

func open_shop(next_chapter := 0) -> void:
	shop_next = next_chapter
	change_scene("res://scenes/Shop.tscn")
