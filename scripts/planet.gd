extends Area2D

enum Owner { NEUTRAL, PLAYER, ENEMY }

@export var owner_type: Owner = Owner.NEUTRAL
@export var drone_count: float = 10.0
@export var upgrade_tier: int = 1

const PLANET_RADIUS: float = 36.0
const SURFACE_SPOTS: int = 6

var selected: bool = false
var current_color: Color = Color(0.55, 0.5, 0.6)
var pulse_phase: float = 0.0
var surface_offsets: Array = []
var displayed_send_fraction: float = 0.5

# Upgrade state
var is_upgrading: bool = false
var upgrade_progress: float = 0.0  # 0.0 -> 1.0

# Mining drones
var miner_count: int = 0
var mine_phase: float = 0.0

@onready var label: Label = $Label

signal owner_changed(planet, new_owner)
signal planet_left_clicked(planet, double_click)
signal planet_right_clicked(planet)

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in range(SURFACE_SPOTS):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(6.0, PLANET_RADIUS - 8.0)
		var size = rng.randf_range(2.5, 5.5)
		surface_offsets.append({"pos": Vector2(cos(angle) * dist, sin(angle) * dist), "size": size})
	update_visuals()

func _process(delta: float) -> void:
	if is_upgrading:
		upgrade_progress += delta / Settings.UPGRADE_DURATION
		if upgrade_progress >= 1.0:
			_finish_upgrade()
		queue_redraw()
	else:
		if owner_type != Owner.NEUTRAL:
			var rate = Settings.TIER_GEN_RATES[upgrade_tier]
			if rate > 0.0:
				drone_count = minf(drone_count + rate * delta, float(get_max_drones()))
	if selected:
		pulse_phase += delta
		queue_redraw()
	if miner_count > 0:
		mine_phase += delta
		queue_redraw()
	update_visuals()

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			planet_left_clicked.emit(self, event.double_click)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			planet_right_clicked.emit(self)
			get_viewport().set_input_as_handled()

# === Drone economy ===

func get_max_drones() -> int:
	return Settings.TIER_MAX_DRONES[upgrade_tier]

func produce_manual() -> bool:
	if is_upgrading or owner_type == Owner.NEUTRAL:
		return false
	drone_count = minf(drone_count + Settings.MANUAL_CLICK_BONUS, float(get_max_drones()))
	_spawn_manual_gain_popup(Settings.MANUAL_CLICK_BONUS)
	update_visuals()
	return true

func _spawn_manual_gain_popup(amount: int) -> void:
	var popup := Label.new()
	popup.text = "+%d" % amount
	popup.position = Vector2(-16.0, -PLANET_RADIUS - 24.0)
	popup.modulate = Color(0.7, 1.0, 1.0, 1.0)
	popup.add_theme_color_override("font_color", Color(0.7, 1.0, 1.0))
	popup.add_theme_color_override("font_outline_color", Color(0.0, 0.15, 0.2))
	popup.add_theme_constant_override("outline_size", 3)
	popup.add_theme_font_size_override("font_size", 18)
	add_child(popup)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 26.0, 0.35)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35)
	tween.finished.connect(popup.queue_free)

# === Mining ===

func get_max_miners() -> int:
	return Settings.TIER_MINER_MAX[upgrade_tier]

func convert_to_miner() -> bool:
	if owner_type == Owner.NEUTRAL:
		return false
	if miner_count >= get_max_miners():
		return false
	if drone_count < 1.0:
		return false
	drone_count -= 1.0
	miner_count += 1
	update_visuals()
	return true

# Returns cores generated this frame — called by main.gd each _process tick.
func drain_cores(delta: float) -> float:
	if miner_count <= 0:
		return 0.0
	return miner_count * Settings.MINER_CORE_RATE * delta

# === Upgrade ===

func can_upgrade() -> bool:
	if is_upgrading:
		return false
	if owner_type == Owner.NEUTRAL:
		return false
	if upgrade_tier >= Settings.TIER_COUNT - 1:
		return false
	return true  # core cost is checked externally by main.gd

func upgrade_core_cost() -> int:
	if upgrade_tier >= Settings.TIER_COUNT - 1:
		return -1
	return Settings.UPGRADE_CORE_COSTS[upgrade_tier + 1]

func start_upgrade() -> bool:
	if not can_upgrade():
		return false
	is_upgrading = true
	upgrade_progress = 0.0
	update_visuals()
	return true

func _finish_upgrade() -> void:
	upgrade_tier += 1
	# Cap miners to new tier's limit (in case it's lower, though it never is here)
	miner_count = mini(miner_count, get_max_miners())
	is_upgrading = false
	upgrade_progress = 0.0
	update_visuals()

func _cancel_upgrade() -> void:
	# No refund — used when planet flips owner mid-upgrade
	is_upgrading = false
	upgrade_progress = 0.0

# === Combat ===

func receive_fleet(count: int, attacking_owner: int) -> void:
	if attacking_owner == owner_type:
		drone_count = minf(drone_count + count, float(get_max_drones()))
	else:
		drone_count -= count
		if drone_count < 0:
			owner_type = attacking_owner
			drone_count = absf(drone_count)
			miner_count = 0  # miners die when planet is captured
			if is_upgrading:
				_cancel_upgrade()
			owner_changed.emit(self, owner_type)
	update_visuals()

# === Drawing ===

func update_visuals() -> void:
	if not label:
		return
	if miner_count > 0:
		label.text = "%d·%d" % [int(drone_count), miner_count]
	else:
		label.text = str(int(drone_count))
	match owner_type:
		Owner.NEUTRAL:
			current_color = Color(0.55, 0.5, 0.6)
		Owner.PLAYER:
			current_color = Color(0.3, 0.55, 1.0)
		Owner.ENEMY:
			current_color = Color(0.95, 0.35, 0.35)
	queue_redraw()

func _draw() -> void:
	var center = Vector2.ZERO
	var c = current_color
	var dim = 0.55 if is_upgrading else 1.0  # planet dims while upgrading

	# Atmospheric glow (layered)
	draw_circle(center, PLANET_RADIUS + 18.0, Color(c.r, c.g, c.b, 0.06 * dim))
	draw_circle(center, PLANET_RADIUS + 12.0, Color(c.r, c.g, c.b, 0.12 * dim))
	draw_circle(center, PLANET_RADIUS + 6.0,  Color(c.r, c.g, c.b, 0.22 * dim))

	# Planet body (dimmed during upgrade)
	draw_circle(center, PLANET_RADIUS, Color(c.r * dim, c.g * dim, c.b * dim, 1.0))

	# Surface details
	var spot_color = Color(c.r * 0.45 * dim, c.g * 0.45 * dim, c.b * 0.5 * dim, 0.75)
	for spot in surface_offsets:
		draw_circle(spot.pos, spot.size, spot_color)

	# Highlight (top-left sphere feel)
	draw_circle(Vector2(-PLANET_RADIUS * 0.4, -PLANET_RADIUS * 0.4), PLANET_RADIUS * 0.22, Color(1, 1, 1, 0.18 * dim))

	# Owner-tinted rim
	draw_arc(center, PLANET_RADIUS - 1.0, 0.0, TAU, 64, c.lightened(0.4), 2.0, true)

	# Tier indicator (small bright dots above the planet)
	_draw_tier_dots(center)

	# Orbiting miner drones (drawn before UI rings so rings overlay them)
	_draw_miners(center)

	# Selected pulsing ring (gentler pulse — stays visible throughout)
	if selected:
		var pulse_alpha = (0.78 + 0.22 * sin(pulse_phase * 4.0)) * (0.45 if is_upgrading else 1.0)
		draw_arc(center, PLANET_RADIUS + 8.0, 0.0, TAU, 64, Color(1.0, 0.95, 0.3, pulse_alpha), 2.5, true)

	# Upgrade progress ring (amber)
	if is_upgrading:
		_draw_upgrade_ring(center)

	# Send-amount ring (only when selected and NOT upgrading)
	if selected and not is_upgrading:
		_draw_send_ring(center)

func _draw_miners(center: Vector2) -> void:
	if miner_count <= 0:
		return
	var r = Settings.MINER_ORBIT_RADIUS
	var col = Color(1.0, 0.78, 0.15)  # amber-gold, same particle style as flying drones
	var spacing = TAU / float(miner_count)
	for i in range(miner_count):
		var angle = mine_phase * Settings.MINER_ORBIT_SPEED + spacing * i
		var pos = center + Vector2(cos(angle), sin(angle)) * r
		draw_circle(pos, 5.5, Color(col.r, col.g, col.b, 0.18))  # outer glow halo
		draw_circle(pos, 3.0, Color(col.r, col.g, col.b, 0.75))  # body
		draw_circle(pos, 1.5, Color(1.0, 1.0, 0.85, 0.95))       # bright core

func _draw_tier_dots(center: Vector2) -> void:
	# Show one dot per tier above tier 0 (so tier 1 = 1 dot, etc.)
	var dots_to_draw = upgrade_tier
	if dots_to_draw <= 0:
		return
	var spacing = 8.0
	var total_width = (dots_to_draw - 1) * spacing
	var y = -PLANET_RADIUS - 10.0
	var color = Color(1.0, 0.95, 0.7, 0.95)
	for i in range(dots_to_draw):
		var x = -total_width / 2.0 + i * spacing
		draw_circle(Vector2(x, y), 2.5, color)
		draw_circle(Vector2(x, y), 4.5, Color(color.r, color.g, color.b, 0.25))

func _draw_send_ring(center: Vector2) -> void:
	var ring_radius = PLANET_RADIUS + 20.0
	var start_angle = -PI / 2.0
	var end_angle = start_angle + displayed_send_fraction * TAU
	draw_arc(center, ring_radius, 0.0, TAU, 72, Color(0.4, 0.7, 0.85, 0.18), 2.0, true)
	draw_arc(center, ring_radius, start_angle, end_angle, 56, Color(0.4, 1.0, 1.0, 0.22), 9.0, true)
	draw_arc(center, ring_radius, start_angle, end_angle, 56, Color(0.55, 1.0, 1.0, 0.5), 5.0, true)
	draw_arc(center, ring_radius, start_angle, end_angle, 56, Color(0.9, 1.0, 1.0, 0.95), 2.4, true)
	var tip = center + Vector2(cos(end_angle), sin(end_angle)) * ring_radius
	draw_circle(tip, 6.0, Color(0.6, 1.0, 1.0, 0.35))
	draw_circle(tip, 3.5, Color(1.0, 1.0, 1.0, 1.0))

func _draw_upgrade_ring(center: Vector2) -> void:
	var ring_radius = PLANET_RADIUS + 14.0
	var start_angle = -PI / 2.0
	var end_angle = start_angle + upgrade_progress * TAU
	# Background full ring
	draw_arc(center, ring_radius, 0.0, TAU, 72, Color(1.0, 0.6, 0.2, 0.18), 2.5, true)
	# Layered amber glow for the filled portion
	draw_arc(center, ring_radius, start_angle, end_angle, 56, Color(1.0, 0.55, 0.15, 0.22), 10.0, true)
	draw_arc(center, ring_radius, start_angle, end_angle, 56, Color(1.0, 0.7,  0.25, 0.55), 6.0, true)
	draw_arc(center, ring_radius, start_angle, end_angle, 56, Color(1.0, 0.85, 0.5,  0.95), 3.0, true)
	# Leading-edge spark
	var tip = center + Vector2(cos(end_angle), sin(end_angle)) * ring_radius
	draw_circle(tip, 7.0, Color(1.0, 0.7, 0.3, 0.4))
	draw_circle(tip, 4.0, Color(1.0, 1.0, 0.85, 1.0))
