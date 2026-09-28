extends RefCounted
## Every tunable number in one place (V2 spec, rule 5). Preload this file and read
## the constants; change values here, not in the systems that use them.

# --- the protagonist ------------------------------------------------------------------------
const PLAYER_HEALTH := 100.0
const PLAYER_SPEED := 6.2
const PLAYER_ACCEL := 50.0
const LUNGE_SPEED := 7.5
const HURT_STUN := 0.25
const HURT_INVULN := 0.4

## Sword combo; impact/cancel are real seconds after the swing starts.
const COMBO := [
	{"clip": "1H_Melee_Attack_Slice_Diagonal", "speed": 1.9, "impact": 0.22, "cancel": 0.34, "damage": 18.0, "knock": 6.0, "dot": 0.4, "range": 2.5, "heavy": false},
	{"clip": "1H_Melee_Attack_Slice_Horizontal", "speed": 1.9, "impact": 0.23, "cancel": 0.36, "damage": 21.0, "knock": 7.0, "dot": 0.35, "range": 2.6, "heavy": false},
	{"clip": "1H_Melee_Attack_Chop", "speed": 1.55, "impact": 0.3, "cancel": 0.5, "damage": 38.0, "knock": 13.0, "dot": 0.25, "range": 2.9, "heavy": true},
]

# --- Kül addımı and the perfect dodge ------------------------------------------------
const DASH_SPEED := 15.0
const DASH_TIME := 0.26
const DASH_COOLDOWN := 0.8
## A dodge started this close to an enemy strike landing counts as perfect.
const PERFECT_WINDOW := 0.12
const PERFECT_SLOWMO_SCALE := 0.3
const PERFECT_SLOWMO_TIME := 0.4
const PERFECT_EMBER := 20.0

# --- Ember meter -----------------------------------------------------------------------
const EMBER_MAX := 100.0
const EMBER_ON_HIT := 6.0
const EMBER_ON_KILL := 10.0
const EMBER_DECAY := 5.0           # per second, out of combat
const EMBER_DECAY_DELAY := 5.0     # seconds without hitting before decay starts

# --- Köz Zərbəsi (tap Q / right mouse) ------------------------------------------------
const TAP_THRESHOLD := 0.25        # shorter press = strike, longer = radial menu
const STRIKE_COST := 50.0
const STRIKE_DAMAGE := 30.0
const STRIKE_RANGE := 4.0
const STRIKE_CONE_DOT := 0.5       # cos(60°): a 120° cone
const STRIKE_KNOCK := 11.0
const STRIKE_COOLDOWN := 0.8

# --- Alov Dalğası (hold Q / right mouse, burns a memory) -----------------------------
const WAVE_DAMAGE := 75.0
const WAVE_RADIUS := 7.0
const WAVE_EDGE_FALLOFF := 0.55
const WAVE_KNOCK := 16.0
const WAVE_COOLDOWN := 1.0
const WAVE_CAST_TRIGGER := 0.26
const WAVE_CAST_TIME := 0.5
const RADIAL_TIME_SCALE := 0.2

# --- Kül Şahının təklifi ---------------------------------------------------------------
const OFFER_HEALTH := 15.0
const OFFER_TIME_SCALE := 0.3
const OFFER_DURATION := 3.0        # real seconds to accept with E

# --- Hearths -------------------------------------------------------------------------------
const HEARTH_RANGE := 2.8
const HEARTH_HEAL := 9.0
const HEARTH_ENEMY_BLOCK := 12.0   # no healing with an enemy this close
const HEARTH_HIT_BLOCK := 4.0      # ...or within this many seconds of being hit

# --- Enemies ---------------------------------------------------------------------------------
## Every telegraph ring grows for WINDUP; during the last UNSTOPPABLE seconds no hit interrupts it.
const WINDUP := 0.9
const UNSTOPPABLE := 0.35
const ENEMIES := {
	"normal": {"health": 40.0, "damage": 12.0, "speed": 3.6, "size": 1.0},
	"fast": {"health": 26.0, "damage": 9.0, "speed": 5.6, "size": 0.95},
	"elite": {"health": 280.0, "damage": 24.0, "speed": 3.2, "size": 1.45},
}
const MAX_ATTACKERS := 2

## Kül Cəngavərinin "Kül Burulğanı": a 360° sweep.
const WHIRL_RADIUS := 3.0
const WHIRL_DAMAGE := 30.0
const WHIRL_TELEGRAPH := 1.2
const WHIRL_HITS_TRIGGER := 3      # hits taken ...
const WHIRL_HITS_WINDOW := 1.5     # ... within this many seconds
const WHIRL_COOLDOWN := 4.0
