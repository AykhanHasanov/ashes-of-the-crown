extends RefCounted
## The eight survivors of Son Ocaq: who they are, how they look (KayKit model,
## hidden meshes, recolor) and where their corner of the camp is.
##
## look: model file, hidden mesh names, recolor [from_min, from_max, to_hue, sat, val] (or [])
## station: [position, idle clip, facing yaw in degrees]

const DIR := "res://assets/characters/adventurers/"

const ORDER := ["rufet", "sabir", "sahbaz", "anar", "elvin", "esref", "ibrahim", "ehliman"]

const PEOPLE := {
	"rufet": {
		"name": "Rüfət", "role": "Mühafizə rəisi",
		"model": "Knight.glb", "hidden": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"],
		"recolor": [], "station": [Vector3(3.0, 0, 13.5), "Idle", 180.0],
		"greet": "Son Ocaq... adı gözəldir, amma içi soyuqdur. Nə lazımdırsa, yanındayam.",
	},
	"sabir": {
		"name": "Sabir", "role": "Qoca vəzir",
		"model": "Mage.glb", "hidden": ["Spellbook_open", "1H_Wand", "2H_Staff"],
		"recolor": [0.55, 0.95, 0.62, 0.8, 0.7], "station": [Vector3(-9.0, 0, -10.5), "Idle", 20.0],
		"greet": "Şahzadəm... sağsan. Bu köhnə gözlər son bir sevinc gördü.",
	},
	"sahbaz": {
		"name": "Şahbaz", "role": "Sərkərdə",
		"model": "Knight.glb", "hidden": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "Round_Shield"],
		"recolor": [0.5, 0.75, 0.0, 0.9, 0.65], "station": [Vector3(-6.0, 0, 11.0), "Sit_Floor_Idle", 60.0],
		"greet": "Ordu dağıldı, şahzadə. Amma mən hələ ayaqdayam. Yaralı, amma ayaqda.",
	},
	"anar": {
		"name": "Anar", "role": "Karvan Gildiyasının başçısı",
		"model": "Rogue.glb", "hidden": ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"],
		"recolor": [0.18, 0.55, 0.1, 1.0, 0.85], "station": [Vector3(12.0, 0, 3.5), "Idle", -90.0],
		"greet": "Karvan yandı, şahzadə. Qırx dəvə, iki yüz çuval. Amma sən sağsan — bu da bir qazancdır.",
	},
	"elvin": {
		"name": "Elvin", "role": "Kralın qeyri-qanuni oğlu",
		"model": "Knight.glb", "hidden": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword", "Round_Shield"],
		"recolor": [0.5, 0.75, 0.8, 1.1, 0.8], "station": [Vector3(-2.5, 0, -12.5), "Idle", 0.0],
		"greet": "Qardaşım. Sağ qalmısan. Heç olmasa kimsə ondan qalıb.",
	},
	"esref": {
		"name": "Əşrəf", "role": "Qartal Dağlarının bəyi",
		"model": "Barbarian.glb", "hidden": ["1H_Axe_Offhand", "Mug", "2H_Axe"],
		"recolor": [], "station": [Vector3(5.5, 0, 8.5), "Sit_Floor_Idle", -150.0],
		"greet": "Qan davamız bitməyib, şahzadə. Amma bu gecə düşmənimiz ortaqdır.",
	},
	"ibrahim": {
		"name": "İbrahim", "role": "Saray alimi, kimyagər",
		"model": "Mage.glb", "hidden": ["Spellbook", "Spellbook_open", "2H_Staff"],
		"recolor": [0.55, 0.95, 0.42, 0.9, 0.65], "station": [Vector3(-12.0, 0, 2.5), "Idle", 90.0],
		"greet": "Köz... sinəndəki köz! Yox, yox, toxunmuram. Sadəcə... heyrətamizdir.",
	},
	"ehliman": {
		"name": "Əhliman", "role": "Közün Ordeninin baş kahini",
		"model": "Mage.glb", "hidden": ["Spellbook", "Spellbook_open", "1H_Wand"],
		"recolor": [0.55, 0.95, 0.02, 1.2, 0.75], "station": [Vector3(8.5, 0, -11.5), "Spellcasting", -20.0],
		"greet": "Közün daşıyıcısı. Od səni seçdi, uşaq. Bunu hiss edirəm.",
	},
}


static func model_path(id: String) -> String:
	return DIR + PEOPLE[id]["model"]


static func display_name(id: String) -> String:
	return PEOPLE[id]["name"]
