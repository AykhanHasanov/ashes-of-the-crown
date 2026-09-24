extends Node
## Yaddaş Yanğını — Ayxan's memories. Every use of the crown's ember burns the
## next memory in the queue. The queue is visible to the player, so each blast
## is an informed sacrifice. Burned memories change dialogue and endings.

signal memory_burned(memory: Dictionary)
signal memories_reset

const MEMORIES := [
	{"id": "rufet_face", "title": "Rüfətin üzü", "text": "Çay kənarında qan qardaşı olduğumuz gün onun gülüşü."},
	{"id": "mother_name", "title": "Anamın adı", "text": "Hər gecə laylamı oxuyan səs. Onun adı..."},
	{"id": "sabir_lesson", "title": "Sabirin ilk dərsi", "text": "\"Tac başa deyil, çiyinə qoyulur, şahzadəm.\""},
	{"id": "kozqala_streets", "title": "Közqalanın küçələri", "text": "Bazarın ədviyyat qoxusu, karvansaranın zəngləri."},
	{"id": "father_voice", "title": "Atamın səsi", "text": "Kral olmazdan əvvəl, sadəcə ata olduğu illər."},
	{"id": "first_sword", "title": "İlk qılıncım", "text": "Şahbazın mənə bağışladığı taxta qılınc."},
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

var queue: Array[Dictionary] = []
var burned: Array[Dictionary] = []


func _ready() -> void:
	reset()


func reset() -> void:
	queue.clear()
	burned.clear()
	for m in MEMORIES:
		queue.append(m.duplicate())
	queue.shuffle()
	# Keep Rüfət's face early in the queue so its consequence is felt in the first chapter.
	for i in queue.size():
		if queue[i]["id"] == "rufet_face":
			var m: Dictionary = queue[i]
			queue.remove_at(i)
			queue.insert(randi_range(0, 2), m)
			break
	memories_reset.emit()


func can_burn() -> bool:
	return not queue.is_empty()


func next_memory() -> Dictionary:
	return queue[0] if not queue.is_empty() else {}


func burn_next() -> Dictionary:
	if queue.is_empty():
		return {}
	var m: Dictionary = queue.pop_front()
	burned.append(m)
	memory_burned.emit(m)
	return m


func is_burned(id: String) -> bool:
	for m in burned:
		if m["id"] == id:
			return true
	return false


func whisper() -> String:
	return WHISPERS[clampi(burned.size() - 1, 0, WHISPERS.size() - 1)]
