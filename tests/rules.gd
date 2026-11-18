extends Node
var failures := 0
func check(ok: bool, rule: String) -> void:
	if ok: print("PASS ", rule)
	else:
		failures += 1
		push_error("FAIL " + rule)
func _ready() -> void:
	Game.autotest = ""
	Game.chapter = 1
	Game.difficulty = 0
	Game.clear_checkpoint()
	Game.upgrades = {"health": 0, "power": 0, "armor": 0, "boots": 0, "magnet": 0}
	Game.force_touch = true
	var level = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(0.2).timeout
	var p = level.player
	p.control_locked = true
	check(p.max_hp == 10 and p.hp == 10, "five hearts contain ten half-heart units")
	p.invuln = 0
	p.dashing = 0
	p.hurt(1, p.position.x - 10)
	check(p.hp == 9, "one ordinary hit costs exactly half a heart")
	p.hurt(1, p.position.x - 10)
	check(p.hp == 9, "invulnerability prevents repeated contact damage")
	p.heal(2)
	check(p.hp == 10, "healing is capped at five hearts")
	p.hp = 6
	p.heal(2)
	check(p.hp == 8, "heart pickup restores one whole heart")
	var pad = level.hud.pad
	pad._press(0, "move_right")
	pad._press(1, "jump")
	check(Input.is_action_pressed("move_right") and Input.is_action_pressed("jump"), "running and jumping support simultaneous fingers")
	pad._release(1)
	check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"), "releasing jump preserves movement")
	pad.release_all()
	check(not Input.is_action_pressed("move_right"), "focus loss releases movement")
	check(is_equal_approx(p.sprite.scale.x, 1.3 / 4.0), "characters are drawn 30% bigger")
	check(p.hurt_rect().size.y >= 36.0, "player hit area matches the bigger body")
	check(ProjectSettings.get_setting("display/window/size/mode") == 3, "fullscreen configured")
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == 0, "landscape phone orientation configured")
	# v8 rules: hard bosses stay winnable, the hero turns instantly, speech bubbles hide behind dialogs
	var hard: Dictionary = Game.DIFFICULTY[2]
	check(int(hard["minion_cap"]) == 6 and is_equal_approx(float(hard["auto_summon"]), 7.0) and is_equal_approx(float(hard["boss_hp"]), 2.0), "hard bosses: at most 6 followers, a call every 7s, 2x health")
	p.attacking = true
	p.move = "atk1"
	p.atk_timer = 0.0
	check(p._can_turn(), "the hero can turn during an attack wind-up")
	p.atk_timer = float(p.MOVES["atk1"]["start"]) + 0.02
	check(not p._can_turn(), "the hero keeps facing during the active hit frames")
	p.attacking = false
	check(p._can_turn(), "the hero turns instantly while running")
	level.hud.dialog([["سليم", "تجربة"]], func(): pass)
	check(Game.dialog_open, "opening the main dialog marks it open (speech bubbles hide)")
	var guard := 0
	while level.hud.dialog_active and guard < 20:
		guard += 1
		level.hud._advance()
		await get_tree().create_timer(0.05).timeout
	check(not Game.dialog_open, "closing the dialog lets speech bubbles return")
	p.hp = 9
	level.hud.refresh()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/rules_half_heart.png")
	print("RULES failures=", failures)
	get_tree().quit(failures)
