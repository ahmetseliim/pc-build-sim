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
- `src/scenes/main/` — Ana oyun sahnesi
- `src/scenes/workbench/` — Montaj masası (Motherboard, MotherboardSlot)
- `src/scenes/inventory/` — Envanter çekmecesi
- `src/scenes/minigames/` — Mini oyunlar (termal macun, vida sıkma, BIOS boot)
- `src/scenes/ui/` — HUD, menüler ve kullanıcı arayüzü
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
Oyunun temel döngüsü aşağıdaki adımlardan oluşur:
1. Mandal aç → CPU tak → Kilitle
2. Termal macun sür (canvas boyama mini oyunu)
3. CPU Fanı tak + 4 vida sık (vida sıkma mini oyunu)
4. RAM, M.2, GPU, PSU kablosu, CMOS pili gibi diğer parçaları yerleştir
5. Tüm parçalar tamamlandığında → BIOS boot ekranına geçiş yap

## Mevcut Durum
- [x] Proje yapısı oluşturuldu
- [x] Autoload singleton'lar yazıldı
- [x] Resource data katmanı tanımlandı
- [ ] Sahneler ve scriptler geliştiriliyor
- [ ] Sprite'lar oluşturuluyor
- [ ] Mini oyunlar implemente ediliyor

## Değişiklik Günlüğü
| Tarih | Geliştirici | Değişiklik |
|-------|-------------|------------|
| 2026-09-27 | Muhammed | Proje Godot 4'e taşındı. Temel yapı oluşturuldu. |
