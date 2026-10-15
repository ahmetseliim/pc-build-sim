# AI Agents Kılavuzu (AGENTS.md)

Bu dosya, AI kodlama asistanlarının (Antigravity, Cursor, Copilot vb.) projeyi anlamasına yardımcı olmak için hazırlanmıştır.

## Proje Özeti
- **PC Build Simulator**: Sürükle-bırak mekanizmasıyla bilgisayar parçalarını anakarta yerleştiren bir 2D mobil simülasyon oyunu
- **Motor**: Godot 4.3, GDScript
- **Hedef Platformlar**: Android, iOS
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
- `src/scenes/workbench/` — Montaj masası (Motherboard, MotherboardSlot)
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
- **1. Dükkân (Tamir):** Müşteriden hazır bir bilgisayar gelir (iş emri kartı). Oyuncu "Bilgisayarı Başlat" ile
  BIOS'ta arızayı teşhis eder, bozuk kabloyu fişine tıklayarak söker, envanterdeki yedeği takar ve tekrar başlatır.
  Bozuk kablo üzerinde yanık/kıvılcım görünür. Senaryo `random_broken_cable` ile her seferinde farklı kablo bozulabilir.
  - *Termal macun yenileme* (`old_paste`): BIOS aşırı ısınma verir → fan vidalarına basılı tutarak sökülür (fan envantere döner)
    → alkollü bez CPU'ya sürüklenip ovalanır (kurumuş macun silinir) → yeni macun → fan geri takılıp vidalanır.
  - *Arızalı RAM* (`faulty_part`, `removable_parts`): RAM'lerden biri rastgele arızalı ama görünüşte sağlam; BIOS hangi
    DIMM'in bozuk olduğunu ve bip sesini yazar. RAM'i sökmek için yuvanın iki ucundaki mandallara tıklanır (gerçekteki gibi);
    ikisi de açılınca RAM yuvasından kalkar, basılı tutularak envantere/başka yuvaya taşınır. Mandallar kapalıyken RAM kilitlidir.
    Tamir dükkânında envanterdeki yedek parçalar "YENİ" etiketlidir (`ComponentData.is_new`).
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
