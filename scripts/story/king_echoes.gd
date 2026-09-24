extends RefCounted
## The three Kül əks-sədaları in Közqala. Each replays a moment of the king's last
## night; together they hint at the truth — he put the crown on knowing it would burn.
## `words` are heard only while "Atamın səsi" is unburned.

const ECHOES := [
	{
		"place": "Taxtın ayağı",
		"pos": Vector3(3.8, 0, -13.6),
		"scene": "Kral tacı öz əli ilə başına qoyur. Tac alışır, amma o geri çəkilmir.",
		"words": "Bitsin. Mənimlə birlikdə bitsin.",
		"anim": "Use_Item",
	},
	{
		"place": "Qərb qalereyası",
		"pos": Vector3(-14.0, 0, -4.0),
		"scene": "Kral məktub yazır. Kağız əlində alışır, o isə yazmağa davam edir.",
		"words": "Oğluma... oğluma de ki...",
		"anim": "Interact",
	},
	{
		"place": "Şərq divarı",
		"pos": Vector3(14.5, 0, 1.5),
		"scene": "Kral divara söykənib pıçıldayır. Közün işığında gözləri boşdur.",
		"words": "Adı nə idi? Oğlumun adı... nə idi?",
		"anim": "Idle",
	},
]

const SILENT := "Dodaqları tərpənirdi, amma heç nə eşitmədin."
