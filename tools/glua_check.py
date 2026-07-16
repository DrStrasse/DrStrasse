import os
import re
import subprocess
import tempfile

def check_glua(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        code = f.read()
    
    lines = code.splitlines()
    cleaned = []
    for line in lines:
        in_string = False
        res = []
        i = 0
        while i < len(line):
            ch = line[i]
            if ch in ('"', "'"):
                if not in_string:
                    in_string = ch
                elif in_string == ch and (i == 0 or line[i-1] != '\\'):
                    in_string = False
            elif not in_string and line[i:i+2] == "//":
                break
            res.append(ch)
            i += 1
        cleaned.append("".join(res))
    code = "\n".join(cleaned)
    
    code = re.sub(r"\bcontinue\b", "do end", code)
    code = re.sub(r"&&", " and ", code)
    code = re.sub(r"\|\|", " or ", code)
    code = re.sub(r"!(?=[^=])", " not ", code)
    
    with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8", delete=False) as tmp:
        tmp.write(code)
        tmp_name = tmp.name
        
    res = subprocess.run(["./.luabuild/lj/src/luajit", "-e", f"local f, err = loadfile([[{tmp_name}]]); if not f then print(err); os.exit(1) end"], capture_output=True, text=True)
    os.remove(tmp_name)
    return res.returncode == 0, res.stdout + res.stderr

lua_files = []
for root, dirs, files in os.walk("."):
    if ".luabuild" in root or ".git" in root or "tools" in root:
        continue
    for f in files:
        if f.endswith(".lua"):
            lua_files.append(os.path.join(root, f))

errs = 0
for path in sorted(lua_files):
    p = os.path.relpath(path, ".")
    ok, msg = check_glua(p)
    if not ok:
        print(f"GLua Syntax check error in {p}:\n{msg}")
        errs += 1

print(f"GLua Syntax check complete: {len(lua_files)} files checked, {errs} syntax errors.")
