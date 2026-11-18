# (loaded via preload in game.gd as HI_BOX)
extends StyleBox
# High-resolution 9-slice frame.
# StyleBoxTexture maps source margins 1:1 to screen margins, so a detailed 4x texture would draw
# huge borders. HiBox draws the nine-patch in a scaled-up space and shrinks it back, so borders
# keep all their detail (crisp on 1080p+ phones) while staying a sane size in the 640x360 UI.

@export var texture: Texture2D
@export var margins := Vector4.ZERO      # source pixels: left, top, right, bottom
@export var ui_scale := 4.0             # source pixels per UI pixel
@export var tint := Color.WHITE
@export var draw_center := true
@export var tile_x := false

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var s := ui_scale
	RenderingServer.canvas_item_set_default_texture_filter(to_canvas_item, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2(1.0 / s, 1.0 / s), 0.0, Vector2.ZERO))
	var r := Rect2(rect.position * s, rect.size * s)
	# never let the borders overlap when the box is smaller than the frame
	var tl := Vector2(margins.x, margins.y)
	var br := Vector2(margins.z, margins.w)
	var fx := minf(1.0, r.size.x / maxf(1.0, tl.x + br.x))
	var fy := minf(1.0, r.size.y / maxf(1.0, tl.y + br.y))
	if fx < 1.0 or fy < 1.0:
		var f := minf(fx, fy)
		RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2(f / s, f / s), 0.0, rect.position * (1.0 - f)))
		r = Rect2(rect.position * s, rect.size * s / f)
	RenderingServer.canvas_item_add_nine_patch(to_canvas_item, r, Rect2(Vector2.ZERO, texture.get_size()), texture.get_rid(),
		tl, br, RenderingServer.NINE_PATCH_TILE_FIT if tile_x else RenderingServer.NINE_PATCH_STRETCH,
		RenderingServer.NINE_PATCH_STRETCH, draw_center, tint)
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D())
