"""Python 3.6+: read Lua as inert text; never evaluate or execute the sample."""

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "evidence/lumin-loader-direct.body"
data = SOURCE.read_bytes()
source = data.decode("utf-8")
strings = []
comments = []
masked = list(source)
tokens = []


def location(offset: int) -> dict:
    return {
        "offset_zero_based": offset,
        "line_one_based": source.count("\n", 0, offset) + 1,
        "column_one_based": offset - source.rfind("\n", 0, offset),
    }


def mask(start: int, end: int) -> None:
    for pos in range(start, end):
        if masked[pos] != "\n":
            masked[pos] = " "


def long_bracket(start):
    opening = re.match(r"\[(=*)\[", source[start:])
    if not opening:
        return None
    closing = "]" + opening.group(1) + "]"
    content_start = start + len(opening.group(0))
    end = source.find(closing, content_start)
    if end < 0:
        return len(source), source[content_start:]
    return end + len(closing), source[content_start:end]


def decode_short(raw: str):
    content = raw[1:-1]
    out = []
    unknown = []
    i = 0
    escapes = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v", "\\": "\\", '"': '"', "'": "'"}
    while i < len(content):
        if content[i] != "\\":
            out.append(content[i]); i += 1; continue
        i += 1
        if i >= len(content):
            unknown.append("trailing_backslash"); break
        char = content[i]
        if char in escapes:
            out.append(escapes[char]); i += 1
        elif char == "z":
            i += 1
            while i < len(content) and content[i].isspace():
                i += 1
        elif char.isdigit():
            value = re.match(r"\d{1,3}", content[i:]).group(0)
            out.append(chr(int(value))); i += len(value)
        elif char == "x" and re.match(r"[0-9a-fA-F]{2}", content[i + 1:i + 3]):
            out.append(chr(int(content[i + 1:i + 3], 16))); i += 3
        elif char == "u" and re.match(r"u\{([0-9a-fA-F]+)\}", content[i:]):
            match = re.match(r"u\{([0-9a-fA-F]+)\}", content[i:])
            out.append(chr(int(match.group(1), 16))); i += len(match.group(0))
        elif char in "\r\n":
            out.append("\n"); i += 1
        else:
            unknown.append("\\" + char)
            out.append("\\" + char); i += 1
    return "".join(out), unknown


i = 0
while i < len(source):
    start = i
    bracket = long_bracket(i)
    if source.startswith("--", i):
        bracket = long_bracket(i + 2)
        if bracket:
            i, content = bracket
        else:
            end = source.find("\n", i)
            i = len(source) if end < 0 else end
            content = source[start + 2:i]
        comments.append({**location(start), "length": i - start, "content": content})
        mask(start, i)
    elif bracket:
        i, content = bracket
        strings.append({**location(start), "length": i - start, "kind": "long_bracket", "content_length": len(content)})
        mask(start, i)
    elif source[i] in "\"'":
        quote = source[i]
        i += 1
        while i < len(source):
            if source[i] == "\\":
                i += 2
            elif source[i] == quote:
                i += 1; break
            else:
                i += 1
        raw = source[start:i]
        decoded, unknown = decode_short(raw)
        entry = {**location(start), "length": len(raw), "kind": "quoted", "decoded_length": len(decoded)}
        if len(raw) <= 160:
            entry.update(raw=raw, decoded=decoded, unknown_escape_sequences=unknown)
        strings.append(entry)
        mask(start, i)
    elif source[i].isalpha() or source[i] == "_":
        i += 1
        while i < len(source) and (source[i].isalnum() or source[i] == "_"):
            i += 1
        tokens.append({"name": source[start:i], **location(start)})
    else:
        i += 1

code = "".join(masked)
interesting = {"HttpGet", "loadstring", "getfenv", "setfenv", "getgenv", "getrenv", "debug", "game", "Players", "LocalPlayer", "request", "http_request", "readfile", "writefile", "isfile", "setclipboard", "syn", "bit32", "string", "table", "buffer", "coroutine", "task", "math", "newproxy", "unpack", "select"}
token_summary = {name: [x for x in tokens if x["name"] == name] for name in sorted(interesting)}
aliases = []
for match in re.finditer(r"\b([A-Za-z_]\w*)\s*=\s*((?:bit32|string|table|buffer|coroutine|debug|task)\.[A-Za-z_]\w*|getfenv|setfenv|unpack|select)\b", code):
    aliases.append({"alias": match.group(1), "target": match.group(2), **location(match.start())})

report = {
    "method": "non_executing_Lua_lexical_scan_not_a_parser_or_VM_decoder",
    "source": SOURCE.name,
    "source_sha256": hashlib.sha256(data).hexdigest(),
    "source_bytes": len(data),
    "source_lines": len(source.splitlines()),
    "comments": comments,
    "string_count": len(strings),
    "strings": strings,
    "visible_token_occurrences": token_summary,
    "visible_aliases": aliases,
    "literal_url_candidates": [{"url": m.group(0), **location(m.start())} for m in re.finditer(r"https?://[^\s\]\"'<>]+", source)],
    "limitations": [
        "Lexical results do not prove call reachability, feature behavior or API validity.",
        "Unknown escapes are preserved and marked, not treated as recovered text.",
        "No payload transformation, bytecode unpacking, sample execution, key action or remote module retrieval.",
    ],
}
output = ROOT / "evidence/static-lexical-summary.json"
output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"output": str(output), "string_count": len(strings), "long_bracket_count": sum(x["kind"] == "long_bracket" for x in strings), "short_strings": [x for x in strings if "raw" in x][:25], "visible_token_counts": {name: len(items) for name, items in token_summary.items()}, "visible_aliases": aliases, "literal_url_candidates": report["literal_url_candidates"]}, ensure_ascii=False, indent=2))
