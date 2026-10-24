"""Python 3.6+: validate evidence identity and coordinates without evaluating Lua."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
expected = {
    "scriptblox-raw-direct.body": (59, "da0393d9129e697ede95a56103d2e30bc329c499ef9e9e87396c2af2b5752970"),
    "lumin-loader-direct.body": (291684, "aecbc6c2561acd12bb37ca5692ff42c39b65e603d73c9019746d1d4611ebc402"),
}
checks = []
for name, (size, digest) in expected.items():
    data = (root / "evidence" / name).read_bytes()
    assert len(data) == size, name + ": size mismatch"
    assert hashlib.sha256(data).hexdigest() == digest, name + ": digest mismatch"
    metadata_name = name[:-5] + ".metadata.json"
    metadata = json.loads((root / "evidence" / metadata_name).read_text(encoding="utf-8-sig"))
    assert metadata["status"] == 200 and metadata["executed"] is False
    assert metadata["sha256"] == digest and metadata["bytes"] == size
    checks.append("identity_and_HTTP_metadata:" + name)

scan = json.loads((root / "evidence/static-lexical-summary.json").read_text(encoding="utf-8"))
source = (root / "evidence/lumin-loader-direct.body").read_text(encoding="utf-8")
assert scan["source_sha256"] == expected["lumin-loader-direct.body"][1]
assert scan["source_lines"] == 3
assert scan["string_count"] == 26
assert sum(item["kind"] == "long_bracket" for item in scan["strings"]) == 1
assert len(scan["visible_aliases"]) == 27
for entry in scan["strings"] + scan["comments"] + scan["visible_aliases"] + scan["literal_url_candidates"]:
    offset = entry["offset_zero_based"]
    assert entry["line_one_based"] == source.count("\n", 0, offset) + 1
    assert entry["column_one_based"] == offset - source.rfind("\n", 0, offset)
    if "raw" in entry:
        assert source[offset:offset + entry["length"]] == entry["raw"]
checks.append("lexical_counts_and_all_retained_coordinates")

manifest = []
for path in sorted(root.rglob("*")):
    if path.is_file() and path.name not in {"manifest-sha256.json", "verification-results.json"} and "__pycache__" not in path.parts:
        data = path.read_bytes()
        manifest.append({"path": path.relative_to(root).as_posix(), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
(root / "evidence/manifest-sha256.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
result = {"result": "passed", "checks": checks, "runtime_original_executed": False, "VM_unpacked": False, "key_flow_invoked": False}
(root / "evidence/verification-results.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result))
