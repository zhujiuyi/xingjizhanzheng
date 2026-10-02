# 测试与辅助文件

| 路径 | 用途 | Git 管理 |
| --- | --- | --- |
| `check-env.sh` | 检查工作区目录和本机工具；不安装软件 | 跟踪 |
| `build_catalog.py` | 从 `code/database/` 的结构与种子 SQL 重建正式数值库 | 跟踪 |
| `run_godot.sh` | 使用锁定引擎打开工程或执行命令 | 跟踪 |
| `build_client.py` | 校验资源、导出客户端并验证实际 Mac 包；`--publish` 将通过检查的包复制到 `code/dist/` | 跟踪 |
| `probes/`、`prepare_godot_probe.py` | 原生数据库/渲染/Blender 技术探针，运行产物在 tmp | 跟踪 |
| `verify_toolchain_downloads.py`、`vendor_sqlite.py`、`install_desktop_templates.py` | 官方包摘要检查与已核验桌面依赖准备 | 跟踪 |
| `tests/` | 可重复执行的测试及测试专用数据 | 跟踪 |
| `tmp/` | 实验、下载、临时文件和中间产物 | 仅跟踪占位文件 |
| `logs/` | 环境检查、运行和测试日志 | 仅跟踪占位文件 |

从工作区根目录运行 `sh jiaoben/check-env.sh`。脚本也可从其他目录调用，会按脚本所在位置定位工作区。

正式游戏逻辑和运行资源放在 `code/`；对外或长期使用的说明放在 `doc/`。下载缓存可以删除，正式源文件与测试成果不能当作临时文件清理。

数值检查入口为 `tests/test_balance.py`；加 `--report` 将结果写入 `logs/数值校验报告.md`。报告可重建，持久的范围说明和验收结果摘要维护在 [开发准备度](../doc/16-开发准备度与缺口清单.md)。测试中的公式是独立参考模型，不代表 Godot 玩法或进度存档已实现。

首版内容检查见 `tests/test_content.py`，进度 DDL/夹具检查见18，接口/占位及 `tests/test_rng_contract.py` 随机流契约检查见21，实际工具链及 `prepare_progress_probe.py` 正式SQL原生探针复现见22。运行专用探针时不得向正式用户档写入数据。

实际游戏检查入口与结果见 [交付记录](../doc/26-开发阶段与交付记录.md)：`tests/store_run.py` 检查存档与迁移，`tests/client_native.gd` 检查主客户端，`tests/combat_client.gd` 检查实际物理战斗，`tests/client_edges_run.py` 检查生命周期边界。GDScript 测试以 `sh jiaoben/run_godot.sh --headless --path code --script ../jiaoben/tests/<测试文件>.gd` 执行。业务探针按 `gameplay_probe.gd`、`full_catalog_gameplay_probe.gd` 顺序运行；完整内容探针依赖前者生成的已关闭基线副本。原生测试使用独立 `tmp` 数据库；运行时不得改写真实玩家进度。

macOS生命周期验收执行 `python3.14 jiaoben/tests/client_edges_run.py --audio-driver CoreAudio`，显式使用原生音频后端并保留严格退出检查。缺省headless Dummy后端的已知退出告警与分开日志见 [数据验证](../doc/24-数据服务实现与验证.md)。

v0.5表现重塑检查：`tests/camera_controls_v2.gd` 覆盖相对输入、九舰三分辨率镜头及机库/飞行切换；`tests/ui_visual_v2.gd` 覆盖实际界面与缩放并输出原生截图；`art/test_hangar_v2.gd` 检查九舰展示及材质/几何边界。图形验证不加 `--headless`，音频使用 `--audio-driver CoreAudio`。艺术构建辅助代码及独立资源来源见 `art/`、`install_interface_v2_assets.py` 和 `interface_v2_sources.json`；技能安装身份在 `gamedev_skills_install.json`。全部测试使用tmp库，不能删除用户进度。

UI 生命周期补充检查为 `tests/ui_lifecycle_v2.gd`。最终 headless 与原生 Metal/CoreAudio 均 27/27 PASS、`engine_diagnostics=0`，日志分别为 `logs/ui-lifecycle-v2-headless.log`、`logs/ui-lifecycle-v2-native.log`，未见错误、警告或资源泄漏；布局检查最终 75/75 PASS、42 张截图。生命周期测试覆盖首次悬停、快速切页、销毁控件、独立旧档继续、失效目标/音效/特效引用、暂停 UI 音效自然结束与退出。修复及证据边界见 [界面重塑方案](../doc/29-操控与界面重塑方案.md)。测试 teardown 在释放节点后等待两帧和 0.25 秒，供音频混音线程释放引用；该等待只属于夹具，不是生产退出或保存规则。

与实际游戏并行运行测试时，必须显式传入 `--log-file` 的独立绝对路径，例如 `--log-file /Users/a0000/workspace/xingjizhanjian/jiaoben/logs/ui-lifecycle-v2-engine-native.log`，不与 AppSupport 的实际 `godot.log` 共用。headless 和原生运行分别保留进程输出与引擎日志；原生音频检查传入 `--audio-driver CoreAudio`。

实际发布诊断使用内置 `--xj-verify-presentation` 入口，不加载外部脚本。`build_client.py` 为每次检查创建独立 fresh `jiaoben/tmp/release-presentation/<UUID>/progress.db`，通过 `XJ_TEST_DATABASE` 传入；主程序拒绝已有数据库及 tmp 外路径。构建脚本要求实际 Mac 包的 Metal/CoreAudio 24 项检查通过，保存首页、机库、NPC、飞行四张截图并使用独立 `--log-file`。目前正在最终导出与发布包复验，尚未交付新版；最终发布 PASS、包路径和摘要以 [交付记录](../doc/26-开发阶段与交付记录.md) 为准。
