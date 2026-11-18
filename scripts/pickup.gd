extends Node2D
# Coins (gneih), hearts and foul sandwiches.

var level: Node = null
var kind := "coin"
var vel := Vector2.ZERO
var physics := false
var t := 0.0
var sprite: Sprite2D
var base_y := 0.0
var magnet := false

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/items.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0 if kind == "coin" else (192 if kind == "heart" else 224), 0, 32, 32)
	sprite.scale = Vector2(Game.SPR, Game.SPR)
	add_child(sprite)
	base_y = position.y
	t = randf() * 3.0
	z_index = 5

func _physics_process(delta: float) -> void:
	t += delta
	if physics:
		vel.y += 700 * delta
		var np := position + vel * delta
		if vel.y > 0 and level != null and level.is_ground(np + Vector2(0, 6)):
			vel = Vector2(vel.x * 0.5, -absf(vel.y) * 0.35)
			if absf(vel.y) < 40:
				physics = false
				base_y = position.y
		else:
			position = np
		if level != null and position.y > level.bottom_y() + 40:
			queue_free()
	else:
		sprite.position.y = sin(t * 3.0) * 1.5
	if kind == "coin":
		var f := int(t * 10.0) % 6
		sprite.region_rect = Rect2(f * 32, 0, 32, 32)
	if level == null or level.player == null:
		return
	var p = level.player
	if p.dead:
		return
	var d: Vector2 = p.center() - global_position
	if kind == "coin" and d.length() < (40.0 + 65.0 * float(Game.upgrades["magnet"])) and not physics:
		global_position += d.normalized() * minf(d.length(), 220.0 * delta)
	if absf(d.x) < 13.0 and absf(d.y) < 19.0 and (not physics or vel.y > -50):
		_collect(p)

func _collect(p: Node) -> void:
	match kind:
		"coin":
			Game.coins += 1
			Audio.sfx("coin", 0.05, -4)
			if Game.coins % 50 == 0:
				p.heal(2)
				if level.hud != null:
					level.hud.toast("٥٠ جنيه = قلب زيادة!")
		"heart":
			p.heal(2)
		"food":
			p.heal(p.max_hp)
			if level.hud != null:
				level.hud.toast("ساندوتش فول.. الصحة رجعت فُل!")
	if level.hud != null:
		level.hud.refresh()
	Game.spawn_fx(get_parent(), "spark", global_position)
	queue_free()
