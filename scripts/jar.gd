extends Node2D
# Breakable chapter object (qolla jar, crate, basket, canopic jar, suitcase...) that drops coins.
# breakables.png: 0 jar (chapters 1-6), 1..6 one object per chapter 7-12.

var level: Node = null
var sprite: Sprite2D
var broken := false

func _ready() -> void:
	add_to_group("hittable")
	var ch: int = level.chapter if level != null else 1
	var idx := clampi(ch - 6, 0, 6)
	sprite = Game.region_sprite("res://assets/sprites/breakables.png", Rect2(idx * 40, 0, 40, 48))
	sprite.position = Vector2(0, -12 + 1)
	add_child(sprite)

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-8, -20), Vector2(16, 20))

func take_hit(_d: int, _dir: int, _src: Node) -> void:
	if broken:
		return
	broken = true
	remove_from_group("hittable")
	Audio.sfx("hit_stick" if (level != null and level.chapter >= 7) else "hit", 0.2)
	Game.spawn_fx(get_parent(), "spark", global_position + Vector2(0, -10), false, 1.4)
	var n := randi_range(2, 4)
	for i in range(n):
		level.spawn_pickup("coin", global_position + Vector2(0, -12), Vector2(randf_range(-70, 70), randf_range(-230, -140)))
	if randf() < 0.12:
		level.spawn_pickup("food", global_position + Vector2(0, -12), Vector2(0, -200))
	queue_free()
