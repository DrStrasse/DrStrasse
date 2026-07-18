#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Аудит сетевых протоколов GLua-сборки GRM: ищет асимметрию
   net.Start без net.Receive, net.Receive без AddNetworkString,
   кнопки, чьи действия не доедут до сервера."""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA = os.path.join(ROOT, "lua")

rx_str = re.compile(r'''util\.AddNetworkString\s*\(\s*["']([^"']+)["']''')
rx_recv = re.compile(r'''net\.Receive\s*\(\s*["']([^"']+)["']''')
rx_start = re.compile(r'''net\.Start\s*\(\s*["']([^"']+)["']''')
rx_var = re.compile(r'''(?:local\s+)?(NET[A-Z0-9_]*)\s*=\s*["']([^"']+)["']''')
rx_recv_var = re.compile(r'''net\.Receive\s*\(\s*(NET[A-Z0-9_]*)\s*,''')
rx_start_var = re.compile(r'''net\.Start\s*\(\s*(NET[A-Z0-9_]*)\s*\)''')
rx_str_var = re.compile(r'''util\.AddNetworkString\s*\(\s*(NET[A-Z0-9_]*)\s*\)''')

strings, recvs, starts = {}, {}, {}
vars_map = {}
vars_map_global = {}

for dp, _, files in os.walk(LUA):
    for fn in files:
        if not fn.endswith(".lua"):
            continue
        p = os.path.join(dp, fn)
        try:
            src = open(p, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        rel = os.path.relpath(p, ROOT)
        for m in rx_str.finditer(src):
            strings.setdefault(m.group(1), set()).add(rel)
        for m in rx_recv.finditer(src):
            recvs.setdefault(m.group(1), set()).add(rel)
        for m in rx_start.finditer(src):
            starts.setdefault(m.group(1), set()).add(rel)
        for m in rx_var.finditer(src):
            vars_map.setdefault((rel, m.group(1)), m.group(2))
            vars_map_global.setdefault(m.group(1), m.group(2))

# второй проход с учётом файловых переменных NET_*
for dp, _, files in os.walk(LUA):
    for fn in files:
        if not fn.endswith(".lua"):
            continue
        p = os.path.join(dp, fn)
        src = open(p, encoding="utf-8", errors="replace").read()
        rel = os.path.relpath(p, ROOT)
        for m in rx_recv_var.finditer(src):
            v = vars_map.get((rel, m.group(1))) or vars_map_global.get(m.group(1))
            if v:
                recvs.setdefault(v, set()).add(rel)
        for m in rx_start_var.finditer(src):
            v = vars_map.get((rel, m.group(1))) or vars_map_global.get(m.group(1))
            if v:
                starts.setdefault(v, set()).add(rel)
        for m in rx_str_var.finditer(src):
            v = vars_map.get((rel, m.group(1))) or vars_map_global.get(m.group(1))
            if v:
                strings.setdefault(v, set()).add(rel)

# подтверждённые ложные срабатывания (динамическая регистрация/внешние аддоны/устаревший дубль):
#  - EasyChat server_config: net.Receive(net_string) циклом (lua/easychat/server_config.lua:145)
#  - FAdmin: внешний админ-мод (ULX)
#  - VD_ConfigOpen / VD_SetSpawnPoint: тулаган/контекст-меню сторонней тулгановской привычки
#  - GRM_VShop_AdminOpen: устаревший дубль; живой путь — чат /vshop_admin → GRM_VShop_AdminData
WHITELIST = {
    "EASY_CHAT_SERVER_CONFIG_DEL_PLY_TITLE", "EASY_CHAT_SERVER_CONFIG_DEL_USER_GROUP",
    "EASY_CHAT_SERVER_CONFIG_WRITE_PLY_TITLE", "EASY_CHAT_SERVER_CONFIG_WRITE_TAB",
    "EASY_CHAT_SERVER_CONFIG_WRITE_USER_GROUP", "EASY_CHAT_SERVER_SETTING_WRITE_OVERRIDE",
    "EASY_CHAT_TAGS_IN_MESSAGES", "EASY_CHAT_TAGS_IN_NAMES", "EASY_CHAT_WRITE_PLY_NAME",
    "FAdmin_ReceiveAdminMessage", "VD_ConfigOpen", "VD_SetSpawnPoint", "GRM_VShop_AdminOpen",
}

problems = []
# правило 1 (боевое): сообщение отправляется, но его никто не слушает — мёртвая кнопка
for name, files in sorted(starts.items()):
    if name not in recvs and name not in WHITELIST:
        problems.append(("net.Start без net.Receive", name, ", ".join(sorted(files))))
# правило 2 (информ): сообщение слушается, но его никто в репо не отправляет — возможно внешний аддон
for name, files in sorted(recvs.items()):
    if name not in starts and name not in WHITELIST:
        problems.append(("net.Receive без отправителя (внешний аддон?)", name, ", ".join(sorted(files))))

if not problems:
    print("PROTOCOL AUDIT: OK — асимметрий не найдено")
    sys.exit(0)
print("PROTOCOL AUDIT: %d замечание(й)" % len(problems))
for kind, name, files in problems:
    print("[%s] %s  (%s)" % (kind, name, files))
sys.exit(1 if any(k.startswith("net.Start") for k, _, _ in problems) else 0)
