extends Node
# Boss fight check on the chosen difficulty (default hard) with a simple fighting bot.
# Reports: time to win, damage taken (in half hearts) vs what the player can afford, peak followers,
# and any follower / projectile seen outside the camera view.
# usage: godot res://tests/BossCheck.tscn -- --chapters=1,6,12 --diff=2
const Projectile = preload("res://scripts/projectile.gd")
var chapters := [1, 4, 6, 8, 10, 12]
var diff := 2
var failures := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapters="):
			chapters = []
			for c in a.substr(11).split(","):
				chapters.append(int(c))
		if a.begins_with("--diff="):
			diff = int(a.substr(7))
	Engine.physics_ticks_per_second = 60
	for ch in chapters:
		await _fight(ch)
	print("BOSSCHECK failures=", failures)
	get_tree().quit(failures)

func _gear(ch: int) -> void:
	Game.autotest = ""
	Game.difficulty = diff
	Game.chapter = ch
	Game.clear_checkpoint()
	var w := ["stick", "saber", "saber", "spear", "spear", "spear", "hammer", "hammer", "hammer", "khopesh", "khopesh", "khopesh"]
	Game.owned = ["stick", w[ch - 1]]
	Game.equipped = w[ch - 1]
	Game.loadout = [w[ch - 1], "stick" if w[ch - 1] != "stick" else ""]
	var u := clampi((ch - 1) / 3, 0, 4)
	Game.upgrades = {"health": u, "power": u, "armor": mini(u, 3), "boots": mini(u, 2), "magnet": 0}
	Game.inventory = {"potion": 2, "bomb": 1}

func _fight(ch: int) -> void:
	_gear(ch)
	var level = load("res://scenes/Level.tscn").instantiate()
	add_child(level)
	await get_tree().create_timer(0.3).timeout
	var p = level.player
	p.global_position = Vector2(level.gate_x * level.T + 40.0, level.boss_pos.y - 4.0)
	await get_tree().create_timer(0.2).timeout
	if not level.boss_started:
		level._start_boss()
	await get_tree().create_timer(0.2).timeout
	var guard := 0
	while level.hud.dialog_active and guard < 200:
		guard += 1
		level.hud._advance()
		await get_tree().create_timer(0.03).timeout
	await get_tree().create_timer(0.4).timeout
	var boss = level.boss
	var budget: int = p.max_hp
	var taken := 0
	var hearts := 0
	var peak := 0
	var off_min := 0
	var off_proj := 0
	var t := 0.0
	var last_hp: int = p.hp
	var cool := 0.0
	while is_instance_valid(boss) and boss.hp > 0 and t < 240.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		cool -= dt
		if p.hp < last_hp:
			taken += last_hp - p.hp
		elif p.hp > last_hp:
			hearts += p.hp - last_hp
		p.hp = p.max_hp
		last_hp = p.hp
		var cam: Camera2D = p.camera
		var half: Vector2 = get_viewport().get_visible_rect().size / cam.zoom / 2.0
		var view := Rect2(cam.get_screen_center_position() - half, half * 2.0).grow(2.0)
		var mins := get_tree().get_nodes_in_group("minion")
		peak = maxi(peak, mins.size())
		for m in mins:
			if m.is_in_group("enemy") and absf(m.global_position.x - view.get_center().x) > view.size.x / 2.0 + 16.0 and m.state != "dead":
				off_min += 1
				if off_min < 4:
					print("  off follower ", m.kind, " ", m.global_position, " view ", view, " state ", m.state)
		for n in level.entities.get_children():
			if n is Projectile and absf(n.global_position.x - view.get_center().x) > view.size.x / 2.0 + 40.0:
				off_proj += 1
				if off_proj < 4:
					print("  off shot ", n.kind, " ", n.global_position, " vel ", n.vel, " view ", view)
		# bot: fight the nearest follower first, otherwise the boss
		var target = boss
		var bd := absf(boss.global_position.x - p.global_position.x)
		for m in mins:
			if m.is_in_group("enemy"):
				var d := absf(m.global_position.x - p.global_position.x)
				if d < bd - 30.0:
					bd = d
					target = m
		var dx: float = target.global_position.x - p.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("attack")
		Input.action_release("jump")
		Input.action_release("dash")
		if absf(dx) > 34.0:
			Input.action_press("move_right" if dx > 0 else "move_left")
		elif cool <= 0.0:
			if (dx > 0) != (p.facing > 0):
				Input.action_press("move_right" if dx > 0 else "move_left")
			Input.action_press("attack")
			cool = 0.16
		if boss.state == "attack" and absf(boss.global_position.x - p.global_position.x) < 50.0 and randf() < 0.03:
			Input.action_press("jump")
	for a in ["move_left", "move_right", "attack", "jump", "dash"]:
		Input.action_release(a)
	var won: bool = not is_instance_valid(boss) or boss.hp <= 0
	var afford := budget + hearts
	print("BOSS ch%d diff%d won=%s time=%.0fs taken=%d afford=%d (max %d + picked %d) peak_followers=%d offscreen_follower_frames=%d offscreen_shot_frames=%d boss_hp=%d" % [ch, diff, won, t, taken, afford, budget, hearts, peak, off_min, off_proj, boss.max_hp if is_instance_valid(boss) else 0])
	if not won:
		failures += 1
		push_error("FAIL boss %d not beaten in 240s" % ch)
	if off_proj > 0 or off_min > 30:
		failures += 1
		push_error("FAIL boss %d: things outside the camera" % ch)
	level.queue_free()
	await get_tree().create_timer(0.3).timeout
