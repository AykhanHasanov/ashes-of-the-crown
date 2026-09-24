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

	"where": {"speaker": "Rüfət", "text": "Postumda idim... Yox. Kral axşam əmr verdi ki, bütün mühafizə saraydan çıxsın. Bunu heç vaxt etməzdi.", "choices": [
		{"text": "Niyə belə etdi?", "next": "why"},
		{"text": "Sənə inanıram.", "next": "believe"},
	]},
	"why": {"speaker": "Rüfət", "text": "Bilmirəm. Amma bir şeyi bilirəm: o, nə edəcəyini bilirdi.", "set": "king_sent_guards_away", "next": "status"},
	"believe": {"speaker": "Rüfət", "text": "...Sağ ol. Bu sözə ehtiyacım vardı.", "set": "rufet_believed", "next": "status"},

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

## After the waves: Rüfət points Ayxan at the ember echoes.
const AFTER_WAVES := {
	"start": {"speaker": "Rüfət", "text": "Bitdi... hələlik. Ayxan, bax — kül hələ də közərir. Orada, orada, bir də orada.", "next": "b"},
	"b": {"speaker": "Rüfət", "text": "Kahinlər deyir ki, böyük od öldüyü yerdə yaddaş qoyur. Sənin közün o yaddaşı oyada bilər. Bəlkə o gecə nə baş verdiyini görərsən.", "next": "c"},
	"c": {"speaker": "Ayxan", "text": "Onda görəcəyəm. O gecə nə baş veribsə, külün içində qalıb.", "end": true, "event": "start_echoes"},
}

## After all three echoes: what Ayxan saw of his father's last night.
const AFTER_ECHOES := {
	"start": {"speaker": "Rüfət", "text": "Nə gördün? Gözlərin yenə közün rəngini alıb.", "choices": [
		{"text": "Atam tacı özü taxdı. Bilə-bilə.", "next": "knew"},
		{"text": "Heç nə anlamadım.", "next": "lost"},
	]},
	"knew": {"speaker": "Rüfət", "text": "Deməli, bu yanğın təsadüf deyildi... Bəs niyə? Niyə səni tək qoydu?", "set": "king_chose_fire", "next": "camp"},
	"lost": {"speaker": "Rüfət", "text": "Tək daşıya bilməzsən.", "next": "camp"},
	"camp": {"speaker": "Rüfət", "text": "Sağ qalanlar Son Ocaqda toplaşıb. Onlara od lazımdır, Ayxan. Sənin odun.", "end": true, "event": "chapter_end"},
}