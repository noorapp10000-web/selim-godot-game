extends CharacterBody2D
# Generic chapter boss driven by an attack list from Game.BOSSES.
# Chapters 7-12 add signature moves: decoy clones + smoke step (fox), sand burrow + venom (scorpion),
# anchor hook + rolling barrels (croc pirate), sun beams + homing scarabs (priest), grenades + shield guard
# (general), illusion casters + snake rain + dodge (viper).

signal health_changed(hp: int, max_hp: int)
signal defeated
signal raged

const Projectile = preload("res://scripts/projectile.gd")
const Decoy = preload("res://scripts/decoy.gd")
const Hazard = preload("res://scripts/hazard.gd")
const GRAVITY := 950.0

var id := 1
var cfg := {}
var level: Node = null
var hp := 20
var max_hp := 20
var speed := 70.0
var attacks: Array = []
var facing := -1
var state := "intro"
var state_t := 0.0
var current := ""
var last_attack := ""
var step := 0
var sub_t := 0.0
var enraged := false
var phase2 := false
var airborne := false
var contact_on := true
var sprite: AnimatedSprite2D
var fw := 80
var fh := 80
var bw := 26.0
var bh := 48.0
var arena_l := 0.0
var arena_r := 0.0
var idle_time := 1.0
var flash_t := 0.0
var invuln := 0.0
var dodge_cd := 1.5
var guarding := false
var hooked := false
var target_x := 0.0
# difficulty
var D: Dictionary = {}
var hit_dmg := 1
var summon_t := 0.0
var stagger_n := 0
var stagger_t := 0.0

func setup(boss_id: int) -> void:
	id = boss_id
	cfg = Game.BOSSES[boss_id]
	D = Game.diff()
	max_hp = int(round(float(cfg["hp"]) * float(D["boss_hp"])))
	hp = max_hp
	speed = float(cfg["speed"]) * float(D["boss_spd"])
	# the first two bosses hit for one heart-half even on hard: a fair warm-up before the full sting
	hit_dmg = mini(int(D["boss_dmg"]), 1) if boss_id <= 2 else int(D["boss_dmg"])
	attacks = _with_extras((cfg["attacks"] as Array).duplicate())

# Medium / hard bosses also leap around the arena and call their gang in.
func _with_extras(list: Array) -> Array:
	if bool(D.get("leap", false)):
		if "summon" not in list:
			list.append("summon")
		list.append("leap")
	return list

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemy")
	add_to_group("hittable")
	add_to_group("boss")
	sprite = Game.char_sprite(self, cfg["sheet"], Game.ENEMY_ANIMS, Game.ENEMY_GRID)
	fw = int(sprite.sprite_frames.get_meta("ww"))
	fh = int(sprite.sprite_frames.get_meta("wh"))
	sprite.play("idle")
	bw = fw * 0.3
	bh = fh * 0.62
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(bw, bh)
	cs.shape = rs
	cs.position = Vector2(0, -bh / 2.0)
	add_child(cs)
	# Attacks and hit areas follow the bigger drawn body; physics body stays the same.
	bw *= Game.CHAR_SCALE
	bh *= Game.CHAR_SCALE
	idle_time = (1.1 - id * 0.05) * float(D["boss_idle"])

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-bw / 2.0 - 4, -bh - 4), Vector2(bw + 8, bh + 4))

func activate() -> void:
	_go("idle")
	Audio.sfx("roar")

func _go(s: String) -> void:
	state = s
	state_t = 0.0
	step = 0
	sub_t = 0.0

func _p() -> Node:
	return level.player if level != null else null

func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 520)
	state_t += delta
	if current != "burrow" or state != "attack":
		invuln = maxf(0.0, invuln - delta)
	dodge_cd -= delta
	var p = _p()
	if state == "dead":
		velocity.x = 0
		move_and_slide()
		return
	if state == "intro" or p == null:
		move_and_slide()
		_anim("idle")
		return
	stagger_t -= delta
	if stagger_t <= 0.0:
		stagger_n = 0
	if float(D["auto_summon"]) > 0.0:
		summon_t += delta * (1.4 if enraged else 1.0)
		if summon_t >= float(D["auto_summon"]):
			summon_t = 0.0
			_call_minions(1 + (1 if enraged else 0))
	var dx: float = p.global_position.x - global_position.x
	match state:
		"idle":
			_face(dx)
			var want := 0.0
			if bool(D.get("leap", false)):
				# restless: presses in from afar, backs off when Selim is in his face
				if absf(dx) > 64.0:
					want = facing * speed * 0.95
				elif absf(dx) < 40.0:
					want = -facing * speed * 0.55
			elif absf(dx) > 70.0:
				want = facing * speed * 0.6
			velocity.x = move_toward(velocity.x, want, 400 * delta)
			_anim("run" if absf(velocity.x) > 5 else "idle")
			if state_t > idle_time:
				_choose()
		"roar":
			velocity.x = 0
			_anim("cast")
			if state_t > 1.3:
				_go("idle")
		"stunned":
			velocity.x = move_toward(velocity.x, 0, 600 * delta)
			_anim("hurt")
			if state_t > 1.0:
				_go("idle")
		"attack":
			_run_attack(delta, p, dx)
	move_and_slide()
	# contact damage
	if contact_on and p != null and not p.dead:
		var pr: Rect2 = p.hurt_rect()
		if pr.intersects(Rect2(global_position + Vector2(-bw / 2.0 + 2, -bh + 4), Vector2(bw - 4, bh - 4))):
			p.hurt(hit_dmg, global_position.x)
	global_position.x = clampf(global_position.x, arena_l + 20, arena_r - 20)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			sprite.modulate = _base_mod()

func _base_mod() -> Color:
	return Color(1.25, 0.8, 0.8) if enraged else Color(1, 1, 1)

func _face(dx: float) -> void:
	if absf(dx) > 6:
		facing = int(signf(dx))
	sprite.flip_h = facing < 0

func _anim(a: String) -> void:
	sprite.flip_h = facing < 0
	if sprite.animation != a:
		sprite.play(a)

func _choose() -> void:
	var opts := attacks.duplicate()
	if opts.size() > 1:
		opts.erase(last_attack)
	current = opts[randi() % opts.size()]
	if current == "summon" and get_tree().get_nodes_in_group("minion").size() >= int(D["minion_cap"]):
		current = "melee"
	last_attack = current
	_go("attack")

func _run_attack(delta: float, p: Node, dx: float) -> void:
	var spd_mul := 1.25 if enraged else 1.0
	match current:
		"melee":
			if step == 0:
				_face(dx)
				velocity.x = facing * speed * 1.2 * spd_mul
				_anim("run")
				if absf(dx) < 44.0 or state_t > 1.6:
					step = 1; sub_t = 0.0
					velocity.x = 0
					sprite.play("smash"); sprite.frame = 0; sprite.pause()
			elif step == 1:
				sub_t += delta
				velocity.x = 0
				_blink(sub_t)
				if sub_t > 0.45 / spd_mul:
					step = 2; sub_t = 0.0
					sprite.modulate = _base_mod()
					sprite.frame = 1; sprite.play("smash")
					Audio.sfx("swing", 0.1)
					velocity.x = facing * 90.0
			elif step == 2:
				sub_t += delta
				velocity.x = move_toward(velocity.x, 0, 400 * delta)
				if sub_t > 0.08 and sub_t < 0.25:
					var reach := fw * 0.5
					var x0 := global_position.x if facing > 0 else global_position.x - reach
					var r := Rect2(Vector2(x0, global_position.y - bh), Vector2(reach, bh))
					if p.hurt_rect().intersects(r):
						p.hurt(hit_dmg, global_position.x)
				if sub_t > 0.65 / spd_mul:
					_end_attack()
		"charge":
			if step == 0:
				_face(dx)
				velocity.x = 0
				_anim("run")
				sprite.speed_scale = 2.0
				_blink(state_t)
				if state_t > 0.65 / spd_mul:
					step = 1; sub_t = 0.0
					sprite.modulate = _base_mod()
					Audio.sfx("roar", 0.1, -6)
			elif step == 1:
				sub_t += delta
				velocity.x = facing * 285.0 * spd_mul
				if sub_t > 0.05 and (is_on_wall() or global_position.x <= arena_l + 22 or global_position.x >= arena_r - 22):
					sprite.speed_scale = 1.0
					level.shake(6.0)
					Audio.sfx("slam")
					Game.spawn_fx(level.entities, "dust", global_position + Vector2(facing * 14, 0), false, 2.0)
					velocity.x = -facing * 120.0
					_go("stunned")
					return
				if sub_t > 1.6:
					sprite.speed_scale = 1.0
					_end_attack()
		"slam":
			if step == 0:
				_face(dx)
				velocity.x = 0
				_anim("jump")
				if state_t > 0.3:
					step = 1; sub_t = 0.0
					velocity.y = -430.0
					var t := 0.9
					velocity.x = clampf(dx / t, -280, 280)
					airborne = true
			elif step == 1:
				sub_t += delta
				_anim("jump")
				if sub_t > 0.15 and is_on_floor():
					step = 2; sub_t = 0.0
					velocity.x = 0
					level.shake(7.0)
					Audio.sfx("slam")
					Game.spawn_fx(level.entities, "dust", global_position, false, 2.5)
					var n := 2 if not enraged else 3
					for i in range(n):
						_wave(-1, 150.0 + i * 50.0)
						_wave(1, 150.0 + i * 50.0)
			elif step == 2:
				sub_t += delta
				_anim("idle")
				if sub_t > 0.6 / spd_mul:
					_end_attack()
		"throw":
			_face(dx)
			velocity.x = 0
			if step < (3 if not enraged else 5):
				sub_t += delta
				if sub_t > 0.42 / spd_mul:
					sub_t = 0.0
					sprite.play("throw")
					_arc(p, 0.7 + step * 0.18)
					step += 1
			elif state_t > 2.4:
				_end_attack()
		"knives":
			_face(dx)
			velocity.x = 0
			var count := 4 if not enraged else 6
			if step < count:
				sub_t += delta
				if sub_t > 0.36 / spd_mul:
					sub_t = 0.0
					sprite.play("stab")
					var high := (step % 2 == 1) and randf() < 0.6
					_straight("knife" if cfg["proj"] != "fire" else "fire", 230.0 * spd_mul, -46.0 if high else -14.0)
					step += 1
			elif state_t > count * 0.4 + 0.6:
				_end_attack()
		"snakes":
			_face(dx)
			velocity.x = 0
			_anim("cast")
			if step == 0 and state_t > 0.5:
				step = 1
				Audio.sfx("throw")
				var n := 2 if not enraged else 3
				for i in range(n):
					var pr := _spawn_proj("snake", global_position + Vector2(facing * (14 + i * 18), -6))
					pr.vel = Vector2(facing * (95.0 + i * 25.0), 0)
					pr.life = 5.0
			if state_t > 1.4:
				_end_attack()
		"fireball":
			_face(dx)
			velocity.x = 0
			_anim("cast")
			if step == 0 and state_t > 0.55:
				step = 1
				Audio.sfx("throw")
				var n := 5 if not enraged else 7
				var c: float = (p.center() - (global_position + Vector2(0, -bh * 0.8))).angle()
				for i in range(n):
					var a: float = c + deg_to_rad(-30.0 + 60.0 * i / float(n - 1))
					var pr := _spawn_proj(str(cfg.get("orb", "fire")), global_position + Vector2(facing * 10, -bh * 0.8))
					pr.vel = Vector2.from_angle(a) * 150.0
			if state_t > 1.5:
				_end_attack()
		"leap":
			if step == 0:
				velocity.x = 0
				_face(dx)
				_anim("jump")
				if state_t > 0.2 / spd_mul:
					step = 1; sub_t = 0.0
					var tx := clampf(p.global_position.x + facing * 110.0, arena_l + 30.0, arena_r - 30.0)
					velocity.y = -470.0
					velocity.x = clampf((tx - global_position.x) / 0.95, -340.0, 340.0)
					airborne = true
					Audio.sfx("dodge", 0.1)
			elif step == 1:
				sub_t += delta
				_anim("jump")
				if sub_t > 0.15 and is_on_floor():
					airborne = false
					velocity.x = 0
					level.shake(4.0)
					Game.spawn_fx(level.entities, "dust", global_position, false, 2.0)
					_face(p.global_position.x - global_position.x)
					# lands straight into the next blow
					current = "melee" if randf() < 0.6 else "charge"
					last_attack = current
					_go("attack")
					return
				if sub_t > 2.0:
					airborne = false
					_end_attack()
		"summon":
			velocity.x = 0
			_anim("cast")
			if step == 0 and state_t > 0.4:
				step = 1
				Audio.sfx("roar")
				_call_minions(int(D["summon"]))
			if state_t > 1.3:
				_end_attack()
		"teleport":
			velocity.x = 0
			if step == 0:
				contact_on = false
				sprite.modulate.a = maxf(0.0, 1.0 - state_t / 0.3)
				if state_t > 0.35:
					step = 1
					var side: float = -p.facing
					var nx: float = p.global_position.x + side * 52.0
					if nx < arena_l + 30 or nx > arena_r - 30:
						nx = p.global_position.x - side * 52.0
					global_position.x = clampf(nx, arena_l + 30, arena_r - 30)
					_face(p.global_position.x - global_position.x)
			elif step == 1:
				sprite.modulate.a = minf(1.0, (state_t - 0.35) / 0.2)
				if state_t > 0.55:
					sprite.modulate = _base_mod()
					contact_on = true
					current = "melee"
					step = 1
					sub_t = 0.15
					sprite.play("smash"); sprite.frame = 0; sprite.pause()
		"smoke_tp":
			velocity.x = 0
			if step == 0:
				if state_t < 0.02:
					_smoke(global_position)
					Audio.sfx("teleport", 0.1)
				contact_on = false
				invuln = 0.3
				sprite.modulate.a = maxf(0.0, 1.0 - state_t / 0.2)
				if state_t > 0.75:
					step = 1
					var side: float = -p.facing
					var nx: float = p.global_position.x + side * 50.0
					if nx < arena_l + 30 or nx > arena_r - 30:
						nx = p.global_position.x - side * 50.0
					global_position.x = clampf(nx, arena_l + 30, arena_r - 30)
					_face(p.global_position.x - global_position.x)
					_smoke(global_position)
			elif step == 1:
				sprite.modulate.a = minf(1.0, (state_t - 0.75) / 0.15)
				if state_t > 0.92:
					sprite.modulate = _base_mod()
					contact_on = true
					current = "melee"
					step = 1
					sub_t = 0.1
					sprite.play("smash"); sprite.frame = 0; sprite.pause()
		"decoy":
			velocity.x = 0
			_face(dx)
			_anim("cast")
			if step == 0 and state_t > 0.4:
				step = 1
				Audio.sfx("teleport", 0.1)
				var n := 2 if not enraged else 3
				for i in range(n):
					var off := (i - (n - 1) / 2.0) * 34.0
					_decoy("runner", global_position + Vector2(off - facing * 10.0, 0), facing, 150.0 + i * 22.0, 2.4)
			if state_t > 1.1:
				_end_attack()
		"burrow":
			if step == 0:
				velocity.x = 0
				_anim("jump")
				if state_t > 0.3:
					step = 1; sub_t = 0.0
					contact_on = false
					invuln = 9.0
					Audio.sfx("burrow", 0.1)
					Game.spawn_fx(level.entities, "dust", global_position, false, 2.5)
					var tw := create_tween()
					tw.tween_property(sprite, "modulate:a", 0.0, 0.2)
			elif step == 1:
				sub_t += delta
				var want: float = p.global_position.x
				global_position.x = move_toward(global_position.x, want, (210.0 if not enraged else 260.0) * delta)
				if int(sub_t * 9.0) != int((sub_t - delta) * 9.0):
					Game.spawn_fx(level.entities, "dust", global_position, false, 1.2)
				if sub_t > 1.1 or absf(global_position.x - want) < 6.0:
					step = 2; sub_t = 0.0
					target_x = global_position.x
			elif step == 2:
				sub_t += delta
				velocity.x = 0
				if int(sub_t * 12.0) != int((sub_t - delta) * 12.0):
					Game.spawn_fx(level.entities, "dust", Vector2(target_x + randf_range(-10, 10), global_position.y), false, 1.4)
				if sub_t > 0.5:
					step = 3; sub_t = 0.0
					invuln = 0.0
					contact_on = true
					sprite.modulate = _base_mod()
					velocity.y = -360.0
					level.shake(5.0)
					Audio.sfx("slam")
					Game.spawn_fx(level.entities, "dust", global_position, false, 3.0)
					if absf(p.global_position.x - target_x) < 30.0 and absf(p.global_position.y - global_position.y) < 40.0:
						p.hurt(hit_dmg, target_x)
			elif step == 3:
				sub_t += delta
				_anim("jump")
				if sub_t > 0.25 and is_on_floor():
					_end_attack()
		"venom":
			_face(dx)
			velocity.x = 0
			var nv := 2 if not enraged else 3
			if step < nv:
				sub_t += delta
				if sub_t > 0.45 / spd_mul:
					sub_t = 0.0
					sprite.play("throw")
					_lob("venom", p.global_position.x + (step - (nv - 1) / 2.0) * 34.0, 0.75)
					Audio.sfx("poison", 0.1)
					step += 1
			elif state_t > nv * 0.45 + 0.7:
				_end_attack()
		"sandrain":
			velocity.x = 0
			_anim("cast")
			if step == 0 and state_t > 0.35:
				step = 1
				sub_t = 0.0
				Audio.sfx("burrow", 0.05)
				if level.has_method("storm"):
					level.storm(3.0)
			elif step >= 1 and step < 9:
				sub_t += delta
				if sub_t > 0.3:
					sub_t = 0.0
					step += 1
					var x := clampf(p.global_position.x + randf_range(-90, 90), arena_l + 20, arena_r - 20)
					var pr := _spawn_proj("stone", Vector2(x, global_position.y - 250))
					pr.grav = 420.0
					pr.vel = Vector2(randf_range(-20, 20), 40)
			elif state_t > 3.2:
				_end_attack()
		"hook":
			if step == 0:
				_face(dx)
			velocity.x = 0
			if step == 0:
				sprite.play("throw"); sprite.frame = 0; sprite.pause()
				_blink(state_t)
				if state_t > 0.5 / spd_mul:
					step = 1
					hooked = false
					sprite.modulate = _base_mod()
					sprite.play("throw")
					var pr := _spawn_proj("anchor", global_position + Vector2(facing * 18, -22))
					pr.vel = Vector2(facing * 270.0, 0)
					pr.life = 1.4
					pr.puller = self
					pr.sprite.flip_h = facing < 0
					Audio.sfx("chain", 0.1)
			elif state_t > 1.4:
				_end_attack()
		"barrels":
			_face(dx)
			velocity.x = 0
			var nb := 2 if not enraged else 3
			if step < nb:
				sub_t += delta
				if sub_t > 0.55 / spd_mul:
					sub_t = 0.0
					sprite.play("throw")
					var pr := _spawn_proj("barrel", global_position + Vector2(facing * 22, -11))
					pr.vel = Vector2(facing * (120.0 + step * 20.0), 0)
					pr.life = 6.0
					Audio.sfx("throw", 0.1)
					step += 1
			elif state_t > nb * 0.55 + 0.6:
				_end_attack()
		"beams":
			velocity.x = 0
			_anim("cast")
			if step == 0 and state_t > 0.3:
				step = 1
				var xs := [p.global_position.x, p.global_position.x - 64.0, p.global_position.x + 64.0]
				if enraged:
					xs.append(p.global_position.x - 128.0)
					xs.append(p.global_position.x + 128.0)
				for i in range(xs.size()):
					var hz := Hazard.new()
					hz.level = level
					hz.kind = "beam"
					hz.warn = 0.75 + i * 0.12
					hz.position = Vector2(clampf(xs[i], arena_l + 12, arena_r - 12), global_position.y)
					level.entities.add_child(hz)
				Audio.sfx("beam", 0.1, -8)
			if state_t > 1.9:
				_end_attack()
		"scarabs":
			velocity.x = 0
			_anim("cast")
			if step == 0 and state_t > 0.45:
				step = 1
				var alive := 0
				for n in get_tree().get_nodes_in_group("hittable"):
					if n is Projectile and n.kind == "scarab":
						alive += 1
				var ns := (3 if not enraged else 4) - alive / 2
				for i in range(maxi(ns, 1)):
					var pr := _spawn_proj("scarab", global_position + Vector2(randf_range(-20, 20), -bh * 0.9))
					pr.vel = Vector2(randf_range(-90, 90), randf_range(-120, -60))
					pr.homing = 1.6
					pr.life = 4.5
				Audio.sfx("scarab", 0.1)
			if state_t > 1.3:
				_end_attack()
		"grenades":
			_face(dx)
			velocity.x = 0
			var ng := 2 if not enraged else 3
			if step < ng:
				sub_t += delta
				if sub_t > 0.5 / spd_mul:
					sub_t = 0.0
					sprite.play("throw")
					_lob("grenade", p.global_position.x + p.velocity.x * 0.25 + (step - (ng - 1) / 2.0) * 40.0, 0.8)
					step += 1
			elif state_t > ng * 0.5 + 1.2:
				_end_attack()
		"shield":
			if step == 0:
				if not guarding:
					guarding = true
					Audio.sfx("clang", 0.05, -6)
					queue_redraw()
				_face(dx)
				velocity.x = facing * speed * 0.4
				_anim("run" if absf(dx) > 30.0 else "idle")
				if state_t > 1.7:
					step = 1; sub_t = 0.0
					guarding = false
					queue_redraw()
					Audio.sfx("roar", 0.1, -6)
			elif step == 1:
				sub_t += delta
				_anim("run")
				sprite.speed_scale = 2.0
				velocity.x = facing * 300.0 * spd_mul
				if sub_t > 0.4 or is_on_wall():
					sprite.speed_scale = 1.0
					_end_attack()
		"illusion":
			velocity.x = 0
			if step == 0:
				contact_on = false
				invuln = 0.3
				sprite.modulate.a = maxf(0.0, 1.0 - state_t / 0.25)
				if state_t > 0.35:
					step = 1
					Audio.sfx("teleport", 0.1)
					var xs := [p.global_position.x - 110.0, p.global_position.x + 110.0, clampf(p.global_position.x + (180.0 if p.global_position.x < (arena_l + arena_r) / 2.0 else -180.0), arena_l + 30, arena_r - 30)]
					for i in range(xs.size()):
						xs[i] = clampf(xs[i], arena_l + 30, arena_r - 30)
					var real := randi() % xs.size()
					for i in range(xs.size()):
						if i == real:
							global_position.x = xs[i]
						else:
							_decoy("caster", Vector2(xs[i], global_position.y), facing, 0.0, 3.2)
					_face(p.global_position.x - global_position.x)
			elif step == 1:
				sprite.modulate.a = minf(1.0, (state_t - 0.35) / 0.2)
				_face(dx)
				_anim("cast")
				if state_t > 0.6:
					sprite.modulate = _base_mod()
					contact_on = true
					step = 2; sub_t = 0.0
			elif step >= 2 and step < 4:
				_face(dx)
				sub_t += delta
				if sub_t > 0.55:
					sub_t = 0.0
					sprite.play("throw")
					var pr := _spawn_proj("venom", global_position + Vector2(facing * 14, -bh * 0.6))
					pr.vel = Vector2(facing * 160.0, -60.0)
					pr.grav = 260.0
					Audio.sfx("poison", 0.1)
					step += 1
			elif state_t > 2.6:
				_end_attack()
		"snakerain":
			velocity.x = 0
			_anim("cast")
			if step == 0 and state_t > 0.4:
				step = 1
				Audio.sfx("hiss", 0.1)
				var n := 4 if not enraged else 5
				for i in range(n):
					var x := clampf(p.global_position.x + (i - (n - 1) / 2.0) * 46.0 + randf_range(-10, 10), arena_l + 20, arena_r - 20)
					var pr := _spawn_proj("snake", Vector2(x, global_position.y - 240 - i * 30))
					pr.drop = true
					pr.crawl = false
					pr.grav = 520.0
					pr.life = 6.0
			if state_t > 2.0:
				_end_attack()

func _call_minions(n: int) -> void:
	# early chapters keep a smaller gang even on hard, so the first bosses stay a fair duel
	var cap := mini(int(D["minion_cap"]), 3 + id / 3) if Game.difficulty == 2 else int(D["minion_cap"])
	var mins: Array = cfg["minions"]
	for i in range(n):
		if get_tree().get_nodes_in_group("minion").size() >= cap:
			return
		# followers always appear inside the camera view (and inside the arena), never off-screen
		var v := _view()
		var lo := maxf(arena_l + 40.0, v.position.x + 40.0)
		var hi := minf(arena_r - 40.0, v.end.x - 40.0)
		if hi < lo:
			hi = lo
		var x := randf_range(lo, hi)
		var pl = _p()
		if pl != null and absf(x - pl.global_position.x) < 40.0:
			x = clampf(x + (60.0 if x < (lo + hi) / 2.0 else -60.0), lo, hi)
		var mk: String = mins[randi() % mins.size()]
		var ros: Dictionary = Game.ROSTER.get(id, {})
		for L in ros:
			if str(level.ENEMY_KEYS.get(L, "")) == mk:
				mk = ros[L]
				break
		level.spawn_enemy(mk, Vector2(x, maxf(global_position.y - 120.0, v.position.y + 28.0)), true)
		_smoke(Vector2(x, global_position.y - 20))

func _blink(t: float) -> void:
	sprite.modulate = Color(2.0, 1.6, 1.6) if int(t * 14) % 2 == 0 else _base_mod()

func on_hooked() -> void:
	# anchor landed: reel the player in and swing right away
	if state == "attack" and current == "hook" and not hooked:
		hooked = true
		current = "melee"
		step = 1
		sub_t = 0.12
		sprite.play("smash"); sprite.frame = 0; sprite.pause()

func _lob(kind: String, tx: float, t: float) -> void:
	var origin := global_position + Vector2(facing * 12, -bh * 0.85)
	var pr := _spawn_proj(kind, origin)
	tx = clampf(tx, arena_l + 16, arena_r - 16)
	var ty: float = global_position.y - 4.0 - origin.y
	pr.grav = 600.0
	pr.vel = Vector2(clampf((tx - origin.x) / t, -280, 280), (ty - 0.5 * 600.0 * t * t) / t)
	pr.life = 3.0
	Audio.sfx("throw", 0.1)

func _decoy(mode: String, pos: Vector2, dir: int, spd: float, life: float) -> void:
	var d := Decoy.new()
	d.level = level
	d.boss = self
	d.sheet = cfg["sheet"]
	d.mode = mode
	d.dir = dir
	d.speed = spd
	d.life = life
	d.position = Vector2(clampf(pos.x, arena_l + 20, arena_r - 20), pos.y)
	level.entities.add_child(d)
	_smoke(d.position)

func _smoke(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/proj2.png")
	s.region_enabled = true
	s.region_rect = Rect2(6 * 48, 0, 48, 48)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = pos + Vector2(0, -22)
	s.scale = Vector2(0.6, 0.6)
	s.z_index = 16
	level.entities.add_child(s)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2(1.5, 1.3), 0.6)
	tw.tween_property(s, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(s.queue_free)

func _draw() -> void:
	if guarding:
		var c := Vector2(facing * (bw * 0.45), -bh * 0.5)
		var a0 := -PI / 2.0 if facing > 0 else PI / 2.0
		draw_arc(c, bh * 0.42, a0, a0 + PI, 16, Color(0.55, 0.8, 1.0, 0.75), 3.0)
		draw_arc(c, bh * 0.36, a0 + 0.3, a0 + PI - 0.3, 12, Color(0.85, 0.95, 1.0, 0.5), 2.0)

func _end_attack() -> void:
	guarding = false
	queue_redraw()
	sprite.speed_scale = 1.0
	sprite.modulate = _base_mod()
	contact_on = true
	_go("idle")
	idle_time = (1.0 - id * 0.06) * (0.6 if enraged else 1.0) * float(D["boss_idle"])

# World rect the camera currently shows.
func _view() -> Rect2:
	var p = _p()
	if p == null or p.camera == null:
		return Rect2(arena_l, global_position.y - 400.0, arena_r - arena_l, 800.0)
	var cam: Camera2D = p.camera
	var half: Vector2 = get_viewport_rect().size / cam.zoom / 2.0
	return Rect2(cam.get_screen_center_position() - half, half * 2.0)

func _spawn_proj(kind: String, pos: Vector2) -> Node:
	# every boss projectile starts on screen: rain / drops enter right at the top edge
	var v := _view()
	pos.x = clampf(pos.x, v.position.x + 8.0, v.end.x - 8.0)
	pos.y = maxf(pos.y, v.position.y - 6.0)
	var pr := Projectile.new()
	pr.level = level
	pr.kind = kind
	pr.position = pos
	level.entities.add_child(pr)
	return pr

func _wave(dir: int, spd: float) -> void:
	var pr := _spawn_proj("wave", global_position + Vector2(dir * 20, -7))
	pr.vel = Vector2(dir * spd, 0)
	pr.life = 3.0
	pr.sprite.flip_h = dir < 0

func _arc(p: Node, t: float) -> void:
	var origin := global_position + Vector2(facing * 10, -bh * 0.9)
	var kind: String = cfg["proj"] if cfg["proj"] != "knife" else "stone"
	var pr := _spawn_proj(kind, origin)
	var tx: float = p.global_position.x + p.velocity.x * 0.3 - origin.x
	var ty: float = (p.global_position.y - 12) - origin.y
	pr.grav = 600.0
	pr.vel = Vector2(clampf(tx / t, -260, 260), (ty - 0.5 * 600.0 * t * t) / t)
	Audio.sfx("throw", 0.1)

func _straight(kind: String, spd: float, y: float) -> void:
	var pr := _spawn_proj(kind, global_position + Vector2(facing * 16, y))
	pr.vel = Vector2(facing * spd, 0)
	pr.sprite.flip_h = facing < 0
	Audio.sfx("throw", 0.1)

func take_hit(dmg: int, _dir: int, _src: Node) -> void:
	if state == "dead" or state == "intro" or invuln > 0.0:
		return
	# General's shield: frontal hits clang off unless it is a heavy (hammer) blow.
	if guarding and _src != null and is_instance_valid(_src) and signf(_src.global_position.x - global_position.x) == facing:
		if dmg >= 4:
			guarding = false
			queue_redraw()
			Audio.sfx("clang", 0.05)
			_go("stunned")
		else:
			Audio.sfx("clang", 0.1, -2)
			Game.spawn_fx(level.entities, "spark", global_position + Vector2(facing * bw * 0.5, -bh * 0.5), false, 1.5)
			invuln = 0.15
			return
	# Fox / viper: quick backflip away from an attack while not committed to a move.
	if cfg.has("dodge") and state == "idle" and dodge_cd <= 0.0 and randf() < float(cfg["dodge"]):
		dodge_cd = 2.6
		invuln = 0.45
		var away := signf(global_position.x - (_src.global_position.x if _src != null and is_instance_valid(_src) else global_position.x - facing))
		velocity = Vector2(away * 230.0, -300.0)
		Audio.sfx("dodge", 0.1)
		_smoke(global_position)
		return
	hp -= dmg
	health_changed.emit(hp, max_hp)
	sprite.modulate = Color(4, 4, 4)
	flash_t = 0.08
	invuln = 0.05
	if hp <= 0:
		_die()
		return
	# poise: on easy a flurry of hits staggers him; on hard he never flinches
	stagger_n += 1
	stagger_t = 2.5
	if int(D["stagger"]) > 0 and stagger_n >= int(D["stagger"]) and not airborne and state != "stunned" and state != "roar":
		stagger_n = 0
		guarding = false
		queue_redraw()
		sprite.speed_scale = 1.0
		contact_on = true
		sprite.modulate = _base_mod()
		sprite.visible = true
		velocity.x = -facing * 80.0
		_go("stunned")
	if not enraged and hp <= max_hp / 2:
		enraged = true
		if cfg.has("phase2"):
			phase2 = true
			attacks = _with_extras((cfg["phase2"] as Array).duplicate())
		speed *= 1.2
		invuln = 1.2
		raged.emit()
		_go("roar")
		Audio.sfx("roar")
		level.shake(5.0)

func _die() -> void:
	_go("dead")
	contact_on = false
	remove_from_group("hittable")
	remove_from_group("enemy")
	sprite.play("hurt")
	Audio.sfx("boss_die")
	level.shake(8.0)
	for m in get_tree().get_nodes_in_group("minion"):
		if m.has_method("take_hit"):
			m.take_hit(99, 1, self)
	for pr in get_tree().get_nodes_in_group("boss_fx"):
		pr.queue_free()
	guarding = false
	queue_redraw()
	var tw := create_tween()
	for i in range(8):
		tw.tween_callback(func(): Game.spawn_fx(level.entities, "spark", global_position + Vector2(randf_range(-bw, bw), randf_range(-bh, 0)), false, 2.0))
		tw.tween_interval(0.12)
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, 0.0), 0.6)
	tw.tween_callback(func(): defeated.emit())
