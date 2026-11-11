"""Static sanity check of src/shared/Config.lua + BattlePass.lua with the standalone `luau` CLI (no Roblox).
usage: python3 tools/check_config.py [/path/to/luau]"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
luau = sys.argv[1] if len(sys.argv) > 1 else "luau"


def read(rel):
    with open(os.path.join(HERE, rel), encoding="utf-8") as f:
        return f.read()


config = re.sub(r"^return Config\s*$", "", read("src/shared/Config.lua"), flags=re.M)
bp = read("src/shared/BattlePass.lua").replace("local Config = require(script.Parent.Config)", "")
bp = re.sub(r"^return BP\s*$", "", bp, flags=re.M)
checks = read("tools/check_config.luau")
checks = "\n".join(l for l in checks.splitlines() if not l.startswith(("Color3 = ", "script = ", "local Config = require", "local BP = require")))
stub = "local Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end, new = function(r, g, b) return { r = r, g = g, b = b } end }\n"
with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
    f.write(stub + config + "\n" + bp + "\n" + checks)
    path = f.name
try:
    res = subprocess.run([luau, path], capture_output=True, text=True)
    print(res.stdout.strip())
    if res.returncode != 0:
        print(res.stderr.strip())
    sys.exit(res.returncode)
finally:
    os.unlink(path)
