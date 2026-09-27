extends RefCounted
## The three Kül əks-sədaları in Közqala. Each replays a moment of the king's last
## night; together they hint at the truth — he put the crown on knowing it would burn.
## `words` are heard only while "Babamın sesi" is unburned.

const ECHOES := [
	{
		"place": "Tahtın dibi",
		"pos": Vector3(3.8, 0, -13.6),
		"scene": "Kral tacı kendi eliyle başına koyuyor. Taç alev alıyor, ama o geri çekilmiyor.",
		"words": "Bitsin. Benimle birlikte bitsin.",
		"anim": "Use_Item",
	},
	{
		"place": "Batı galerisi",
		"pos": Vector3(-14.0, 0, -4.0),
		"scene": "Kral bir mektup yazıyor. Kâğıt elinde tutuşuyor, o ise yazmaya devam ediyor.",
		"words": "Oğluma... oğluma de ki...",
		"anim": "Interact",
	},
	{
		"place": "Doğu duvarı",
		"pos": Vector3(14.5, 0, 1.5),
		"scene": "Kral duvara yaslanmış, fısıldıyor. Közün ışığında gözleri bomboş.",
		"words": "Adı neydi? Oğlumun adı... neydi?",
		"anim": "Idle",
	},
]

const SILENT := "Dudakları kıpırdıyordu, ama hiçbir şey duymadın."
