extends Node

# Global sinyal veriyolu (EventBus)
# Tüm sistemlerin birbirinden bağımsız haberleşmesini sağlar.

signal part_installed(slot_id: String, part_data: Resource)
signal part_removed(slot_id: String, part_data: Resource)
signal part_drag_started(part: Control) ## Parça envanterden tutuldu
signal part_dropped(part: Control, global_point: Vector2) ## Parça sürüklenip bırakıldı
signal part_return_requested(part: Control) ## Parça envantere geri dönmeli
signal part_unplug_requested(part: Control) ## Takılı (bozuk) kablo sökülmek istendi
signal part_extract_requested(part: Control) ## Takılı parça yuvasından tutulup çekildi (sürükleyerek söküm)
signal part_locked_touched(part: Control) ## Mandalları kapalı (kilitli) parça tutulmaya çalışıldı
signal cpu_state_changed(state: String)
signal warning_requested(message: String) ## Oyuncuya uyarı göster (HTML'deki alert)
signal info_requested(message: String) ## Oyuncuya bilgi mesajı göster
signal paste_applied()
signal paste_failed()
signal screw_locked(screw_id: String)
signal all_screws_locked()
signal fan_mounted()
signal fan_unmounted() ## Fanın dört vidası da söküldü
signal build_complete()
signal bios_boot_requested() ## "Bilgisayarı Başlat" butonuna basıldı
signal bios_boot_started()
signal bios_boot_finished()
signal boot_failed() ## POST testi arıza buldu
signal inventory_updated()
