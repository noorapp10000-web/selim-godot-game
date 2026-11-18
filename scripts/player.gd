extends CharacterBody2D
# Selim: run, jump + double jump, dash and a varied move set: a 5-hit ground chain mixing weapon swings
# with kicks (swing, swing, front kick, heavy swing, roundhouse), a dash slide-sweep, a rising uppercut
# right after take-off, a flying kick in the air and an overhead plunge smash that shakes the ground.

signal hp_changed(hp: int, max_hp: int)
signal died

const SPEED := 148.0
const ACCEL := 1900.0
const AIR_ACCEL := 1350.0
const FRICTION := 2300.0
const TURN_ACCEL := 3200.0
const GRAVITY := 950.0
const FALL_MUL := 1.18
const APEX_MUL := 0.62
const JUMP_V := -348.0
const DJUMP_V := -310.0
const MAX_FALL := 440.0
const DASH_SPEED := 330.0
const DASH_TIME := 0.18
const DASH_CD := 0.55
# dur/start/act = timings (s), dmg = base damage, w/h/y = hit box (world px, y up from the feet),
# w = reach in front of the body, matched to the drawn limb/weapon tip (+~5px grace) - v8 QA overlay.
# kb/lift = knockback given to enemies, weapon = swing that uses the weapon's damage/reach/tempo.
const MOVES := {
	"atk1": {"dur": 0.24, "start": 0.05, "act": 0.12, "dmg": 1, "w": 28.0, "h": 38.0, "y": 40.0, "kb": 150.0, "lift": -130.0, "weapon": true},
	"atk2": {"dur": 0.24, "start": 0.05, "act": 0.12, "dmg": 1, "w": 28.0, "h": 38.0, "y": 40.0, "kb": 160.0, "lift": -130.0, "weapon": true},
	"kick": {"dur": 0.27, "start": 0.07, "act": 0.11, "dmg": 1, "w": 29.0, "h": 30.0, "y": 34.0, "kb": 230.0, "lift": -120.0, "weapon": false, "lunge": 70.0},
	"atk3": {"dur": 0.34, "start": 0.12, "act": 0.12, "dmg": 2, "w": 36.0, "h": 38.0, "y": 40.0, "kb": 230.0, "lift": -150.0, "weapon": true, "lunge": 140.0},
	"rhkick": {"dur": 0.38, "start": 0.1, "act": 0.14, "dmg": 2, "w": 30.0, "h": 40.0, "y": 46.0, "kb": 330.0, "lift": -230.0, "weapon": false, "lunge": 90.0},
	"sweep": {"dur": 0.36, "start": 0.04, "act": 0.22, "dmg": 2, "w": 31.0, "h": 20.0, "y": 22.0, "kb": 110.0, "lift": -260.0, "weapon": false, "lunge": 270.0},
	"upper": {"dur": 0.36, "start": 0.03, "act": 0.17, "dmg": 2, "w": 22.0, "h": 58.0, "y": 60.0, "kb": 60.0, "lift": -390.0, "weapon": false},
	"fkick": {"dur": 0.42, "start": 0.02, "act": 0.34, "dmg": 2, "w": 31.0, "h": 32.0, "y": 38.0, "kb": 250.0, "lift": -160.0, "weapon": false, "air": true},
	"slam": {"dur": 1.4, "start": 0.0, "act": 1.4, "dmg": 3, "w": 30.0, "h": 40.0, "y": 40.0, "kb": 200.0, "lift": -300.0, "weapon": true, "air": true},
}
const COMBO := ["atk1", "atk2", "kick", "atk3", "rhkick"]

var level: Node = null
var max_hp := 10
var hp := 10
var facing := 1
var coyote := 0.0
var jump_buf := 0.0
var can_double := true
var dashing := 0.0
var dash_cd := 0.0
var attacking := false
var atk_index := 0
var move := "atk1"
var combo_i := -1
var air_used := 0
var air_t := 0.0
var since_dash := 9.0
var slam_phase := 0
var atk_timer := 0.0
var combo_window := 0.0
var queued_attack := false
var hurt_timer := 0.0
var invuln := 0.0
var dead := false
var control_locked := false
var hit_set := {}
var last_safe := Vector2.ZERO
var safe_timer := 0.0
var was_on_floor := true
var shake := 0.0
var look := 0.0
var afterimage_t := 0.0
var land_t := 0.0
var air_peak_vy := 0.0
var step_t := 0.0

var sprite: AnimatedSprite2D
var camera: Camera2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	add_to_group("player")
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(12, 28)
	cs.shape = rs
	cs.position = Vector2(0, -14)
	add_child(cs)
	max_hp = 10 + int(Game.upgrades["health"]) * 2
	hp = max_hp
	sprite = Game.char_sprite(self, "player" if Game.equipped == "stick" else "player_" + Game.equipped, Game.PLAYER_ANIMS, Game.PLAYER_GRID)
	sprite.play("idle")
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	get_parent().add_child.call_deferred(camera)
	_init_camera.call_deferred()
	last_safe = global_position

func _init_camera() -> void:
	camera.global_position = global_position + Vector2(0, -32)
	camera.make_current()
	camera.reset_smoothing()

func set_limits(l: int, t: int, r: int, b: int) -> void:
	camera.limit_left = l
	camera.limit_top = t
	camera.limit_right = r
	camera.limit_bottom = b

func center() -> Vector2:
	return global_position + Vector2(0, -19)

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-7, -36), Vector2(14, 36))

func _physics_process(delta: float) -> void:
	if dead:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		velocity.x = move_toward(velocity.x, 0, 200 * delta)
		move_and_slide()
		return
	if not control_locked:
		if Input.is_action_just_pressed("weapon") and not attacking and not Game.can_switch():
			if level != null and level.hud != null: level.hud.toast("جهّز سلاح تاني من الدكان عشان تبدّل")
		elif Input.is_action_just_pressed("weapon") and not attacking:
			Game.cycle_weapon()
			sprite.sprite_frames = Game.frames(Game.player_sheet(), Game.PLAYER_ANIMS, 8, 11)
			sprite.play("idle")
			sprite.modulate = Color(2.2, 2.0, 1.6)
			create_tween().tween_property(sprite, "modulate", Color(1, 1, 1), 0.25)
			Game.spawn_fx(get_parent(), "spark", center() + Vector2(facing * 8, 0), false, 1.2)
			if level != null and level.hud != null: level.hud.refresh(); level.hud.toast(str(Game.weapon_data()["name"]))
		if Input.is_action_just_pressed("potion"):
			use_item("potion")
			if level != null and level.hud != null: level.hud.refresh()
		if Input.is_action_just_pressed("bomb"):
			use_item("bomb")
			if level != null and level.hud != null: level.hud.refresh()
	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	var dir := 0.0
	if not control_locked:
		dir = Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	since_dash += delta
	if on_floor:
		coyote = 0.1
		can_double = true
		air_used = 0
		air_t = 0.0
	else:
		coyote -= delta
		air_t += delta
	if not control_locked and Input.is_action_just_pressed("jump"):
		jump_buf = 0.13
	else:
		jump_buf -= delta
	# dash
	if not control_locked and Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and hurt_timer <= 0.0:
		if dir != 0.0:
			facing = int(signf(dir))
		dashing = DASH_TIME
		dash_cd = DASH_CD / (1.0 + float(Game.upgrades["boots"]) * 0.08)
		attacking = false
		Audio.sfx("dash", 0.1)
		Game.spawn_fx(get_parent(), "dust", global_position + Vector2(-facing * 6, -6), facing < 0)
	if dashing > 0.0 and not control_locked and Input.is_action_just_pressed("attack"):
		dashing = 0.0
		_start_attack(true)
	if dashing > 0.0:
		since_dash = 0.0
		dashing -= delta
		velocity = Vector2(facing * DASH_SPEED, 0)
		afterimage_t -= delta
		if afterimage_t <= 0.0:
			afterimage_t = 0.04
			_afterimage()
		move_and_slide()
		_update_anim()
		_post_move(delta)
		return
	# attack
	if not control_locked and Input.is_action_just_pressed("attack"):
		if attacking:
			queued_attack = true
		else:
			_start_attack()
	if hurt_timer > 0.0:
		hurt_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 500 * delta)
		if dir != 0.0:
			facing = int(signf(dir))
	else:
		var target := dir * SPEED * (1.0 + float(Game.upgrades["boots"]) * 0.08)
		if attacking and on_floor:
			target *= 0.3
		if attacking and (move == "sweep" or move == "fkick" or move == "slam"):
			# slides and air moves carry their own momentum
			target = velocity.x
			if move == "sweep":
				velocity.x = move_toward(velocity.x, 0.0, 620.0 * delta)
				target = velocity.x
		var acc := ACCEL if on_floor else AIR_ACCEL
		if dir == 0.0 and on_floor:
			acc = FRICTION
		elif dir != 0.0 and signf(velocity.x) != signf(dir) and absf(velocity.x) > 10.0:
			acc = TURN_ACCEL if on_floor else AIR_ACCEL * 1.4
		velocity.x = move_toward(velocity.x, target, acc * delta)
		if dir != 0.0 and _can_turn():
			facing = int(signf(dir))
	var g := GRAVITY
	if velocity.y > 0.0:
		g *= FALL_MUL
	elif absf(velocity.y) < 70.0 and Input.is_action_pressed("jump"):
		g *= APEX_MUL
	velocity.y = minf(velocity.y + g * delta, MAX_FALL if not (attacking and move == "slam") else 620.0)
	if not on_floor:
		air_peak_vy = maxf(air_peak_vy, velocity.y)
	if jump_buf > 0.0 and hurt_timer <= 0.0:
		if coyote > 0.0:
			_jump(JUMP_V)
			coyote = 0.0
		elif can_double:
			can_double = false
			_jump(DJUMP_V)
			Game.spawn_fx(get_parent(), "dust", global_position, false, 1.3)
	if not control_locked and Input.is_action_just_released("jump") and velocity.y < -120.0:
		velocity.y *= 0.5
	move_and_slide()
	_process_attack(delta)
	_update_anim()
	_post_move(delta)

func _post_move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		Game.spawn_fx(get_parent(), "dust", global_position)
		if air_peak_vy > 260.0 and not attacking and dashing <= 0.0:
			land_t = 0.12
		air_peak_vy = 0.0
	land_t = maxf(0.0, land_t - delta)
	if on_floor and absf(velocity.x) > 100.0 and dashing <= 0.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.28
			Game.spawn_fx(get_parent(), "dust", global_position + Vector2(-facing * 4, 0), facing < 0, 0.6)
	was_on_floor = on_floor
	if on_floor and level != null:
		safe_timer += delta
		if safe_timer > 0.3 and level.is_ground(global_position + Vector2(-7, 4)) and level.is_ground(global_position + Vector2(7, 4)):
			last_safe = global_position
			safe_timer = 0.0
	if level != null and global_position.y > level.bottom_y() + 48:
		_fell()
	# camera look-ahead + shake
	look = lerpf(look, facing * 40.0, delta * 2.2)
	var off := Vector2(look, 0)
	if shake > 0.0:
		off += Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake = maxf(0.0, shake - delta * 18.0)
	camera.offset = off
	if camera.is_inside_tree():
		camera.global_position = global_position + Vector2(0, -32)

# QA overlay (autotest only): red = active attack area, green = body hit area
var debug_boxes := false
func _draw() -> void:
	if not debug_boxes:
		return
	var hr := hurt_rect()
	draw_rect(Rect2(hr.position - global_position, hr.size), Color(0.3, 1, 0.4, 0.9), false, 1.0)
	if attacking:
		var md: Dictionary = MOVES[move]
		var on := atk_timer >= float(md["start"]) and atk_timer <= float(md["start"]) + float(md["act"])
		var ar := attack_rect()
		draw_rect(Rect2(ar.position - global_position, ar.size), Color(1, 0.2, 0.2, 0.9 if on else 0.3), false, 1.0)

func _process(_d: float) -> void:
	if debug_boxes:
		queue_redraw()
	if invuln > 0.0 and not dead:
		sprite.visible = int(invuln * 18.0) % 2 == 0
	else:
		sprite.visible = true

func _jump(v: float) -> void:
	velocity.y = v
	jump_buf = 0.0
	Audio.sfx("jump", 0.05)

# Selim turns the instant the stick is pushed: while running, between hits, during an attack's
# wind-up and in the recovery after the active frames. Only slides / air dives (which carry their own
# momentum) and the active hit window keep the current facing so a swing never flips mid-hit.
func _can_turn() -> bool:
	if not attacking:
		return true
	if move in ["sweep", "fkick", "slam"]:
		return false
	var md: Dictionary = MOVES[move]
	var a0: float = md["start"]
	return atk_timer < a0 or atk_timer > a0 + float(md["act"])

func _start_attack(from_dash := false) -> void:
	if not control_locked and not from_dash:
		var d := Input.get_axis("move_left", "move_right")
		if d != 0.0:
			facing = int(signf(d))
	var on_floor := is_on_floor()
	var next := ""
	if from_dash or (on_floor and since_dash < 0.16):
		next = "sweep"
	elif not on_floor:
		if attacking and move != "fkick" and move != "upper":
			return
		if air_used == 0 and air_t < 0.22 and velocity.y < -120.0:
			next = "upper"
		elif air_used >= 1 and (move == "fkick" or move == "upper"):
			next = "slam"
		elif air_used == 0:
			next = "fkick"
		else:
			return
		air_used += 1
	else:
		combo_i = (combo_i + 1) % COMBO.size() if combo_window > 0.0 else 0
		next = COMBO[combo_i]
	move = next
	atk_index = 2 if move in ["atk3", "rhkick", "slam", "sweep", "upper"] else (0 if move == "atk1" else 1)
	attacking = true
	atk_timer = 0.0
	slam_phase = 0
	hit_set.clear()
	queued_attack = false
	var md: Dictionary = MOVES[move]
	sprite.play(move if sprite.sprite_frames.has_animation(move) else ["atk1", "atk2", "atk3"][atk_index])
	if bool(md["weapon"]):
		Audio.sfx(Game.weapon_sfx("swing"), 0.12)
	else:
		Audio.sfx("swing", 0.2, -2)
	if md.has("lunge"):
		velocity.x = facing * float(md["lunge"])
	match move:
		"upper":
			velocity.y = minf(velocity.y, -250.0)
			velocity.x = facing * 60.0
		"fkick":
			velocity.x = facing * 235.0
			velocity.y = minf(velocity.y, -60.0)
			_afterimage()
		"slam":
			velocity = Vector2(facing * 40.0, -150.0)
			sprite.pause()
		"sweep":
			Game.spawn_fx(get_parent(), "dust", global_position + Vector2(-facing * 6, -4), facing < 0, 1.2)

func _end_attack() -> void:
	attacking = false
	combo_window = 0.38
	if queued_attack:
		_start_attack()

func _process_attack(delta: float) -> void:
	if not attacking:
		combo_window -= delta
		return
	var md: Dictionary = MOVES[move]
	var tempo := float(Game.weapon_data()["tempo"]) if bool(md["weapon"]) and move != "slam" else 1.0
	atk_timer += delta * tempo
	if move == "slam":
		if slam_phase == 0:
			if atk_timer > 0.12:
				velocity.y = 560.0
				velocity.x = facing * 30.0
			_do_hits()
			if is_on_floor() and atk_timer > 0.14:
				_slam_impact()
			elif atk_timer > 1.4:
				_end_attack()
		elif atk_timer > 0.32:
			_end_attack()
		return
	if bool(md.get("air", false)) and is_on_floor() and atk_timer > 0.06:
		_end_attack()
		return
	if move == "fkick" and int(atk_timer * 30.0) % 3 == 0:
		_afterimage()
	var a0: float = md["start"]
	if atk_timer >= a0 and atk_timer <= a0 + float(md["act"]):
		_do_hits()
	if atk_timer >= float(md["dur"]):
		_end_attack()

func _slam_impact() -> void:
	slam_phase = 1
	atk_timer = 0.0
	sprite.play("slam")
	sprite.frame = 1
	shake = maxf(shake, 7.0)
	Audio.sfx("slam", 0.1)
	Game.spawn_fx(get_parent(), "dust", global_position + Vector2(-16, 0), true, 1.8)
	Game.spawn_fx(get_parent(), "dust", global_position + Vector2(16, 0), false, 1.8)
	Game.hitstop(0.06)
	# ground shockwave: hits everyone close on both sides
	var r := Rect2(global_position + Vector2(-58, -26), Vector2(116, 28))
	for n in get_tree().get_nodes_in_group("hittable"):
		if not is_instance_valid(n) or not n.has_method("hurt_rect") or hit_set.has(n):
			continue
		if r.intersects(n.hurt_rect()):
			hit_set[n] = true
			var d := 1 if n.global_position.x >= global_position.x else -1
			_hit(n, _move_damage() + 1, d, 210.0, -280.0)

func _move_damage() -> int:
	var md: Dictionary = MOVES[move]
	var wd := int(Game.weapon_data()["damage"])
	return int(md["dmg"]) + (wd if bool(md["weapon"]) else wd / 2) + int(Game.upgrades.get("power", 0))

func attack_rect() -> Rect2:
	var md: Dictionary = MOVES[move]
	var reach := float(Game.weapon_data()["reach"])
	var w: float = float(md["w"]) + (reach if bool(md["weapon"]) else reach * 0.25)
	var h: float = md["h"]
	var x := global_position.x + (2.0 if facing > 0 else -2.0 - w)
	if move == "slam":
		x = global_position.x - w / 2.0 + facing * 8.0
	return Rect2(Vector2(x, global_position.y - float(md["y"])), Vector2(w, h))

func _do_hits() -> void:
	var r := attack_rect()
	var md: Dictionary = MOVES[move]
	for n in get_tree().get_nodes_in_group("hittable"):
		if hit_set.has(n) or not is_instance_valid(n):
			continue
		if not n.has_method("hurt_rect"):
			continue
		if r.intersects(n.hurt_rect()):
			hit_set[n] = true
			_hit(n, _move_damage(), facing, float(md["kb"]), float(md["lift"]))
			if move == "fkick":
				# bounce off the target so the kick can chain into the plunge smash
				velocity = Vector2(-facing * 90.0, -170.0)

func _hit(n: Node, dmg: int, dir: int, kb: float, lift: float) -> void:
	if n.has_method("take_hit_ex"):
		n.take_hit_ex(dmg, dir, self, kb, lift)
	else:
		n.take_hit(dmg, dir, self)
	if n.is_in_group("enemy") or n.is_in_group("boss_fx"):
		var heavy := dmg >= 3 or move in ["rhkick", "upper", "slam", "atk3"]
		shake = maxf(shake, 4.0 if heavy else 2.5)
		Audio.sfx(Game.weapon_sfx("hit") if bool(MOVES[move]["weapon"]) else "hit", 0.15)
		Game.spawn_fx(get_parent(), "spark", n.hurt_rect().get_center() + Vector2(-dir * 4, 0), false, 1.4 if heavy else 1.0)
		Game.hitstop(0.07 if heavy else 0.04)

func hurt(amount: int, from_x: float) -> void:
	if dead or invuln > 0.0 or dashing > 0.0:
		return
	# scarab armour: each level gives a 15% chance to shrug the blow off
	if randf() < 0.15 * float(Game.upgrades.get("armor", 0)):
		invuln = 0.45
		Audio.sfx("clang", 0.1)
		Game.spawn_fx(get_parent(), "spark", center(), false, 1.5)
		sprite.modulate = Color(1.6, 1.8, 2.4)
		create_tween().tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)
		return
	hp -= amount
	hp_changed.emit(hp, max_hp)
	Audio.sfx("hurt")
	shake = 5.0
	Game.spawn_fx(get_parent(), "spark", center())
	if hp <= 0:
		_die()
		return
	invuln = 1.1
	hurt_timer = 0.3
	attacking = false
	var d := signf(global_position.x - from_x)
	if d == 0.0:
		d = -facing
	velocity = Vector2(d * 170.0, -210.0)

func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	hp_changed.emit(hp, max_hp)
	Audio.sfx("heal")

func _fell() -> void:
	hp -= 1
	hp_changed.emit(hp, max_hp)
	Audio.sfx("hurt")
	if hp <= 0:
		_die()
		global_position.y = level.bottom_y() + 40
		return
	global_position = last_safe + Vector2(0, -2)
	velocity = Vector2.ZERO
	invuln = 1.2
	shake = 4.0

func _die() -> void:
	if dead:
		return
	dead = true
	attacking = false
	sprite.play("die")
	sprite.visible = true
	velocity = Vector2(-facing * 90.0, -240.0)
	died.emit()

func _afterimage() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	g.flip_h = sprite.flip_h
	g.scale = sprite.scale
	g.offset = sprite.offset
	g.global_position = sprite.global_position
	g.modulate = Color(1.0, 0.6, 0.4, 0.55)
	g.z_index = -1
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)

func _update_anim() -> void:
	sprite.flip_h = facing < 0
	var a := "idle"
	if dead:
		a = "die"
	elif dashing > 0.0:
		a = "dash"
	elif hurt_timer > 0.0:
		a = "hurt"
	elif attacking:
		return
	elif not is_on_floor():
		a = "jump" if velocity.y < 0.0 else "fall"
	elif land_t > 0.0 and absf(velocity.x) < 60.0:
		a = "land"
	elif absf(velocity.x) > 12.0:
		a = "run"
	if a == "run":
		sprite.speed_scale = clampf(absf(velocity.x) / SPEED, 0.55, 1.15)
	else:
		sprite.speed_scale = 1.0
	if sprite.animation != a:
		sprite.play(a)

func use_item(id: String) -> void:
	if dead or control_locked or int(Game.inventory.get(id, 0)) <= 0:
		return
	if id == "potion" and hp >= max_hp:
		return
	Game.inventory[id] -= 1
	Game.save_game()
	if id == "potion":
		hp = mini(max_hp, hp + 6)
		hp_changed.emit(hp, max_hp)
		Audio.sfx("potion", 0.05)
		sprite.modulate = Color(1.6, 2.2, 1.6)
		create_tween().tween_property(sprite, "modulate", Color(1, 1, 1), 0.4)
		Game.spawn_fx(get_parent(), "spark", center() + Vector2(0, -10), false, 1.6)
	else:
		invuln = maxf(invuln, 1.5)
		shake = 6.0
		Audio.sfx("bomb_boom", 0.05)
		Game.spawn_fx(get_parent(), "dust", center(), false, 5.0)
		_smoke_cloud()
		for n in get_tree().get_nodes_in_group("hittable"):
			if is_instance_valid(n) and n.has_method("take_hit") and n.global_position.distance_to(global_position) < 110.0:
				n.take_hit(8, facing, self)

# Smoke-bomb cloud (proj2.png cell 6) that swells and fades around Selim.
func _smoke_cloud() -> void:
	for i in range(3):
		var c := Sprite2D.new()
		c.texture = load("res://assets/sprites/proj2.png")
		c.region_enabled = true
		c.region_rect = Rect2(6 * 48, 0, 48, 48)
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		c.position = global_position + Vector2((i - 1) * 26.0, -18.0 - (i % 2) * 8.0)
		c.scale = Vector2(0.5, 0.5)
		c.z_index = 18
		c.flip_h = i == 2
		get_parent().add_child(c)
		var tw := c.create_tween()
		tw.set_parallel(true)
		tw.tween_property(c, "scale", Vector2(1.9, 1.6), 0.9).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 0.0, 0.9).set_delay(0.25)
		tw.chain().tween_callback(c.queue_free)
