extends Node
const Maps = preload("res://levels/expanded_maps.gd")
const Story = preload("res://scripts/story_data.gd")
var failures := 0
func check(ok: bool, rule: String) -> void:
	if ok: print("PASS ", rule)
	else:
		failures += 1
		push_error("FAIL " + rule)
func enemies(ch: int) -> int:
	var n := 0
	for r in Maps.MAPS[ch]:
		for c in r:
			if c in "TURJD": n += 1
	return n
func _ready() -> void:
	check(Game.CHAPTER_COUNT == 12 and Game.CHAPTERS.size() == 12 and Game.BOSSES.size() == 12, "game has twelve chapters and bosses")
	var prev := -1
	for ch in range(1, 13):
		check(Maps.MAPS.has(ch) and Story.SCENES.has("ch%d_intro" % ch) and Story.SCENES.has("ch%d_outro" % ch) and Story.BOSS_INTRO.has(ch) and Story.BOSS_RAGE.has(ch) and Story.NPCS.has(ch), "chapter %d has map, story, boss and NPC data" % ch)
		check(enemies(ch) > prev, "chapter %d has more enemies than the previous chapter" % ch)
		prev = enemies(ch)
		check(ResourceLoader.exists("res://assets/art/pan_ch%d.png" % ch) and ResourceLoader.exists("res://assets/sprites/boss%d.png" % ch) and ResourceLoader.exists("res://assets/story/st_ch%d.jpg" % ch), "chapter %d art exists" % ch)
	check(Game.BOSSES[12]["hp"] > Game.BOSSES[6]["hp"] and Game.BOSSES[7]["hp"] > Game.BOSSES[6]["hp"], "late bosses are tougher")
	Game.difficulty = 0
	Game.wallet = 500; Game.unlocked = 2; Game.owned = ["stick"]; Game.equipped = "stick"; Game.loadout = ["stick", ""]
	Game.upgrades = {"health": 0, "power": 0, "armor": 0, "boots": 0, "magnet": 0}
	check(Game.purchase("saber") == "تم الشراء" and Game.wallet == 50 and Game.equipped == "saber", "buying the saber spends 450 coins and equips it")
	check(Game.loadout == ["stick", "saber"], "a bought weapon goes into the free second slot")
	check(Game.purchase("spear") == "لسه مقفول" and Game.wallet == 50, "locked spear cannot be bought before chapter 4")
	Game.wallet = 20
	check(Game.purchase("potion") == "الجنيهات مش كفاية" and Game.wallet == 20, "potion purchase is refused without 60 coins")
	check(Game.item_price("spear") == 900 and Game.item_price("hammer") == 1600 and Game.item_price("khopesh") == 2600, "weapons cost 900 / 1600 / 2600")
	check(Game.item_price("health") == 300, "first heart upgrade costs 300")
	Game.upgrades["health"] = 1
	check(Game.item_price("health") == 540, "second heart upgrade costs 540 (each level dearer)")
	Game.upgrades["health"] = 4
	Game.wallet = 5000
	check(Game.purchase("health") == "وصلت لأقصى تطوير" and Game.wallet == 5000, "heart upgrade stops at level 4")
	# two-weapon loadout
	Game.unlocked = 12; Game.owned = ["stick", "saber", "spear"]; Game.loadout = ["stick", "saber"]; Game.equipped = "saber"
	Game.cycle_weapon()
	check(Game.equipped == "stick", "weapon button swaps to the other loadout weapon")
	Game.cycle_weapon()
	check(Game.equipped == "saber", "weapon button swaps back (spear in the bag is never picked)")
	Game.purchase("hammer")
	check(Game.loadout.size() == 2 and "hammer" in Game.loadout and Game.equipped == "hammer" and not ("saber" in Game.loadout), "a new weapon replaces the one in hand when both slots are full")
	Game.set_loadout_slot(1, "spear")
	check(Game.loadout[1] == "spear" and Game.loadout.size() == 2, "player can choose which owned weapon sits in slot 2")
	Game.loadout = ["stick", ""]; Game.equipped = "stick"
	Game.cycle_weapon()
	check(Game.equipped == "stick" and not Game.can_switch(), "with one weapon in the loadout there is nothing to swap")
	# difficulty
	check(Game.DIFFICULTY.size() == 3 and Game.DIFFICULTY[0]["name"] == "سهل" and Game.DIFFICULTY[1]["name"] == "متوسط" and Game.DIFFICULTY[2]["name"] == "صعب", "three difficulties: easy, medium, hard")
	check(Game.DIFFICULTY[0]["extra"] < Game.DIFFICULTY[1]["extra"] and Game.DIFFICULTY[1]["extra"] < Game.DIFFICULTY[2]["extra"], "each difficulty fields more fighters")
	check(Game.DIFFICULTY[0]["boss_hp"] < Game.DIFFICULTY[1]["boss_hp"] and Game.DIFFICULTY[1]["boss_hp"] < Game.DIFFICULTY[2]["boss_hp"] and Game.DIFFICULTY[0]["boss_spd"] < Game.DIFFICULTY[2]["boss_spd"], "bosses get tougher and faster with difficulty")
	check(Game.DIFFICULTY[0]["minion_cap"] < Game.DIFFICULTY[1]["minion_cap"] and Game.DIFFICULTY[1]["minion_cap"] < Game.DIFFICULTY[2]["minion_cap"] and Game.DIFFICULTY[0]["auto_summon"] == 0.0 and Game.DIFFICULTY[2]["auto_summon"] > 0.0, "boss followers grow with difficulty")
	check(Game.DIFFICULTY[2]["stagger"] == 0 and Game.DIFFICULTY[0]["stagger"] > 0, "hard bosses never flinch, easy ones do")
	# maps: longer chapters, pre-boss checkpoint and clear-all barrier
	var prev_w := 0
	for ch in range(1, 13):
		var rows: Array = Maps.MAPS[ch]
		var w := 0
		var xs := {"X": -1, "k": -1, "G": -1, "K": -1}
		for r in rows:
			w = maxi(w, (r as String).length())
			for key in xs:
				var i := (r as String).find(key)
				if i >= 0: xs[key] = i
		check(w > prev_w, "chapter %d is longer than the one before (%d)" % [ch, w])
		prev_w = w
		check(xs["K"] > 0 and xs["X"] > xs["K"] and xs["k"] > xs["X"] and xs["G"] > xs["k"], "chapter %d: mid checkpoint, then barrier, then pre-boss checkpoint, then boss gate" % ch)
		var between := 0
		for r in rows:
			for x in range(xs["X"], xs["G"]):
				if x < (r as String).length() and (r as String)[x] in "TURJD": between += 1
		check(between == 0, "chapter %d has no fighters between the barrier and the boss" % ch)
	Game.unlocked = 2
	Game.chapter = 3; Game.coins = 12; Game.completed = []
	var before := Game.wallet
	Game.set("_changing", true)
	Game.chapter_complete()
	check(Game.wallet == before + 12 + 45, "first chapter 3 clear banks picked coins plus 45 reward")
	Game.difficulty = 2
	Game.chapter = 4; Game.coins = 0; Game.completed = []
	before = Game.wallet
	Game.chapter_complete()
	check(Game.wallet == before + 75, "hard difficulty pays 1.5x the clear reward (chapter 4: 75)")
	Game.difficulty = 0
	Game.upgrades = {"health": 0, "power": 0, "armor": 0, "boots": 0, "magnet": 0}
	Game.owned = ["stick"]; Game.loadout = ["stick", ""]; Game.equipped = "stick"
	Game.save_game()
	Game.set("_changing", false)
	print("EXPANSION failures=", failures)
	get_tree().quit(failures)
