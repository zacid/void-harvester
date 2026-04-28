extends Node2D

# Simple gradient bar: solid blue on the player side, solid red on the enemy side,
# with a smooth fade where they meet. The fade position reflects the drone balance.

const BAR_WIDTH: float    = 800.0
const BAR_HEIGHT: float   = 10.0
const BAR_CENTER_X: float = 800.0
const BAR_TOP_Y: float    = 862.0
const FADE_HALF: float    = 60.0   # half-width of the soft transition zone
const SLICES: int         = 80     # number of thin rects used to fake the gradient

const PLAYER_COLOR: Color = Color(0.3, 0.6, 1.0)
const ENEMY_COLOR: Color  = Color(1.0, 0.4, 0.4)

var planets_node: Node2D = null

func _process(_delta: float) -> void:
	queue_redraw()

func _totals() -> Dictionary:
	var p = 0
	var e = 0
	if planets_node != null:
		for planet in planets_node.get_children():
			match planet.owner_type:
				1: p += int(planet.drone_count)
				2: e += int(planet.drone_count)
	return {"player": p, "enemy": e}

func _draw() -> void:
	var t = _totals()
	var sum_d = max(t.player + t.enemy, 1)
	var player_share = float(t.player) / float(sum_d)

	var bar_x = BAR_CENTER_X - BAR_WIDTH * 0.5
	var bar_y = BAR_TOP_Y
	var boundary_x = bar_x + BAR_WIDTH * player_share

	# Outer soft glow
	for i in range(4):
		var pad = float(i + 1) * 2.0
		draw_rect(Rect2(bar_x - pad, bar_y - pad, BAR_WIDTH + pad * 2, BAR_HEIGHT + pad * 2),
			Color(0.4, 0.5, 0.7, 0.04 * (4 - i)))

	# Gradient body — many thin slices with linearly interpolated color
	var slice_w = BAR_WIDTH / float(SLICES)
	for i in range(SLICES):
		var x = bar_x + i * slice_w
		var cx = x + slice_w * 0.5
		var d = cx - boundary_x
		var mix = clamp(d / (FADE_HALF * 2.0) + 0.5, 0.0, 1.0)
		var c = PLAYER_COLOR.lerp(ENEMY_COLOR, mix)
		draw_rect(Rect2(x, bar_y, slice_w + 0.6, BAR_HEIGHT), c)

	# Bright top edge for a thin highlight
	draw_rect(Rect2(bar_x, bar_y, BAR_WIDTH, 1.0), Color(1, 1, 1, 0.45))
