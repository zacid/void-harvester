extends Node2D

# Each instance represents ONE drone. A "fleet" is many of these spawned in sequence.

const TRAIL_LENGTH: int = 8
const TRAIL_SAMPLE_INTERVAL: float = 0.025

var target_planet: Node
var fleet_owner: int = 0
var speed: float = 220.0
var color: Color = Color(0.7, 0.7, 0.7)
var trail: Array = []
var sample_timer: float = 0.0

func init(from_pos: Vector2, target: Node, owner_val: int) -> void:
	var jitter = Settings.DRONE_SPAWN_JITTER
	position = from_pos + Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	target_planet = target
	fleet_owner = owner_val
	var v = Settings.FLEET_SPEED_VARIANCE
	speed = Settings.FLEET_SPEED * randf_range(1.0 - v, 1.0 + v)
	_update_color()

func _ready() -> void:
	_update_color()

func _update_color() -> void:
	match fleet_owner:
		1:
			color = Color(0.4, 0.7, 1.0)
		2:
			color = Color(1.0, 0.45, 0.45)
		_:
			color = Color(0.75, 0.75, 0.75)

func _draw() -> void:
	# Trail (older = fainter, smaller)
	var n = trail.size()
	for i in range(n):
		var t = float(i + 1) / float(n)
		var local_pos = trail[i] - global_position
		var size = 0.6 + t * 1.6
		draw_circle(local_pos, size, Color(color.r, color.g, color.b, t * 0.4))

	# The drone itself: small halo + bright core
	draw_circle(Vector2.ZERO, 4.5, Color(color.r, color.g, color.b, 0.18))
	draw_circle(Vector2.ZERO, 2.8, Color(color.r, color.g, color.b, 0.55))
	draw_circle(Vector2.ZERO, 1.6, Color(1.0, 1.0, 1.0, 0.95))

func _process(delta: float) -> void:
	if not is_instance_valid(target_planet):
		queue_free()
		return

	sample_timer += delta
	if sample_timer >= TRAIL_SAMPLE_INTERVAL:
		sample_timer = 0.0
		trail.append(global_position)
		if trail.size() > TRAIL_LENGTH:
			trail.pop_front()

	position = position.move_toward(target_planet.global_position, speed * delta)
	queue_redraw()

	if position.distance_to(target_planet.global_position) < 5.0:
		target_planet.receive_fleet(1, fleet_owner)
		queue_free()
