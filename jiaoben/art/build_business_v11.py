#!/usr/bin/env python3
"""Original industrial SVG artwork and an asset-only mapping of catalog IDs.

Run normally before the native GLB capture; run --finalize after the capture.
The read-only catalog selects visual families, never copies balance values.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "code/assets/business_v11"
CATALOG = ROOT / "code/data/catalog.db"
PREFIX = "res://assets/business_v11/"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def shell(content: str, accent: str = "#8aaeba", tier: int = 0, seed: str = "") -> str:
    """Metal foreground, restrained color, clipped corners and legible bevels."""
    marks = "".join(
        f'<path d="M{195 + n * 13} 203v20" stroke="{accent}" stroke-width="7"/>'
        for n in range(tier)
    )
    index = int(hashlib.sha256(seed.encode()).hexdigest()[:4], 16) if seed else 0
    code = "".join(
        f'<path d="M{32 + n * 5} 222v{4 + ((index >> n) & 1) * 5}"/>'
        for n in range(9)
    )
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<defs>
  <linearGradient id="metal" x1="0" y1="0" x2=".6" y2="1">
    <stop stop-color="#c4d0d2"/><stop offset=".25" stop-color="#778a93"/>
    <stop offset=".6" stop-color="#4c626c"/><stop offset="1" stop-color="#243843"/>
  </linearGradient>
  <linearGradient id="dark" x1="0" y1="0" x2="1" y2="1">
    <stop stop-color="#354954"/><stop offset="1" stop-color="#102029"/>
  </linearGradient>
  <linearGradient id="accent" x1="0" y1="0" x2=".5" y2="1">
    <stop stop-color="{accent}"/><stop offset="1" stop-color="#344a55"/>
  </linearGradient>
</defs>
<path d="M21 8h220l7 7v226l-7 7H15l-7-7V21Z" fill="#08151d" stroke="#29424d" stroke-width="2"/>
<path d="M20 20h216v216H20Z" fill="none" stroke="#142b35"/>
<path d="M24 56h208M24 128h208M24 200h208M56 24v208M128 24v208M200 24v208" stroke="#152831" stroke-width="1"/>
<path d="M21 39V21h18M217 21h18v18M21 217v18h18M217 235h18v-18" fill="none" stroke="#54727f" stroke-width="3"/>
<ellipse cx="128" cy="196" rx="78" ry="12" fill="#020a10" opacity=".65"/>
<g stroke="#152934" stroke-width="2.3" stroke-linejoin="round">{content}</g>
<g stroke="#69838d" stroke-width="2">{code}</g>{marks}
</svg>'''


def bolts(points: list[tuple[int, int]]) -> str:
    return "".join(f'<circle cx="{x}" cy="{y}" r="2.7" fill="#b0bec3"/>' for x, y in points)


def module_art(item_id: str, tier: int, family: str = "", size: int = 0) -> tuple[str, str]:
    colors = {1: "#8da9b2", 2: "#709bad", 3: "#b5a479"}
    accent = colors[tier]
    if family == "drone" or "drone" in item_id:
        art = '''<path d="M45 146l42-74 95 7 33 79-49 40-90-9Z" fill="url(#metal)"/>
<path d="M66 139l30-48 66 7 28 53-32 24-74-8Z" fill="url(#dark)"/>
<path d="M88 105l25 3-13 41-29-6Z M119 109l24 3-7 42-29-4Z M150 114l22 3 9 39-38-2Z" fill="#08141e"/>
<path d="M89 139l11-35 12 13 3 19-12 8Z M125 146l8-32 12 11 6 24-15 4Z M160 150l-1-27 12 8 12 23-15 4Z" fill="url(#accent)"/>
<path d="M56 147l23 6-2 19-14-2Z M180 167l17-12 6 11-19 16Z" fill="url(#accent)"/>
<path d="M93 67l14-25 15 21-10 14Z M146 60l13-24 19 25-14 13Z" fill="url(#metal)"/>
<path d="M99 57l9-9 7 13 M152 51l8-9 10 16" stroke="#bed6df" stroke-width="3" fill="none"/>
<path d="M95 164h42M103 175h32" stroke="#7796a0" stroke-width="4"/>'''
    elif (family == "kinetic" and size == 3) or "kinetic_siege" in item_id:
        art = '''<path d="M35 150l45-49 70 18 37 53-50 33-81-16Z" fill="url(#dark)"/>
<path d="M58 125l48-24 54 26-20 52-58-9Z" fill="url(#metal)"/>
<path d="M88 82l24-21 113 44-17 27-116-38Z M74 109l24-21 112 42-21 30-110-39Z" fill="url(#metal)"/>
<path d="M203 96l22 9-17 27-21-9Z M191 122l20 8-22 30-23-11Z" fill="#08141e"/>
<path d="M121 69l7 30 M143 78l7 29 M165 87l6 30 M107 101l6 29 M132 109l6 30 M155 118l6 30" stroke="#607f89" stroke-width="8"/>
<path d="M69 143l21 9-8 28-20-8Z M104 152l31 8-7 18-30-9Z" fill="url(#accent)"/>
<path d="M48 145l-8 19 22 8M131 190l23-13" stroke="#bbc8c9" stroke-width="6"/>'''
    elif (family == "kinetic" and size == 2) or "kinetic_lance" in item_id:
        art = '''<path d="M46 147l37-43 53 17 26 47-39 31-62-22Z" fill="url(#dark)"/>
<path d="M66 111l38-27 42 22 9 48-41 27-37-15Z" fill="url(#metal)"/>
<path d="M102 73l24-13 102 54-17 25-109-43Z" fill="url(#metal)"/>
<path d="M210 104l18 10-17 25-23-9Z" fill="#08141e"/>
<path d="M127 69l-7 31 M148 80l-7 28 M169 91l-7 26 M190 102l-8 26" stroke="#7896a0" stroke-width="9"/>
<path d="M79 121l32 11-10 36-28-10Z" fill="url(#accent)"/>
<path d="M64 164l19 6M89 178l20 7" stroke="#c6d4d7" stroke-width="4"/>
<path d="M151 127l33 12" stroke="#b9cecf" stroke-width="4"/>'''
    elif "kinetic" in item_id:
        art = '''<path d="M51 145l34-37 49 11 14 23-38 49-53-15Z" fill="url(#dark)"/>
<path d="M86 89l39-14 63 39-13 21-60-26-28 7Z" fill="url(#metal)"/>
<path d="M148 80l23-8 45 27-8 19-55-26Z" fill="url(#metal)"/>
<path d="M199 94l17 5-8 19-16-8Z" fill="#10222b"/>
<path d="M91 131l30-13 37 22-28 35-38-10Z" fill="url(#metal)"/>
<path d="M57 145l27 9-10 24-17-6Z" fill="url(#accent)"/>
<path d="M92 142l30 7M99 153l26 7M108 166l15-4" stroke="#172b35" stroke-width="4"/>
<path d="M179 91l8-12M167 84l7-11" stroke="#d1d9d8" stroke-width="3"/>'''
    elif "thermal" in item_id:
        art = '''<path d="M61 155l20-36 63 3 26 41-17 27-65-7Z" fill="url(#metal)"/>
<path d="M79 98l36-27 42 16 26 34-36 21-48-8Z" fill="url(#dark)"/>
<path d="M118 64l45 13 32 35-28 32-46-14-27-35Z" fill="url(#metal)"/>
<path d="M153 82l24 6 14 20-20 23-25-6-13-21Z" fill="#24353b"/>
<path d="M156 92l17 3 8 13-14 12-13-4-8-11Z" fill="#d6aa66"/>
<path d="M74 133l62 12M68 145l75 11M76 161l77 11" stroke="#213642" stroke-width="5"/>
<path d="M101 77l13 53M111 71l15 60" stroke="#8a9699" stroke-width="3"/>'''
    elif "pulse" in item_id:
        art = '''<path d="M58 147l41-21 61 3 35 29-32 28-76-5Z" fill="url(#metal)"/>
<ellipse cx="130" cy="109" rx="60" ry="39" fill="url(#dark)" transform="rotate(-20 130 109)"/>
<ellipse cx="130" cy="109" rx="46" ry="29" fill="#081a24" stroke="#8c9ca2" stroke-width="10" transform="rotate(-20 130 109)"/>
<ellipse cx="130" cy="109" rx="28" ry="17" fill="url(#accent)" transform="rotate(-20 130 109)"/>
<path d="M67 123l21-5M178 82l20-4M108 70l7 20M149 131l5 17" stroke="#c6c6b3" stroke-width="8"/>
<path d="M102 150l15 24M136 146l15 25" stroke="#223941" stroke-width="8"/>'''
    elif "shield" in item_id:
        art = '''<path d="M52 136l19-56 69-23 60 42-20 73-64 33Z" fill="url(#metal)"/>
<path d="M69 134l15-45 54-16 44 30-16 56-49 27Z" fill="url(#dark)"/>
<path d="M89 109l49-23 30 19-3 38-37 26-35-14Z" fill="url(#accent)"/>
<path d="M89 110l36 21 42-25M124 130l4 39M101 85l12 33M149 88l-9 31M152 153l24 7M92 145l-16 14" fill="none" stroke="#b1c8cd" stroke-width="3"/>
<path d="M64 125l17 9M112 184l5-18M177 110l17-4" stroke="#d5dbd8" stroke-width="5"/>'''
    elif "armor_pressure" in item_id:
        art = '''<path d="M48 137l32-61 94 3 33 71-39 44-91-6Z" fill="url(#dark)"/>
<path d="M55 127l26-58 91 1 31 58-42 52-74-5Z" fill="url(#metal)"/>
<path d="M69 130l27-47 58 1 34 46-34 35-63-2Z" fill="url(#dark)"/>
<path d="M86 115l20-22 43 1 21 24-23 36-44-3Z" fill="url(#metal)"/>
<path d="M100 111h42l11 15-13 15h-33l-13-17Z" fill="url(#accent)"/>
<path d="M80 79l16 8M178 85l-14 6M71 149l21-3M174 156l-21-8" stroke="#c2c8c9" stroke-width="4"/>'''
    elif "armor_feather" in item_id:
        art = '''<path d="M42 134l40-49 125 20-56 88-81-14Z" fill="url(#dark)"/>
<path d="M54 109l47-55 113 42-54 64-78-10Z" fill="url(#metal)"/>
<path d="M67 113l16-17 100 30-14 15Z" fill="url(#accent)"/>
<path d="M86 90l16-18 98 35-12 13Z" fill="url(#dark)"/>
<path d="M81 155l90 8-16 15-72-8Z" fill="url(#metal)"/>
<path d="M102 57l13 7-51 55M152 77l12 5-51 64M200 96l10 6-45 49" stroke="#c4cccc" stroke-width="3"/>'''
    elif "engine" in item_id:
        art = '''<path d="M55 133l20-61 51-15 63 42-10 75-71 22Z" fill="url(#metal)"/>
<path d="M62 117l33-12 44 33-13 52-38-12Z" fill="url(#dark)"/>
<ellipse cx="160" cy="145" rx="31" ry="43" fill="url(#dark)" transform="rotate(20 160 145)"/>
<ellipse cx="160" cy="145" rx="23" ry="31" fill="#091b25" transform="rotate(20 160 145)"/>
<ellipse cx="160" cy="145" rx="13" ry="19" fill="url(#accent)" transform="rotate(20 160 145)"/>
<path d="M86 75l42 32M79 88l42 31M72 101l42 31" stroke="#bec9cc" stroke-width="4"/>
<path d="M172 95l19 8-8 35-18-6Z" fill="url(#accent)"/>
<path d="M95 161l24 5M99 174l19 4" stroke="#627d88" stroke-width="3"/>'''
    elif "scanner" in item_id:
        art = '''<path d="M70 158l53-23 66 29-43 33-57-7Z" fill="url(#metal)"/>
<path d="M121 108h20v53h-20Z" fill="url(#dark)"/>
<path d="M61 99q51-62 125-10l-51 45Z" fill="url(#metal)"/>
<path d="M65 98q57-38 116-10l-46 31Z" fill="url(#dark)"/>
<path d="M94 96l42 18M136 114l12-38M137 113l34-17" fill="none" stroke="#c1c9c9" stroke-width="3"/>
<path d="M130 106l24-56" stroke="#b8c6c9" stroke-width="6"/>
<circle cx="157" cy="45" r="8" fill="url(#accent)"/>
<path d="M99 167h37v14H99Z" fill="url(#accent)"/>'''
    elif "industry" in item_id:
        art = '''<path d="M58 89l45-26 66 23 24 60-55 42-68-25Z" fill="url(#metal)"/>
<path d="M72 119l43-21 44 19-18 57-43-12Z" fill="url(#dark)"/>
<path d="M109 105l33 13-16 69-29-9Z" fill="url(#accent)"/>
<path d="M57 121l24 9-6 49-17 6-10-13Z" fill="url(#metal)"/>
<path d="M145 130l30-13 23 48-16 22-15-7Z" fill="url(#metal)"/>
<path d="M50 170l14 27 21-12M176 166l-6 28 24 5" fill="none" stroke="#adbec4" stroke-width="10"/>
<path d="M90 78l17 6M83 90l18 6M160 104l18-6" stroke="#bfc9c9" stroke-width="4"/>'''
    else:  # Repair projector: bridge arms and an actual service emitter.
        art = '''<path d="M50 133l40-54 73 4 44 57-46 53-79-11Z" fill="url(#metal)"/>
<path d="M90 115l26-14 39 19-15 44-34-7Z" fill="url(#dark)"/>
<path d="M62 119l29-18 18 11-15 24-33 15Z" fill="url(#dark)"/>
<path d="M153 103l25 10 13 34-20 13-21-34Z" fill="url(#dark)"/>
<path d="M95 140l32-7 22 13-14 24-31-3Z" fill="url(#accent)"/>
<path d="M118 141h10v8h8v10h-8v8h-10v-8h-8v-10h8Z" fill="#c1dbd7" stroke="none"/>
<path d="M76 160l17 5M150 172l18-11M95 92l57 5" stroke="#bbc8ca" stroke-width="4"/>'''
    return art + bolts([(83, 83), (177, 151)]), accent


def ore_art(item_id: str) -> tuple[str, str]:
    color = {
        "ore_ferrosilicate": "#9c9690", "ore_conductive_crystal": "#77a9be",
        "ore_echo_silica": "#8b9ab6", "ore_mirror_crystal": "#92b1b7",
        "ore_corrosion_titanium": "#98a48c", "ore_pressure_steel": "#919da8",
        "ore_solar_core": "#b9a06c", "ore_phase_stone": "#a18aa7",
    }[item_id]
    n = int(sha_bytes(item_id)[:2], 16) % 16
    art = f'''<path d="M48 145l16-{43+n} 48-29 53 16 39 49-17 41-61 18-52-21Z" fill="url(#dark)"/>
<path d="M64 {102-n}l48-29 19 57-58 30Z" fill="url(#metal)"/>
<path d="M112 73l53 16 39 49-73-8Z" fill="url(#accent)"/>
<path d="M73 160l58-30 73 8-17 41-61 18Z" fill="url(#dark)"/>
<path d="M101 112l10-23 18 13-4 28-16 10Z" fill="{color}"/>
<path d="M138 146l17-19 23 9-12 35-18 2Z" fill="{color}"/>
<path d="M85 163l12-15 15 8-3 14-13 8Z" fill="url(#accent)"/>
<path d="M75 112l20-16M150 105l28 19M114 183l17-20" stroke="#b4c0c1" opacity=".6" stroke-width="3"/>'''
    if "crystal" in item_id or "solar" in item_id:
        art += f'<path d="M139 86l12-36 20 26-6 36-21 9Z" fill="{color}"/><path d="M151 50l2 45 12 17" fill="none" stroke="#d9e0da" stroke-width="2"/>'
    elif "echo" in item_id:
        art += '<path d="M78 113l22 49M91 101l24 42M105 87l17 40" stroke="#a9bac3" stroke-width="5"/>'
    elif "phase" in item_id:
        art += '<path d="M128 83l-18 34 28 19-11 33" fill="none" stroke="#c3a0c4" stroke-width="5"/>'
    return art, color


def sha_bytes(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def other_item_art(item_id: str, item_type: str) -> tuple[str, str]:
    accent = "#8aa8ae"
    if item_type == "ammo":
        art = '<path d="M58 160l23-69 19-23 17 25-22 80Z" fill="url(#metal)"/><path d="M95 178l23-75 21-27 20 25-26 87Z" fill="url(#metal)"/><path d="M137 182l28-75 22-20 13 24-24 82Z" fill="url(#dark)"/><path d="M71 120l32 9M109 131l36 10M152 146l32 11" stroke="#b5a77f" stroke-width="8"/>'
    elif item_type == "consumable":
        art = '<path d="M49 104l41-31 99 29 10 72-50 25-90-30Z" fill="url(#metal)"/><path d="M89 74l99 28-43 29-96-28Z" fill="url(#dark)"/><path d="M71 70l21-20 40 12 7 22-15 9-8-18-22-5-13 13Z" fill="url(#metal)"/><path d="M130 139h18v15h15v18h-15v15h-18v-15h-15v-18h15Z" fill="#a0b6ae"/><path d="M71 125l5 31M179 123l5 40" stroke="#132833" stroke-width="8"/>'
    elif "structural_stock" in item_id:
        art = '<path d="M43 148l54-73 101 26-55 75Z" fill="url(#metal)"/><path d="M43 148v23l100 29 55-75v-24l-55 75Z" fill="url(#dark)"/><path d="M82 125l37-45M107 135l37-46M132 145l37-46" stroke="#253d47" stroke-width="11"/><path d="M48 148l95 28 49-64" fill="none" stroke="#becbd0" stroke-width="4"/>'
    elif "conductive_medium" in item_id:
        art = '<path d="M76 75l54-15 51 31v88l-48 20-55-24Z" fill="url(#metal)"/><path d="M87 100l43-13 38 17v61l-38 17-41-20Z" fill="url(#dark)"/><path d="M96 120l33-10 28 11v40l-27 11-33-14Z" fill="url(#accent)"/><path d="M98 79V54l26-8 21 12v24M90 144l36 14 32-11" fill="none" stroke="#b0c3c8" stroke-width="4"/>'
    elif item_type == "material":
        accent = "#a5a195" if "dense" in item_id else "#7f9a9e"
        art = '<path d="M51 157l39-40 92 20 22 40-39 21-90-17Z" fill="url(#dark)"/><path d="M52 125l39-43 87 20 25 39-42 25-87-21Z" fill="url(#metal)"/><path d="M76 106l31-37 59 13 25 35-37 23-59-17Z" fill="url(#accent)"/><path d="M97 81l10-12 58 14 11 16-33 13Z" fill="#bfcbcc"/><path d="M74 145l87 21M75 179l90 18" stroke="#7c939d" stroke-width="3"/>'
        if "pressure" in item_id:
            art += '<path d="M97 90l39 51M115 83l39 50M133 81l39 41" stroke="#344b57" stroke-width="8"/>'
        elif "feather" in item_id:
            art += '<path d="M78 137l96-27M81 149l96-27" stroke="#c8d4d3" stroke-width="5"/>'
    elif "relic" in item_id:
        accent = "#a49aaf"
        art = '<path d="M72 75l55-23 56 32-8 65-41 44-62-21-16-47Z" fill="url(#dark)"/><path d="M98 73l49 18-8 36 34 29-39 37-45-21 17-40-20-28Z" fill="url(#metal)"/><path d="M118 90l-10 19 23 16-13 30 19 20" fill="none" stroke="#b6a7bf" stroke-width="5"/><path d="M72 92l23 8M144 67l-4 17M164 128l16 11" stroke="#a89fae" stroke-width="4"/>'
        if "logic" in item_id:
            art += '<path d="M93 101h55v47H93Z" fill="#15282f"/><path d="M98 108h42v32H98Z" fill="url(#accent)"/><path d="M87 112h10M87 126h10M143 112h10M143 126h10" stroke="#c5bacb" stroke-width="4"/>'
    elif "weapon_frame" in item_id or "scan_frame" in item_id:
        art = '<path d="M52 117l52-47 85 27 16 55-59 49-79-22Z" fill="url(#metal)"/><path d="M76 123l31-28 58 19 10 33-35 28-48-13Z" fill="#07151d"/><path d="M71 104l27 16M160 108l15-22M151 170l12 17M66 151l23-1" stroke="#9aabb1" stroke-width="7"/>'
        if "scan" in item_id:
            art += '<path d="M98 126q25-34 61-3l-32 28Z" fill="url(#accent)"/><path d="M127 145l8-45" stroke="#c3cdd0" stroke-width="4"/>'
        else:
            art += '<path d="M105 145l53-52 16 15-54 51Z" fill="url(#dark)"/><path d="M157 93l17 15-8 10-16-14Z" fill="url(#accent)"/>'
    elif "power_cell" in item_id or "sensor_core" in item_id:
        art = '<path d="M62 90l61-28 58 30v78l-54 29-62-25Z" fill="url(#metal)"/><path d="M81 111l44-18 35 16v51l-36 20-42-17Z" fill="url(#dark)"/><path d="M126 65v24M64 92l18 19M181 92l-21 17" stroke="#c6d0ce" stroke-width="4"/>'
        if "power" in item_id:
            art += '<path d="M90 121l19-6v40l-18-3ZM119 110l20 5v49l-20-4ZM148 120l10 6v30l-10 7Z" fill="url(#accent)"/>'
        else:
            art += '<circle cx="124" cy="139" r="26" fill="#0c1b24" stroke="#9eafb7" stroke-width="7"/><circle cx="124" cy="139" r="16" fill="url(#accent)"/><circle cx="120" cy="135" r="6" fill="#c6d7d8"/>'
    elif "pulse_ring" in item_id or "thermal_focus" in item_id:
        accent = "#b39c7e" if "thermal" in item_id else "#819eaa"
        art = '<ellipse cx="126" cy="127" rx="69" ry="51" fill="url(#metal)" transform="rotate(-25 126 127)"/><ellipse cx="126" cy="127" rx="45" ry="30" fill="#08161e" stroke="#435b68" stroke-width="11" transform="rotate(-25 126 127)"/><path d="M65 116l26 2M166 90l18-14M158 155l10 19M93 170l11-25" stroke="#c4ced0" stroke-width="8"/>'
        if "thermal" in item_id:
            art += '<ellipse cx="126" cy="127" rx="32" ry="20" fill="url(#accent)" transform="rotate(-25 126 127)"/><path d="M94 120l64 7M105 102l30 51" stroke="#d3c3a7" stroke-width="3"/>'
        else:
            art += '<path d="M91 106q39-35 77-2M82 144q43 37 82-4" fill="none" stroke="#9eacb7" stroke-width="6"/>'
    elif "thruster_cluster" in item_id:
        art = '<path d="M65 78l49-14 66 42-8 63-58 24-51-40Z" fill="url(#metal)"/><ellipse cx="145" cy="142" rx="30" ry="40" fill="url(#dark)" transform="rotate(20 145 142)"/><ellipse cx="145" cy="142" rx="18" ry="27" fill="url(#accent)" transform="rotate(20 145 142)"/><ellipse cx="92" cy="147" rx="19" ry="26" fill="url(#dark)"/><ellipse cx="92" cy="147" rx="11" ry="17" fill="url(#accent)"/><path d="M80 84l45 27M75 96l44 27" stroke="#b1c1c6" stroke-width="5"/>'
    elif "repair_mesh" in item_id or "mist_fiber" in item_id:
        accent = "#92a6a2" if "repair" in item_id else "#9d9bb0"
        art = '<path d="M54 100l58-30 88 53-51 73-78-25Z" fill="url(#dark)"/><path d="M56 105l87 68M70 96l87 62M86 85l83 61M105 78l78 57M188 116l-90 61M173 105l-86 56M158 95l-85 52M143 86l-82 49" stroke="#acbcbf" stroke-width="5"/><path d="M58 102l10 51 80 28 47-57-83-44Z" fill="none" stroke="#526b78" stroke-width="8"/>'
        if "mist" in item_id:
            art += '<path d="M75 121q18-69 46-34t31 69 20-42" fill="none" stroke="#b2a4c5" stroke-width="4"/>'
    elif "anchor_ceramic" in item_id:
        accent = "#b7b2a2"
        art = '<path d="M79 82l44-25 48 26 28 54-34 52-63-6-36-46Z" fill="url(#metal)"/><path d="M112 82l25-5 22 31-13 51-34 1-17-43Z" fill="url(#accent)"/><path d="M89 109l65 12M99 154l43 8M112 84l13 78" stroke="#263c45" stroke-width="5"/><path d="M83 148l13 35M165 114l16 14" stroke="#c1c8c5" stroke-width="5"/>'
    else:  # Fire/industry/projection electronics use different actual control symbols.
        art = '<path d="M49 111l43-40 92 27 19 67-52 32-89-31Z" fill="url(#metal)"/><path d="M72 115l30-27 60 20 13 42-34 22-58-20Z" fill="url(#dark)"/><path d="M78 106l21 6M73 117l21 6M166 129l17-5M168 142l17-5M97 157l-3 16M112 162l-3 16" stroke="#b8b6a0" stroke-width="5"/>'
        if "fire_control" in item_id:
            art += '<circle cx="123" cy="133" r="24" fill="none" stroke="#aabdc5" stroke-width="4"/><path d="M123 104v58M94 133h58" stroke="#a8bac3" stroke-width="3"/><circle cx="123" cy="133" r="7" fill="url(#accent)"/>'
        elif "industry_control" in item_id:
            art += '<path d="M97 145v-21l14 8v-17l15 9v-24l23 17v36Z" fill="url(#accent)"/><path d="M104 147h38M130 111v15" stroke="#d5d9d4" stroke-width="3"/>'
        else:
            art += '<path d="M98 130l23-16 25 19-25 15Z" fill="url(#accent)"/><path d="M92 141l29 18 31-21M121 110V97M94 125l-10-8M149 127l12-9" fill="none" stroke="#b5c4c8" stroke-width="4"/>'
    return art + bolts([(76, 104), (171, 165)]), accent


def category_art(kind: str, variant: str = "") -> str:
    if kind == "research":
        art = '<path d="M75 156l49-27 64 29-49 37-64-22Z" fill="url(#metal)"/><path d="M108 128V76l31-13 22 16v65" fill="url(#dark)"/><path d="M139 69l36 15-6 26-25-9Z" fill="url(#metal)"/><path d="M79 96l12-20 22 12-10 33Z" fill="url(#accent)"/><path d="M112 118l-15 22 30 14 16-24" fill="none" stroke="#b4c9cd" stroke-width="7"/><path d="M82 170l57 14 39-24" fill="none" stroke="#4f6b78" stroke-width="4"/>'
        if "hulls" in variant: art += '<path d="M52 73l22-23 20 10-10 19Z" fill="#b2bdbd"/>'
        if "tech_iii" in variant: art += '<path d="M66 51l22 11-8 20-26-7Z" fill="#aa94b7"/>'
        if "base" in variant: art += '<path d="M54 59h34v27H54Z" fill="#83a4a8"/>'
    elif kind == "facility":
        art = '<path d="M42 139l44-28 45 14v53l-44 26-45-24Z" fill="url(#dark)"/><path d="M129 100l40-22 46 24v53l-39 25-47-26Z" fill="url(#metal)"/><path d="M85 54l48-18 25 47-32 30-41-18Z" fill="url(#dark)"/><path d="M87 153l45-28 45 29-44 27Z" fill="url(#metal)"/><path d="M95 88l42 52M62 133l81-46M115 172l50-37" stroke="#a2b8bf" stroke-width="7"/><path d="M58 148h22v25H58Z" fill="url(#accent)"/>'
        if "repair" in variant: art += '<path d="M174 113h11v9h9v11h-9v9h-11v-9h-9v-11h9Z" fill="#aec6c0"/>'
        elif "industry" in variant: art += '<path d="M166 125l12-10 19 11-4 20-19 3Z" fill="#b1a47e"/>'
        elif "navigation" in variant: art += '<circle cx="181" cy="125" r="15" fill="none" stroke="#b1c8d0" stroke-width="4"/><path d="M181 105v40M161 125h40" stroke="#b1c8d0" stroke-width="2"/>'
        elif "warehouse" in variant: art += '<path d="M163 115h31v26h-31ZM168 112v34M180 112v34M192 112v34" fill="#86999a" stroke="#243a45" stroke-width="3"/>'
    elif kind == "mission":
        art = '<path d="M67 60l84-9 40 26-11 113-85 15-38-32Z" fill="url(#metal)"/><path d="M84 73l67-7 22 15-9 95-66 12-26-24Z" fill="url(#dark)"/><path d="M103 49l42-4 14 12-4 17-43 5-13-12Z" fill="url(#accent)"/><path d="M94 148l55-6M92 161l50-6M90 174l36-4" stroke="#acbec3" stroke-width="4"/>'
        if "combat" in variant or "patrol" in variant:
            art += '<path d="M107 91l42 37M147 88l-40 43M101 123l10 11M143 123l11-10" stroke="#b9a88a" stroke-width="6"/>'
        elif "mining" in variant or "delivery" in variant:
            art += '<path d="M100 105l24-14 27 13-6 27-25 7-22-14Z" fill="url(#accent)"/>'
        elif "story" in variant:
            art += '<path d="M125 90l8 13 15 4-10 11 1 16-16-6-13 9-2-16-11-9 15-6Z" fill="#b6a57e"/>'
        else:
            art += '<circle cx="123" cy="111" r="20" fill="none" stroke="#a4bbc7" stroke-width="4"/><path d="M110 122l26-27-8 28Z" fill="url(#accent)"/>'
    elif kind == "blueprint":
        art = '<path d="M59 73l93-18 40 35-6 94-104 20-35-34Z" fill="url(#dark)"/><path d="M74 87l71-14 26 23-8 70-69 15-22-24Z" fill="#15313e"/><path d="M91 107l37-9 21 17-4 28-35 10-21-17Z" fill="none" stroke="#9bbbc8" stroke-width="4"/><path d="M128 98l-2 34-37 4M126 132l18 11M82 165l42-8M161 86l-6 50" stroke="#668a9e" stroke-width="3"/>'
    else:
        art = '<path d="M62 91l63-27 67 31v78l-68 28-62-30Z" fill="url(#metal)"/><path d="M63 91l61 30 68-26M124 121v79" fill="none" stroke="#1c333d" stroke-width="5"/><path d="M88 80l64 31 1 28-17 7-1-27-61-29Z" fill="url(#accent)"/>'
    if kind in {"item", "ship"}:
        art += '<circle cx="180" cy="182" r="33" fill="#0b1a23" stroke="#89a6b2" stroke-width="3"/><path d="M167 171q0-13 12-13t12 12q0 8-12 12v7M179 198v4" fill="none" stroke="#c8d8df" stroke-width="6" stroke-linecap="round"/>'
    return art


def write_svg(relative: str, text: str) -> None:
    path = ASSETS / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    ET.fromstring(text)
    path.write_text(text + "\n", encoding="utf-8", newline="\n")


def build(finalize: bool) -> dict:
    entries: list[dict[str, str]] = []
    models: list[dict[str, str]] = []
    connection = sqlite3.connect(f"file:{CATALOG}?mode=ro", uri=True)
    module_tiers = dict(connection.execute("SELECT module_id,tech_level FROM module_tech_defs"))
    has_profiles = connection.execute("SELECT 1 FROM sqlite_schema WHERE type='table' AND name='weapon_behavior_defs'").fetchone() is not None
    module_profiles = {mid: (family, size) for mid, family, size in connection.execute("SELECT module_id,family_id,size_class FROM weapon_behavior_defs")} if has_profiles else {}
    for item_id, item_type in connection.execute("SELECT item_id,item_type FROM item_defs ORDER BY item_id"):
        tier = module_tiers.get(item_id, 0)
        if item_type == "module":
            family, size = module_profiles.get(item_id, ("", 0))
            content, accent = module_art(item_id, tier, family, size)
        elif item_type == "ore":
            content, accent = ore_art(item_id)
        else:
            content, accent = other_item_art(item_id, item_type)
        relative = f"items/{item_id}.svg"
        write_svg(relative, shell(content, accent, tier, item_id))
        entries.append({"kind": "item", "id": item_id, "resource_path": PREFIX + relative})
    for (ship_id,) in connection.execute("SELECT ship_id FROM ship_defs ORDER BY ship_id"):
        entries.append({"kind": "ship", "id": ship_id, "resource_path": PREFIX + f"ships/{ship_id}.png"})
        source = ROOT / f"code/assets/ship_v3/{ship_id}.glb"
        models.append({"resource_path": f"res://assets/ship_v3/{ship_id}.glb", "sha256": sha(source)})
    for kind, table, column in [("research", "research_defs", "research_id"), ("facility", "base_module_defs", "base_module_id"), ("mission", "mission_defs", "mission_id")]:
        for (identifier,) in connection.execute(f"SELECT {column} FROM {table} ORDER BY {column}"):
            relative = f"{kind}/{identifier}.svg"
            write_svg(relative, shell(category_art(kind, identifier), seed=identifier))
            entries.append({"kind": kind, "id": identifier, "resource_path": PREFIX + relative})
    item_paths = {entry["id"]: entry["resource_path"] for entry in entries if entry["kind"] == "item"}
    ship_paths = {entry["id"]: entry["resource_path"] for entry in entries if entry["kind"] == "ship"}
    for recipe, output in connection.execute("SELECT recipe_id,output_item_id FROM recipe_defs ORDER BY recipe_id"):
        entries.append({"kind": "blueprint", "id": recipe, "resource_path": item_paths[output]})
    for recipe, output in connection.execute("SELECT hull_recipe_id,ship_id FROM hull_recipe_defs ORDER BY hull_recipe_id"):
        entries.append({"kind": "blueprint", "id": recipe, "resource_path": ship_paths[output]})
    connection.close()
    for kind in ["ship", "item", "research", "facility", "mission", "blueprint"]:
        write_svg(f"generic/{kind}.svg", shell(category_art(kind), seed=kind))
    resources = []
    missing = []
    for path in sorted({entry["resource_path"] for entry in entries} | {PREFIX + f"generic/{kind}.svg" for kind in ["ship", "item", "research", "facility", "mission", "blueprint"]}):
        file = ROOT / "code" / path.removeprefix("res://")
        if not file.is_file():
            missing.append(path)
            continue
        resources.append({"resource_path": path, "sha256": sha(file), "size_bytes": file.stat().st_size})
    if finalize and missing:
        raise RuntimeError("Native thumbnails still missing: " + ", ".join(missing))
    manifest = {
        "format_version": 1,
        "asset_version": "business-v11-industrial-lists",
        "scope": "Baked business portraits and ID-to-art mapping only. Definitions, prices, quantities, power and persistence remain exclusively in SQLite.",
        "authoring": {
            "origin": "Project-authored SVG geometry; ship portraits are native Godot captures of the project's formal original ship_v3 GLBs with the existing PBR surface style.",
            "license": "Original project artwork. Existing model/material dependency provenance remains in assets/ship_v3/manifest.json and assets/interface_v2/manifest.json.",
            "svg_source": "jiaoben/art/build_business_v11.py",
            "ship_renderer": "jiaoben/art/render_business_v11.gd",
            "ship_image_size": [256, 256],
            "svg_viewbox": [256, 256],
            "runtime_policy": "Prebaked PNG/SVG imported by Godot; shared Texture2D cache; no frame-time portrait rendering.",
            "unknown_id_policy": "Category-specific generic art. Unknown ships use an unidentified crate/question mark, never an invented specific hull.",
        },
        "source_assets": models,
        "resources": resources,
        "entries": sorted(entries, key=lambda entry: (entry["kind"], entry["id"])),
        "qa": {"status": "All declared portraits exist and checksums refreshed; native UI inspection is owned by the integrator." if not missing else "SVG complete; native ship captures pending.", "pending_resource_paths": missing},
    }
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--finalize", action="store_true", help="Require all nine native GLB captures and refresh every asset SHA.")
    args = parser.parse_args()
    manifest = build(args.finalize)
    counts = {kind: sum(entry["kind"] == kind for entry in manifest["entries"]) for kind in ["ship", "item", "research", "facility", "mission", "blueprint"]}
    print("BUSINESS_V11_ASSETS", json.dumps({"entries": counts, "resources": len(manifest["resources"]), "pending": len(manifest["qa"]["pending_resource_paths"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
