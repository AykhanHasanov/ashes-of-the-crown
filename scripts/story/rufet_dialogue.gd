extends RefCounted
## Chapter 1, "Birinci səhər": Ayxan finds Rüfət at the south gate three days after
## the Night of Ash. If the ember has already burned "Rüfətin üzü", Ayxan no longer
## recognizes his blood brother and the scene plays out differently.
## Format: see scripts/ui/dialogue_ui.gd.

const DATA := {
	"start": {"branch": {"memory": "rufet_face", "burned": "stranger", "intact": "greet"}},

	# --- Ayxan remembers him -------------------------------------------------
	"greet": {"speaker": "Rüfət", "text": "Ayxan! Şükür... Üç gündür külün altında səni axtarıram. Hamı öldüyünü deyirdi.", "next": "greet2"},
	"greet2": {"speaker": "Rüfət", "text": "Yaralısan? Otur, ocağın yanında otur. Sənə deməli olduğum çox şey var.", "choices": [
		{"text": "Atam... Kral haradadır?", "next": "king"},
		{"text": "Yanğın gecəsi sən haradaydın, Rüfət?", "next": "where"},
		{"text": "Sonra danışarıq. Vəziyyət necədir?", "next": "status"},
	]},

	"king": {"speaker": "Rüfət", "text": "Taxt salonunda idi. Alov... onun içindən çıxdı, Ayxan. Kənardan yox — içindən.", "next": "king2"},
	"king2": {"speaker": "Rüfət", "text": "Səhər olanda nə kral qalmışdı, nə tac. Yalnız o krater... və sənin sinəndə yanan o köz.", "next": "ember"},
	"ember": {"speaker": "Rüfət", "text": "O köz sənə güc verir, görürəm. Amma hər dəfə istifadə edəndə gözlərin bir az da yad olur.", "choices": [
		{"text": "Bu mənim yükümdür. Sən yox, mən daşıyacağam.", "next": "ember_a"},
		{"text": "Nə demək istəyirsən?", "next": "ember_b"},
	]},
	"ember_a": {"speaker": "Rüfət", "text": "Onda heç olmasa bunu yadda saxla: nə qədər yandırsan da, mən sənin qardaşınam.", "next": "status"},
	"ember_b": {"speaker": "Rüfət", "text": "Qoca Sabir deyir ki, Tacın odunu daşıyan hər kral il-il unudurmuş. Sənin atan axırda... öz oğlunun adını da unutmuşdu.", "set": "lore_forgetting_king", "next": "status"},

	"where": {"speaker": "Rüfət", "text": "Mən... postumda idim.", "set": "rufet_hesitated", "next": "where2"},
	"where2": {"speaker": "Rüfət", "text": "Yox. Sənə yalan deməyəcəyəm. Sabir məni aşağı şəhərə göndərmişdi — bir məktubu çatdırmaq üçün. Qayıdanda saray artıq yanırdı.", "choices": [
		{"text": "Hansı məktub? Kimə?", "next": "letter"},
		{"text": "Sənə inanıram.", "next": "trust"},
	]},
	"letter": {"speaker": "Rüfət", "text": "Möhürlü idi, açmadım. Karvansarada Anarın adamlarına verdim. Bundan artığını bilmirəm, and olsun.", "set": "clue_letter", "next": "status"},
	"trust": {"speaker": "Rüfət", "text": "...Sağ ol. Bu sözə hamıdan çox ehtiyacım vardı.", "set": "rufet_trusted", "next": "status"},

	# --- The ember took his face ----------------------------------------------
	"stranger": {"speaker": "Rüfət", "text": "Ayxan! Şükür... Üç gündür külün altında səni axtarıram.", "choices": [
		{"text": "Dayan! Sən kimsən?", "next": "stranger_a"},
		{"text": "...Səsin tanışdır. Amma üzün...", "next": "stranger_b"},
	]},
	"stranger_a": {"speaker": "Rüfət", "text": "Mənəm, Rüfət! Çay kənarında qan qardaşı olduğumuz gün... Yadında deyil?", "next": "stranger2"},
	"stranger_b": {"speaker": "Rüfət", "text": "Ayxan, mənəm — Rüfət. Niyə elə baxırsan? Sanki məni ilk dəfə görürsən.", "next": "stranger2"},
	"stranger2": {"speaker": "Ayxan", "text": "Adını bilirəm. Amma sənin üzün... xatirəmdə onun yerində yalnız kül var.", "next": "stranger3"},
	"stranger3": {"speaker": "Rüfət", "text": "Deməli, o köz səndən bunu da aldı...", "set": "rufet_forgotten", "next": "stranger4"},
	"stranger4": {"speaker": "Rüfət", "text": "Eybi yox. Sən məni unutsan da, mən səni unutmayacağam. İndi qulaq as —", "next": "status"},

	# --- Shared ending ----------------------------------------------------------
	"status": {"speaker": "Rüfət", "text": "Vəziyyət pisdir. Şahbazın ordusu şimal darvazasında dağılıb. Əhlimanın kahinləri meydanda bağırır ki, bu, ilahi hökmdür.", "next": "status2"},
	"status2": {"speaker": "Rüfət", "text": "Elvin artıq özünü taxtın varisi elan edib. Karvan yolu bağlıdır, dağlarda Əşrəf bəy susur. İbrahim isə yanğından bəri yoxa çıxıb.", "next": "alarm"},
	"alarm": {"speaker": "Rüfət", "text": "Dayan... eşidirsən? Kül tərpənir.", "next": "alarm2"},
	"alarm2": {"speaker": "Rüfət", "text": "Kölgələr qalxır! Qılıncını çək, Ayxan — yaralansan, ocaqların yanına qaç, onların istisi səni sağaldar!", "end": true, "event": "start_waves"},
}
