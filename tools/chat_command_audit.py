#!/usr/bin/env python3
"""Inventory GRM chat commands and detect the RP-chat command swallowing regression."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LUA = ROOT / "lua"
HOOK_RE = re.compile(r'hook\.Add\(\s*["\']PlayerSay["\']')
CMD_RE = re.compile(r'["\']([!/][A-Za-z_][A-Za-z0-9_]*)(?:\s|["\'])')

files = []
commands = set()
player_say_only = []
for path in sorted(LUA.rglob("*.lua")):
    text = path.read_text(encoding="utf-8", errors="ignore")
    if not HOOK_RE.search(text):
        continue
    found = sorted(set(CMD_RE.findall(text)))
    if not found:
        continue
    rel = path.relative_to(ROOT).as_posix()
    files.append((rel, found, "PlayerSayTransform" in text))
    commands.update(found)
    if "PlayerSayTransform" not in text:
        player_say_only.append(rel)

rp_path = LUA / "autorun" / "sh_grm_rp_chat.lua"
rp = rp_path.read_text(encoding="utf-8", errors="ignore")
guard = 'if prefix == "/" or prefix == "!" then return end'
if guard not in rp:
    print("ERROR: RP-chat may swallow commands belonging to other modules", file=sys.stderr)
    sys.exit(1)

required = {
    "lua/autorun/sh_grm_arrest.lua": ("PlayerSayTransform", "/grm_arrest_admin", "/arrest", "/unarrest"),
    "lua/autorun/sh_faction_fixes.lua": ("FactionsExt_MaskCommands", "/mask"),
    "lua/autorun/sh_grm_admin_hub.lua": ('net.Start("GRM_Arrest_Admin")',),
}
for rel, needles in required.items():
    text = (ROOT / rel).read_text(encoding="utf-8", errors="ignore")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        print(f"ERROR: {rel} misses command routing contract: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)

print(f"CHAT COMMAND AUDIT: {len(commands)} command names in {len(files)} PlayerSay modules")
print(f"PlayerSay-only modules protected by RP pass-through: {len(player_say_only)}")
for rel in player_say_only:
    print(f"  fallback: {rel}")
print("RP unknown slash/bang pass-through: OK")
