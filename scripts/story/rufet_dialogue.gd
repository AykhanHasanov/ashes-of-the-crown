extends RefCounted
## Chapter 1, "İlk sabah": Ayxan finds Rüfət at the south gate three days after
## the Night of Ash. If the ember has already burned "Rüfet'in yüzü", Ayxan no longer
## recognizes his blood brother and the scene plays out differently.
## Format: see scripts/ui/dialogue_ui.gd.

const DATA := {
	"start": {"branch": {"memory": "rufet_face", "burned": "stranger", "intact": "greet"}},

	# --- Ayxan remembers him -------------------------------------------------
	"greet": {"speaker": "Rüfet", "text": "Ayxan! Çok şükür... Üç gündür külün altında seni arıyorum. Herkes öldüğünü söylüyordu.", "next": "greet2"},
	"greet2": {"speaker": "Rüfet", "text": "Yaralı mısın? Otur, ocağın yanına otur. Sana anlatmam gereken çok şey var.", "choices": [
		{"text": "Babam... Kral nerede?", "next": "king"},
		{"text": "Yangın gecesi sen neredeydin, Rüfet?", "next": "where"},
		{"text": "Sonra konuşuruz. Durum ne?", "next": "status"},
	]},

	"king": {"speaker": "Rüfet", "text": "Taht salonundaydı. Alev... onun içinden çıktı, Ayxan. Dışarıdan değil, içinden.", "next": "king2"},
	"king2": {"speaker": "Rüfet", "text": "Sabah olduğunda ne kral kalmıştı ne taç. Sadece o krater... ve senin göğsünde yanan o köz.", "next": "ember"},
	"ember": {"speaker": "Rüfet", "text": "O köz sana güç veriyor, görüyorum. Ama her kullandığında gözlerin biraz daha yabancılaşıyor.", "choices": [
		{"text": "Bu benim yüküm. Sen değil, ben taşıyacağım.", "next": "ember_a"},
		{"text": "Ne demek istiyorsun?", "next": "ember_b"},
	]},
	"ember_a": {"speaker": "Rüfet", "text": "O zaman en azından şunu unutma: ne kadar yakarsan yak, ben senin kardeşinim.", "next": "status"},
	"ember_b": {"speaker": "Rüfet", "text": "Yaşlı Sabir der ki Tacın ateşini taşıyan her kral yıllar içinde unutmaya başlarmış. Senin baban en sonunda... kendi oğlunun adını bile unutmuştu.", "set": "lore_forgetting_king", "next": "status"},

	"where": {"speaker": "Rüfet", "text": "Nöbetimdeydim... Hayır. Kral akşam bütün muhafızların saraydan çıkmasını emretti. Bunu asla yapmazdı.", "choices": [
		{"text": "Neden böyle yaptı?", "next": "why"},
		{"text": "Sana inanıyorum.", "next": "believe"},
	]},
	"why": {"speaker": "Rüfet", "text": "Bilmiyorum. Ama bir şeyi biliyorum: ne yapacağını biliyordu.", "set": "king_sent_guards_away", "next": "status"},
	"believe": {"speaker": "Rüfet", "text": "...Sağ ol. Bu söze ihtiyacım vardı.", "set": "rufet_believed", "next": "status"},

	# --- The ember took his face ----------------------------------------------
	"stranger": {"speaker": "Rüfet", "text": "Ayxan! Çok şükür... Üç gündür külün altında seni arıyorum.", "choices": [
		{"text": "Dur! Sen kimsin?", "next": "stranger_a"},
		{"text": "...Sesin tanıdık. Ama yüzün...", "next": "stranger_b"},
	]},
	"stranger_a": {"speaker": "Rüfet", "text": "Benim, Rüfet! Nehir kıyısında kan kardeşi olduğumuz gün... Hatırlamıyor musun?", "next": "stranger2"},
	"stranger_b": {"speaker": "Rüfet", "text": "Ayxan, benim, Rüfet. Neden öyle bakıyorsun? Sanki beni ilk kez görüyorsun.", "next": "stranger2"},
	"stranger2": {"speaker": "Ayxan", "text": "Adını biliyorum. Ama yüzün... hafızamda onun yerinde sadece kül var.", "next": "stranger3"},
	"stranger3": {"speaker": "Rüfet", "text": "Demek o köz senden bunu da aldı...", "set": "rufet_forgotten", "next": "stranger4"},
	"stranger4": {"speaker": "Rüfet", "text": "Önemli değil. Sen beni unutsan da ben seni unutmayacağım. Şimdi dinle —", "next": "status"},

	# --- Shared ending ----------------------------------------------------------
	"status": {"speaker": "Rüfet", "text": "Durum kötü. Şahbaz'ın ordusu kuzey kapısında dağıldı. Ehliman'ın rahipleri meydanda bunun ilahi bir hüküm olduğunu haykırıyor.", "next": "status2"},
	"status2": {"speaker": "Rüfet", "text": "Elvin kendini çoktan tahtın varisi ilan etti. Kervan yolu kapalı, dağlarda Eşref Bey susuyor. İbrahim ise yangından beri ortada yok.", "next": "alarm"},
	"alarm": {"speaker": "Rüfet", "text": "Dur... duyuyor musun? Kül kıpırdıyor.", "next": "alarm2"},
	"alarm2": {"speaker": "Rüfet", "text": "Gölgeler kalkıyor! Kılıcını çek, Ayxan! Yaralanırsan ocakların yanına koş, sıcaklıkları seni iyileştirir!", "end": true, "event": "start_waves"},
}

## After the waves: Rüfət points Ayxan at the ember echoes.
const AFTER_WAVES := {
	"start": {"speaker": "Rüfet", "text": "Bitti... şimdilik. Ayxan, bak, kül hâlâ kor kor yanıyor. Şurada, şurada, bir de şurada.", "next": "b"},
	"b": {"speaker": "Rüfet", "text": "Rahipler büyük bir ateşin söndüğü yerde bir hatıra bıraktığını söyler. Senin közün o hatırayı uyandırabilir. Belki o gece ne olduğunu görürsün.", "next": "c"},
	"c": {"speaker": "Ayxan", "text": "O zaman göreceğim. O gece ne olduysa külün içinde kaldı.", "end": true, "event": "start_echoes"},
}

## After all three echoes: what Ayxan saw of his father's last night.
const AFTER_ECHOES := {
	"start": {"speaker": "Rüfet", "text": "Ne gördün? Gözlerin yine közün rengine büründü.", "choices": [
		{"text": "Babam tacı kendisi taktı. Bile bile.", "next": "knew"},
		{"text": "Hiçbir şey anlamadım.", "next": "lost"},
	]},
	"knew": {"speaker": "Rüfet", "text": "Demek bu yangın tesadüf değildi... Peki neden? Seni neden yalnız bıraktı?", "set": "king_chose_fire", "next": "camp"},
	"lost": {"speaker": "Rüfet", "text": "Bunu tek başına taşıyamazsın.", "next": "camp"},
	"camp": {"speaker": "Rüfet", "text": "Hayatta kalanlar Son Ocak'ta toplandı. Onların ateşe ihtiyacı var, Ayxan. Senin ateşine.", "end": true, "event": "chapter_end"},
}