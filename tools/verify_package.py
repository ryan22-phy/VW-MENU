"""Verify local packaging integrity, ownership of sources and evidence hashes.

No Lua/Luau is executed by this script. Python standard library only.
"""
from pathlib import Path
import hashlib
import json
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MODULES = ["CleanupManager", "SettingsManager", "NotificationManager", "UIController",
           "FeatureRegistry", "FeatureController", "Main"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify():
    standalone = (ROOT / "VW_MENU.lua").read_text(encoding="utf-8")
    model = ET.parse(str(ROOT / "VW_MENU.rbxmx"))
    scripts = {}
    for item in model.iter("Item"):
        props = item.find("Properties")
        if props is not None and item.attrib["class"] in ("ModuleScript", "LocalScript"):
            scripts[props.find("string[@name='Name']").text] = props.find("ProtectedString[@name='Source']").text
    assert len(scripts) == 8, "Model must contain seven modules and one bootstrap"
    files = {}
    for name in MODULES + ["Bootstrap.client"]:
        path = ROOT / "src" / (name + ".lua")
        source = path.read_text(encoding="utf-8-sig")
        model_name = name.replace(".client", "")
        assert scripts[model_name] == source, "Model differs from source: " + name
        if name in MODULES:
            bundled = re.sub(r"require\(script\.Parent\.(\w+)\)", r'__require("\1")', source)
            assert bundled in standalone, "Standalone differs from source: " + name
        # These patterns would introduce remote execution or executor coupling.
        assert not re.search(r"\b(?:loadstring|getgenv|gethui|readfile|writefile|hookmetamethod)\s*\(|\bHttpGet\s*\(|https?://", source), "Unexpected remote/executor dependency in " + name
        files[str(path.relative_to(ROOT))] = {"bytes": path.stat().st_size, "sha256": sha(path)}
    assert "script.Parent" not in standalone, "Unresolved module dependency"
    for artifact in ("VW_MENU.lua", "VW_MENU.rbxmx"):
        path = ROOT / artifact
        files[artifact] = {"bytes": path.stat().st_size, "sha256": sha(path)}
    result = {
        "result": "PASS", "sourceModules": len(MODULES), "bootstrapScripts": 1,
        "checks": ["model-source equality", "standalone-source equality", "local module resolution",
                   "no remote/executor dependency in independent sources"],
        "scope": "Packaging and source checks only; not a Roblox runtime test",
        "files": files,
    }
    target = ROOT / "tests" / "package-results.json"
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Package integrity: PASS (7 modules, 1 bootstrap, local dependencies only)")


if __name__ == "__main__":
    verify()
