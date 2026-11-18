extends CharacterBody2D
# Street gang members. `kind` is the behaviour archetype (thug / thug2 club, thrower, knife, dog charger);
# `sheet` is the look (every chapter fields its own fighters, see Game.ROSTER).

const Projectile = preload("res://scripts/projectile.gd")
const Pickup = preload("res://scripts/pickup.gd")
const StoryData = preload("res://scripts/story_data.gd")
const GRAVITY := 950.0

var kind := "thug"
var sheet := "thug"
var chapter := 1
var level: Node = null
var hp := 3
var speed := 45.0
var chase_speed := 85.0
var attack_range := 26.0
var windup := 0.4
var recover := 0.55
var throw_cd := 1.0
var throw_every := 2.2
var facing := -1
var state := "patrol"
var state_t := 0.0
var noticed := false
var did_action := false
var contact_cd := 0.0
var is_minion := false
var sprite: AnimatedSprite2D
var w := 14.0
var h := 30.0
var max_hp := 3
var hp_bar_t := 0.0
var sight := 185.0
var ferocity := 0.0
var launched := false
var always_chase := false
var map_id := ""

func setup(k: String, ch: int) -> void:
	sheet = k
	kind = str(Game.ENEMY_TYPES.get(k, k))
	chapter = ch
	var bonus := (ch - 1) / 2
	match kind:
		"thug":
			hp = 3 + bonus; speed = 42.0; chase_speed = 82.0 + ch * 3; windup = 0.42 - ch * 0.02
		"thug2":
			hp = 4 + bonus; speed = 48.0; chase_speed = 92.0 + ch * 3; windup = 0.38 - ch * 0.02
		"thrower":
			hp = 2 + bonus; speed = 35.0; chase_speed = 50.0; throw_every = 2.3 - ch * 0.12
		"knife":
			hp = 4 + bonus; speed = 58.0; chase_speed = 112.0 + ch * 3; windup = 0.26; recover = 0.4; throw_every = 2.8 - ch * 0.1
		"dog":
			hp = 2 + bonus / 2; speed = 55.0; chase_speed = 175.0 + ch * 5; w = 22.0; h = 16.0

	# Look-specific flavour on top of the archetype.
	match sheet:
		"brute", "bodyguard":
			hp += 2; chase_speed *= 0.85; windup += 0.06
		"thief", "bandit":
			chase_speed *= 1.12
		"croc":
			hp += 2; chase_speed *= 0.62; w = 32.0; h = 14.0
		"scorpion":
			hp += 1; chase_speed *= 0.8; w = 24.0; h = 16.0
		"cultist", "charmer":
			throw_every *= 1.1
	windup = maxf(windup, 0.20)
	throw_every = maxf(throw_every, 0.85)
	recover = maxf(0.28, recover - ch * 0.012)
	# difficulty: tougher, faster, quicker to swing and to spot Selim
	var D: Dictionary = Game.diff()
	hp = int(ceil(hp * float(D["enemy_hp"])))
	speed *= float(D["enemy_spd"])
	chase_speed *= float(D["enemy_spd"])
	windup = maxf(0.14, windup * float(D["windup"]))
	recover = maxf(0.16, recover * float(D["recover"]))
	throw_every = maxf(0.6, throw_every * float(D["throw"]))
	sight = 185.0 * float(D["sight"])
	ferocity = float(D["ferocity"])

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemy")
	add_to_group("hittable")
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w - 2, h)
	cs.shape = rs
	cs.position = Vector2(0, -h / 2.0)
	add_child(cs)
	if kind == "dog":
		sprite = Game.char_sprite(self, sheet if Game.HIRES.has(sheet) else "dog", Game.DOG_ANIMS, Game.DOG_GRID)
	else:
		sprite = Game.char_sprite(self, sheet if Game.HIRES.has(sheet) else kind, Game.ENEMY_ANIMS, Game.ENEMY_GRID)
	sprite.play("idle")
	max_hp = hp
	facing = -1 if randf() < 0.7 else 1
	throw_cd = randf_range(0.6, 1.6)

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-w * Game.CHAR_SCALE / 2.0 - 2, -h * Game.CHAR_SCALE - 2), Vector2(w * Game.CHAR_SCALE + 4, h * Game.CHAR_SCALE + 2))

func _player() -> Node:
	if level == null:
		return null
	return level.player

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	did_action = false
	var atk := "stab" if kind == "knife" else "smash"
	match s:
		"windup":
			sprite.play(atk)
			sprite.frame = 0
			sprite.pause()
		"attack":
			sprite.play(atk)
			sprite.frame = 1
		"throw":
			sprite.play("throw")
		"bite":
			sprite.play("atk")

func _physics_process(delta: float) -> void:
	if state == "dead":
		velocity.y = minf(velocity.y + GRAVITY * delta, 450)
		velocity.x = move_toward(velocity.x, 0, 100 * delta)
		move_and_slide()
		return
	var p = _player()
	# far-away fighters sleep until Selim gets close (keeps big hard-mode crowds cheap)
	if p != null and not is_minion and not always_chase and state == "patrol" and is_on_floor() and absf(p.global_position.x - global_position.x) > 520.0:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, 450)
	state_t += delta
	throw_cd -= delta
	contact_cd -= delta
	var dx := 0.0
	var dy := 0.0
	var sees := false
	if p != null:
		dx = p.global_position.x - global_position.x
		dy = p.global_position.y - global_position.y
		sees = absf(dx) < sight and absf(dy) < 70.0 + ferocity * 30.0 and not p.dead
	var dist := absf(dx)
	match state:
		"patrol":
			velocity.x = facing * speed
			if _at_edge() or is_on_wall():
				facing = -facing
				velocity.x = facing * speed
			if sees or ((is_minion or always_chase) and p != null):
				_notice()
				_set_state("chase")
		"chase":
			if p == null or p.dead:
				_set_state("patrol")
			elif not sees and dist > 280.0 + ferocity * 200.0 and not is_minion and not always_chase:
				_set_state("patrol")
			else:
				_face(dx)
				if kind == "thrower":
					if dist < 70.0 and not _at_edge(-1):
						velocity.x = -facing * chase_speed
					else:
						velocity.x = 0.0
					if throw_cd <= 0.0 and dist < 240.0:
						_set_state("throw")
				elif kind == "dog":
					velocity.x = facing * chase_speed
					if dist < 18.0 and absf(dy) < 22.0:
						_set_state("bite")
				else:
					if dist > attack_range:
						velocity.x = facing * chase_speed
					else:
						velocity.x = 0.0
						_set_state("windup")
					if kind == "knife" and throw_cd <= 0.0 and dist > 90.0 and dist < 220.0 and absf(dy) < 30.0:
						_set_state("throw")
				if _at_edge() and kind != "dog":
					velocity.x = 0.0
				elif _at_edge() and kind == "dog":
					velocity.x = 0.0
		"windup":
			velocity.x = move_toward(velocity.x, 0, 700 * delta)
			sprite.modulate = Color(1.5, 1.2, 1.2) if int(state_t * 20) % 2 == 0 else Color(1, 1, 1)
			if state_t >= windup:
				sprite.modulate = Color(1, 1, 1)
				_set_state("attack")
				Audio.sfx("swing", 0.15, -4)
				if kind == "knife":
					velocity.x = facing * 120.0
		"attack":
			velocity.x = move_toward(velocity.x, 0, 500 * delta)
			if state_t > 0.08 and state_t < 0.22 and not did_action and p != null:
				var reach := 30.0 if kind != "knife" else 26.0
				var hx := global_position.x + facing * reach * 0.5
				if absf(p.global_position.x - hx) < reach * 0.5 + 8.0 and absf(dy) < 30.0:
					p.hurt(1, global_position.x)
					did_action = true
			if state_t > 0.34:
				# fierce fighters string a second blow straight after the first
				if not did_action and p != null and randf() < ferocity * 0.6 and absf(dx) < attack_range + 14.0:
					_face(dx)
					_set_state("windup")
					state_t = windup * 0.45
				else:
					_set_state("recover")
		"recover":
			velocity.x = 0.0
			if state_t > recover:
				_set_state("chase")
		"throw":
			velocity.x = 0.0
			if state_t >= 0.22 and not did_action and p != null:
				did_action = true
				_throw(p)
			if state_t > 0.5:
				throw_cd = throw_every + randf_range(-0.3, 0.5)
				_set_state("chase")
		"bite":
			velocity.x = facing * chase_speed * 0.6
			if not did_action and p != null and absf(dx) < 20.0 and absf(dy) < 24.0:
				did_action = true
				p.hurt(1, global_position.x)
			if state_t > 0.3:
				_set_state("recover_dog")
		"recover_dog":
			velocity.x = -facing * 60.0 if state_t < 0.25 else 0.0
			if state_t > 0.7:
				_set_state("chase")
		"hurt":
			velocity.x = move_toward(velocity.x, 0, (180.0 if launched else 500.0) * delta)
			if launched:
				if state_t > 0.25 and is_on_floor():
					launched = false
					Game.spawn_fx(level.entities if level != null else get_parent(), "dust", global_position, false, 1.2)
					_set_state("chase")
					state_t = -0.25
			elif state_t > 0.32 * (1.0 - ferocity * 0.35):
				_set_state("chase")
	move_and_slide()
	# boss followers stay on screen: ranged ones would otherwise back off and shoot from out of view
	if is_minion and level != null and level.player != null and level.player.camera != null:
		var cam: Camera2D = level.player.camera
		var half: float = get_viewport_rect().size.x / cam.zoom.x / 2.0
		var cx := cam.get_screen_center_position().x
		global_position.x = clampf(global_position.x, cx - half + 12.0, cx + half - 12.0)
	if level != null and global_position.y > level.bottom_y() + 60:
		# fell into a pit: counts as beaten, otherwise a checkpoint would bring it back
		if state != "dead" and level.has_method("on_enemy_killed"):
			level.on_enemy_killed(self)
		remove_from_group("enemy")
		queue_free()
	_anim()

func _at_edge(dir_mul := 1) -> bool:
	if level == null:
		return false
	var f := facing * dir_mul
	var probe := global_position + Vector2(f * (w / 2.0 + 4.0), 6)
	return not level.is_ground(probe) and is_on_floor()

func _face(dx: float) -> void:
	if absf(dx) > 4.0:
		facing = int(signf(dx))

func _notice() -> void:
	if noticed:
		return
	noticed = true
	if kind != "dog" and randf() < 0.5:
		_say(StoryData.TAUNTS[randi() % StoryData.TAUNTS.size()])

func _say(t: String) -> void:
	if Game.dialog_open:
		return
	Voice.play_bark("taunt", t)
	var b := Game.make_bubble(true)
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Game.font_body)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(1, 0.93, 0.76))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.z_index = 30
	add_child(b)
	b.reset_size()
	b.position = Vector2(-b.size.x / 2.0, -h * Game.CHAR_SCALE - 22.0 - b.size.y)
	# keep the taunt inside the camera view (below the HUD strip)
	if level != null and level.player != null and level.player.camera != null:
		var cam: Camera2D = level.player.camera
		var half: Vector2 = get_viewport_rect().size / cam.zoom / 2.0
		var c := cam.get_screen_center_position()
		var gx := clampf(global_position.x + b.position.x, c.x - half.x + 6.0, c.x + half.x - 6.0 - b.size.x)
		var gy := maxf(global_position.y + b.position.y, c.y - half.y + 34.0)
		b.position = Vector2(gx, gy) - global_position
	Game.bubble_tail(b, -b.position.x)
	b.pivot_offset = Vector2(b.size.x / 2.0, b.size.y)
	b.scale = Vector2(0.5, 0.5)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(b, "modulate:a", 0.0, 0.3)
	tw.tween_callback(b.queue_free)

func _throw(p: Node) -> void:
	var pr := Projectile.new()
	pr.level = level
	var origin := global_position + Vector2(facing * 10, -34)
	pr.position = origin
	if kind == "knife":
		pr.kind = "venom" if sheet == "viperman" else "knife"
		pr.vel = Vector2(facing * (200.0 if sheet == "viperman" else 230.0), 0)
		pr.position.y = global_position.y - 16
	else:
		match sheet:
			"charmer": pr.kind = "pot"
			"cultist": pr.kind = "fire"
			"slinger": pr.kind = "stone"
			_: pr.kind = "bottle" if randf() < 0.6 else "stone"
		var t := 0.85
		var tx: float = p.global_position.x - origin.x
		var ty: float = (p.global_position.y - 14) - origin.y
		pr.grav = 600.0
		pr.vel = Vector2(tx / t, (ty - 0.5 * 600.0 * t * t) / t)
		pr.vel.x = clampf(pr.vel.x, -220, 220)
	level.entities.add_child(pr)
	Audio.sfx("throw", 0.1, -3)

# Hits from Selim's move set: kb/lift decide how far the blow throws the fighter (uppercuts launch).
func take_hit_ex(dmg: int, dir: int, src: Node, kb: float, lift: float) -> void:
	take_hit(dmg, dir, src)
	if state == "dead":
		velocity = Vector2(dir * maxf(160.0, kb * 0.8), minf(-220.0, lift))
		return
	var heavy := 1.0 if kind != "dog" else 1.2
	velocity = Vector2(dir * kb * heavy, lift)
	if lift <= -250.0:
		launched = true
		sprite.play("hurt")

func take_hit(dmg: int, dir: int, _src: Node) -> void:
	if state == "dead":
		return
	hp -= dmg
	hp_bar_t = 2.5
	queue_redraw()
	sprite.modulate = Color(4, 4, 4)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	velocity = Vector2(dir * (150.0 if dmg < 2 else 230.0), -130.0)
	if not noticed:
		_notice()
	facing = -dir
	if hp <= 0:
		_die(dir)
	else:
		_set_state("hurt")

func _die(dir: int) -> void:
	_set_state("dead")
	remove_from_group("hittable")
	remove_from_group("enemy")
	if level != null and level.has_method("on_enemy_killed"):
		level.on_enemy_killed(self)
	Audio.sfx("enemy_die", 0.15)
	velocity = Vector2(dir * 160.0, -220.0)
	var coins := 1 + (1 if randf() < 0.5 else 0) + (1 if kind == "knife" else 0)
	for i in range(coins):
		level.spawn_pickup("coin", global_position + Vector2(randf_range(-6, 6), -14), Vector2(randf_range(-60, 60), randf_range(-200, -120)))
	# boss followers drop hearts more often so long hard boss fights stay winnable
	if randf() < (0.22 if is_minion else 0.07):
		level.spawn_pickup("heart", global_position + Vector2(0, -14), Vector2(0, -180))
	hp_bar_t = 0.0
	queue_redraw()
	if kind == "dog":
		sprite.play("hurt")
		var tw0 := create_tween()
		tw0.tween_property(sprite, "rotation", dir * 1.4, 0.3)
	else:
		sprite.play("die")
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	if hp_bar_t > 0.0:
		hp_bar_t -= delta
		if hp_bar_t <= 0.0:
			queue_redraw()

func _draw() -> void:
	if hp_bar_t <= 0.0 or state == "dead":
		return
	var bw := 18.0
	var y := -h * Game.CHAR_SCALE - 8.0
	draw_rect(Rect2(-bw / 2.0 - 1, y - 1, bw + 2, 4), Color(0.06, 0.02, 0.03, 0.9))
	draw_rect(Rect2(-bw / 2.0, y, bw * clampf(float(hp) / max_hp, 0, 1), 2), Color(0.95, 0.25, 0.2))
	draw_rect(Rect2(-bw / 2.0, y, bw * clampf(float(hp) / max_hp, 0, 1), 1), Color(1, 0.6, 0.45))

func _anim() -> void:
	if state == "dead":
		return
	sprite.flip_h = facing < 0
	if state in ["windup", "attack", "throw", "bite"]:
		return
	var a := "idle"
	if kind == "dog":
		match state:
			"chase", "patrol":
				a = "run" if absf(velocity.x) > 5.0 else "idle"
			"hurt", "dead":
				a = "hurt"
	else:
		match state:
			"patrol", "chase":
				a = "run" if absf(velocity.x) > 5.0 else "idle"
			"hurt":
				a = "hurt"
			"dead":
				a = "die"
	if sprite.animation != a or not sprite.is_playing():
		sprite.play(a)
