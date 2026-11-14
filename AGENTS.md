# AI Agents Kılavuzu (AGENTS.md)

Bu dosya, AI kodlama asistanlarının (Antigravity, Cursor, Copilot vb.) projeyi anlamasına yardımcı olmak için hazırlanmıştır.

## Proje Özeti
- **PC Build Simulator**: Sürükle-bırak mekanizmasıyla bilgisayar parçalarını anakarta yerleştiren bir 2D mobil simülasyon oyunu
- **Motor**: Godot 4.3, GDScript
- **Hedef Platformlar**: Android, iOS (yatay ekran)
- **İlham**: Good Pizza, Great Pizza tarzı simülasyon oyunları

## Mimari Kararlar
- **Motor ve Dil**: Godot 4 + GDScript (Python benzeri, tip güvenli)
- **Renderer**: Compatibility (OpenGL 3) — mobil uyumluluk ve performans için
- **Resource Pattern**: Parça verileri (CPU, GPU vb.) `.tres` dosyaları olarak saklanır
- **Autoload Singleton'lar**: Global state ve iletişim için `EventBus`, `GameManager`, `InventoryManager`, `AudioManager`
- **Sahne Tabanlı Mimari**: Her özellik ve mekanik bağımsız bir sahne (Scene) olarak tasarlanır

## Modül Haritası
Proje dizin yapısı ve açıklamaları:
- `src/autoload/` — Global singleton scriptleri
- `src/resources/` — Veri sınıfı tanımları (`ComponentData`, `CPUData`, `GPUData`)
- `src/scenes/menu/` — Ana menü (senaryo seçimi; oyunun açılış sahnesi)
- `src/scenes/main/` — Ana oyun sahnesi (montaj masası)
- `src/resources/ScenarioData.gd` + `data/scenarios/*.tres` — Dükkâna gelen işler (hazır takılı parçalar, envanter, arızalar).
  Yeni senaryo: `.tres` oluştur ve `GameManager.SCENARIOS` listesine ekle
- `src/scenes/counter/` — Tezgâh (dükkânın ön yüzü): müşteri kapıdan girer, sıraya dizilir, arızayı anlatır; iş bitince yorum/yıldız/ödeme yapıp çıkar (`Counter`, `CustomerWalker`)
- `src/resources/CustomerData.gd` + `data/customers/*.tres` — Müşteri karakterleri (ad, tip, isim rengi, selam ve teşekkür sözü).
  Görseller `assets/characters/<ad>.png` (belden yukarı, 768×1152, saydam): normal, `_mutlu`, `_kirgin`, `_konusma` (ağzı açık).
  Yumuşak 2D stilde Codex ile üretildi; istemler ve üretim betikleri depo dışında `gorsel-uretim/tam/`. Eski SVG'ler kullanılmıyor.
  Tezgâhta müşteri büyük (`COUNTER_SCALE`), tezgâhın arkasından yükselir/iner (`CustomerWalker.rise_in/sink_out`), konuşurken ağız oynar,
  4–5 yıldızda mutlu, 1–2 yıldızda ve rafsız işte kırgın yüz (`set_mood`). Balon yüzün yanında, geniş tarafta (`Counter._layout_bubble`).
  Satın alınan dekor tezgâhta görünür (`Counter.COUNTER_DECOR`: çay ocağı, saksı, ikinci tabure, dolu raf, ışıklı tabela, vitrin ışığı; yeni dekor PNG'si `assets/shop/dekor/<id>.png`, dosya yoksa `ResourceLoader.exists` ile sessizce atlanır; katman `front` tezgâh üstü / `back` duvar-zemin, müşterilerin arkası; konumlar görseller gelince ayarlanacak).
  Dükkân arka planı ve tezgâh önü `assets/shop/*.png`; seviyeye göre arka plan `LevelData.background` (`shop_back_s<seviye>.png`, dosya yoksa `shop_back.png`); tabela yazıları `SIGN_TEXTS` ile üstüne konur.
  Kariyerde günün her işine `CareerManager._assign_customers()` ile bir karakter atanır
- `data/parts/<tür>/<id>.tres` — Parça kataloğu (32 parça; tür klasörleri: ram, sata, m2, fan, psu, gpu, cpu, paste).
  Her parça `ComponentData` (CPU/GPU için `CPUData`/`GPUData`) olarak id, marka (kurgu: Kartal, Pusula, Zirve, Volta, Nimbus, Demirci),
  model, kademe (1 ekonomik, 2 dengeli, 3 üst), `buy_price`/`sell_price`, RAM türü, kapasite, watt, `min_shelf_level`, `art` taşır.
  Fiyat kuralı: kademe 2 alış ≈ 1,8×, kademe 3 ≈ 3× kademe 1; satış = alış × 1,4–1,55. `InventoryManager` açılışta klasörü yükler:
  `create_part(id)` katalog parçasının kopyasını verir (boyut `PART_SIZES` ile yuvaya 1:1 zorlanır), `catalog_parts(tür, raf_seviyesi)` listeler.
  Eski tür adı (`"ram"`, `"m2"`, `"gpu"`...) hâlâ geçerli ve DEĞİŞMEDEN genel (markasız) parça verir; senaryolar bunları kullanır.
  Kablolar kataloğa girmez. Etiketi `PartArt.part_label()` kurar ("Kartal 8 GB DDR4"); markasız parça eski çizimini korur.
  Yeni parça: `.tres` ekle (id dosya adıyla aynı, `part_size` yuva boyutu). Senaryo `inventory_parts` listesi tür adı ya da katalog id'si kabul eder;
  yuva türü her zaman parçanın `part_type` alanından bilinir (`Motherboard._preinstall_scenario_parts` listedeki adı değil `data.part_type`'ı kullanır).
- `src/utils/PartOffer.gd` + `CareerManager.offer` — Tezgâhta parça teklifi ve müşteri bütçesi (Aşama 3 / P2). `ScenarioData.offer_part_type` ("ram", "m2"; boşsa
  teklif yok, bugünkü akış) ve `base_budget` (işçilik + parça toplamı için ₺ taban) yalnız `faulty_ram` (880) ve `dead_ssd` (1150) senaryolarında dolu.
  `CustomerData.budget_type` (`dar` ×0,8, `orta` ×1,0, `genis` ×1,6) bütçeyi ve tepkiyi belirler: dar bütçeyi aşarsa gider ve çıkmaya sevinir; orta %15'e kadar
  aşımı kabul eder (normal yüz, bahşiş yok); geniş en ucuza "daha iyisi yok muydu" der (bahşiş yarı), çıkmaya kızar (kırgın yüz, bahşiş yok); uygun seçim mutlu yüz ve
  bahşişe +%5. Çok aşım: kırgın yüz, müşteri gider, kaçan kazanç teklifin toplamı (`turn_away_current(lost)`).
  `Counter` müşterinin şikâyetine bütçe sözünü ekler (`PartOffer.budget_line`, tona göre), konuşma bitince "Atölyeye Al" yerine teklif kartını açar
  (`_show_offer_card`: gelen anakarta uyan kademe 1-2-3 parçaları + varsa çıkma "Demirci" parçası; marka, model, toplam, parça kârı; düğme ≥ 46 ekran pikseli).
  `CareerManager.choose_part(id)`: alış fiyatı kasadan hemen düşer, parça işin envanterine YENİ olarak `ram`/`m2` yerine konur (`GameManager.job_hook` → `_apply_offer_to_job`),
  seçim ve iş anakartı kayda yazılır (menüye çıkıp dönmek seçimi silmez). Çıkma parça %20 arızalı gelir (`ComponentData.is_faulty` → `PartItem.is_broken`, BIOS'ta yakalanır);
  sökülünce yenisi alış fiyatına yeniden alınır (`replace_faulty_part`, bir kez). Stok yok; uyumsuz parça listelenmez. Listelenen en yüksek kademe dükkân seviyesine bağlıdır (P5): `CareerManager.shelf_level()` seviye 1 → kademe 1, seviye 2 → ≤2, seviye 3-4 → hepsi; Test menüsündeki (kariyer dışı) işlerde 3 sabit (`PartOffer.MAX_SHELF_LEVEL`). O kademede karta uyan parça yoksa `PartOffer.options` bir üst kademeye çıkar, kart hiç boş kalmaz.
  Finans: kasadan alış, müşteriden işçilik + parça satışı + bahşiş; hata cezası yalnız işçiliğe. Fiş ve gün sonu özeti işçilik/parça/bahşişi ayrı satır gösterir.
- Yeni işler (Aşama 3 / P4): toplam 13 senaryo (menüde), `CAREER_POOL` 12 iş (`full_build` yalnız menüde). `ScenarioData.complaints` her işe 3 şikâyet metni verir
  (biri rastgele seçilir, tezgâh ve iş emri aynı metni gösterir); `loose_parts`/`loose_count` takılı gelmeyen (yerinden çıkmış) parçaları envantere verir.
  Yeni raflar: NVMe (2.500 ₺, 10 iş ★3,0), güç kaynağı (3.500 ₺, 16 iş ★3,0), ekran kartı (6.000 ₺, 30 iş ★3,5); SSD rafı 800 ₺.
  PSU, GPU ve SATA söküme açık (dokununca bağlı kablolar envantere döner, parça kalkar); arızalı PSU'da güç düğmesi tepkisiz, arızalı GPU'da "NO VIDEO SIGNAL" (`BiosPostTest`).
  `PartOffer` teklif türleri: ram, m2, sata, psu, gpu (karta uyum: ilgili yuvası olan kart, H81'de DDR3).
- `src/scenes/workbench/` — Montaj masası (Motherboard, MotherboardSlot)
- Anakart modelleri: `src/resources/BoardData.gd` + `data/boards/*.tres` (ad, dönem, soket, RAM türü, renkler) ve
  yerleşim sahneleri (modern: `Motherboard.tscn`, diğerleri: `src/scenes/workbench/boards/*.tscn`). Kod (`Motherboard.gd`)
  tüm kartlarda ortaktır; kartta olmayan yuvalar (M.2, ekran kartı, SATA) atlanır, BIOS karta göre konuşur.
  Senaryo `board_paths` ile hangi kartlarla gelebileceğini söyler (rastgele seçilir).
  Yeni kart: sahneyi kopyala, yuvaları taşı/sil, `.tres` oluştur ve senaryoların `board_paths` listesine ekle.
- `src/autoload/CareerManager.gd` — Kariyer: para, itibar (yıldız), gün düzeni, hata sayımı ve kayıt (`user://kariyer.json`).
  İlk 3 gün `PLANNED_DAYS`, sonrası `CAREER_POOL`'dan rastgele (1. gün 2, sonra 3, 5. günden itibaren 4 müşteri).
  Ücret senaryonun `price` alanı; her hata -%10 ve -1 yıldız (en az %50 ücret, en az 1 yıldız). Hatalar: macun taşması,
  sağlam parça sökme, ilk teşhisten sonraki her başarısız BIOS, parçaya zarar verecek sıra hataları (`Motherboard._reject(..., true)`). Yardım mesajları ceza kesmez.
  Hatalar ve aktif iş kayda yazılır: menüye çıkıp dönmek hataları silmez. Kayıt önce geçici dosyaya yazılır, `version` alanı taşır (şu an 5: `offer`, `day_part_sales`,
  `day_part_cost`; 6: `shop_level`; 3, 4 ve 5 numaralı kayıtlar `.get` varsayılanlarıyla açılır, dükkân seviyesi 1).
  Menüdeki "Test" listesinden açılan işler kariyeri etkilemez (`is_career = false`).
  Bahşiş yıldıza göre ayrı ödenir (`TIP_RATES`: 5★ %15, 4★ %8, 3★ %3).
- `src/resources/LevelData.gd` + `data/levels/seviye_1..4.tres` — Dükkânın büyüme aşamaları (Aşama 3 / P5): ad, bedel, gereken iş ve yıldız, günlük müşteri sayısı, arka plan yolu, açtıkları (metin listesi).
  1 Köşe tamircisi (başlangıç) · 2 Mahalle dükkânı (12 iş, ★3,0, 4.000 ₺, günde 5) · 3 Montaj atölyesi (35 iş, ★3,5, 14.000 ₺, günde 6) · 4 Teknoloji mağazası (80 iş, ★4,0, 32.000 ₺, günde 7).
  `CareerManager.shop_level` kayıtta durur; `level_block_reason()` kapalı-neden metni (`purchase_block_reason` gibi), `buy_level()` şart + para kontrolüyle seviye atlar, alım anında kaydeder.
  Seviye 1'de günlük müşteri bugünkü kural (1. gün 2, sonra 3, 5. günden 4) ve `PLANNED_DAYS` planlı ilk günler; 2+'da `LevelData.daily_customers`. Yeni seviye bir sonraki günden geçerli.
  İş havuzu: seviye 1 `LEVEL1_POOL` (7 iş: fan, kablo, RAM, macun, SSD, RAM yükseltme, gevşek parça), seviye 2+ tüm `CAREER_POOL` (12). Seviye 2+'da iş emri başlığı yalnız belirtiyi söyler
  (`ScenarioData.symptom_title`, `GameManager.order_title`; 12 işte dolu, boşsa eski başlık). `CustomerData.min_shop_level` (varsayılan 1): `_assign_customers` yalnız `min_shop_level <= shop_level` olanlardan atar.
  Mağaza (`ResultScreen`): ilk sekme "Dükkân" büyüt kartı (şartlar, eksik olan kırmızı, açılanlar, alım düğmesi, kutlama). Raf alımlarına `UpgradeData.required_level` (NVMe, güç kaynağı 2; ekran kartı 3).
- `src/resources/UpgradeData.gd` + `data/upgrades/*.tres` — Gün sonu mağazasındaki alımlar (Good Pizza, Great Pizza mantığı).
  Türler: `raf` (iş türü açar), `alet` (kolaylık), `dekor` (bahşiş, müşteri). Etki kodda id ile sorgulanır:
  `CareerManager.effect_active(id)` (yalnız kariyerde). Senaryonun `required_upgrade` alanı alınmamışsa müşteri tezgâhta
  geri gönderilir (`turn_away_current`), ücreti gün sonunda "kaçan kazanç" olur. Rafsız işten günde en fazla bir müşteri gelir.
  Kira yok. Alım anında kaydedilir. Yeni alım: `.tres` oluştur, etkisini id ile bağla. `required_level` dükkân seviyesi şartıdır (kapalı-neden: "Seviye N: ad gerekli").
  Dekor etkileri (P5): `isikli_tabela` (2.500 ₺, seviye 2) ve `dolu_raf` (9.000 ₺, seviye 3) günde %50 ihtimalle +1 müşteri (`CareerManager.EXTRA_CUSTOMER_DECOR`, `_begin_day`);
  `vitrin_isigi` (1.200 ₺, seviye 2) memnun müşterinin bahşiş oranına +%5 (`TIP_DECOR_BONUS`, `tip_for`); `saksi` (300 ₺) ve `ikinci_tabure` (800 ₺) yalnız görünüm.
- `src/scenes/ui/ResultScreen.tscn` — Gün sonu özeti (kazanç, bahşiş, geri gönderilen müşteri) ve dükkân mağazası
- `src/scenes/inventory/` — Envanter çekmecesi
- `src/scenes/minigames/` — Mini oyunlar (termal macun, vida sıkma, BIOS boot)
- `src/scenes/ui/` — HUD, menüler ve kullanıcı arayüzü
- `src/utils/` — Ortak yardımcılar (`UIStyle`: yazı tipleri ve CSS benzeri çizim; `PartArt`: parça ve kablo fişi çizimleri, PSU port konumları)
- `src/scenes/workbench/CableLayer.gd` — Takılı ve sürüklenen kabloları (Bezier eğrisi) çizer
- `assets/` — Sprite, font, ses ve tema dosyaları
- `data/components/` — Parçaların oluşturulmuş `.tres` dosyaları

## Kodlama Kuralları
- **Tip Güvenliği**: GDScript 2.0 static typing kullan (`var x: int = 0`)
- **Sınıflar**: Yeniden kullanılabilir her script'te `class_name` tanımla
- **İletişim**: Signal'leri `EventBus` üzerinden tetikle (decoupled mimari için)
- **Node Referansları**: Her zaman `@onready` ile al
- **Inspector**: Inspector'a açılacak değişkenler için `@export` kullan
- **İsimlendirme**: Dosya, sahne ve class isimleri `PascalCase` (`.gd`, `.tscn`), klasör ve resource isimleri `snake_case` olmalıdır
- **Yorum Dili**: Yorumlar ve belgelendirmeler **Türkçe** olmalıdır

## Oyun Mekanikleri
Oyun iki aşamalıdır:
- **Kariyer akışı:** Tezgâh (müşteri yürüyerek gelir, şikâyetini ve bütçesini söyler; RAM/SSD işinde teklif kartından parça seçilir, müşteri tepki verir) → "Bilgisayarı Atölyeye Al" → atölye (tamir)
  → BIOS başarılı → tezgâha dönülür, müşteri yorumunu, yıldızını ve ödemesini söyleyip kapıdan çıkar, sıradakiler ilerler
  → günün son müşterisi gidince Gün Sonu Özeti (`ResultScreen`). Tezgâh görselleri ve yazı tipleri (Baloo 2, Nunito)
  "Müşteri Karakterleri" tasarım dosyasından alındı (`assets/shop/`, `assets/fonts/`).
- **1. Dükkân (Tamir):** Müşteriden hazır bir bilgisayar gelir (iş emri kartı). Oyuncu "Bilgisayarı Başlat" ile
  BIOS'ta arızayı teşhis eder, bozuk kabloyu fişine tıklayarak söker, envanterdeki yedeği takar ve tekrar başlatır.
  Bozuk kablo üzerinde yanık/kıvılcım görünür. Senaryo `random_broken_cable` ile her seferinde farklı kablo bozulabilir.
  - *Termal macun yenileme* (`old_paste`): BIOS aşırı ısınma verir → fan vidalarına basılı tutarak sökülür (fan envantere döner)
    → alkollü bez CPU'ya sürüklenip ovalanır (kurumuş macun silinir) → yeni macun → fan geri takılıp vidalanır.
  - *Arızalı RAM* (`faulty_part`, `removable_parts`): RAM'lerden biri rastgele arızalı ama görünüşte sağlam; BIOS hangi
    DIMM'in bozuk olduğunu ve bip sesini yazar. RAM'i sökmek için yuvanın iki ucundaki mandallara tıklanır (gerçekteki gibi);
    ikisi de açılınca RAM yuvasından kalkar, basılı tutularak envantere/başka yuvaya taşınır. Mandallar kapalıyken RAM kilitlidir.
    Tamir dükkânında envanterdeki yedek parçalar "YENİ" etiketlidir (`ComponentData.is_new`).
  - *Ölü SSD* (`faulty_part: "m2"`): Windows açılmaz, BIOS "M.2 NOT RESPONDING / Reboot and Select proper Boot device" yazar.
    Sökülebilir M.2 ucundaki tek vidayla sabitlenir (`ScrewMechanic.mode = "m2"`): vidaya basılı tutup sök → SSD açılı
    kalkar → envantere taşı → YENİ SSD'yi tak ve vidasını sık (`GameManager.m2_secured`).
  - *CPU Fan Error* (`cpu_fan_error.tres`): fanın kablosu (`cpufan`, `cable_from: "fan"`) anakarttaki FAN girişine takılı
    değil; BIOS "CPU Fan Error! Press F1 to Resume" der. Fan sökülünce kablosu da otomatik çıkıp envantere döner.
- **2. Dükkân (Montaj):** Sıfırdan montaj (`full_build.tres`), aşağıdaki döngü. Bu hâl `tam-montaj-v1` etiketiyle de kayıtlı.

Montaj döngüsü:
1. Mandal aç → CPU tak → Kilitle
2. Termal macun sür (canvas boyama mini oyunu)
3. CPU Fanı tak + 4 vida sık (vida sıkma mini oyunu)
4. RAM, M.2, SATA SSD, ekran kartı ve güç kaynağını yerleştir (envanter boyutu = yuva boyutu, 1:1)
5. Kabloları bağla: fiş envanterden sürüklenir, kablo PSU portundan (SATA veri: anakart SATA portundan) uzar.
   24-pin ATX, CPU 8-pin (EPS), PCIe 8-pin (GPU takılınca), SATA güç ve SATA veri (SSD takılınca)
6. Tüm yuvalar dolu, fan vidalı ve bozuk kablo yokken → "Bilgisayarı Başlat" → BIOS POST
   (BIOS takılı/bozuk parçaları kontrol eder; arıza varsa kırmızı satırla durur)

## Mevcut Durum
- [x] Proje yapısı oluşturuldu
- [x] Autoload singleton'lar yazıldı
- [x] Resource data katmanı tanımlandı
- [x] Sahneler ve scriptler (HTML prototipindeki görünüm ve oynanış birebir taşındı)
- [ ] Sprite'lar oluşturuluyor (şu an tüm görseller `_draw()` ile çiziliyor)
- [x] Mini oyunlar (termal macun, vida sıkma, BIOS boot)

## Değişiklik Günlüğü
| Tarih | Geliştirici | Değişiklik |
|-------|-------------|------------|
| 2026-09-27 | Muhammed | Proje Godot 4'e taşındı. Temel yapı oluşturuldu. |
| 2026-10-14 | Ahmet Selim | `index.html` prototipinin tasarımı ve oynanışı Godot'a birebir taşındı (mandal, macun, vida, kablolar, CMOS, uyarılar). |
| 2026-11-15 | Claude | Aşama 3 / P5: dükkân seviyeleri (`LevelData`, `data/levels`, `CareerManager.shop_level`/`buy_level`), mağazada "Dükkân" sekmesi, seviyeye göre müşteri sayısı, iş havuzu, parça kademesi ve belirsiz iş emri başlığı; 5 dekor alımı ve tezgâh dekor/arka plan altyapısı (görseller henüz yok, dosya yoksa atlanır); `CustomerData.min_shop_level`; kayıt sürümü 6. |
| 2026-11-14 | Claude | Aşama 3 / P2: tezgâhta parça teklifi (`PartOffer`, teklif kartı), müşteri bütçe tipleri, tepkiler, çıkma parça arızası, parça/işçilik ayrı fiş, 3 yeni katalog parçası (DDR3 Kartal/Pusula, M.2 Demirci), kayıt sürümü 5. |
| 2026-11-14 | Claude | Aşama 3 / P1: parça kataloğu (`data/parts`, 29 parça), `create_part(id)`, etikette marka ve kapasite, kayıt sürümü 4. |
| 2026-11-11 | Claude | Görsel yenileme: 10 müşteri yumuşak 2D stilde belden yukarı, 4 ifade; yeni dükkân arka planı ve tezgâh önü; tezgâhtan yükselme/inme, konuşurken ağız, balon yüzün yanında; çay ocağı tezgâhta görünür. |
| 2026-11-10 | Claude | Aşama 2: gün sonu mağazası (Raf, Alet, Dekor), SSD rafı, cırcır tornavida, macun şablonu, çay ocağı, bahşiş, rafsız müşterinin geri gönderilmesi. Kayıt sürümü 3. |
| 2026-11-10 | Claude | Aşama 1: ceza ve kayıt düzeltmeleri, tezgâh ile iş emrinde aynı şikâyet, RAM numarası, kodla üretilen sesler, telefon yatay düzeni (`UIStyle.is_compact`: anakart solda, envanter sağda), Android geri tuşu. |
