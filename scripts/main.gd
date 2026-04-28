extends Node2D

@export var fleet_scene: PackedScene

@onready var planets_container: Node2D = $Planets
@onready var fleets_container: Node2D = $Fleets
@onready var hud_label: Label = $HUD/Label
@onready var send_label: Label = $HUD/SendLabel
@onready var upgrade_label: Label = $HUD/UpgradeLabel
@onready var upgrade_button: Button = $HUD/UpgradeButton
@onready var balance_bar: Node2D = $HUD/BalanceBar
@onready var ai_timer: Timer = $AITimer

var selected_planet = null
var game_over: bool = false
var send_fraction: float = Settings.SEND_FRACTION_DEFAULT

func _ready() -> void:
	_randomize_planet_positions()
	balance_bar.planets_node = planets_container
	for planet in get_planets():
		planet.owner_changed.connect(_on_owner_changed)
		planet.planet_left_clicked.connect(_on_planet_left_clicked)
		planet.planet_right_clicked.connect(_on_planet_right_clicked)
	ai_timer.timeout.connect(_on_ai_timer_timeout)
	ai_timer.wait_time = Settings.AI_TICK_INTERVAL
	ai_timer.start()
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	hud_label.text = ""
	_refresh_hud()

func _randomize_planet_positions() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var player_planet = null
	var enemy_planet = null
	var neutrals: Array = []
	for p in get_planets():
		match p.owner_type:
			p.Owner.PLAYER: player_planet = p
			p.Owner.ENEMY:  enemy_planet = p
			_: neutrals.append(p)
	var placed: Array = []
	if player_planet != null:
		player_planet.position = _pick_position_in_zone(rng, Settings.MAP_PLAYER_ZONE, placed)
		placed.append(player_planet.position)
	if enemy_planet != null:
		enemy_planet.position = _pick_position_in_zone(rng, Settings.MAP_ENEMY_ZONE, placed)
		placed.append(enemy_planet.position)
	for n in neutrals:
		n.position = _pick_position_in_zone(rng, Settings.MAP_NEUTRAL_ZONE, placed)
		placed.append(n.position)

func _pick_position_in_zone(rng: RandomNumberGenerator, zone: Rect2, placed: Array) -> Vector2:
	var min_d = Settings.MAP_MIN_PLANET_DISTANCE
	var best = Vector2(zone.position.x + zone.size.x * 0.5, zone.position.y + zone.size.y * 0.5)
	for _attempt in range(Settings.MAP_PLACEMENT_ATTEMPTS):
		var candidate = Vector2(
			rng.randf_range(zone.position.x, zone.position.x + zone.size.x),
			rng.randf_range(zone.position.y, zone.position.y + zone.size.y)
		)
		var ok = true
		for other in placed:
			if candidate.distance_to(other) < min_d:
				ok = false
				break
		if ok:
			return candidate
		best = candidate  # fall back to last attempt
	return best

func _process(_delta: float) -> void:
	if selected_planet != null:
		_refresh_hud()

func _input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_send(Settings.SEND_FRACTION_STEP)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_send(-Settings.SEND_FRACTION_STEP)
			return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Ignore world-click deselect when the mouse is over HUD controls.
			if get_viewport().gui_get_hovered_control() != null:
				return
			# Empty-space deselect using a geometric check — doesn't depend on
			# Godot's input-handled flag, which can be unreliable from Area2D._input_event.
			if not _click_was_on_planet():
				_deselect()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			_adjust_send(Settings.SEND_FRACTION_STEP)
		elif event.keycode == KEY_DOWN:
			_adjust_send(-Settings.SEND_FRACTION_STEP)

func _click_was_on_planet() -> bool:
	var pos = get_global_mouse_position()
	for planet in get_planets():
		if pos.distance_to(planet.global_position) <= planet.PLANET_RADIUS:
			return true
	return false

# === Planet click handlers ===

func _on_planet_left_clicked(planet, _double_click: bool) -> void:
	if game_over:
		return
	if planet.owner_type != planet.Owner.PLAYER:
		return
	# Left-click: select + produce one drone.
	_select(planet)
	planet.produce_manual()
	_refresh_hud()

func _on_planet_right_clicked(planet) -> void:
	if game_over:
		return
	if selected_planet == null or planet == selected_planet:
		return
	if selected_planet.is_upgrading:
		return
	launch_fleet(selected_planet, planet)

# === Selection ===

func _select(planet) -> void:
	if selected_planet == planet:
		return
	if selected_planet != null:
		selected_planet.selected = false
		selected_planet.update_visuals()
	selected_planet = planet
	planet.selected = true
	planet.displayed_send_fraction = send_fraction
	planet.update_visuals()
	_refresh_hud()

func _deselect() -> void:
	if selected_planet == null:
		return
	selected_planet.selected = false
	selected_planet.update_visuals()
	selected_planet = null
	_refresh_hud()

# === Send fraction ===

func _adjust_send(delta: float) -> void:
	send_fraction = clampf(send_fraction + delta, Settings.SEND_FRACTION_MIN, Settings.SEND_FRACTION_MAX)
	send_fraction = round(send_fraction * 10.0) / 10.0
	if selected_planet != null:
		selected_planet.displayed_send_fraction = send_fraction
		selected_planet.queue_redraw()
	_refresh_hud()

# === Fleet launch ===

func launch_fleet(source, target) -> void:
	if source.is_upgrading:
		return
	var fraction = send_fraction if source.owner_type == source.Owner.PLAYER else 0.5
	var count = int(source.drone_count * fraction)
	if count < 1:
		return
	source.drone_count -= count
	var spawn_pos = source.global_position
	var owner_val = source.owner_type
	if source == selected_planet:
		_refresh_hud()
	# Spawn N individual drones, staggered, so they stream out like a swarm.
	for i in range(count):
		if not is_instance_valid(target):
			return
		_spawn_drone(spawn_pos, target, owner_val)
		if i < count - 1:
			await get_tree().create_timer(Settings.DRONE_SPAWN_INTERVAL).timeout

func _spawn_drone(from_pos: Vector2, target, owner_val: int) -> void:
	var drone = fleet_scene.instantiate()
	fleets_container.add_child(drone)
	drone.init(from_pos, target, owner_val)

# === HUD ===

func _refresh_hud() -> void:
	if not send_label or not upgrade_label or not upgrade_button:
		return
	var pct = int(round(send_fraction * 100.0))
	if selected_planet != null:
		var n = int(selected_planet.drone_count * send_fraction)
		send_label.text = "Send: %d%%  (%d drones)" % [pct, n]
		upgrade_label.text = _upgrade_status_text(selected_planet)
		_refresh_upgrade_button(selected_planet)
	else:
		send_label.text = "Send: %d%%" % pct
		upgrade_label.text = ""
		upgrade_button.text = "Upgrade"
		upgrade_button.disabled = true

func _refresh_upgrade_button(planet) -> void:
	if planet.owner_type != planet.Owner.PLAYER:
		upgrade_button.text = "Upgrade"
		upgrade_button.disabled = true
		return
	if planet.is_upgrading:
		upgrade_button.text = "Upgrading..."
		upgrade_button.disabled = true
		return
	if planet.upgrade_tier >= Settings.TIER_COUNT - 1:
		upgrade_button.text = "Max Tier"
		upgrade_button.disabled = true
		return
	var cost = planet.upgrade_cost()
	upgrade_button.text = "Upgrade (%d)" % cost
	upgrade_button.disabled = planet.drone_count < cost

func _on_upgrade_button_pressed() -> void:
	if game_over:
		return
	if selected_planet == null:
		return
	if selected_planet.start_upgrade():
		_refresh_hud()

func _upgrade_status_text(planet) -> String:
	if planet.owner_type != planet.Owner.PLAYER:
		return ""
	if planet.is_upgrading:
		var pct = int(round(planet.upgrade_progress * 100.0))
		return "Upgrading…  %d%%" % pct
	if planet.upgrade_tier >= Settings.TIER_COUNT - 1:
		return "Tier %d  (max)" % planet.upgrade_tier
	var cost = planet.upgrade_cost()
	if planet.drone_count >= cost:
		return "Tier %d  →  Tier %d  (button, cost %d)" % [planet.upgrade_tier, planet.upgrade_tier + 1, cost]
	return "Tier %d  →  Tier %d  (need %d drones)" % [planet.upgrade_tier, planet.upgrade_tier + 1, cost]

# === Win/lose ===

func get_planets() -> Array:
	return planets_container.get_children()

func _on_owner_changed(_planet, _new_owner) -> void:
	check_win_lose()

func check_win_lose() -> void:
	var player_count = 0
	var enemy_count = 0
	for planet in get_planets():
		if planet.owner_type == planet.Owner.PLAYER:
			player_count += 1
		elif planet.owner_type == planet.Owner.ENEMY:
			enemy_count += 1
	if enemy_count == 0 and player_count > 0:
		game_over = true
		hud_label.text = "YOU WIN!\nPress R to restart"
	elif player_count == 0:
		game_over = true
		hud_label.text = "GAME OVER\nPress R to restart"

# === AI ===

func _on_ai_timer_timeout() -> void:
	if game_over:
		return
	var enemy_planets: Array = []
	var target_planets: Array = []
	for planet in get_planets():
		if planet.owner_type == planet.Owner.ENEMY:
			if not planet.is_upgrading:
				enemy_planets.append(planet)
		else:
			target_planets.append(planet)
	if enemy_planets.is_empty() or target_planets.is_empty():
		return
	enemy_planets.sort_custom(func(a, b): return a.drone_count > b.drone_count)
	var source = enemy_planets[0]
	if source.drone_count < Settings.AI_MIN_DRONES_TO_ATTACK:
		return
	target_planets.sort_custom(func(a, b):
		return a.global_position.distance_to(source.global_position) < b.global_position.distance_to(source.global_position)
	)
	launch_fleet(source, target_planets[0])
