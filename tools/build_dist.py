#!/usr/bin/env python3
"""Пересборка архивов dist/ из рабочего дерева.

Четыре архива:
  grm_single_addon.zip  — весь аддон, файлы под префиксом grm/
  grm_full_code.zip     — то же самое, но без префикса
  grm_economy.zip       — экономика, банк, документы, служебные компьютеры
                          и модули розыска/штрафов, от которых они зависят
  grm_fix_hud_tab_currency.zip — точечный фикс HUD/TAB/валюты

Запуск: python3 tools/build_dist.py
"""
import os
import shutil
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")

# Каталоги контента аддона (те, что реально существуют, попадают в сборку).
CONTENT_DIRS = ["lua", "materials", "models", "sound", "resource", "gamemodes", "maps"]

# Экономический срез: ядро экономики + всё, что его использует.
ECONOMY_FILES = [
    # Общие контракты нужны service-компьютерам: Access/Net/Audit/Persistence.
    "lua/autorun/sh_01_grm_core.lua",
    "lua/autorun/sh_02_grm_persistence.lua",
    "lua/autorun/sh_03_grm_access.lua",
    "lua/autorun/sh_04_grm_net.lua",
    "lua/autorun/sh_05_grm_audit.lua",
    "lua/autorun/sh_06_grm_performance.lua",
    "lua/autorun/sh_07_grm_sound.lua",
    "lua/autorun/sh_grm_identity.lua",
    "lua/autorun/sh_grm_currency.lua",
    "lua/autorun/sh_grm_economy.lua",
    "lua/autorun/sh_grm_incassation.lua",
    "lua/autorun/sh_grm_perm_entities.lua",
    "lua/autorun/sh_grm_prop_protect.lua",
    "lua/autorun/sh_grm_medical.lua",
    "lua/autorun/sh_grm_documents.lua",
    # розыск и штрафы: служебные компьютеры ниже без них не работают
    "lua/autorun/sh_grm_wanted_config.lua",
    "lua/autorun/sh_grm_wanted_access.lua",
    "lua/autorun/sh_grm_wanted_fines.lua",
    # фаза 3: лист розыска, ориентировки, обмен сведениями, спецслужбы
    "lua/autorun/sh_grm_wanted_board.lua",
    "lua/autorun/sh_grm_wanted_bulletins.lua",
    "lua/autorun/sh_grm_wanted_exchange.lua",
    "lua/autorun/sh_grm_special_service.lua",
    # фаза 4: госуслуги, счета, дипломы и меню банкомата
    "lua/autorun/sh_grm_services.lua",
    "lua/autorun/sh_grm_service_orders.lua",
    "lua/autorun/sh_grm_diplomas.lua",
    "lua/autorun/sh_grm_atm.lua",
    "lua/autorun/server/sv_grm_services_commands.lua",
    "lua/autorun/sh_factions.lua",
    "lua/autorun/client/cl_grm_ui_theme.lua",
    "lua/autorun/sh_00_grm_ui.lua",
    "lua/autorun/server/sv_grm_wanted.lua",
    "lua/autorun/server/sv_grm_comp_terminal.lua",
    "lua/autorun/server/sv_grm_wanted_commands.lua",
    "lua/autorun/client/cl_grm_wanted.lua",
    "lua/autorun/client/cl_grm_comp_terminal.lua",
    "lua/weapons/weapon_grm_incass_bag/shared.lua",
    "lua/weapons/gmod_tool/stools/grm_bank_tool.lua",
    "lua/weapons/gmod_tool/stools/grm_service_tool.lua",
]
# Энтити экономического среза — целиком по три файла.
ECONOMY_ENTS = [
    "grm_bank_terminal", "grm_bank_vault", "grm_bank_computer", "grm_doc_computer",
    "grm_comp_police", "grm_comp_military_police", "grm_comp_security",
    "grm_comp_military", "grm_comp_traffic", "grm_comp_medical",
    "grm_comp_cityhall", "grm_comp_court",
    "grm_vault_cash", "grm_money_press", "grm_money_printer",
]
for ent in ECONOMY_ENTS:
    for part in ("cl_init.lua", "init.lua", "shared.lua"):
        ECONOMY_FILES.append("lua/entities/%s/%s" % (ent, part))

HUD_FIX_FILES = [
    "lua/autorun/sh_grm_currency.lua",
    "lua/autorun/sh_grm_economy.lua",
    "lua/autorun/sh_grm_tab_menu.lua",
    "lua/autorun/client/cl_grm_hud.lua",
]


def collect_all():
    """Все файлы контента в рабочем дереве, путями относительно корня репозитория."""
    out = []
    for d in CONTENT_DIRS:
        base = os.path.join(ROOT, d)
        if not os.path.isdir(base):
            continue
        for dirpath, _dirnames, filenames in os.walk(base):
            for fn in sorted(filenames):
                full = os.path.join(dirpath, fn)
                out.append(os.path.relpath(full, ROOT))
    return sorted(out)


def build(name, files, prefix=""):
    path = os.path.join(DIST, name)
    tmp = path + ".tmp"
    written = 0
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in files:
            src = os.path.join(ROOT, rel)
            if not os.path.isfile(src):
                print("  пропуск (нет файла): %s" % rel)
                continue
            z.write(src, prefix + rel)
            written += 1
    shutil.move(tmp, path)
    size = os.path.getsize(path)
    print("%-34s %4d файлов, %8.1f КБ" % (name, written, size / 1024.0))


def main():
    os.makedirs(DIST, exist_ok=True)
    everything = collect_all()
    build("grm_single_addon.zip", everything, prefix="grm/")
    build("grm_full_code.zip", everything)
    build("grm_economy.zip", ECONOMY_FILES, prefix="grm/")
    build("grm_fix_hud_tab_currency.zip", HUD_FIX_FILES)


if __name__ == "__main__":
    main()
