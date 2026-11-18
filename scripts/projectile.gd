extends Node2D
# Thrown objects / boss projectiles. Distance-based hits keep it light for mobile.
# Classic kinds live on proj.png (32px cells); the newer boss kinds on proj2.png (48px cells).

const Hazard = preload("res://scripts/hazard.gd")
const KINDS := {"bottle": 0, "stone": 1, "pot": 2, "knife": 3, "fire": 4, "snake": 6, "wave": 8}
const KINDS2 := {"venom": 0, "grenade": 1, "barrel": 2, "scarab": 3, "anchor": 4, "sunorb": 5, "smoke": 6}
# Texture scale per proj2 kind (48px art -> ~16-24 world px).
const SCALE2 := {"venom": 0.34, "grenade": 0.3, "barrel": 0.46, "scarab": 0.36, "anchor": 0.44, "sunorb": 0.42, "smoke": 0.5}

var level: Node = null
var kind := "bottle"
var vel := Vector2.ZERO
var grav := 0.0
var dmg := 1
var life := 4.0
var crawl := false
var drop := false          # falls, then crawls along the ground (snake rain)
var homing := 0.0          # steering strength toward the player (scarabs)
var puller: Node = null    # anchor hook: pulls the player toward this node on hit
var spin := 0.0
var sprite: Sprite2D
var anim_t := 0.0

func _ready() -> void:
	add_to_group("hittable")
	add_to_group("boss_fx")
	sprite = Sprite2D.new()
	if KINDS2.has(kind):
		sprite.texture = load("res://assets/sprites/proj2.png")
		sprite.region_enabled = true
		sprite.region_rect = Rect2(KINDS2[kind] * 48, 0, 48, 48)
		var sc: float = SCALE2[kind]
		sprite.scale = Vector2(sc, sc)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		sprite.texture = load("res://assets/sprites/proj.png")
		sprite.region_enabled = true
		sprite.region_rect = Rect2(KINDS.get(kind, 0) * 32, 0, 32, 32)
		sprite.scale = Vector2(Game.SPR, Game.SPR)
	sprite.flip_h = vel.x < 0
	add_child(sprite)
	z_index = 15
	if kind in ["bottle", "stone", "pot", "grenade"]:
		spin = 10.0 * signf(vel.x if vel.x != 0.0 else 1.0)
	if kind == "barrel":
		spin = 7.0 * signf(vel.x if vel.x != 0.0 else 1.0)
		crawl = true
	if kind in ["snake", "wave"] and not drop:
		crawl = true

func hurt_rect() -> Rect2:
	var r := 10.0 if kind == "barrel" else 7.0
	return Rect2(global_position - Vector2(r, r), Vector2(r * 2, r * 2))

func take_hit(_d: int, _dir: int, _src: Node) -> void:
	if kind == "wave":
		return
	Audio.sfx("hit", 0.2, -6)
	if kind == "grenade":
		_explode()
		return
	_break()

func _physics_process(delta: float) -> void:
	if homing > 0.0 and level != null and level.player != null and not level.player.dead:
		var want: Vector2 = (level.player.center() - global_position).normalized() * 105.0
		vel = vel.lerp(want, clampf(homing * delta, 0.0, 1.0))
		sprite.flip_h = vel.x < 0
	vel.y += grav * delta
	position += vel * delta
	if kind == "barrel":
		sprite.rotation += spin * delta
	else:
		rotation += spin * delta
	anim_t += delta
	if kind in ["fire", "snake", "wave"]:
		var base: int = KINDS[kind]
		sprite.region_rect = Rect2((base + (int(anim_t * 10) % 2)) * 32, 0, 32, 32)
	elif kind == "scarab":
		sprite.scale.y = SCALE2["scarab"] * (0.8 + 0.2 * absf(sin(anim_t * 30.0)))
	elif kind == "sunorb":
		sprite.modulate = Color(1.3, 1.2, 1.0) if int(anim_t * 12) % 2 == 0 else Color(1, 1, 1)
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if level == null:
		return
	# never let a shot keep flying (or hit) from outside the camera view
	if level.player != null and level.player.camera != null:
		var cam: Camera2D = level.player.camera
		var half: Vector2 = get_viewport_rect().size / cam.zoom / 2.0
		var cc := cam.get_screen_center_position()
		if absf(global_position.x - cc.x) > half.x + 24.0 or global_position.y > cc.y + half.y + 40.0:
			queue_free()
			return
	var p = level.player
	if p != null and not p.dead:
		var c: Vector2 = p.center()
		var rx := 13.0 if kind == "barrel" else 10.0
		if absf(c.x - global_position.x) < rx and absf(c.y - global_position.y) < 17.0:
			p.hurt(dmg, global_position.x - vel.x)
			if puller != null and is_instance_valid(puller):
				var d := signf(puller.global_position.x - p.global_position.x)
				p.velocity = Vector2(d * 340.0, -140.0)
				if puller.has_method("on_hooked"):
					puller.on_hooked()
			if kind == "grenade":
				_explode()
			else:
				_break()
			return
	if drop:
		if level.is_solid(global_position + Vector2(0, 6)):
			position.y = floor((global_position.y + 6) / 16.0) * 16.0 - 6.0
			drop = false
			grav = 0.0
			crawl = true
			vel = Vector2(90.0 * (1.0 if randf() < 0.5 else -1.0), 0)
			sprite.flip_h = vel.x < 0
		return
	if crawl:
		var d := signf(vel.x)
		var probe_y := 14.0 if kind == "barrel" else 10.0
		if not level.is_ground(global_position + Vector2(d * 6, probe_y)) or level.is_solid(global_position + Vector2(d * 10, -2)):
			_break()
	elif level.is_solid(global_position):
		_land()

# Hitting the floor: venom leaves a puddle, grenades sit and fuse, the rest shatter.
func _land() -> void:
	var gy := floorf(global_position.y / 16.0) * 16.0
	if kind == "venom":
		_spawn_hazard("puddle", Vector2(global_position.x, gy))
		Audio.sfx("poison", 0.1, -4)
		queue_free()
	elif kind == "grenade":
		_spawn_hazard("fuse", Vector2(global_position.x, gy))
		queue_free()
	else:
		_break()

func _explode() -> void:
	_spawn_hazard("blast", global_position)
	queue_free()

func _spawn_hazard(k: String, pos: Vector2) -> void:
	if level == null:
		return
	var hz := Hazard.new()
	hz.level = level
	hz.kind = k
	hz.position = pos
	level.entities.call_deferred("add_child", hz)

func _break() -> void:
	if level != null:
		Game.spawn_fx(level.entities, "spark", global_position)
	queue_free()
