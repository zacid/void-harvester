class_name Settings
extends RefCounted

# === Upgrade tiers ===
# Index = tier. Tier 0 = no auto-gen (manual only).
const TIER_COUNT: int = 4
const UPGRADE_COSTS: Array[int]      = [0,    10,   25,   50]   # cost to reach this tier
const TIER_GEN_RATES: Array[float]   = [0.0,  0.5,  1.0,  2.0]  # drones per second
const TIER_MAX_DRONES: Array[int]    = [999, 999, 999, 999]     # effectively uncapped for now

const UPGRADE_DURATION: float = 5.0  # seconds locked while upgrading

# === Starting tiers per owner ===
const PLAYER_START_TIER: int  = 1
const ENEMY_START_TIER: int   = 2
const NEUTRAL_START_TIER: int = 1

# === Manual production ===
const MANUAL_CLICK_BONUS: int = 1  # drones added per left-click on owned planet

# === Send fraction ===
const SEND_FRACTION_DEFAULT: float = 0.5
const SEND_FRACTION_MIN: float     = 0.1
const SEND_FRACTION_MAX: float     = 1.0
const SEND_FRACTION_STEP: float    = 0.1

# === AI core ===
const AI_TICK_INTERVAL: float       = 2.5     # how often AI considers attacking
const AI_MIN_DRONES_TO_ATTACK: int  = 5

# === AI manual production (human-like clicking — one click at a time) ===
const AI_ENABLE_MANUAL_CLICKS: bool = true
const AI_CLICK_INTERVAL: float      = 0.40    # seconds between clicks (one planet per tick)
const AI_CLICK_FOCUS_CHANCE: float  = 0.55    # chance to keep clicking the same planet (vs moving to next)

# === AI upgrades ===
const AI_ENABLE_UPGRADES: bool      = true
const AI_UPGRADE_CHECK_INTERVAL: float = 5.0  # how often AI considers upgrading
const AI_UPGRADE_CHANCE: float      = 0.65    # probability of acting when an opportunity exists
const AI_UPGRADE_DRONE_RESERVE: int = 6       # AI won't upgrade if it'd leave fewer than this many drones

# === AI defense (reacts to player attacks) ===
const AI_ENABLE_DEFENSE: bool       = true
const AI_DEFENSE_REACTION_TIME: float = 0.7   # seconds of human-like delay before reacting
const AI_DEFENSE_BUFFER: int        = 3       # extra drones beyond just-enough-to-stop-attack
const AI_DEFENSE_TIME_SLACK: float  = 0.5     # ok if reinforcements arrive up to this many sec late

# === Map layout (1600x900 window) ===
const MAP_PLAYER_ZONE: Rect2  = Rect2(120, 220, 200, 560)   # x, y, w, h — left side
const MAP_ENEMY_ZONE: Rect2   = Rect2(1280, 220, 200, 560)  # right side
const MAP_NEUTRAL_ZONE: Rect2 = Rect2(360, 130, 880, 660)   # middle band (clears HUD top-left)
const MAP_MIN_PLANET_DISTANCE: float = 140.0
const MAP_PLACEMENT_ATTEMPTS: int = 200

# === Fleet / Drones ===
const FLEET_SPEED: float = 220.0
const FLEET_SPEED_VARIANCE: float = 0.15      # +/- fraction per drone
const DRONE_SPAWN_INTERVAL: float = 0.02       # seconds between successive drone spawns within one launch
const DRONE_SPAWN_JITTER: float = 14.0         # pixels of random offset around source planet
