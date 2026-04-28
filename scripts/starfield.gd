extends Node2D

const STAR_COUNT: int = 320
const NEBULA_BLOBS: int = 6

var stars: Array = []
var nebula: Array = []
var twinkle_time: float = 0.0

func _ready() -> void:
	# Fresh randomization every run — different starfield + nebula each game
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(STAR_COUNT):
		stars.append({
			"pos": Vector2(rng.randf() * 1600.0, rng.randf() * 900.0),
			"size": rng.randf_range(0.4, 1.9),
			"alpha": rng.randf_range(0.25, 0.95),
			"speed": rng.randf_range(0.6, 2.4),
			"phase": rng.randf() * TAU
		})
	# Faint nebula tints scattered around
	var hues = [
		Color(0.35, 0.15, 0.55),
		Color(0.1, 0.25, 0.55),
		Color(0.55, 0.2, 0.4),
		Color(0.2, 0.45, 0.55),
		Color(0.45, 0.25, 0.6)
	]
	for i in range(NEBULA_BLOBS):
		nebula.append({
			"pos": Vector2(rng.randf() * 1600.0, rng.randf() * 900.0),
			"radius": rng.randf_range(160.0, 280.0),
			"color": hues[i % hues.size()]
		})
	queue_redraw()

func _process(delta: float) -> void:
	twinkle_time += delta
	queue_redraw()

func _draw() -> void:
	# Soft nebula blobs (concentric circles, very transparent)
	for blob in nebula:
		var c = blob.color
		for layer in range(4):
			var r = blob.radius * (1.0 - layer * 0.22)
			var a = 0.025 + layer * 0.015
			draw_circle(blob.pos, r, Color(c.r, c.g, c.b, a))
	# Stars with subtle twinkle
	for star in stars:
		var t = 0.7 + 0.3 * sin(twinkle_time * star.speed + star.phase)
		var a = star.alpha * t
		draw_circle(star.pos, star.size, Color(1.0, 1.0, 1.0, a))
