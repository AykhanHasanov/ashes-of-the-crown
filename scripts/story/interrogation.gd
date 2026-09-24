extends RefCounted
## Chapter 2 people and interrogations. Each suspect has a look (KayKit model,
## recolor, props), a camp station, and lines: a warm and a cold greeting, an alibi
## (with an evasive variant used when they are the traitor), an answer for each of
## their own traits (innocent / guilty), a denial for traits that are not theirs,
## a confession when rightly accused and a protest when wrongly accused.
##
## build(id) turns this data into a dialogue for scripts/ui/dialogue_ui.gd, taking
## the hidden traitor, the clues found and the suspect's trust into account.

const Conspiracy := preload("res://scripts/story/conspiracy.gd")
const DIR := "res://assets/characters/adventurers/"

## look: model, hidden meshes, recolor [from_min, from_max, to_hue, sat, val] (or []),
## station: [position, idle clip, facing yaw in degrees]
const PEOPLE := {
	"sabir": {
		"model": "Mage.glb", "hidden": ["Spellbook_open", "1H_Wand", "2H_Staff"],
		"recolor": [0.55, 0.95, 0.62, 0.8, 0.7],
		"station": [Vector3(-9.0, 0, -10.5), "Idle", 20.0],
		"greet": "Şahzadəm... sağsan. Allah bu köhnə gözlərə son bir sevinc göstərdi.",
		"cold": "Ayxan. Deyirlər, o köz səni dəyişib. Görürəm ki, doğrudur.",
		"alibi": "Kül Gecəsi kitabxanada idim. Rüfəti aşağı şəhərə mən göndərdim — kraldan gələn möhürlü məktubla.",
		"alibi_guilty": "Kitabxanada... bəli, kitabxanada idim. Səhərə qədər. Heç kəs görmədi, çünki... hamı yatırdı.",
		"traits": {
			"incense": ["Ladan? Qırx ildir hər səhər atəşgahda dua edirəm. Cübbəm ladansız qalmayıb.", "Ladan... O gecə atəşgaha getmədim. Yox — getdim. Bu nə sualdır, şahzadəm?"],
			"ink": ["Mürəkkəb vəzirin qanıdır. O gecə kralın son fərmanını üzü köçürürdüm.", "Barmaqlarım? Yazırdım, təbii ki. Nə yazdığımı isə soruşma."],
			"seal": ["Kral möhürünün ikinci nüsxəsi qanunla məndə idi. Rüfətin daşıdığı məktubu da mən möhürlədim.", "Möhür məndə idi, bəli. Amma kim deyir ki, o gecə onu mən işlətdim?"],
		},
		"deny": "Bu iz mənə aid deyil, şahzadəm. Soyuq düşün — atan kimi.",
		"confess": "Atan artıq kral deyildi, Ayxan. Tacın içindəki şey idi. Mən sadəcə qapını açdım... Kül Şahı söz vermişdi ki, səni əsirgəyəcək.",
		"protest": "Qırx il bu taxta xidmət etdim və sən məni... Yaxşı. Gedirəm. Amma satqın hələ də gülümsəyir, Ayxan.",
	},
	"anar": {
		"model": "Rogue.glb", "hidden": ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"],
		"recolor": [0.18, 0.55, 0.1, 1.0, 0.85],
		"station": [Vector3(12.0, 0, 3.5), "Idle", -90.0],
		"greet": "Şahzadə! Ticarət batdı, amma sən sağsan — bu, ilin ən yaxşı sövdələşməsidir.",
		"cold": "Hə, köz daşıyan varis. Nə istəyirsən? Pulsuz heç nə vermirəm.",
		"alibi": "Karvansarada hesab aparırdım. Qırx dəvə, iki yüz çuval. Hamısını yandırdılar.",
		"alibi_guilty": "Karvansarada idim. Hesablar... bəli, hesablar. Hansı saatda? Yadımda deyil, şahzadə.",
		"traits": {
			"coin": ["İmperiya sikkəsi? Mən tacirəm. Dünyanın hər pulu cibimdən keçir.", "O sikkə çox adamda ola bilər. Niyə mənə elə baxırsan?"],
			"sulfur": ["Kükürd Novruz atəşfəşanlığı üçün idi. Anbarımda yüz kisə vardı — hamısı yandı.", "Kükürd anbardan yoxa çıxmışdı. Kimin götürdüyünü bilmirəm. Həqiqətən."],
			"lefthand": ["Bəli, solaxayam. Anam deyirdi ki, şeytanın əlidir. Amma mən ancaq tərəzi tuturam.", "Hər şey sol əllə edilmir ki, şahzadə. Sən də ağıllı ol."],
		},
		"deny": "O iz? Mənim deyil. Başqa müştəri axtar.",
		"confess": "İmperiya qızıl verdi, Ayxan. Çox qızıl. Kükürdü mən daşıdım — odu başqası yandırmalı idi... Amma kül hamımızı yedi.",
		"protest": "Mən? Tacir? Mən pul qazanıram, şəhər yandırmıram! Səhv sövdələşmə etdin, şahzadə.",
	},
	"elvin": {
		"model": "Knight.glb", "hidden": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword", "Round_Shield"],
		"recolor": [0.5, 0.75, 0.8, 1.1, 0.8],
		"station": [Vector3(-2.5, 0, -12.5), "Idle", 0.0],
		"greet": "Qardaşım. Sağ qalmısan. Nə yaxşı — taxt boş qalmaz, deyilmi?",
		"cold": "Ayxan. Közlü varis. Heç kim səni kral kimi görmür, bunu bil.",
		"alibi": "Şimal qülləsində idim. Zadəganlara məktub yazırdım — dəstək üçün. Bəli, taxt üçün. Gizlətmirəm.",
		"alibi_guilty": "Qüllədə idim. Tək. Nə yazırdım? Şeir. Bəli... şeir.",
		"traits": {
			"ink": ["O gecə otuz məktub yazdım. Barmaqlarım hələ də qaradır.", "Yazmaq cinayətdir? ...Hansı məktublardan danışırsan?"],
			"coin": ["İmperiyanın elçisi hədiyyə göndərmişdi. Rədd etdim. Sikkəni isə xatirə kimi saxladım.", "O sikkə hədiyyə idi. Heç nə demək deyil."],
			"seal": ["Möhür? Atam mənə heç vaxt möhür vermədi, Ayxan. Heç vaxt. Bunu sən də bilirsən.", "Möhürə toxunmadım. Yalnız... baxdım. Bir dəfə."],
		},
		"deny": "Bu, mənə aid deyil. Başqa qurban axtar, qardaş.",
		"confess": "Taxt mənim haqqım idi! Atam məni gizlətdi, səni böyütdü. Kül Şahı mənə tac vəd etdi... Mən sadəcə qəbul etdim.",
		"protest": "Deməli, belə. Qardaşını sürgün edirsən. Tarix bunu unutmayacaq, Ayxan.",
	},
	"sahbaz": {
		"model": "Knight.glb", "hidden": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "Round_Shield"],
		"recolor": [0.5, 0.75, 0.0, 0.9, 0.65],
		"station": [Vector3(-6.0, 0, 11.0), "Sit_Floor_Idle", 60.0],
		"greet": "Şahzadə. Ordu dağıldı, amma mən hələ ayaqdayam. Yaralı, amma ayaqda.",
		"cold": "Sən. Oğlumu edam etdirən kralın oğlu. Nə istəyirsən?",
		"alibi": "Şimal darvazasında idim, adamlarımla. Kölgələr ilk orada qalxdı. Yarımızı itirdik.",
		"alibi_guilty": "Darvazada idim. Sonra... saraya getdim, kömək üçün. Amma gec idi.",
		"traits": {
			"boots": ["Hər əsgər ağır çəkmə geyinir, şahzadə. Min adamım var idi.", "Saraya getmişdim, dedim axı. Kömək üçün."],
			"fur": ["Qışda şimal darvazasında hamımız canavar xəzi geyinirik. Soyuqdur orada.", "Xəz... Əşrəf bəyin hədiyyəsi idi. Köhnə sövdələşmə."],
			"lefthand": ["Sol əlimlə qılınc tuturam, bəli. Bütün ordu bunu bilir. Gizlətmirəm.", "Oğlum da solaxay idi. Sən bunu bilirsən? Yox, bilmirsən."],
		},
		"deny": "Bu, mənim izim deyil. Əsgər kimi danış, şahzadə — sübutla.",
		"confess": "Kral oğlumu öldürdü! Bir sözlə! Kül Şahı dedi ki, tac yansa, ruhlar azad olacaq... oğlum qayıdacaq...",
		"protest": "Otuz il ordu. Otuz il sədaqət. Sonu da budur. Get, şahzadə. Kölgələr səni aparanda mən olmayacağam.",
	},
	"esref": {
		"model": "Barbarian.glb", "hidden": ["1H_Axe_Offhand", "Mug", "2H_Axe"],
		"recolor": [],
		"station": [Vector3(5.5, 0, 8.5), "Sit_Floor_Idle", -150.0],
		"greet": "Qartal Dağlarının salamı, şahzadə. Qan davamız bitməyib, amma bu gecə düşmənimiz ortaqdır.",
		"cold": "Varis. Taxtın oğlu. Dağlılar səni tanımır.",
		"alibi": "Şəhərin kənarında, çadırımda idim. Danışıq üçün gəlmişdim. Kral məni qəbul etmədi.",
		"alibi_guilty": "Çadırımda. Tək. Adamlarım ova getmişdi. Bəli... gecə ovuna.",
		"traits": {
			"boots": ["Dağ çəkməsi ağırdır, şahzadə. Qayalarda yüngül çəkmə yaramır.", "Mənim çəkmələrim saraya girməz. Qapıdakılar buraxmazdı... adətən."],
			"fur": ["Canavar xəzi bizim bayrağımızdır. Hər dağlı geyinir.", "Yüz dağlıdan biri ola bilər. Məni niyə seçirsən?"],
			"coin": ["İmperiya bizimlə də ticarət edir. Onların qızılı dağlarda çoxdur.", "İmperiya bizə azadlıq vəd etdi. Söz vermək hələ cinayət deyil."],
		},
		"deny": "Bu iz dağlardan gəlmir. Aşağıda axtar.",
		"confess": "Üç nəsil! Üç nəsil sizin taxtınız bizim qanımızı içdi. Kül Şahı dedi ki, tac yansa, dağlar azad olacaq. Mən inandım.",
		"protest": "Deməli, qan davası davam edir. Dağlara qayıdıram, varis. Bir daha gəlməyəcəyəm.",
	},
	"rufet": {
		"model": "Knight.glb", "hidden": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"],
		"recolor": [],
		"station": [Vector3(3.0, 0, 13.5), "Idle", 180.0],
		"greet": "Ayxan. Son Ocaq... adı gözəldir, amma içi soyuqdur. Nə lazımdırsa, yanındayam.",
		"cold": "Ayxan. Yenə məni tanımırsan, eləmi? Yaxşı... soruş.",
		"alibi": "Bilirsən də: Sabir məni möhürlü məktubla göndərmişdi. Anarın adamlarına verdim. Qayıdanda saray yanırdı.",
		"alibi_guilty": "Sənə demişdim axı. Məktub, karvansara, qayıdış. Niyə yenə soruşursan?",
		"traits": {
			"boots": ["Mühafizə çəkməsidir. Mən də geyinirəm, qırx adamım da.", "Sarayda idim, bəli — qayıdandan sonra. Səni axtarırdım."],
			"seal": ["Möhürlü məktubu mən daşıdım, Ayxan. Möhürün izi mənim əlimdə də qala bilərdi.", "O möhürü Sabir verdi. Mən sadəcə... Ayxan, mənə elə baxma."],
			"lefthand": ["Solaxayam, bilirsən. Uşaqlıqdan. Şahbaz qılınc dərsində buna görə məni döyürdü.", "Qan qardaşından şübhələnirsən? Sol əlimlə səni üç dəfə ölümdən qurtarmışam."],
		},
		"deny": "Bu, mənim izim deyil, Ayxan. And olsun.",
		"confess": "Mən sənin yerinə kral olmaq istəmirdim, Ayxan! Səni qorumaq istəyirdim! Kül Şahı dedi ki, od səni yox, kralı alacaq... Səni seçəcəyini bilmirdim.",
		"protest": "Qan qardaşını sürgün edirsən... Yaxşı. Amma bil: sən məni unutsan da, mən səni unutmayacağam.",
	},
	"ibrahim": {
		"model": "Mage.glb", "hidden": ["Spellbook", "Spellbook_open", "2H_Staff"],
		"recolor": [0.55, 0.95, 0.42, 0.9, 0.65],
		"station": [Vector3(-12.0, 0, 2.5), "Idle", 90.0],
		"greet": "Şahzadə! Köz... sinəndəki köz! İcazə ver baxım — yox, yox, toxunmuram. Heyrətamizdir.",
		"cold": "Ah. Sən. Tacın qalığını daşıyan. Məndən uzaq dur, lütfən.",
		"alibi": "Laboratoriyamda idim, qüllənin altında. Tacın odunu ölçürdüm. Alov... sanki nəfəs alırdı.",
		"alibi_guilty": "Laboratoriyada. Sonra bir neçə gün itkin düşdüm, bəli. Qorxdum. Alimin də qorxmağa haqqı var.",
		"traits": {
			"incense": ["Ladandan yağ çıxarıram. Laboratoriyam həmişə ladan qoxuyur.", "Ladan təcrübə üçün idi. Hansı təcrübə? Elmi. Anlamazsan."],
			"ink": ["Min səhifə qeyd! Tac haqqında bildiyim hər şey. Onlar da yandı.", "Qeydlərim... itib. Yandı. Bəli, hamısı yandı."],
			"sulfur": ["Kükürd kimyagərin çörəyidir. Amma yaşıl alov? O, mənim formulum deyil... ya da...", "Yaşıl alov nəzəri olaraq mümkündür. Nəzəri olaraq! Mən sadəcə yazmışdım..."],
		},
		"deny": "Bu iz mənə aid deyil. Elmi düşün, şahzadə: sübutlar zəncir kimidir.",
		"confess": "Tacın odunu azad etmək istəyirdim! Min illik güc, qəfəsdə! Formulu mən yazdım... Kül Şahı mənə səs verdi, Ayxan. Səs verdi!",
		"protest": "Elm cinayət deyil! Sən səhv edirsən. Tarix səni axmaq kimi xatırlayacaq.",
	},
	"ehliman": {
		"model": "Mage.glb", "hidden": ["Spellbook", "Spellbook_open", "1H_Wand"],
		"recolor": [0.55, 0.95, 0.02, 1.2, 0.75],
		"station": [Vector3(8.5, 0, -11.5), "Spellcasting", -20.0],
		"greet": "Közün daşıyıcısı. Od səni seçdi, bunu hiss edirəm. Od qarşısında hamımız bərabərik, uşaq.",
		"cold": "Sən közü ləkələdin. Hər istifadədə. Od səni bağışlamayacaq.",
		"alibi": "Atəşgahda dua edirdim. Od məni gecə yarısı çağırdı. Oyananda şəhər alov içində idi.",
		"alibi_guilty": "Atəşgahda. Od mənə... göstərdi. Nə göstərdi? Bu, müqəddəs sirrdir.",
		"traits": {
			"incense": ["Ladan duanın nəfəsidir. Mən ladan qoxuyuram, şahzadə.", "Ladan hər yerdə olur. Odun olduğu yerdə. Bu, hökm deyil."],
			"sulfur": ["Kükürdü atəşgahda müqəddəs alov üçün yandırırıq. Yaşıl alov ilahi əlamətdir.", "Yaşıl od ilahi hökmdür! Mən sadəcə odu çağırdım. Od özü qərar verdi."],
			"lefthand": ["Sol əl odun əlidir, qədim kitablar belə deyir. Bəli, solaxayam.", "Od seçdi, Ayxan. Mən sadəcə alət idim."],
		},
		"deny": "Od bu izi mənə göstərmir. Yalançı peyğəmbərlərə qulaq asma.",
		"confess": "Kül Şahı tanrıdır, Ayxan! Tac onu min il qəfəsdə saxladı. Mən onu azad etdim. Sən də onun qabısan — diz çök!",
		"protest": "Od şahiddir: günahsız birini sürgün etdin. Kül bunu yadda saxlayacaq, uşaq.",
	},
}

const COLD_TRUST := 35
const HINT_TRUST := 55


static func model_path(id: String) -> String:
	return DIR + PEOPLE[id]["model"]


static func display_name(id: String) -> String:
	return Conspiracy.SUSPECTS[id]["name"]


## Interrogation dialogue for one suspect, built from the current GameState.
static func build(id: String) -> Dictionary:
	var p: Dictionary = PEOPLE[id]
	var name := display_name(id)
	var guilty := GameState.traitor == id
	var cold := int(GameState.trust.get(id, 50)) < COLD_TRUST
	if id == "rufet" and Memory.is_burned("rufet_face"):
		cold = true
	var d := {}
	d["start"] = {"speaker": name, "text": p["cold"] if cold else p["greet"], "next": "menu", "do": ["talked:" + id]}

	var menu_choices := [{"text": "Kül Gecəsi harada idin?", "next": "alibi"}]
	if not GameState.clues.is_empty():
		menu_choices.append({"text": "Sübutu göstər...", "next": "clues"})
	menu_choices.append({"text": "Səncə, satqın kimdir?", "next": "hint"})
	menu_choices.append({"text": "Hələlik bu qədər.", "event": "talk_end"})
	d["menu"] = {"speaker": "Ayxan", "text": "(%s gözlərimin içinə baxır. Nə soruşum?)" % name, "choices": menu_choices}

	d["alibi"] = {"speaker": name, "text": p["alibi_guilty"] if guilty else p["alibi"], "next": "menu"}

	var clue_choices := []
	for t in GameState.clues:
		clue_choices.append({"text": Conspiracy.TRAITS[t]["title"], "next": "clue_" + t})
		var own: Dictionary = p["traits"]
		if own.has(t):
			# Confronting someone with their own trait stings, guilty or not
			d["clue_" + t] = {"speaker": name, "text": own[t][1] if guilty else own[t][0], "next": "clues", "do": ["trust:%s:-4" % id]}
		else:
			d["clue_" + t] = {"speaker": name, "text": p["deny"], "next": "clues", "do": ["trust:%s:-8" % id]}
	clue_choices.append({"text": "Geri", "next": "menu"})
	d["clues"] = {"speaker": "Ayxan", "text": "(Hansı izi göstərim?)", "choices": clue_choices}

	if int(GameState.trust.get(id, 50)) >= HINT_TRUST:
		d["hint"] = {"speaker": name, "text": _hint_line(id), "next": "menu", "do": ["trust:%s:2" % id, "flag:hint_" + id]}
	else:
		d["hint"] = {"speaker": name, "text": "Sənə hələ o qədər etibar etmirəm ki, kiminsə adını çəkim.", "next": "menu"}
	return d


## Trusting suspects share what they saw. Mostly true, sometimes a wrong guess.
static func _hint_line(id: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameState.traitor + id)
	var pick: String = GameState.traitor
	if id == GameState.traitor or rng.randf() < 0.35:
		var others := Conspiracy.SUSPECTS.keys().filter(func(s): return s != id)
		pick = others[rng.randi() % others.size()]
	return "O gecə saray tərəfdə %s də var idi. Tələsirdi, başını aşağı salmışdı. Bəlkə heç nə demək deyil... bəlkə də." % display_name(pick)


## The council at the hearth: name the traitor.
static func accusation() -> Dictionary:
	var choices := []
	for id in Conspiracy.SUSPECTS:
		choices.append({"text": "%s — %s" % [display_name(id), Conspiracy.SUSPECTS[id]["role"]], "event": "accuse:" + id})
	choices.append({"text": "Hələ yox. Daha çox bilməliyəm.", "event": "accuse_cancel"})
	return {"start": {"speaker": "Ayxan", "text": "(Hamı Son Ocağın ətrafına toplaşıb. Bir ad demək qalıb. Səhv etsəm, günahsız biri gedəcək — satqın isə qalacaq.)", "choices": choices}}


static func confession(id: String) -> Dictionary:
	return {
		"start": {"speaker": "Ayxan", "text": "%s. Kül Gecəsi sənin əsərindir." % display_name(id), "next": "c"},
		"c": {"speaker": display_name(id), "text": PEOPLE[id]["confess"], "next": "ash"},
		"ash": {"speaker": "Kül Şahı", "text": "...kifayətdir. Bu qab artıq mənimdir.", "end": true, "event": "traitor_revealed"},
	}


static func wrong_verdict(id: String) -> Dictionary:
	return {
		"start": {"speaker": "Ayxan", "text": "%s. Kül Gecəsi sənin əsərindir." % display_name(id), "next": "p"},
		"p": {"speaker": display_name(id), "text": PEOPLE[id]["protest"], "next": "v"},
		"v": {"speaker": "Ayxan", "text": "(Düşərgə susur. %s darvazadan çıxır və qaranlıqda itir. Kimsə ocağın o biri tərəfində yüngülcə gülümsəyir.)" % display_name(id), "end": true, "event": "wrong_verdict"},
	}
