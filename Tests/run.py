"""Compile shipped Lua as 5.1 and exercise history without a WoW process."""
from pathlib import Path
import re

from lupa.lua51 import LuaRuntime


root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval("function(source, name) assert(loadstring(source, name)) end")
files = [path for path in root.rglob("*.lua") if "Tests" not in path.parts]
for path in files:
    compile_lua(path.read_text(encoding="utf-8-sig"), str(path))
print(f"PASS: {len(files)} addon files compile with {lua.eval('_VERSION')}")

toc = (root / "Sintezza_Loot.toc").read_text(encoding="utf-8-sig")
version = re.search(r"^## Version:\s*(\S+)", toc, re.M)[1]
assert "16001" in re.search(r"^## Interface:\s*(.+)", toc, re.M)[1]
sections = re.findall(r"^## (\S+)", (root / "CHANGELOG.md").read_text(encoding="utf-8-sig"), re.M)
assert next(section for section in sections if section != "Unreleased") == version
assert f'rawVersion = "{version}"' in (root / "Core.lua").read_text(encoding="utf-8-sig")
for line in toc.splitlines():
    if line.strip() and not line.startswith("#"):
        assert (root / line.strip().replace("\\", "/")).is_file(), line
print(f"PASS: TOC paths, Forever interface and version {version}")

lua.globals().ADDON_ROOT = root.as_posix()
lua.execute((root / "Tests" / "History.lua").read_text(encoding="utf-8"))
lua.execute((root / "Tests" / "RunEvidence.lua").read_text(encoding="utf-8"))
lua.execute((root / "Tests" / "HistoryUI.lua").read_text(encoding="utf-8"))
lua.execute((root / "Tests" / "HistoryLocale.lua").read_text(encoding="utf-8"))
lua.execute((root / "Tests" / "TrackerRefresh.lua").read_text(encoding="utf-8"))
lua.execute((root / "Tests" / "TrackerLifecycle.lua").read_text(encoding="utf-8"))
lua.execute((root / "Tests" / "RollSkinSettings.lua").read_text(encoding="utf-8"))
