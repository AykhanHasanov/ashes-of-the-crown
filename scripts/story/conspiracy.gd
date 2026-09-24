extends RefCounted
## The Night of Ash conspiracy. One of eight suspects is secretly chosen as the
## traitor each playthrough; the three Kül əks-sədaları (ember echoes) in Közqala
## each reveal one of the traitor's three traits. Every suspect has a unique set
## of three traits, so all three clues always point to exactly one person, while
## one or two clues still leave several suspects standing.

const TRAITS := {
	"boots": {
		"title": "Ağır əsgər çəkməsi",
		"echo": "Taxt salonunun qapısında ağır əsgər çəkmələrinin səsi... Addımlar tələsmir. Bu adam sarayı yaxşı tanıyırdı.",
		"anim": "Walking_A",
	},
	"incense": {
		"title": "Ladan qoxusu",
		"echo": "Alovdan bir an əvvəl havada ladan qoxusu var. Atəşgahlarda yandırılan ağır, şirin ladan.",
		"anim": "Spellcasting",
	},
	"ink": {
		"title": "Mürəkkəbli barmaqlar",
		"echo": "Taxtın söykənəcəyində mürəkkəbli barmaq izləri qalıb. Kim idisə, yanğından az əvvəl nəsə yazırdı.",
		"anim": "Interact",
	},
	"coin": {
		"title": "Yad imperiyanın sikkəsi",
		"echo": "Kraterin kənarında bir sikkə parıldayır: üzərində qonşu imperiyanın qartalı. Bu pul Atəşanda xərclənmir.",
		"anim": "PickUp",
	},
	"fur": {
		"title": "Canavar xəzi",
		"echo": "Kül boz canavar xəzinin liflərini fırladır. Belə xəzi yalnız Qartal Dağlarında geyinirlər.",
		"anim": "Idle",
	},
	"seal": {
		"title": "Kral möhürünün izi",
		"echo": "Ərimiş qızılın içində kral möhürünün izi var. Amma o gecə möhürü daşıyan kral deyildi.",
		"anim": "Use_Item",
	},
	"sulfur": {
		"title": "Kükürd və yaşıl qığılcım",
		"echo": "Alovun rəngi təbii deyil: yaşıl qığılcımlar, kükürd iyi... Bu od kimyagər əli ilə qalanıb.",
		"anim": "Spellcast_Raise",
	},
	"lefthand": {
		"title": "Soldan vurulmuş zərbə",
		"echo": "Keşikçinin cəsədində bıçaq yarası. Zərbə soldan vurulub: qatil solaxaydır.",
		"anim": "1H_Melee_Attack_Stab",
	},
}

const SUSPECTS := {
	"sabir": {"name": "Sabir", "role": "Qoca vəzir", "traits": ["incense", "ink", "seal"]},
	"anar": {"name": "Anar", "role": "Karvan Gildiyasının başçısı", "traits": ["coin", "sulfur", "lefthand"]},
	"elvin": {"name": "Elvin", "role": "Qeyri-qanuni qardaş", "traits": ["ink", "coin", "seal"]},
	"sahbaz": {"name": "Şahbaz", "role": "Sərkərdə", "traits": ["boots", "fur", "lefthand"]},
	"esref": {"name": "Əşrəf", "role": "Qartal Dağlarının bəyi", "traits": ["boots", "fur", "coin"]},
	"rufet": {"name": "Rüfət", "role": "Mühafizə rəisi", "traits": ["boots", "seal", "lefthand"]},
	"ibrahim": {"name": "İbrahim", "role": "Saray alimi, kimyagər", "traits": ["incense", "ink", "sulfur"]},
	"ehliman": {"name": "Əhliman", "role": "Közün Ordeninin baş kahini", "traits": ["incense", "sulfur", "lefthand"]},
}

## Where the three echoes appear in Közqala, in spot order.
const ECHO_SPOTS := [
	{"pos": Vector3(3.8, 0, -13.6), "place": "Taxtın ayağı"},
	{"pos": Vector3(-14.0, 0, -4.0), "place": "Qərb qalereyası"},
	{"pos": Vector3(14.5, 0, 1.5), "place": "Şərq divarı"},
]
