#!/usr/bin/env python3
"""
tools/audit_perf.py — аудит нагрузки и порядка выполнения GRM.

Ищет в lua-файлах:
  1) покадровые хуки (Think, Tick, HUDPaint, PostDraw*, RenderScene, Move,
     SetupMove, CreateMove, PreDrawOpaqueRenderables) и внутри них —
     дорогие вызовы (ents.FindByClass/FindInSphere, player.GetAll,
     util.TraceLine/TraceHull, GetEyeTrace, Material, file.Read/Write,
     util.JSONToTable, table.Copy, string.find в цикле);
  2) частые таймеры (timer.Create с интервалом < 1 c);
  3) старты подсистем (InitPostEntity / Initialize / timer.Simple на старте),
     которые ещё не переведены на GRM.Boot;
  4) ent:Think без NextThink-троттлинга.

Вывод: таблица «файл — тип — деталь», сгруппированная по тяжести.
Использование: python3 tools/audit_perf.py [--json]
"""
import os, re, sys, json, math
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAN_DIRS = ["lua", "addons"]
SKIP_PARTS = ("/easychat/", "/luatest/", "/.luabuild/")

FRAME_HOOKS = ("Think", "Tick", "HUDPaint", "HUDPaintBackground", "PostDrawTranslucentRenderables",
               "PostDrawOpaqueRenderables", "PreDrawOpaqueRenderables", "RenderScene",
               "SetupMove", "CreateMove", "Move", "DrawOverlay", "PostRender", "PreRender")

HEAVY = {
    "ents.FindByClass": 4, "ents.FindInSphere": 4, "ents.FindInBox": 4, "ents.GetAll": 5,
    "player.GetAll": 3, "util.TraceLine": 3, "util.TraceHull": 3, "GetEyeTrace": 3,
    "file.Read": 5, "file.Write": 5, "file.Find": 5, "util.JSONToTable": 4, "util.TableToJSON": 4,
    "Material(": 2, "surface.GetTextSize": 1, "table.Copy": 2, "net.Start": 2,
    "SetNWString": 1, "SetNWInt": 1, "SetNWFloat": 1, "SetNWBool": 1,
}

# перф-слой GRM: эти обёртки уже кэшируют, их не считаем нарушением
SAFE_PREFIX = ("GRM.Perf.", "GRM.Boot.")


def strip_comments(src: str) -> str:
    """Вырезает комментарии, СОХРАНЯЯ переносы строк — иначе номера строк
    в отчёте уезжают и указывают не на тот код."""
    def keep_newlines(m):
        return "\n" * m.group(0).count("\n")
    src = re.sub(r"--\[\[.*?\]\]", keep_newlines, src, flags=re.S)
    src = re.sub(r"--[^\n]*", "", src)
    return src


def block_of(src: str, start: int) -> str:
    """Грубое выделение тела функции от позиции start до баланса end."""
    depth = 0
    i = start
    n = len(src)
    began = False
    while i < n:
        m = re.compile(r"\b(function|if|for|while|do|end)\b").search(src, i)
        if not m:
            break
        word = m.group(1)
        if word in ("function", "if", "for", "while", "do"):
            depth += 1
            began = True
        elif word == "end":
            depth -= 1
        i = m.end()
        if began and depth <= 0:
            return src[start:i]
    return src[start:start + 4000]


def scan_file(path: str):
    rel = os.path.relpath(path, ROOT)
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return []
    src = strip_comments(raw)
    findings = []

    # 1) покадровые хуки
    for m in re.finditer(r'hook\.Add\(\s*"([A-Za-z_]+)"\s*,\s*"([^"]*)"', src):
        hook_name, hook_id = m.group(1), m.group(2)
        if hook_name not in FRAME_HOOKS:
            continue
        body = block_of(src, m.end())
        # block_of иногда «переезжает» за конец хука (однострочные if/end в
        # минифицированном коде). Обрезаем по первому закрытию hook.Add.
        cut = body.find("\nend)")
        if cut > 0:
            body = body[:cut]
        score = 0
        hits = []
        # Построчно: строка, где уже используется перф-слой GRM (кэш сущностей,
        # игроков, change-only NW), нарушением не считается — там ents.FindByClass
        # стоит лишь как фолбэк.
        # Склеиваем перенос логического «or» с предыдущей строкой: фолбэк
        # вида «GRM.Perf.Entities(c)\n or ents.FindByClass(c)» — не нарушение.
        merged, lines = [], body.split("\n")
        for line in lines:
            if merged and line.lstrip().startswith(("or ", "and ")):
                merged[-1] = merged[-1] + " " + line.strip()
            else:
                merged.append(line)
        for line in merged:
            if any(p in line for p in SAFE_PREFIX):
                continue
            for call, weight in HEAVY.items():
                cnt = line.count(call)
                if cnt:
                    score += weight * cnt
                    hits.append(call)
        # Хук с собственным троттлингом (ранний выход по CurTime) считается
        # вдвое легче: тяжёлая работа выполняется не каждый кадр.
        head = body[:260]
        throttled = ("CurTime()" in head and "return" in head) or ("RealTime()" in head and "return" in head)
        if throttled:
            score = math.floor(score / 2)
        if score >= 3:
            findings.append({
                "file": rel, "kind": "frame_hook", "score": score,
                "detail": ("[троттлинг есть] " if throttled else "") +
                    f"{hook_name} / {hook_id}: " + ", ".join(sorted(set(hits))),
            })

    # 2) частые таймеры
    for m in re.finditer(r'timer\.Create\(\s*[^,]+,\s*([0-9.]+)', src):
        try:
            period = float(m.group(1))
        except ValueError:
            continue
        if period < 1.0:
            line = src[:m.start()].count("\n") + 1
            # Фолбэк-ветка «если GRM.Boot нет — крутим таймер» не выполняется
            # на живом сервере: Boot есть всегда. Такие места не считаем.
            window = src[max(0, m.start() - 400):m.start()]
            if "GRM.Boot" in window:
                continue
            findings.append({
                "file": rel, "kind": "fast_timer", "score": int(6 / max(period, 0.05)),
                "detail": f"строка {line}: интервал {period} c",
            })

    # 3) старты не через Boot
    boot_used = "GRM.Boot" in src
    for m in re.finditer(r'hook\.Add\(\s*"(InitPostEntity|Initialize|PostGamemodeLoaded)"\s*,\s*"([^"]*)"', src):
        if boot_used:
            continue
        findings.append({
            "file": rel, "kind": "eager_start", "score": 3,
            "detail": f"{m.group(1)} / {m.group(2)} — не переведён на GRM.Boot",
        })

    # 4) ENT:Think без троттлинга
    for m in re.finditer(r'function\s+ENT:Think\s*\(', src):
        # block_of на минифицированном коде обрывается раньше времени —
        # смотрим фиксированное окно после объявления.
        body = src[m.end():m.end() + 4000]
        if "NextThink" not in body and "CurTime()" not in body:
            findings.append({
                "file": rel, "kind": "ent_think", "score": 4,
                "detail": "ENT:Think без SetNextThink/троттлинга по CurTime",
            })

    return findings


def main():
    all_findings = []
    for d in SCAN_DIRS:
        base = os.path.join(ROOT, d)
        for dirpath, _dirs, files in os.walk(base):
            for fn in files:
                if not fn.endswith(".lua"):
                    continue
                full = os.path.join(dirpath, fn)
                rel = "/" + os.path.relpath(full, ROOT).replace(os.sep, "/")
                if any(p in rel for p in SKIP_PARTS):
                    continue
                all_findings.extend(scan_file(full))

    if "--json" in sys.argv:
        print(json.dumps(all_findings, ensure_ascii=False, indent=1))
        return

    by_kind = defaultdict(list)
    for f in all_findings:
        by_kind[f["kind"]].append(f)

    titles = {
        "frame_hook": "ПОКАДРОВЫЕ ХУКИ С ТЯЖЁЛЫМИ ВЫЗОВАМИ",
        "fast_timer": "ТАЙМЕРЫ ЧАЩЕ РАЗА В СЕКУНДУ",
        "eager_start": "СТАРТЫ ПОДСИСТЕМ МИМО GRM.Boot",
        "ent_think": "ENT:Think БЕЗ ТРОТТЛИНГА",
    }
    for kind in ("frame_hook", "fast_timer", "ent_think", "eager_start"):
        rows = sorted(by_kind.get(kind, []), key=lambda r: -r["score"])
        print("\n=== %s (%d) ===" % (titles[kind], len(rows)))
        for r in rows[:40]:
            print("  %3d  %-62s %s" % (r["score"], r["file"], r["detail"]))
        if len(rows) > 40:
            print("  … ещё %d" % (len(rows) - 40))

    print("\nВсего находок: %d" % len(all_findings))


if __name__ == "__main__":
    main()
