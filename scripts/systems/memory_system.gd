extends Node
## Yaddaş Yanğını — Ayxan's memories are his fuel. The player chooses which one
## burns for each Alov Dalğası; only Kül Şahı's offer picks one at random.
## Burned memories never come back.
##
## `gifted` will hold memories given by survivors (V2 phase 5); they burn the same way.

signal memory_burned(memory: Dictionary)
signal memories_reset

const MEMORIES := [
	{"id": "rufet_face", "title": "Rüfet'in yüzü", "text": "Nehir kıyısında kan kardeşi olduğumuz gün onun gülüşü.",
		"cost": "Rüfet'i tanımayacaksın."},
	{"id": "mother_name", "title": "Annemin adı", "text": "Her gece ninnimi söyleyen ses. Onun adı...",
		"cost": "Ocakların sıcaklığı daha zayıf iyileştirecek."},
	{"id": "sabir_lesson", "title": "Sabir'in ilk dersi", "text": "\"Taç başa değil, omuza konur, şehzadem.\"",
		"cost": "Kusursuz kaçış zorlaşacak."},
	{"id": "kozqala_streets", "title": "Közkale'nin sokakları", "text": "Çarşının baharat kokusu, kervansarayın çanları.",
		"cost": "Yol gösteren işaretler sönecek."},
	{"id": "father_voice", "title": "Babamın sesi", "text": "Kral olmadan önce, sadece bir baba olduğu yıllar.",
		"cost": "Yankılar susacak."},
	{"id": "first_sword", "title": "İlk kılıcım", "text": "Şahbaz'ın bana hediye ettiği tahta kılıç.",
		"cost": "Ağır darben zayıflayacak."},
]

## Kül Şahı grows louder with every burned memory.
const WHISPERS := [
	"...biraz daha, küçük şah...",
	"...hatıralar sadece yüktür...",
	"...onların yüzü sana ne verdi ki?...",
	"...babanı da böyle yedim. Yavaş yavaş...",
	"...taç seni bekliyor. BEN seni bekliyorum...",
	"...Ayxan kimdi?...",
]
const GIFT_WHISPER := "...başkasının acısı da lezzetli..."

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
