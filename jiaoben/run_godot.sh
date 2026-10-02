#!/bin/sh
# 只选择已安装且版本匹配的引擎；不下载、不安装。默认打开正式工程。
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workspace_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
engine=${GODOT_BIN:-"$HOME/Applications/Godot-4.7.2.app/Contents/MacOS/Godot"}
if [ ! -x "$engine" ]; then
    printf '未找到固定版本引擎；请按 doc/22 配置 GODOT_BIN。\n' >&2
    exit 1
fi
actual_version=$("$engine" --version)
if [ "$actual_version" != '4.7.2.stable.official.ed1daf0bf' ]; then
    printf '版本不匹配：%s；请审阅 code/toolchain.lock.toml 后再升级。\n' "$actual_version" >&2
    exit 1
fi
if [ "$#" -eq 0 ]; then
    exec "$engine" --editor --path "$workspace_dir/code"
fi
exec "$engine" "$@"
