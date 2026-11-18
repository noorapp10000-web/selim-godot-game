extends Node
# Visual QA: for each chapter, park the camera on a raised ledge / platform and save a screenshot
# (user://shots/tiles_chN.png) so tile edges, plank platforms and floor seams can be inspected.
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	for ch in range(1, 13):
		Game.autotest = ""
		Game.chapter = ch
		Game.clear_checkpoint()
		var level = load("res://scenes/Level.tscn").instantiate()
		add_child(level)
		await get_tree().create_timer(0.3).timeout
		level.hud.visible = false
		for c in level.hud.get_children():
			if c is CanvasItem:
				c.visible = false
		# first spot (after the start) where a block ledge and a plank platform are both near
		var px := 40
		for x in range(40, level.map_w - 40):
			var has_plank := false
			var has_step := false
			for y in range(level.map_h):
				if level.cell(x, y) == "=":
					has_plank = true
				if level.cell(x, y) == "#" and level.cell(x, y - 1) == " " and level.cell(x - 1, y) == " ":
					has_step = true
			if has_plank and has_step:
				px = x
				break
		var p = level.player
		p.control_locked = true
		p.invuln = 99.0
		var gy := 0
		for y in range(level.map_h):
			if level.cell(px - 3, y) == "#":
				gy = y
				break
		p.global_position = Vector2((px - 3) * level.T + 8, gy * level.T - 1)
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/tiles_ch%d.png" % ch)
		print("TILES ch", ch, " x=", px)
		level.queue_free()
		await get_tree().create_timer(0.2).timeout
	get_tree().quit()
