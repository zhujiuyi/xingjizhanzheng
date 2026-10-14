"""Check shipped font cmap against strict UTF-8 source and SQLite content, without OS fallback."""
from __future__ import annotations
import argparse
import bisect
import json
from pathlib import Path
import sqlite3
import struct
import unicodedata

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "code/assets/interface_v3/NotoSansCJKsc-Regular.otf"

def cmap_ranges(data: bytes) -> list[tuple[int, int, int]]:
    tables = {}
    for i in range(struct.unpack_from(">H", data, 4)[0]):
        tag, _, offset, length = struct.unpack_from(">4sIII", data, 12 + 16 * i)
        tables[tag] = data[offset:offset + length]
    cmap = tables[b"cmap"]
    candidates = []
    for i in range(struct.unpack_from(">H", cmap, 2)[0]):
        platform, encoding, offset = struct.unpack_from(">HHI", cmap, 4 + 8 * i)
        if struct.unpack_from(">H", cmap, offset)[0] == 12 and platform in (0, 3):
            candidates.append((platform == 3 and encoding == 10, offset))
    if not candidates:
        raise ValueError("Expected full Unicode cmap format 12 in upstream Noto CJK")
    _, offset = max(candidates)
    count = struct.unpack_from(">I", cmap, offset + 12)[0]
    return [struct.unpack_from(">III", cmap, offset + 16 + i * 12) for i in range(count)]

def required(codepoint: int) -> bool:
    return (0x3400 <= codepoint <= 0x9FFF or 0x20000 <= codepoint <= 0x323AF
            or 0x2000 <= codepoint <= 0x303F or 0xFF00 <= codepoint <= 0xFFEF
            or 0xA0 <= codepoint <= 0xFF or 0x370 <= codepoint <= 0x3FF
            or 0x20 <= codepoint <= 0x7E)

def run(report_path: Path | None) -> int:
    seen: dict[int, set[str]] = {}
    defects = []
    source_count = 0
    def collect(text: str, origin: str):
        if "\ufffd" in text:
            defects.append("replacement character in " + origin)
        for c in set(text):
            if required(ord(c)):
                seen.setdefault(ord(c), set()).add(origin)
    for source in (ROOT / "code").rglob("*"):
        if source.suffix not in (".gd", ".gdshader", ".sql", ".tscn") or any(part in (".godot", "dist") for part in source.parts):
            continue
        source_count += 1
        collect(source.read_text(encoding="utf-8", errors="strict"), str(source.relative_to(ROOT)))
    database = ROOT / "code/data/catalog.db"
    table_count = 0
    with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as db:
        for (name,) in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"):
            table_count += 1
            for row in db.execute('SELECT * FROM "' + name.replace('"', '""') + '"'):
                for value in row:
                    if isinstance(value, str): collect(value, "catalog:" + name)
    # UI frequently uses these to express distance, rates, selection and state.
    collect("星际战舰航行采矿护盾装甲结构保存读取任务取消远征 · × / → ← ↑ ↓ ± % Ⅰ Ⅱ Ⅲ", "required UI sample")
    # Every shipped weight is scanned: headings render in Medium, so a character
    # present only in Regular would show as tofu on a heading and nowhere else.
    fonts = sorted(FONT.parent.glob("NotoSansCJKsc-*.otf"))
    if not fonts:
        raise ValueError(f"No shipped weights found beside {FONT.relative_to(ROOT)}")
    missing = []
    scans = []
    for font_path in fonts:
        ranges = cmap_ranges(font_path.read_bytes())
        starts = [item[0] for item in ranges]
        font_missing = 0
        for value, origins in sorted(seen.items()):
            index = bisect.bisect_right(starts, value) - 1
            covered = index >= 0 and ranges[index][0] <= value <= ranges[index][1] and ranges[index][2] + value - ranges[index][0] != 0
            if not covered:
                font_missing += 1
                missing.append({"font": font_path.name, "codepoint": f"U+{value:04X}", "character": chr(value), "name": unicodedata.name(chr(value), "UNNAMED"), "origins": sorted(origins)})
        scans.append({"font": str(font_path.relative_to(ROOT)), "missing": font_missing, "required": len(seen)})
    report = {"fonts": scans, "source_files": source_count, "catalog_tables": table_count, "required_unique_codepoints": len(seen), "required_codepoints": sorted(seen), "missing": missing, "encoding_defects": defects}
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print(f"FONT_GLYPHS_RESULT {'PASS' if not missing and not defects else 'FAIL'} chars={len(seen)} missing={len(missing)} defects={len(defects)}")
    return 1 if missing or defects else 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    raise SystemExit(run(parser.parse_args().report))
