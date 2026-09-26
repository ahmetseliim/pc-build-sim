extends Node

# Global sinyal veriyolu (EventBus)
# Tüm sistemlerin birbirinden bağımsız haberleşmesini sağlar.

signal part_installed(slot_id: String, part_data: Resource)
signal part_removed(slot_id: String)
signal paste_applied()
signal paste_failed()
signal screw_locked(screw_id: String)
signal all_screws_locked()
signal fan_mounted()
signal build_complete()
signal bios_boot_started()
signal bios_boot_finished()
signal inventory_updated()
