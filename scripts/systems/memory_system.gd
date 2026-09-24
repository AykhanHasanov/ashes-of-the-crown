extends Node
## Yaddaş Yanğını — Ayxan's memories are his fuel. The player chooses which one
## burns for each Alov Dalğası; only Kül Şahı's offer picks one at random.
## Burned memories never come back.
##
## `gifted` will hold memories given by survivors (V2 phase 5); they burn the same way.

signal memory_burned(memory: Dictionary)
signal memories_reset

const MEMORIES := [
	{"id": "rufet_face", "title": "Rüfətin üzü", "text": "Çay kənarında qan qardaşı olduğumuz gün onun gülüşü.",
		"cost": "Rüfəti tanımayacaqsan."},
	{"id": "mother_name", "title": "Anamın adı", "text": "Hər gecə laylamı oxuyan səs. Onun adı...",
		"cost": "Ocaqların istisi daha zəif sağaldacaq."},
	{"id": "sabir_lesson", "title": "Sabirin ilk dərsi", "text": "\"Tac başa deyil, çiyinə qoyulur, şahzadəm.\"",
		"cost": "Mükəmməl yayınma çətinləşəcək."},
	{"id": "kozqala_streets", "title": "Közqalanın küçələri", "text": "Bazarın ədviyyat qoxusu, karvansaranın zəngləri.",
		"cost": "Yol göstərən işarələr sönəcək."},
	{"id": "father_voice", "title": "Atamın səsi", "text": "Kral olmazdan əvvəl, sadəcə ata olduğu illər.",
		"cost": "Əks-sədalar susacaq."},
	{"id": "first_sword", "title": "İlk qılıncım", "text": "Şahbazın mənə bağışladığı taxta qılınc.",
		"cost": "Güclü zərbən zəifləyəcək."},
]

## Kül Şahı grows louder with every burned memory.
const WHISPERS := [
	"...bir az da, balaca şah...",
	"...xatirələr yalnız yükdür...",
	"...onların üzü sənə nə verdi ki?...",
	"...atanı da belə yedim. Yavaş-yavaş...",
	"...tac səni gözləyir. MƏN səni gözləyirəm...",
	"...Ayxan kim idi?...",
]
const GIFT_WHISPER := "...başqasının acısı da dadlıdır..."

var burned: Array[Dictionary] = []
var gifted: Array[Dictionary] = []


func _ready() -> void:
	reset()


func reset() -> void:
	burned.clear()
	gifted.clear()
	memories_reset.emit()


func unburned() -> Array:
	return MEMORIES.filter(func(m): return not is_burned(m["id"]))


func can_burn() -> bool:
	return not unburned().is_empty() or not gifted.is_empty()


func get_memory(id: String) -> Dictionary:
	for m in MEMORIES:
		if m["id"] == id:
			return m
	return {}


## Burns one of Ayxan's own memories by id. Returns it, or {} if it was already gone.
func burn(id: String) -> Dictionary:
	if is_burned(id):
		return {}
	var m := get_memory(id)
	if m.is_empty():
		return {}
	burned.append(m.duplicate())
	memory_burned.emit(m)
	return m


## Kül Şahı chooses: a random unburned memory of Ayxan's own.
func burn_random() -> Dictionary:
	var left := unburned()
	if left.is_empty():
		return {}
	return burn(left.pick_random()["id"])


func is_burned(id: String) -> bool:
	for m in burned:
		if m["id"] == id:
			return true
	return false


func to_dict() -> Dictionary:
	return {"burned": burned.map(func(m): return m["id"])}


func from_dict(data: Dictionary) -> void:
	burned.clear()
	gifted.clear()
	for id in data.get("burned", []):
		var m := get_memory(id)
		if not m.is_empty():
			burned.append(m.duplicate())
	memories_reset.emit()


func whisper() -> String:
	return WHISPERS[clampi(burned.size() - 1, 0, WHISPERS.size() - 1)]
