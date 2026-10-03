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

UI 生命周期补充检查为 `tests/ui_lifecycle_v2.gd`。对应v0.5及存档卡片阶段的 headless 与原生 Metal/CoreAudio 均 27/27 PASS、`engine_diagnostics=0`，日志分别为 `logs/ui-lifecycle-v2-headless.log`、`logs/ui-lifecycle-v2-native.log`，未见错误、警告或资源泄漏；该阶段布局检查75/75 PASS、42 张截图。生命周期测试覆盖首次悬停、快速切页、销毁控件、独立旧档继续、失效目标/音效/特效引用、暂停 UI 音效自然结束与退出。修复及证据边界见 [界面重塑方案](../doc/29-操控与界面重塑方案.md)。测试 teardown 在释放节点后等待两帧和 0.25 秒，供音频混音线程释放引用；该等待只属于夹具，不是生产退出或保存规则。

与实际游戏并行运行测试时，必须显式传入 `--log-file` 的独立绝对路径，例如 `--log-file /Users/a0000/workspace/xingjizhanjian/jiaoben/logs/ui-lifecycle-v2-engine-native.log`，不与 AppSupport 的实际 `godot.log` 共用。headless 和原生运行分别保留进程输出与引擎日志；原生音频检查传入 `--audio-driver CoreAudio`。

实际发布诊断使用内置 `--xj-verify-presentation` 入口，不加载外部脚本。`build_client.py` 为每次检查创建独立 fresh `jiaoben/tmp/release-presentation/<UUID>/progress.db`，通过 `XJ_TEST_DATABASE` 传入；主程序拒绝已有数据库及 tmp 外路径。构建脚本要求实际Mac包的Metal/CoreAudio **33项检查、6张截图**，包括首页、机库、NPC、飞行、档案卡片和靠站提示，使用独立 `--log-file`。先行源码33/33 PASS的 `logs/source-v3-presentation2.log` 保留；实际最终Release `0.6.0-3196c031-20261003-054157` 已另行33/33 PASS，见 [实际包日志](logs/0.6.0-3196c031-20261003-054157-mac-presentation.log) 与 [引擎日志](logs/0.6.0-3196c031-20261003-054157-mac-presentation-engine.log)。截图在 `tmp/release-presentation/b7a35a15-15ad-4fca-bad4-a65372ff10b6/`，该目录内进度库只属于夹具。额外人工操作复查因Mac锁屏尚未完成，不记录为人工PASS。最终包路径和摘要见 [交付记录](../doc/26-开发阶段与交付记录.md)。

## v0.6表现与易用性检查

| 入口 | 范围与当前证据 |
| --- | --- |
| `tests/font_v3_glyphs.py`、`tests/font_theme_v3.gd` | 官方OTF字形/UTF-8检查、共享字体、九项资源、Theme与人员Label3D。最终报告`logs/font-v3-final-coverage.json`覆盖103文件、84张内容表、816字符，缺字/编码替换字0；独立字体headless29、原生34项/5图通过，不代替Windows实机。 |
| `tests/interaction_v3.gd`、`tests/interaction_v3_run.py` | 真实Main的F候选/指定鼠标目标、范围速度权限、门充能取消、暂停与键盘/指针阻塞。headless51、原生55项通过；原生OS鼠标检查与headless分开。 |
| `build_navigation_v3.py`、`tests/navigation_v3.gd` | 重建只读导航SQLite；雷达范围、选中连线/离屏、天体只航向和高缩放布局。最新headless62、整机原生67项/5图通过，使用当前星空/地貌；最终日志`logs/navigation-v3-native-final.log`。 |
| `art/build_station_v3.py`、`art/build_station_manifest_v3.py`、`art/test_station_v3.gd`、`art/preview_station_v3.gd` | 原创空间站构建、清单、模型/材质及原碰撞锚点保持；headless与原生各114项通过。预览产物在tmp；整机与实际包固定诊断分开记录。 |
| `art/build_ships_v3.py`、`art/build_ship_v3_manifest.py`、`art/test_ship_v3.gd`、`art/preview_ship_v3.gd` | 九类舰与静默敌舰工业视觉、原wrapper碰撞/挂点保持；headless与原生契约各410项通过，10个GLB＋shader共11运行资源。模型合计673,622三角；自动导入LOD不等于手工LOD或性能保证。 |
| `tests/presentation_failures.gd`、`tests/failure_factory.gd` | 真实Main/Store准备路径注入玩家/NPC模型失败，验证模拟不推进和旧world/epoch/slot保持，恢复后可再加载保存。headless＋显式CoreAudio28项通过、严格诊断0；不向个人库写入故障对象。 |

最终整机原生回归汇总在 `logs/v3-final-native-acceptance.log`：导航67/5图、布局75/42图、镜头208、客户端36、物理战斗18、生命周期27，六脚本均PASS、退出0、diagnostics=0。对应日志前缀为 `navigation-v3-native-final`、`ui-v3-layout-final`、`camera-v3-final`、`client-v3-final`、`combat-v3-final`、`lifecycle-v3-final`，各有独立引擎日志。实际Release另行校验124项原始资源、ad-hoc签名、六项数据库与33项表现诊断并通过；[构建身份](../code/dist/0.6.0-3196c031-20261003-054157/build-manifest.json)记录源提交与构建时 `source_dirty=false`。Windows x64导出、PE/PCK/DLL检查通过，Windows原生运行未验收；源码、实际包固定诊断和人工复查保持独立结论。

星空和地貌来源见 `../code/assets/navigation_v3/sources.json`；正式生成图放code，下载/制作中间文件、预览和日志仍放tmp/logs。新版资源说明分别在 `navigation_v3`、`station_v3`、`ship_v3` 的README；验证范围汇总见 [31](../doc/31-EVE第二银河参考与易用性改版.md)。不要启动第二个Godot原生测试或同时编辑器导入，先与正在验收的整合者协调运行窗口。所有夹具继续使用独立临时库，不复用个人存档。


v0.6.1航行视角补丁：`tests/flight_visibility_v4.gd` 验证独立SQLite中舰首存读档、HUD说明、“显示舰船”按钮、镜头恢复不改变运动、V阻断与高缩放布局；本轮验收结果见26。实际发布入口现要求35项检查和6张截图，新增舰首模式说明与找回舰船检查；上文v0.6的33项属于历史结果。源码原生四项回归汇总为 `logs/v061-native-acceptance.log`；各测试和发布包均使用独立tmp库及独立引擎日志。


v0.6.1专项已完成：`flight_visibility_v4.gd` headless/CoreAudio44项、Metal/CoreAudio49项（真实OS hover3项/2图）均通过且严格诊断0。真实SQLite保存舰首、重启继续、按钮恢复跟随并保存再重启全部通过。实际新包 `0.6.1-74ccdab4-20261003-133018` 的35项表现/6图、六项数据库、资源摘要及临时签名另行通过；相关日志前缀为构建ID，截图目录 `tmp/release-presentation/444a75a5-5b57-43fc-b5ca-8ac9701337be/`。窗口已释放，未写个人进度；Windows原生仍待实机验收，最新包位置见26。


v0.6.2目标标注专项：`tests/target_annotations_v5.gd` 使用独立fresh Main/SQLite，冻结玩法物理并保留真实render回调。headless/CoreAudio54项、Metal/CoreAudio58项/4图通过；验证单一名称Label、无阴影/描边、选中目标排除重复通道、模型实例不变、动态/静止切换、三视角、四组布局与失效/暂停清理。NPC通过未改SQLite原型创建测试runtime DTO，再走生产sync_entities，不能冒充自然任务解锁。原生与headless日志前缀`target-annotations-v5`，所有检查严格诊断0。实际发布端点现要求37项/6图，新增清晰名称和唯一标注/Model检查；源码与实际包证据见26，不使用旧35项代替。

v0.6.2实际新包 `0.6.2-8d86553e-20261003-141501` 已通过37项Metal/CoreAudio表现检查/6图、六项数据库、124项原始资源摘要与ad-hoc签名。构建时源提交 `8d86553e0251234a6700d38c8268bf7889ebdbd3`、`source_dirty=false`；构建日志为 `logs/client-v062-build.log`，实际包日志前缀为构建ID，八份导出/签名/数据库/表现及引擎日志严格诊断0。截图目录 `tmp/release-presentation/24f66996-dade-48ba-a6de-fa65b3e7f1be/`，其中靠站截图已经查看，显示单层名称和选中框。Windows Release及PE/PCK/DLL检查通过，原生运行尚未验证；交付物和摘要见 [26](../doc/26-开发阶段与交付记录.md)。


## v0.7.0曦航对标与自动导航

`build_local_navigation.py` 从正式 SQL 构建独立只读 v1 导航数据库，清单只存身份/摘要。`tests/local_navigation_geometry_v6.gd` 检查实际十站九舰的三维安全落点及规则/取消边界。`tests/navigation_commands_v6_run.py` 默认 headless/CoreAudio，`--native` 要求独占原生窗口，使用 fresh tmp 库检查真实 Main 导航、SQLite 到达保存和重开、实体射线选择、火力辅助并行、总览设备和布局；原生与 headless 证据分别记录。截图不能替代实际物理与持久状态检查。

发布固定端点已扩展为46项检查、9张实际包截图，新增图形星图、真实设备、独立导航SQLite、先存起点再跃迁、站外停船、实际射线选站及业务进站；构建器逐张检查PNG与摘要。此次测试结果和实际包身份见 [32](../doc/32-曦航对标与导航交互改进.md) 与 [26](../doc/26-开发阶段与交付记录.md)，旧版本结果保留为历史。
