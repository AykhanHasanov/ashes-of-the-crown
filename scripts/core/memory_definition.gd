extends Resource
## One of Ayxan's memories (Yaddaş Yanğını), stored as a .tres under res://data/memories/.
## Text fields are translation keys (res://localization/strings.csv); show them with tr().
## The id is permanent: saves and code refer to memories only by id.

@export var id: StringName
@export var display_name_key: String      # e.g. MEMORY_RUFET_FACE_NAME
@export var description_key: String       # the memory itself
@export var cost_key: String              # what burning it takes away
@export var icon: Texture2D               # none yet
@export var fire_power_value := 75.0      # fire damage the memory feeds (today every memory equals combat.json ember.wave_damage)
@export var order := 0                    # position on the HUD, wheel and journal
