"""Rebuild and check independent code using explicit local Luau executables.

Usage: python tools/validate.py --luau PATH/luau.exe --compiler PATH/luau-compile.exe
No downloads, installation, Roblox launch or execution of reference samples.
"""
from pathlib import Path
import argparse
import datetime
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    parser.add_argument("--compiler", required=True)
    parser.add_argument("--work-dir", default=str(Path.cwd() / "work" / "vw-menu-validation"))
    args = parser.parse_args()
    temporary = Path(args.work_dir).resolve()
    temporary.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment["TMP"] = str(temporary)
    environment["TEMP"] = str(temporary)
    python = sys.executable
    steps = [
        ("build", [python, "-B", str(ROOT / "tools/build.py")]),
        ("package", [python, "-B", str(ROOT / "tools/verify_package.py")]),
        ("evidence", [python, "-B", str(ROOT / "analysis/tools/verify_evidence.py")]),
        ("isolated_logic", [python, "-B", str(ROOT / "tests/isolated_tests.py"), "--luau", args.luau]),
        ("main_integration", [python, "-B", str(ROOT / "tests/main_integration_tests.py"), "--luau", args.luau]),
    ]
    sources = sorted(str(p) for p in (ROOT / "src").glob("*.lua"))
    sources += sorted(str(p) for p in (ROOT / "tests").glob("*.lua"))
    sources.append(str(ROOT / "VW_MENU.lua"))
    steps.append(("compile", [args.compiler, "--null"] + sources))
    result = {
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
        "scope": "Local compilation, static evidence and isolated logic/adapters; not Roblox runtime",
        "steps": [],
    }
    for name, command in steps:
        run = subprocess.run(command, cwd=str(ROOT), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             universal_newlines=True, encoding="utf-8", errors="replace", env=environment)
        result["steps"].append({"name": name, "exit_code": run.returncode, "output": run.stdout})
        print("{}: {} (exit {})".format(name, "PASS" if run.returncode == 0 else "FAIL", run.returncode))
        if name == "compile":
            (ROOT / "tests/compile-results.txt").write_text(
                "Official Luau compiler v0.740\nFiles: {}\nExit code: {}\n{}\n"
                "Only independent code/tests compiled. No reference sample compiled.\n".format(
                    len(sources), run.returncode, run.stdout), encoding="utf-8")
        if run.returncode != 0:
            print(run.stdout)
            break
    result["result"] = "PASS" if len(result["steps"]) == len(steps) and all(
        item["exit_code"] == 0 for item in result["steps"]) else "FAIL"
    (ROOT / "tests/final-validation.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if result["result"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
