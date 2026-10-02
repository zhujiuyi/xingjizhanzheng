#!/bin/sh
# 只读取环境与目录，不安装软件，不输出环境变量或凭据。
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workspace_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
failures=0

printf '星际战舰 · 环境检查\n工作区：%s\n' "$workspace_dir"

for directory in code doc jiaoben jiaoben/tests jiaoben/tmp jiaoben/logs; do
    if [ -d "$workspace_dir/$directory" ]; then
        printf '[OK] %s/\n' "$directory"
    else
        printf '[缺失] %s/\n' "$directory"
        failures=$((failures + 1))
    fi
done

if command -v git >/dev/null 2>&1; then
    git --version
    if [ -d "$workspace_dir/.git" ] && git -C "$workspace_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf '[OK] 工作区 Git 已初始化\n'
    else
        printf '[缺失] 工作区 Git 尚未初始化\n'
        failures=$((failures + 1))
    fi
else
    printf '[缺失] Git\n'
    failures=$((failures + 1))
fi

for binary in node npm python3; do
    if command -v "$binary" >/dev/null 2>&1; then
        printf '[可用] %s：' "$binary"
        "$binary" --version
    else
        printf '[可选工具未安装] %s\n' "$binary"
    fi
done

godot_binary=''
if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
    godot_binary=$GODOT_BIN
elif [ -x "$HOME/Applications/Godot-4.7.2.app/Contents/MacOS/Godot" ]; then
    godot_binary="$HOME/Applications/Godot-4.7.2.app/Contents/MacOS/Godot"
elif command -v godot >/dev/null 2>&1; then
    godot_binary=$(command -v godot)
elif command -v godot4 >/dev/null 2>&1; then
    godot_binary=$(command -v godot4)
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    godot_binary=/Applications/Godot.app/Contents/MacOS/Godot
fi

if [ -n "$godot_binary" ]; then
    printf '[可用] Godot：'
    "$godot_binary" --version
elif [ -f "$workspace_dir/code/project.godot" ]; then
    printf '[缺失] 游戏工程使用 Godot，但未找到引擎\n'
    failures=$((failures + 1))
else
    printf '[待选型] 尚无游戏工程；不把基础环境通过视为引擎就绪\n'
fi

if [ -x "$HOME/Applications/Blender-4.5.14.app/Contents/MacOS/Blender" ]; then
    printf '[可用] Blender 4.5.14 LTS（用户 Applications）\n'
else
    printf '[未找到固定路径 Blender] 按 doc/22 核验建模工具\n'
fi

if [ "$failures" -ne 0 ]; then
    printf '检查失败：%s 项\n' "$failures"
    exit 1
fi
printf '基础环境检查通过。\n'
