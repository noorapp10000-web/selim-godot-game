extends Node2D
# Builds a chapter from its ASCII map: tiles, enemies, pickups, checkpoints, ambush arenas, the clear-all
# barrier before the boss and the boss arena.
# Map letters: # ground, = one-way plank, ^ spikes, C coin, H heart, Q jar, M moving hazard, N npc,
# T/U/R/J/D fighters, K mid checkpoint, k pre-boss checkpoint, X clear-all barrier, W ambush arena,
# P start, G boss gate, B boss, F father.

const LevelData = preload("res://levels/expanded_maps.gd")
const StoryData = preload("res://scripts/story_data.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BossScript = preload("res://scripts/boss.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const CheckpointScript = preload("res://scripts/checkpoint.gd")
const NpcScript = preload("res://scripts/npc.gd")
const JarScript = preload("res://scripts/jar.gd")
const MoverScript = preload("res://scripts/mover.gd")
const HudScript = preload("res://scripts/hud.gd")
const T := 16
const ENEMY_KEYS := {"T": "thug", "U": "thug2", "R": "thrower", "D": "dog", "J": "knife"}
# Letters pick the archetype slot; Game.ROSTER decides which chapter fighter fills it.

var chapter := 1
var cfg := {}
var rows: Array = []
var map_w := 0
var map_h := 17
var tilemap: TileMapLayer
var entities: Node2D
var player: Node = null
var hud: Node = null
var boss: Node = null
var bg_sprite: Sprite2D
var bg_layer: CanvasLayer
var bg_near: Sprite2D
var bg_haze: TextureRect
var water_lines: Array = []
var spawn := Vector2(48, 192)
var checkpoint_pos := Vector2.ZERO
var checkpoint_node: Node = null
var gate_x := -1
var boss_pos := Vector2.ZERO
var father_pos := Vector2.ZERO
var boss_started := false
var boss_done := false
var spikes: Array[Rect2] = []
var cage: Node2D = null
var father: Node2D = null
var time_t := 0.0
var amb_layer: CanvasLayer
var storm_rect: ColorRect
# checkpoints / clear-all barrier / ambushes
var checkpoints := {}
var killed_ids: Array = []
var waves_done: Array = []
var barrier_x := -1.0
var barrier_body: StaticBody2D = null
var barrier_gate: Sprite2D = null
var barrier_glow: ColorRect = null
var barrier_open := false
var blocked_t := 0.0
var ambushes: Array = []
var ambush: Dictionary = {}
var remaining_cache := 0
var remaining_t := 0.0
var barrier_ground_y := 0.0

func _ready() -> void:
	chapter = Game.chapter
	cfg = Game.CHAPTERS[chapter]
	rows = LevelData.MAPS[chapter]
	map_h = rows.size()
	for r in rows:
		map_w = maxi(map_w, (r as String).length())
	_build_background()
	_build_tiles()
	entities = Node2D.new()
	entities.name = "Entities"
	add_child(entities)
	var cm := CanvasModulate.new()
	cm.color = cfg["tint"]
	add_child(cm)
	_decorate()
	_build_pits()
	_build_ambience()
	_spawn_objects()
	_spawn_player()
	hud = HudScript.new()
	hud.level = self
	add_child(hud)
	hud.show_title(cfg["num"], cfg["name"], cfg["place"])
	Audio.play_music(cfg["music"])
	if Game.autotest != "":
		_autotest()

# ---------------------------------------------------------------- map queries
func cell(x: int, y: int) -> String:
	if y < 0:
		return " "
	if y >= map_h:
		return " "
	if x < 0 or x >= map_w:
		return "#"
	var r: String = rows[y]
	if x >= r.length():
		return " "
	return r[x]

func is_solid(p: Vector2) -> bool:
	var cx := int(floor(p.x / T))
	var cy := int(floor(p.y / T))
	if boss_started and cx == gate_x and not boss_done:
		return true
	if cy >= map_h:
		return false
	return cell(cx, cy) == "#"

func is_ground(p: Vector2) -> bool:
	var cx := int(floor(p.x / T))
	var cy := int(floor(p.y / T))
	if cy >= map_h:
		return false
	var c := cell(cx, cy)
	return c == "#" or c == "="

func bottom_y() -> float:
	return map_h * T

# ---------------------------------------------------------------- build
func _build_background() -> void:
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var sky := ColorRect.new()
	sky.color = cfg["sky"]
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(sky)
	bg_sprite = Sprite2D.new()
	bg_sprite.texture = load("res://assets/art/pan_ch%d.png" % chapter)
	bg_sprite.centered = false
	bg_sprite.region_enabled = true
	bg_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg_sprite.region_rect = Rect2(0, 0, 1400, 360)
	bg_sprite.modulate = Color(0.95, 0.95, 1.0)
	bg_layer.add_child(bg_sprite)
	bg_near = Sprite2D.new()
	bg_near.texture = load("res://assets/art/near_ch%d.png" % chapter)
	bg_near.centered = false
	bg_near.region_enabled = true
	bg_near.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg_near.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg_layer.add_child(bg_near)
	# atmospheric haze near the horizon so the playfield pops
	var g := Gradient.new()
	var hz: Color = cfg.get("haze", cfg["sky"].darkened(0.55))
	g.set_color(0, Color(hz, 0.0))
	g.set_color(1, Color(hz, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	bg_haze = TextureRect.new()
	bg_haze.texture = gt
	bg_haze.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_haze.stretch_mode = TextureRect.STRETCH_SCALE
	bg_haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_haze.anchor_top = 0.45
	bg_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg_haze)

# Ground atlas per chapter (assets/sprites/ground_chN.png, 64px cells, drawn at 1/4 scale = 16 world px):
# rows 0-3 = the chapter's ground strata from the walkable surface downwards (8 seamless columns),
# row 4 = row 3 flipped (so deep ground mirrors without seams), row 5 = plank tiles (0-3) and spikes (4).
const GROUND_TT := 64
const DEPTH_MOD := [Color(1, 1, 1), Color(0.8, 0.78, 0.82), Color(0.64, 0.62, 0.68)]

func _build_tiles() -> void:
	var TT := GROUND_TT
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TT, TT)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/sprites/ground_ch%d.png" % chapter)
	src.texture_region_size = Vector2i(TT, TT)
	ts.add_source(src, 0)
	var h := TT / 2.0
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for row in range(5):
		for col in range(8):
			var co := Vector2i(col, row)
			src.create_tile(co)
			var alts := [0]
			for d in range(1, DEPTH_MOD.size()):
				alts.append(src.create_alternative_tile(co))
			for ai in range(alts.size()):
				var td := src.get_tile_data(co, alts[ai])
				td.modulate = DEPTH_MOD[ai]
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, full)
	for col in range(4):
		var co := Vector2i(col, 5)
		src.create_tile(co)
		var pd := src.get_tile_data(co, 0)
		pd.add_collision_polygon(0)
		pd.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, -h + 24), Vector2(-h, -h + 24)]))
		pd.set_collision_polygon_one_way(0, 0, true)
	src.create_tile(Vector2i(4, 5))
	tilemap = TileMapLayer.new()
	tilemap.tile_set = ts
	tilemap.scale = Vector2(16.0 / TT, 16.0 / TT)
	tilemap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(tilemap)
	var side_tex := _edge_tex(Vector2(1, 0))
	var under_tex := _edge_tex(Vector2(0, 1))
	for y in range(map_h):
		for x in range(map_w):
			var c := cell(x, y)
			if c == "#":
				var depth := 0
				while depth < 8 and cell(x, y - depth - 1) == "#":
					depth += 1
				var band := depth if depth < 4 else (4 if (depth - 4) % 2 == 0 else 3)
				var alt := 0 if depth < 4 else (1 if depth < 6 else 2)
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(x % 8, band), alt)
				# shade exposed sides and undersides so blocks and ledges read as solid volumes
				for side in [-1, 1]:
					if cell(x + side, y) != "#" and x + side >= 0 and x + side < map_w:
						var sp := Sprite2D.new()
						sp.texture = side_tex
						sp.centered = false
						sp.flip_h = side > 0
						sp.position = Vector2(x * T + (0.0 if side < 0 else T - 6.0), y * T)
						sp.scale = Vector2(6.0 / 16.0, 1.0)
						sp.z_index = 1
						add_child(sp)
						if depth == 0:
							var cap := ColorRect.new()
							cap.color = Color(1, 0.95, 0.85, 0.35)
							cap.size = Vector2(1, T)
							cap.position = Vector2(x * T + (0.0 if side < 0 else T - 1.0), y * T)
							cap.z_index = 1
							add_child(cap)
				if cell(x, y + 1) != "#" and y + 1 < map_h:
					var us := Sprite2D.new()
					us.texture = under_tex
					us.centered = false
					us.flip_v = true
					us.position = Vector2(x * T, y * T + T - 7.0)
					us.scale = Vector2(1.0, 7.0 / 16.0)
					us.z_index = 1
					add_child(us)
			elif c == "=":
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(x % 4, 5))
			elif c == "^":
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(4, 5))
				spikes.append(Rect2(x * T + 2, y * T + 7, T - 4, T - 7))
	if chapter == 11:
		_train_joints()

# 16x16 dark gradient used to shade exposed tile edges (dir = direction the shadow fades towards).
func _edge_tex(dir: Vector2) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.01, 0.03, 0.62))
	g.set_color(1, Color(0.02, 0.01, 0.03, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 16
	gt.height = 16
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = dir
	return gt

# Chapter 11 runs on the roofs of a moving train: break long ground runs into separate carriages with
# dark couplings, so it reads as carriage after carriage instead of one endless car.
func _train_joints() -> void:
	var run := 0
	for x in range(1, map_w - 1):
		var top := -1
		for y in range(map_h):
			if cell(x, y) == "#":
				top = y
				break
		if top < 0:
			run = 0
			continue
		run += 1
		if run >= 26 and cell(x + 1, top) == "#" and cell(x - 1, top) == "#" and cell(x, top - 1) == " " and x < map_w - 60:
			run = 0
			var gap := ColorRect.new()
			gap.color = Color(0.03, 0.02, 0.03, 0.96)
			gap.size = Vector2(5, (map_h - top) * T)
			gap.position = Vector2(x * T + 5.5, top * T + 3)
			gap.z_index = 2
			add_child(gap)
			for i in range(int((map_h - top) * T / 4.0)):
				var fold := ColorRect.new()
				fold.color = Color(0.2, 0.17, 0.16, 0.9)
				fold.size = Vector2(5, 1)
				fold.position = Vector2(x * T + 5.5, top * T + 5 + i * 4)
				fold.z_index = 2
				add_child(fold)
			for sx in [4.5, 10.5]:
				var rim := ColorRect.new()
				rim.color = Color(0.55, 0.5, 0.45, 0.8)
				rim.size = Vector2(1, (map_h - top) * T)
				rim.position = Vector2(x * T + sx, top * T + 2)
				rim.z_index = 2
				add_child(rim)

func _build_pits() -> void:
	var water := chapter == 3 or chapter == 4 or chapter == 9
	var col := Color(0.12, 0.3, 0.45) if water else Color(0.03, 0.02, 0.03)
	var x := 0
	while x < map_w:
		if cell(x, map_h - 1) != "#":
			var x0 := x
			while x < map_w and cell(x, map_h - 1) != "#":
				x += 1
			var g := Gradient.new()
			g.set_color(0, Color(col, 0.0))
			g.set_color(1, Color(col, 1.0))
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.width = 4
			gt.height = 64
			gt.fill_from = Vector2(0, 0)
			gt.fill_to = Vector2(0, 0.6)
			var sp := Sprite2D.new()
			sp.texture = gt
			sp.centered = false
			sp.scale = Vector2((x - x0) * T / 4.0, 1.25)
			sp.position = Vector2(x0 * T, (map_h - 4) * T)
			sp.z_index = 8
			add_child(sp)
			if water:
				var body := ColorRect.new()
				body.color = Color(0.1, 0.26, 0.4, 0.85)
				body.size = Vector2((x - x0) * T, 3 * T)
				body.position = Vector2(x0 * T, (map_h - 1) * T - 5)
				body.z_index = 9
				add_child(body)
				for k in range(2):
					var wl := ColorRect.new()
					wl.color = Color(0.62, 0.86, 1.0, 0.75 - k * 0.35)
					wl.size = Vector2((x - x0) * T, 1.0)
					wl.position = Vector2(x0 * T, (map_h - 1) * T - 6 + k * 2.5)
					wl.z_index = 10
					add_child(wl)
					water_lines.append(wl)
		else:
			x += 1

func _decorate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter * 977
	var decor: Array = cfg["decor"]
	var last := -10
	for x in range(3, map_w - 46):
		if x - last < 5:
			continue
		for y in range(2, map_h):
			if cell(x, y) == "#" and cell(x, y - 1) == " " and cell(x, y - 2) == " " and cell(x, y - 3) == " ":
				if cell(x - 1, y) == "#" and cell(x + 1, y) == "#" and rng.randf() < float(cfg.get("decor_rate", 0.16)):
					var idx: int = decor[rng.randi() % decor.size()]
					var s: Sprite2D
					if idx >= 100:
						# hi-res chapter props (props2.png: 160x256 cells at 1/4 scale)
						s = Game.region_sprite("res://assets/sprites/props2.png", Rect2((idx - 100) * 160, 0, 160, 256), false)
						s.scale = Vector2(0.25, 0.25)
						s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
					else:
						s = Game.region_sprite("res://assets/sprites/props.png", Rect2(idx * 80, 0, 80, 128))
					s.position = Vector2(x * T + 8, y * T - 32 + 1.5)
					s.z_index = -2
					s.flip_h = rng.randf() < 0.5 and idx != 7
					s.modulate = Color(0.9, 0.88, 0.92)
					add_child(s)
					last = x
				break

func _spawn_objects() -> void:
	var npc_i := 0
	if Game.checkpoint_active:
		killed_ids = Game.cp_killed.duplicate()
		waves_done = Game.cp_waves.duplicate()
	# The pre-boss lantern (k) stands past the clear-all barrier (X) and only lights once every fighter
	# before the barrier is beaten, so respawning there never brings any of them back.
	for y in range(map_h):
		for x in range(map_w):
			if cell(x, y) == "X":
				barrier_x = x * T
	var past_barrier := Game.checkpoint_active and Game.checkpoint_idx >= 2 and barrier_x >= 0.0
	for y in range(map_h):
		for x in range(map_w):
			var c := cell(x, y)
			var foot := Vector2(x * T + 8, (y + 1) * T)
			var mid := Vector2(x * T + 8, y * T + 8)
			match c:
				"P":
					spawn = foot
				"K", "k":
					var k := CheckpointScript.new()
					k.level = self
					k.idx = 1 if c == "K" else 2
					k.position = foot
					entities.add_child(k)
					checkpoints[k.idx] = k
					if k.idx == 1:
						checkpoint_pos = foot
						checkpoint_node = k
				"X":
					barrier_x = x * T
				"W":
					var wid := "w%d" % x
					if past_barrier and x * T < barrier_x:
						if wid not in waves_done:
							waves_done.append(wid)
					elif wid not in waves_done:
						ambushes.append({"id": wid, "x": x * T + 8, "y": foot.y, "l": (x - 12) * T, "r": (x + 13) * T})
				"C":
					spawn_pickup("coin", mid, Vector2.ZERO)
				"H":
					spawn_pickup("heart", mid, Vector2.ZERO)
				"Q":
					var j := JarScript.new()
					j.level = self
					j.position = foot
					entities.add_child(j)
				"N":
					var arr: Array = StoryData.NPCS[chapter]
					if npc_i < arr.size():
						var info: Array = arr[npc_i]
						var n := NpcScript.new()
						n.level = self
						n.npc_name = info[0]
						n.sheet = info[1]
						n.lines = info[2]
						n.position = foot
						entities.add_child(n)
					npc_i += 1
				"M":
					var m := MoverScript.new()
					m.position = Vector2(x * T + 8, (y + 1) * T)
					m.amp = 40.0
					m.spd = 1.2 + chapter * 0.08
					add_child(m)
				"G":
					gate_x = x
				"B":
					boss_pos = foot
				"F":
					father_pos = foot
				_:
					if ENEMY_KEYS.has(c):
						var who := Game.roster_sheet(chapter, c)
						var kind: String = who if who != "" else ENEMY_KEYS[c]
						var mid_id := "%d_%d" % [x, y]
						if past_barrier and x * T < barrier_x:
							continue
						if mid_id not in killed_ids:
							spawn_enemy(kind, foot, false).map_id = mid_id
						# difficulty: extra fighters next to every map fighter. Seeded per fighter so the
						# same extras (same ids) appear on every load and checkpoint kills always match.
						var rng := RandomNumberGenerator.new()
						rng.seed = hash("%d|%d|%s" % [chapter, Game.difficulty, mid_id])
						var extra := float(Game.diff()["extra"])
						var n_extra := int(extra) + (1 if rng.randf() < extra - int(extra) else 0)
						var offs := [26.0, -26.0, 48.0, -48.0]
						var placed := 0
						for o in offs:
							if placed >= n_extra:
								break
							var fp: Vector2 = foot + Vector2(o, 0)
							if is_ground(fp + Vector2(0, 4)) and not is_solid(fp + Vector2(0, -8)) and cell(int(fp.x / T), y) == " ":
								placed += 1
								var eid := "%s_e%d" % [mid_id, placed]
								if eid not in killed_ids:
									var e2 := spawn_enemy(kind if rng.randf() < 0.6 else Game.roster_sheet(chapter, ["T", "U", "R", "J"][rng.randi() % 4]), fp, false)
									e2.map_id = eid
	if barrier_x >= 0.0:
		_build_barrier()
	if father_pos != Vector2.ZERO:
		father = Node2D.new()
		father.position = father_pos
		entities.add_child(father)
		var fs := Game.char_sprite(father, "hassan" if chapter >= 7 else "father", Game.NPC_ANIMS, Game.NPC_GRID)
		fs.flip_h = true
		fs.play("idle")
		cage = Game.region_sprite("res://assets/sprites/cage.png", Rect2(0, 0, 80, 104))
		cage.position = Vector2(0, -26)
		father.add_child(cage)

func spawn_enemy(kind: String, pos: Vector2, minion: bool) -> Node:
	var e := EnemyScript.new()
	e.setup(kind, chapter)
	e.level = self
	e.position = pos
	e.is_minion = minion
	if minion:
		e.add_to_group("minion")
	entities.add_child(e)
	return e

func spawn_pickup(kind: String, pos: Vector2, vel: Vector2) -> void:
	var p := PickupScript.new()
	p.level = self
	p.kind = kind
	p.position = pos
	if vel != Vector2.ZERO:
		p.vel = vel
		p.physics = true
	entities.call_deferred("add_child", p)

func _spawn_player() -> void:
	player = PlayerScript.new()
	player.level = self
	var cp_idx := Game.checkpoint_idx if Game.checkpoint_idx > 0 else 1
	if Game.checkpoint_active and checkpoints.has(cp_idx):
		player.position = (checkpoints[cp_idx] as Node2D).position + Vector2(10, 0)
		Game.coins = Game.coins_at_checkpoint
		for i in checkpoints:
			if int(i) <= cp_idx:
				checkpoints[i].set_active(true)
	else:
		player.position = spawn
		Game.coins = 0
	entities.add_child(player)
	player.set_limits(0, -40, map_w * T, map_h * T)
	player.died.connect(_on_player_died)

# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	time_t += delta
	if player != null:
		var cam: Camera2D = player.camera
		var cc := cam.get_screen_center_position()
		var vs := get_viewport().get_visible_rect().size
		# the train chapter rushes through the landscape even when Selim stands still
		var rush := time_t * 230.0 if chapter == 11 and not boss_done else 0.0
		# backgrounds always cover the full screen: scaled up on tall screens and never pushed down far
		# enough to show a strip of bare sky colour above them
		var k := maxf(1.0, (vs.y + 44.0) / 360.0)
		bg_sprite.scale = Vector2(k, k)
		bg_near.scale = Vector2(k, k)
		bg_sprite.region_rect = Rect2(cc.x * 0.42 + rush * 0.18, 0, (vs.x + 4.0) / k, 360)
		bg_near.region_rect = Rect2(cc.x * 0.85 + rush, 0, (vs.x + 4.0) / k, 360)
		bg_near.position.y = vs.y - 360.0 * k + clampf((cc.y - 150.0) * -0.3, -30.0, 30.0)
		bg_sprite.position.y = minf(0.0, vs.y - 360.0 * k + clampf((cc.y - 150.0) * -0.15, -20.0, 20.0))
		for i in range(water_lines.size()):
			(water_lines[i] as ColorRect).modulate.a = 0.6 + 0.4 * sin(time_t * 3.0 + i * 1.7)

func _physics_process(_d: float) -> void:
	if player == null or player.dead:
		return
	var feet := Rect2(player.global_position + Vector2(-5, -10), Vector2(10, 10))
	for r in spikes:
		if feet.intersects(r):
			player.hurt(1, player.global_position.x - player.facing * 4)
			if not player.dead and player.invuln > 0.9:
				player.velocity.y = -280
			break
	_update_barrier(_d)
	_update_ambush()
	if not boss_started and gate_x >= 0 and player.global_position.x > gate_x * T + 56:
		_start_boss()

# ---------------------------------------------------------------- ambience
# Screen-space particles per chapter mood (museum dust, sandstorm, river glints, sunrise motes,
# dusk embers, citadel fireflies). Sits above the world, below the HUD.
func _dot_tex(soft := true) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0) if soft else Color(1, 1, 1, 1))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 8
	gt.height = 8
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	return gt

func _emitter(amount: int, life: float, col: Color, vmin: float, vmax: float, dir: Vector2, spread: float, smin: float, smax: float, grav := Vector2.ZERO) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.amount = amount
	e.lifetime = life
	e.preprocess = life
	e.texture = _dot_tex()
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(380, 200)
	e.position = Vector2(320, 180)
	e.direction = dir
	e.spread = spread
	e.gravity = grav
	e.initial_velocity_min = vmin
	e.initial_velocity_max = vmax
	e.scale_amount_min = smin
	e.scale_amount_max = smax
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col, 0.0))
	ramp.add_point(0.2, col)
	ramp.add_point(0.8, col)
	ramp.set_color(ramp.get_point_count() - 1, Color(col, 0.0))
	e.color_ramp = ramp
	amb_layer.add_child(e)
	return e

func _build_ambience() -> void:
	amb_layer = CanvasLayer.new()
	amb_layer.layer = 2
	add_child(amb_layer)
	storm_rect = ColorRect.new()
	storm_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	storm_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storm_rect.color = Color(0.85, 0.7, 0.45, 0.0)
	amb_layer.add_child(storm_rect)
	match str(cfg.get("ambience", "")):
		"museum":
			_emitter(26, 6.0, Color(0.75, 0.85, 1.0, 0.35), 4, 10, Vector2(0.3, -1), 180, 0.25, 0.6)
		"sandstorm":
			storm_rect.color.a = 0.1
			_emitter(70, 1.6, Color(0.95, 0.85, 0.65, 0.55), 260, 380, Vector2(-1, 0.08), 6, 0.2, 0.45)
			_emitter(18, 3.0, Color(0.9, 0.78, 0.55, 0.25), 90, 150, Vector2(-1, 0.02), 10, 1.2, 2.2)
		"river":
			_emitter(20, 3.5, Color(1.0, 1.0, 0.9, 0.45), 3, 8, Vector2(1, -0.2), 40, 0.2, 0.45)
		"sunrise":
			_emitter(30, 5.0, Color(1.0, 0.82, 0.45, 0.45), 6, 14, Vector2(0.4, -1), 60, 0.25, 0.55)
		"dusk":
			_emitter(22, 2.6, Color(1.0, 0.6, 0.3, 0.6), 80, 140, Vector2(-1, -0.25), 15, 0.18, 0.35)
		"citadel":
			var ff := _emitter(24, 4.0, Color(0.6, 1.0, 0.55, 0.75), 4, 12, Vector2(0, -1), 180, 0.25, 0.5)
			ff.emission_rect_extents = Vector2(380, 80)
			ff.position = Vector2(320, 250)

# Boss sandstorm: thicken the sand overlay for a few seconds.
func storm(dur: float) -> void:
	if storm_rect == null:
		return
	var base := 0.1 if str(cfg.get("ambience", "")) == "sandstorm" else 0.0
	var tw := create_tween()
	tw.tween_property(storm_rect, "color:a", 0.38, 0.4)
	tw.tween_interval(maxf(0.1, dur - 0.9))
	tw.tween_property(storm_rect, "color:a", base, 0.5)

func shake(amount: float) -> void:
	if player != null:
		player.shake = maxf(player.shake, amount)

# ---------------------------------------------------------------- kills, checkpoints, barrier, ambushes
func on_enemy_killed(e: Node) -> void:
	var id: String = str(e.get("map_id"))
	if id != "" and id not in killed_ids:
		killed_ids.append(id)
		Game.checkpoint_progress(killed_ids, waves_done)

func on_checkpoint(idx: int) -> void:
	Game.set_checkpoint(idx, killed_ids, waves_done)

# Fighters still standing before the boss plaza (boss followers and ambush waves are not counted;
# an ambush that has not been fought yet counts as one).
func remaining_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_in_group("boss") or e.is_in_group("minion") or e.is_in_group("ambush"):
			continue
		if barrier_x >= 0.0 and e.global_position.x > barrier_x + 24.0:
			continue
		n += 1
	for a in ambushes:
		if not a.get("started", false):
			n += 1
	return n

func nearest_remaining() -> Node:
	var best: Node = null
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_in_group("boss") or e.is_in_group("minion"):
			continue
		var d: float = absf(e.global_position.x - player.global_position.x)
		if d < bd:
			bd = d
			best = e
	return best

func _build_barrier() -> void:
	barrier_body = StaticBody2D.new()
	barrier_body.collision_layer = 1
	barrier_body.position = Vector2(barrier_x + 8, 0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(10, map_h * T * 2)
	cs.shape = rs
	barrier_body.add_child(cs)
	add_child(barrier_body)
	var ground_y := 0.0
	for y in range(map_h):
		if cell(int(barrier_x / T), y) == "#":
			ground_y = y * T
			break
	barrier_ground_y = ground_y
	barrier_gate = Game.region_sprite("res://assets/sprites/gate.png", Rect2(0, 0, 32, 160))
	barrier_gate.position = Vector2(barrier_x + 8, ground_y - 40)
	barrier_gate.z_index = 4
	add_child(barrier_gate)
	barrier_glow = ColorRect.new()
	barrier_glow.color = Color(1.0, 0.25, 0.15, 0.25)
	barrier_glow.size = Vector2(18, 90)
	barrier_glow.position = Vector2(barrier_x - 1, ground_y - 90)
	barrier_glow.z_index = 3
	add_child(barrier_glow)
	if remaining_enemies() == 0:
		_open_barrier(true)

func _update_barrier(delta: float) -> void:
	remaining_t -= delta
	if remaining_t <= 0.0:
		remaining_t = 0.25
		remaining_cache = remaining_enemies()
		if hud != null and hud.has_method("set_remaining") and not boss_started:
			hud.set_remaining(remaining_cache, not barrier_open and barrier_x >= 0.0 and player.global_position.x > barrier_x - 220.0)
	if barrier_x < 0.0 or barrier_open:
		return
	if barrier_glow != null:
		barrier_glow.color.a = 0.18 + 0.12 * sin(time_t * 6.0)
	if remaining_cache == 0 and remaining_enemies() == 0:
		_open_barrier(false)
		return
	var near: bool = player.global_position.x > barrier_x - 40.0
	if near:
		blocked_t += delta
		if blocked_t > 0.0 and blocked_t - delta <= 0.0 and hud != null:
			hud.toast("ممنوع تعدّي! لسه فيه %d عدو ورا.. اقضي عليهم الأول" % remaining_cache)
		# stragglers stuck far behind are pulled in so the player is never soft-locked
		if blocked_t > 5.0:
			blocked_t = 0.01
			var pulled := 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.is_in_group("boss") or e.is_in_group("minion"):
					continue
				e.always_chase = true
				if absf(e.global_position.x - player.global_position.x) > 300.0 and pulled < 4:
					pulled += 1
					e.global_position = Vector2(barrier_x - 150.0 - pulled * 30.0, player.global_position.y - 140.0)
					e.velocity = Vector2.ZERO
			if pulled > 0 and hud != null:
				hud.toast("الباقيين جايين لك!")
	else:
		blocked_t = minf(blocked_t, 0.0)
		if player.global_position.x < barrier_x - 160.0:
			blocked_t = 0.0

func _open_barrier(silent: bool) -> void:
	barrier_open = true
	if barrier_body != null:
		barrier_body.queue_free()
		barrier_body = null
	if barrier_glow != null:
		barrier_glow.queue_free()
		barrier_glow = null
	if barrier_gate != null:
		if silent:
			barrier_gate.visible = false
		else:
			var tw := create_tween()
			tw.tween_property(barrier_gate, "position:y", barrier_gate.position.y - 120.0, 0.6).set_trans(Tween.TRANS_BACK)
			tw.tween_property(barrier_gate, "modulate:a", 0.0, 0.3)
	if not silent:
		Audio.sfx("checkpoint")
		shake(3.0)
		if hud != null:
			hud.toast("الطريق اتفتح! الزعيم مستنيك.. ونقطة حفظ قدامك")

func _update_ambush() -> void:
	if ambush.is_empty():
		for a in ambushes:
			if not a.get("started", false) and player.global_position.x > float(a["x"]) - 40.0 and absf(player.global_position.y - float(a["y"])) < 90.0:
				_start_ambush(a)
				break
		return
	var alive := 0
	for e in get_tree().get_nodes_in_group("ambush"):
		if e.is_in_group("enemy"):
			alive += 1
	if alive == 0 and ambush.get("spawned", false):
		ambush["wave"] = int(ambush["wave"]) + 1
		if int(ambush["wave"]) >= int(Game.diff()["waves"]):
			_end_ambush()
		else:
			ambush["spawned"] = false
			_ambush_wave()

func _start_ambush(a: Dictionary) -> void:
	a["started"] = true
	ambush = a
	ambush["wave"] = 0
	ambush["walls"] = []
	for wx in [float(a["l"]), float(a["r"])]:
		var b := StaticBody2D.new()
		b.collision_layer = 1
		b.position = Vector2(wx, 0)
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(8, map_h * T * 2)
		cs.shape = rs
		b.add_child(cs)
		add_child(b)
		var glow := ColorRect.new()
		glow.color = Color(1.0, 0.3, 0.15, 0.3)
		glow.size = Vector2(4, map_h * T)
		glow.position = Vector2(-2, 0)
		b.add_child(glow)
		(ambush["walls"] as Array).append(b)
	player.set_limits(int(a["l"]) - 4, -40, int(a["r"]) + 4, map_h * T)
	Audio.sfx("roar", 0.1, -4)
	shake(3.0)
	if hud != null:
		hud.toast("كمين! اصمد لحد ما تخلّص على كل الموجات")
	_ambush_wave()

func _ambush_wave() -> void:
	var n := int(Game.diff()["wave"]) + chapter / 4 + int(ambush["wave"])
	var letters := ["T", "U", "R", "J", "D"]
	for i in range(n):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x: float = float(ambush["x"]) + side * randf_range(70.0, 170.0)
		x = clampf(x, float(ambush["l"]) + 16.0, float(ambush["r"]) - 16.0)
		var L: String = letters[randi() % letters.size()]
		var kind := Game.roster_sheet(chapter, L)
		var e := spawn_enemy(kind if kind != "" else ENEMY_KEYS[L], Vector2(x, float(ambush["y"]) - 150.0 - i * 12.0), false)
		e.always_chase = true
		e.add_to_group("ambush")
	ambush["spawned"] = true
	if int(ambush["wave"]) > 0 and hud != null:
		hud.toast("الموجة %d!" % (int(ambush["wave"]) + 1))

func _end_ambush() -> void:
	for b in ambush.get("walls", []):
		if is_instance_valid(b):
			b.queue_free()
	waves_done.append(str(ambush["id"]))
	Game.checkpoint_progress(killed_ids, waves_done)
	spawn_pickup("heart", Vector2(float(ambush["x"]), float(ambush["y"]) - 30.0), Vector2(0, -160))
	for i in range(4):
		spawn_pickup("coin", Vector2(float(ambush["x"]), float(ambush["y"]) - 30.0), Vector2(randf_range(-90, 90), randf_range(-240, -160)))
	ambush = {}
	player.set_limits(0, -40, map_w * T, map_h * T)
	Audio.sfx("checkpoint")
	if hud != null:
		hud.toast("عدّيت الكمين! كمّل")

# ---------------------------------------------------------------- boss
func _start_boss() -> void:
	boss_started = true
	var gate := StaticBody2D.new()
	gate.collision_layer = 1
	gate.position = Vector2(gate_x * T + 8, 0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(16, map_h * T * 2)
	cs.shape = rs
	gate.add_child(cs)
	add_child(gate)
	var gs: Sprite2D = Game.region_sprite("res://assets/sprites/gate.png", Rect2(0, 0, 32, 160))
	gs.position = Vector2(gate_x * T + 8, (map_h - 4) * T - 40 - 160)
	add_child(gs)
	var tw := create_tween()
	tw.tween_property(gs, "position:y", float((map_h - 4) * T - 40), 0.35).set_trans(Tween.TRANS_BOUNCE)
	Audio.sfx("slam")
	shake(4.0)
	player.set_limits(gate_x * T, -40, map_w * T, map_h * T)
	boss = BossScript.new()
	boss.setup(chapter)
	boss.level = self
	boss.position = boss_pos
	boss.arena_l = gate_x * T + 16
	boss.arena_r = (map_w - 2) * T
	entities.add_child(boss)
	boss.health_changed.connect(func(h, m): hud.set_boss_hp(h, m))
	boss.defeated.connect(_on_boss_defeated)
	boss.raged.connect(_on_boss_rage)
	Audio.play_music("boss_final" if chapter in [6, 12] else "boss", 0.6)
	if hud != null and hud.has_method("set_remaining"):
		hud.set_remaining(-1, false)
	player.control_locked = true
	player.velocity.x = 0
	hud.dialog(StoryData.BOSS_INTRO[chapter], _on_boss_intro_done)

func _on_boss_intro_done() -> void:
	player.control_locked = false
	hud.show_boss(Game.BOSSES[chapter]["name"], boss.hp, boss.max_hp)
	boss.activate()

func _on_boss_rage() -> void:
	var line: Array = StoryData.BOSS_RAGE[chapter]
	hud.bark(line[0], line[1])

func _on_boss_defeated() -> void:
	boss_done = true
	hud.hide_boss()
	Audio.stop_music(0.4)
	Audio.sfx("victory_hit", 0.0, -2)
	Audio.sfx("checkpoint")
	player.control_locked = true
	if cage != null:
		var tw := create_tween()
		tw.tween_property(cage, "position:y", -200.0, 0.8)
	hud.toast("انتصار!")
	await get_tree().create_timer(2.4).timeout
	Game.chapter_complete()

func _on_player_died() -> void:
	Game.deaths += 1
	hud.toast("وقعت يا بطل.. قوم تاني!")
	await get_tree().create_timer(1.7).timeout
	Game.reload_level()

# ---------------------------------------------------------------- automated smoke test (cmdline: -- --autotest=NAME)
func _autotest() -> void:
	var mode := Game.autotest
	await get_tree().create_timer(0.6).timeout
	if mode.begins_with("ui"):
		# UI review: chapter banner, touch pad, NPC bubble, enemy taunt, dialog box, pause menu
		await get_tree().create_timer(0.5).timeout
		_shot("ui_banner")
		await get_tree().create_timer(2.6).timeout
		_shot("ui_hud")
		var npc = null
		for c in entities.get_children():
			if c.get_script() == NpcScript:
				npc = c
				break
		if npc != null:
			player.global_position = npc.global_position + Vector2(-40, -4)
			await get_tree().create_timer(0.9).timeout
			_shot("ui_npc")
		for n in get_tree().get_nodes_in_group("enemy"):
			if n.has_method("_say"):
				player.global_position = n.global_position + Vector2(-90, -4)
				await get_tree().create_timer(0.25).timeout
				n._say(StoryData.TAUNTS[0])
				await get_tree().create_timer(0.35).timeout
				_shot("ui_taunt")
				break
		player.invuln = 99.0
		hud.dialog(StoryData.BOSS_INTRO[chapter], func(): pass)
		await get_tree().create_timer(2.2).timeout
		_shot("ui_dialog")
		print("AUTOTEST dialog vis=", hud.d_text.visible_characters, " typing=", hud.typing, " ts=", Engine.time_scale, " paused=", get_tree().paused, " pm=", hud.process_mode, " txt=", hud.d_text.text.length(), " pf=", hud.portrait_frame.modulate.a)
		for i in range(3):
			var ev := InputEventAction.new()
			ev.action = "accept"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.1).timeout
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.6).timeout
		_shot("ui_dialog2")
		while hud.dialog_active:
			hud._advance()
			hud._advance()
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.4).timeout
		hud.toggle_pause()
		await get_tree().create_timer(0.4).timeout
		_shot("ui_pause")
		get_tree().quit()
		return
	if mode == "vis":
		await get_tree().create_timer(1.0).timeout
		_shot("vis_a")
		Input.action_press("move_right")
		for i in range(6):
			await get_tree().create_timer(0.15).timeout
			_shot("run%d" % i)
		Input.action_release("move_right")
		await get_tree().create_timer(0.3).timeout
		_shot("vis_b")
		player.global_position += Vector2(300, -40)
		await get_tree().create_timer(1.5).timeout
		_shot("vis_c")
		get_tree().quit()
		return
	if mode == "moves":
		player.debug_boxes = true
		for n in get_tree().get_nodes_in_group("enemy"):
			if n.has_method("hurt_rect"):
				n.set_meta("qa", true)
		await get_tree().create_timer(2.6).timeout
		var e0 = null
		for n in get_tree().get_nodes_in_group("enemy"):
			if n.global_position.x > player.global_position.x + 60:
				e0 = n
				break
		player.global_position = e0.global_position + Vector2(-46, -4)
		player.facing = 1
		await get_tree().create_timer(0.5).timeout
		for i in range(5):
			Input.action_press("attack")
			await get_tree().create_timer(0.04).timeout
			Input.action_release("attack")
			await get_tree().create_timer(0.1).timeout
			_shot("move_combo%d" % i)
			print("AUTOTEST move ", player.move, " anim=", player.sprite.animation)
			await get_tree().create_timer(0.14).timeout
		await get_tree().create_timer(0.5).timeout
		Input.action_press("dash")
		await get_tree().create_timer(0.05).timeout
		Input.action_release("dash")
		Input.action_press("attack")
		await get_tree().create_timer(0.08).timeout
		Input.action_release("attack")
		await get_tree().create_timer(0.02).timeout
		_shot("move_sweep_a")
		print("AUTOTEST sweep_a pos=", player.global_position, " anim=", player.sprite.animation, " f=", player.sprite.frame, " vis=", player.sprite.visible, " ctx=", player.get_global_transform_with_canvas().origin)
		await get_tree().create_timer(0.06).timeout
		_shot("move_sweep")
		print("AUTOTEST move ", player.move, " anim=", player.sprite.animation)
		await get_tree().create_timer(0.6).timeout
		Input.action_press("jump")
		await get_tree().create_timer(0.06).timeout
		Input.action_press("attack")
		await get_tree().create_timer(0.05).timeout
		Input.action_release("attack")
		Input.action_release("jump")
		await get_tree().create_timer(0.1).timeout
		_shot("move_upper")
		print("AUTOTEST move ", player.move, " anim=", player.sprite.animation)
		await get_tree().create_timer(0.9).timeout
		Input.action_press("jump")
		await get_tree().create_timer(0.08).timeout
		Input.action_release("jump")
		await get_tree().create_timer(0.3).timeout
		Input.action_press("attack")
		await get_tree().create_timer(0.05).timeout
		Input.action_release("attack")
		await get_tree().create_timer(0.1).timeout
		_shot("move_fkick")
		print("AUTOTEST move ", player.move, " anim=", player.sprite.animation)
		Input.action_press("attack")
		await get_tree().create_timer(0.05).timeout
		Input.action_release("attack")
		await get_tree().create_timer(0.12).timeout
		_shot("move_slam_air")
		print("AUTOTEST move ", player.move, " anim=", player.sprite.animation)
		await get_tree().create_timer(0.5).timeout
		_shot("move_slam_land")
		print("AUTOTEST move ", player.move, " anim=", player.sprite.animation, " frame=", player.sprite.frame)
		get_tree().quit()
		return
	if mode == "ambush":
		await get_tree().create_timer(2.6).timeout
		var a: Dictionary = ambushes[0]
		player.global_position = Vector2(float(a["x"]) - 80.0, float(a["y"]) - 4.0)
		await get_tree().create_timer(0.3).timeout
		Input.action_press("move_right")
		await get_tree().create_timer(0.6).timeout
		Input.action_release("move_right")
		await get_tree().create_timer(1.6).timeout
		_shot("ambush")
		print("AUTOTEST ambush active=", not ambush.is_empty(), " foes=", get_tree().get_nodes_in_group("ambush").size())
		var guard := 0
		while not ambush.is_empty() and guard < 12:
			guard += 1
			player.invuln = 2.0
			for n in get_tree().get_nodes_in_group("ambush"):
				if n.is_in_group("enemy") and n.is_on_floor():
					n.take_hit(999, 1, null)
			await get_tree().create_timer(1.0).timeout
		print("AUTOTEST ambush cleared=", ambush.is_empty(), " done=", waves_done)
		await get_tree().create_timer(0.4).timeout
		_shot("ambush_done")
		get_tree().quit()
		return
	if mode.begins_with("shot"):
		await get_tree().create_timer(2.6).timeout
		_shot("level_start")
		Input.action_press("move_right")
		await get_tree().create_timer(1.2).timeout
		Input.action_press("jump")
		await get_tree().create_timer(0.25).timeout
		Input.action_release("jump")
		Input.action_press("attack")
		await get_tree().create_timer(0.06).timeout
		_shot("level_jump_attack")
		Input.action_release("attack")
		await get_tree().create_timer(1.2).timeout
		Input.action_release("move_right")
		# warp near first enemy for a fight shot
		var e = null
		for n in get_tree().get_nodes_in_group("enemy"):
			if n.global_position.x > player.global_position.x + 60:
				e = n
				break
		if e != null:
			player.global_position = e.global_position + Vector2(-70, -4)
			await get_tree().create_timer(0.8).timeout
			for i in range(3):
				Input.action_press("attack")
				await get_tree().create_timer(0.05).timeout
				Input.action_release("attack")
				await get_tree().create_timer(0.16).timeout
			_shot("level_fight")
		# checkpoint
		player.global_position = checkpoint_pos + Vector2(-30, -4)
		await get_tree().create_timer(1.0).timeout
		Input.action_press("move_right")
		await get_tree().create_timer(0.4).timeout
		Input.action_release("move_right")
		await get_tree().create_timer(0.3).timeout
		_shot("level_checkpoint")
		print("AUTOTEST checkpoint_active=", Game.checkpoint_active, " idx=", Game.checkpoint_idx)
		# rule: no entering the boss area while fighters are still standing behind
		if barrier_x >= 0.0:
			player.global_position = Vector2(barrier_x - 40.0, barrier_ground_y - 2.0)
			await get_tree().create_timer(0.3).timeout
			Input.action_press("move_right")
			await get_tree().create_timer(1.0).timeout
			Input.action_release("move_right")
			await get_tree().create_timer(0.4).timeout
			print("AUTOTEST barrier_blocked=", player.global_position.x < barrier_x + 4.0, " remaining=", remaining_enemies(), " px=", player.global_position.x, " bx=", barrier_x)
			_shot("barrier_blocked")
			for a in ambushes:
				a["started"] = true
			for n in get_tree().get_nodes_in_group("enemy"):
				if not n.is_in_group("boss"):
					n.take_hit(999, 1, null)
			await get_tree().create_timer(0.8).timeout
			print("AUTOTEST barrier_open=", barrier_open, " remaining=", remaining_enemies())
			_shot("barrier_open")
			if checkpoints.has(2):
				player.global_position = (checkpoints[2] as Node2D).position + Vector2(-30, -4)
				await get_tree().create_timer(0.3).timeout
				Input.action_press("move_right")
				await get_tree().create_timer(0.5).timeout
				Input.action_release("move_right")
				await get_tree().create_timer(0.3).timeout
				print("AUTOTEST preboss_checkpoint idx=", Game.checkpoint_idx, " killed=", Game.cp_killed.size())
				_shot("preboss_checkpoint")
		# boss
		player.global_position = Vector2(gate_x * T + 80, (map_h - 4) * T - 2)
		await get_tree().create_timer(0.8).timeout
		_shot("boss_intro")
		for i in range(14):
			var ev := InputEventAction.new()
			ev.action = "accept"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(2.5).timeout
		_shot("boss_fight")
		# fight: spam attacks next to boss
		var t0 := 0.0
		while is_instance_valid(boss) and not boss_done and t0 < 100.0:
			player.invuln = 2.0
			player.hp = player.max_hp
			if absf(boss.global_position.x - player.global_position.x) > 30:
				var d := signf(boss.global_position.x - player.global_position.x)
				Input.action_release("move_left" if d > 0 else "move_right")
				Input.action_press("move_right" if d > 0 else "move_left")
			else:
				Input.action_release("move_left")
				Input.action_release("move_right")
			Input.action_press("attack")
			await get_tree().create_timer(0.05).timeout
			Input.action_release("attack")
			await get_tree().create_timer(0.12).timeout
			t0 += 0.17
			if int(t0 * 10) == 50:
				_shot("boss_mid")
		Input.action_release("move_left")
		Input.action_release("move_right")
		print("AUTOTEST boss_done=", boss_done, " boss_hp=", boss.hp if is_instance_valid(boss) else -1, " t=", t0)
		await get_tree().create_timer(1.0).timeout
		_shot("boss_end")
		await get_tree().create_timer(2.0).timeout
		print("AUTOTEST done chapter=", chapter, " unlocked=", Game.unlocked)
		get_tree().quit()

func _shot(name: String) -> void:
	print("AUTOTEST state ", name, " pos=", player.global_position, " cam=", player.camera.get_screen_center_position(), " vis=", player.sprite.visible, " inv=", player.invuln, " hp=", player.hp, " dead=", player.dead, " anim=", player.sprite.animation, " sgp=", player.sprite.global_position, " mod=", player.modulate, player.sprite.modulate, " vit=", player.is_visible_in_tree(), " tex=", player.sprite.sprite_frames.get_frame_texture(player.sprite.animation, player.sprite.frame), " par=", player.get_parent().name, " z=", player.z_index, " canvas=", player.sprite.get_global_transform_with_canvas().origin, " vp=", get_viewport().get_visible_rect().size)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://shots/ch%d_%s.png" % [chapter, name]
	DirAccess.make_dir_recursive_absolute("user://shots")
	img.save_png(path)
	print("AUTOTEST shot ", ProjectSettings.globalize_path(path))
