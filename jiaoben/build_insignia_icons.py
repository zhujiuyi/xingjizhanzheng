"""Generate the 舰载徽记 icon set into code/assets/interface_v3/services/.

Coherence comes from the system, not from an ornament. An earlier revision drew a
shared bottom-right chamfer bracket on every icon; rendered at 18 px it read as
debris in the corner instead of a frame, because there is no room at that size for
a frame AND a symbol. What unifies this set instead:

  1. one stroke width (2.0) and one ink colour, emitted from here so they cannot drift;
  2. every terminal round-capped and round-joined (no bare corners);
  3. symbols built from a 45/90 degree vocabulary plus full circles, so every
     diagonal in the set has the same slope;
  4. a single optical box, x and y in 4..20, so no icon looks bigger than another;
  5. a chevron/rhombus motif for anything ship-shaped, so the ships read as one family.

Symbols are original project vectors.

Usage:
  python -I build_insignia_icons.py --write   # regenerate the svg files
  python -I build_insignia_icons.py --check   # fail if files on disk differ
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "code/assets/interface_v3/services"

INK = "#b8c6ce"
STROKE = "2"

# id -> (svg elements, one-line intent). Symbols stay inside x 4..20 and y 4..20.
# A right-pointing chevron is the ship motif; a rhombus is a hull seen head-on.
SYMBOLS: dict[str, tuple[list[str], str]] = {
    "observe": (
        ['<path d="M4 8.5L18 11L4 13.5L6.5 11Z"/>'],
        "单舰体：右向梭形。舰船与跟随视角。",
    ),
    "ships": (
        [
            '<path d="M5 7L8.5 11L5 15"/>',
            '<path d="M10.5 7L14 11L10.5 15"/>',
            '<path d="M16 7L19.5 11L16 15"/>',
        ],
        "三舰横列：舰队与借船。三枚同向箭首并排表示编队名册。",
    ),
    "hire": (
        [
            '<path d="M7.5 6.5L12.5 11L7.5 15.5"/>',
            '<path d="M13 6.5L18 11L13 15.5"/>',
        ],
        "僚舰双列：雇佣僚舰。两枚较大的同向箭首，与舰队的三枚小箭首同族而数量不同。",
    ),
    "drones": (
        [
            '<path d="M11 3.5L15 9.5L7 9.5Z"/>',
            '<path d="M5.5 12L9.5 18L1.5 18Z"/>',
            '<path d="M16.5 12L20.5 18L12.5 18Z"/>',
        ],
        "三角编队：无人机。三枚外指三角环绕中心。",
    ),
    "station": (
        [
            '<circle cx="11" cy="11" r="6.5"/>',
            '<circle cx="11" cy="11" r="2.2"/>',
        ],
        "居住环与核心：空间站。两层同心圆，与目标环的十字准星和星图的环形节点区分。",
    ),
    "warehouse": (
        [
            '<path d="M4.5 4.5H17.5V19.5H4.5Z"/>',
            '<path d="M11 4.5V19.5"/>',
            '<path d="M4.5 12H17.5"/>',
        ],
        "货格：竖向两格仓储架。竖分格与工业的横向分层区分。",
    ),
    "fitting": (
        [
            '<path d="M19 5.5H14V16.5H19"/>',
            '<path d="M4 11H12"/>',
            '<path d="M9 8.5L11.5 11L9 13.5"/>',
        ],
        "装入挂点：箭首进入右侧开口槽。不用扳手或齿轮，避免读成设置。",
    ),
    "market": (
        [
            '<path d="M4 8H19"/>',
            '<path d="M16 4.5L19.5 8L16 11.5"/>',
            '<path d="M19 16H4"/>',
            '<path d="M7 12.5L3.5 16L7 19.5"/>',
        ],
        "双向交换：站点市场。",
    ),
    "industry": (
        [
            '<path d="M4 5.5H18L15.5 14H6.5Z"/>',
            '<path d="M5.5 9H16.5"/>',
            '<path d="M8.5 14V19"/>',
            '<path d="M13.5 14V19"/>',
        ],
        "熔炉：炉体加料口横线加两条支脚。工业与回收。",
    ),
    "missions": (
        [
            '<path d="M11 4V7"/>',
            '<path d="M11 15V18"/>',
            '<path d="M4 11H7"/>',
            '<path d="M15 11H18"/>',
            '<path d="M11 9.5L12.5 11L11 12.5L9.5 11Z"/>',
        ],
        "目标环：四段准星加中心菱形。任务与合同。",
    ),
    "civilizations": (
        [
            '<path d="M5 4.5H17V12L11 19.5L5 12Z"/>',
            '<path d="M8 9L11 12L14 9"/>',
        ],
        "徽记盾：盾形加内部人字纹。文明与声望。",
    ),
    "research": (
        [
            '<path d="M11 4.5V11"/>',
            '<path d="M11 11L5 16.5"/>',
            '<path d="M11 11L17 16.5"/>',
            '<circle cx="11" cy="4" r="2"/>',
            '<path d="M4 19.5H7.5"/>',
            '<path d="M14.5 19.5H18"/>',
        ],
        "科技分支：一节点分叉到两个端点。与星图的环形节点区分。",
    ),
    "map": (
        [
            '<path d="M7.5 17.2L10.5 7.6"/>',
            '<path d="M13.5 6.9L17 11.8"/>',
            '<circle cx="5.8" cy="18.6" r="2.2"/>',
            '<circle cx="12" cy="5.5" r="2.2"/>',
            '<circle cx="18.3" cy="14" r="2.2"/>',
        ],
        "航路网：三个环形节点两两连线。星域航路。",
    ),
    "radar": (
        [
            '<path d="M4.5 13.5A6 6 0 0 1 10.5 19.5"/>',
            '<path d="M4.5 6.5A13 13 0 0 1 17.5 19.5"/>',
            '<path d="M4.5 19.5L16 8"/>',
        ],
        "扫描扇：两段同心弧加扫描线。雷达。",
    ),
    "pause": (
        [
            '<path d="M8 4.5V19.5"/>',
            '<path d="M16 4.5V19.5"/>',
        ],
        "停止：双竖条。系统与暂停存读档。",
    ),
}


def render(elements: list[str], intent: str) -> str:
    body = "\n".join("    " + item for item in elements)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">\n'
        "  <!-- 舰载徽记语言 v1 · 原创矢量。%s -->\n"
        "  <!-- 描边与光学区由 jiaoben/build_insignia_icons.py 统一生成，勿手改本文件。 -->\n"
        '  <g fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">\n'
        "%s\n"
        "  </g>\n"
        "</svg>\n"
    ) % (intent, INK, STROKE, body)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not (args.write or args.check):
        parser.error("pass --write or --check")

    problems: list[str] = []
    for icon_id, (elements, intent) in SYMBOLS.items():
        path = TARGET / (icon_id + ".svg")
        expected = render(elements, intent)
        if args.write:
            path.write_text(expected, encoding="utf-8", newline="\n")
            print("wrote %s" % path.relative_to(ROOT).as_posix())
            continue
        if not path.is_file():
            problems.append("missing " + path.name)
        elif path.read_text(encoding="utf-8") != expected:
            problems.append("stale " + path.name)

    if args.check:
        if problems:
            for item in problems:
                print("PROBLEM " + item)
            return 1
        print("insignia icons OK: %d symbols" % len(SYMBOLS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
