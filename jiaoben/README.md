# 测试与辅助文件

## 星图重塑

从根目录执行 `/usr/local/bin/python3.14 jiaoben/tests/star_chart_v13_run.py`，追加`--native`独占Metal/CoreAudio窗口。fresh tmp SQLite验证真实Main的单选情报、方向/门资格/载重变化、输入隔离、关闭重开/换世界/实际旅行绑定、四布局及120/300个纯UI节点；日志和结构化结果在logs，截图和DB在tmp。共用`feature-audit.lock`，不得与其它Godot检查/编辑器导入并行。原生Viewport事件与额外系统输入复查分别记录，最终结果见40。

当前发行包内置表现门槛为90项/14图（增加12项星图检查，保留原78项），`build_client.py`必须用实际bundle/PCK独立运行；未通过不得发布。历史小节的旧检查数属于对应版本。

## 全量功能审核

从工作区根目录执行 `/usr/local/bin/python3.14 jiaoben/tests/feature_audit_run.py`。统一runner串行执行现有客户端、战斗、存档、界面、导航及新增完整进度、经济、模块开关、借船清理和历史容量/内容增量专项；每组独立输出与引擎日志，严格检查端点、退出与诊断。`--native`执行默认原生整合组；`--native --only navigation-commands targets visibility --merge`补充操控/标注/可见性并合入同一汇总。`--only`选择检查，`--merge`保留其它已执行结果；不得同时运行两个runner，锁文件仅在tmp。

旧catalog夹具由runner从已存在Git提交 `c2ac4ae5eb43dc9ab052f09ea5d2a72c542edf4c` 的正式数值库提取到 `tmp/audit-catalog-v090.db`，验证固定SHA，不覆盖身份不同的既有文件。独立运行历史probe前先用runner准备该夹具。借船清理probe依赖先执行`gameplay_probe.gd`得到已关闭基线。原始v0.8.4发行测试库是本机历史额外证据，不是默认runner依赖；额外`--legacy`输入只允许已关闭tmp测试库。

本轮功能矩阵、确认修复、实际检查数、夹具与原生边界见 [39](../doc/39-功能完整性审核与测试.md)。测试源码和正式代码按各自目录纳入Git，所有运行数据库、截图、日志仍留在tmp/logs，不能带入正式用户存档。

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

发布固定端点已扩展为48项检查、9张实际包截图，新增图形星图、真实设备、独立导航SQLite、先存起点再跃迁、站外停船、实际射线选站及业务进站；另检查运动后速度读数和连续渲染中的标注唯一性，构建器逐张检查PNG与摘要。此次测试结果和实际包身份见 [32](../doc/32-曦航对标与导航交互改进.md) 与 [26](../doc/26-开发阶段与交付记录.md)，旧版本结果保留为历史。

## v0.8.0输入与运动检查

新版采用常驻光标、左键短击选择/长按观察、WS观察航向推进、AD转弯及总览双击接近。旧v6的Alt、捕获鼠标、鼠标操舰及右键观察断言已由v7契约替代；旧源码结果只属于历史。适用导航、UI布局、生命周期、真实战斗和存读档回归仍须执行；维护旧夹具时替换失效输入契约，不删业务覆盖，也不能忽略生产错误。

| 入口 | 当前headless证据与边界 |
| --- | --- |
| `tests/camera_pointer_v7.gd`、`tests/camera_pointer_v7_run.py` | CoreAudio280项、原生294项/2图通过：九舰三视角、真实Main输入、观察松手保持、三维航向推进/弯向、手动接管惯性、开火/交战及三镜头SQLite重开；`--components-only`只验组件，不能代替完整入口。原生由整合者独占窗口执行。 |
| `tests/overview_commands_v7.gd` | CoreAudio52项通过、退出0：实际Viewport GUI事件检查同一目标行单击/双击及单发请求、远景无导航、Main非法替换保持原导航、真实NPC资格与交战、换选择不转火、四组布局。原生分支另检查实际tooltip生成、文字/弹窗尺寸并输出4布局+4tooltip图；最终原生68项/8图通过。 |
| `tests/scene_rendering_v7.gd` | 851项通过：独立十星区、79实际目标与243 Mesh实例；检查单模型、材料pass与远景结构，不代表所有个人存档复现。 |
| `tests/navigation_render_poses_v7.gd` | 567项通过：实际引擎插值与生产NavHUD，80帧插值差异，标记/虚线/雷达使用一致姿态；接触体的测试运动不写入正式平衡定义或存档。 |
| `tests/flight_motion_visual_v7.gd` | 490项通过：实际Main物理与render回调、真实行星，120插值帧，所测中心误差0；headless没有图像证据。原生497项/6图通过，已查看代表帧，具体数据见33。 |

上述当前日志分别为 `logs/camera-pointer-v7-headless{,-engine}.log`、`logs/overview-commands-v7-headless{,-engine}.log`、`logs/scene-rendering-v7-{headless,engine-headless}.log`、`logs/navigation-render-poses-v7-{headless,engine-headless}.log`、`logs/flight-motion-v7-{headless,engine-headless}.log`；各组stdout和独立引擎日志未见错误、警告、脚本错误或退出泄漏。数目对应当前完整运行，后续新增检查须以新的执行结果更新。

完整输入检查可从工作区根目录执行`/usr/local/bin/python3.14 jiaoben/tests/camera_pointer_v7_run.py`。其他GDScript入口使用`sh jiaoben/run_godot.sh --headless --audio-driver CoreAudio --path code --script ../jiaoben/tests/<文件名>.gd --log-file <本轮独立引擎日志绝对路径>`，并单独保存stdout。去掉`--headless`或使用`--native`之前必须与整合者协调独占原生窗口；不要并行打开Godot原生测试或编辑器导入。

新版内置发布诊断固定要求**53项检查、9张截图**，新增物理插值、常驻指针、右键禁用、普通鼠标移动及左拖/松开保留跃迁的实际状态验证；最终实际Mac包必须独立通过，不能以headless或源码结果代替。当前源码原生及实际Mac发布包53/53、9图已通过，实施和证据范围见 [33](../doc/33-指令式操舰与运动重影修正.md)，最终构建身份见26。模型/相机/插值修正不证明TAA是原因，也不承诺个人存档所有重影均已解决。

最终实际交付构建`0.8.0-46586463-20261003-175154`来自干净已推送源`46586463`，Mac六项数据库、53项Metal/CoreAudio表现/9图、125项资源和临时签名通过，8份构建日志严格诊断0；Windows导出组件通过、原生仍待实机。ZIP与截图已重算摘要，包路径与SHA见26。

## v0.8.1教学采矿与资源情报

`python3.14 jiaoben/tests/mining_resources_v8_run.py` 执行真实Main与SQLite采矿检查；`--native` 使用Metal/CoreAudio及实际窗口焦点，需独占图形测试窗口。所有进度、日志、截图位于`tmp/`或`logs/`，不访问个人档案。

最终headless **160/160**、原生 **170/170与9图**通过，退出0，完整输出与独立引擎日志严格错误、警告、泄漏0。日志为`logs/mining-resources-v8-{headless,native}{,-engine}.log`，原生截图在`tmp/mining-resources-v8/native/`。覆盖实际矿点资格、F、距离/视线/设备、有限付费周期、双采集头、末单位立即保存、满舱/配额、再生/暂停/SQLite重开、远距离总览、当前/已访问星系矿量及未知情报、四组布局和真实文字高度；T2实际接取、绑定样本、转仓/归还清理、补领、保存的样本损失、重开补采与一次性实物结算；普通借船同attempt归还重领保持额度0及唯一SQL合同、发行历史追加。普通额度0和历史样本损失是明确状态夹具，不声称自然采完600单位或自然损毁；非采矿前置任务及位置/解锁采用明确准备，不作为自然通关或个人档案人工试玩证据。

最终相关headless回归为UI **104**、总览 **52**、内置表现诊断 **59**，日志`logs/v081-final-{ui,overview,presentation}{,-engine}.log`，均退出0且严格诊断0。本轮其余检查为玩法144、完整内容216、SQLite247；字体111源码文件/84表/857字符、缺字和编码缺陷0，证据见[交付记录](../doc/26-开发阶段与交付记录.md)。

发布诊断现在固定要求**59项检查、10张截图**，新增实际资源表查询、远距离矿量及文字几何、星图情报、真实最后单位采矿产出、耗尽拒绝及暂停倒计时。构建脚本仍须从干净源执行实际Mac Release独立运行，不能用源检查代替实际包。实际包身份和结果见26及下段。

最终实际交付`0.8.1-21368d9d-20261003-192837`来自干净已推送源`21368d9d`，Mac六项数据库、59项Metal/CoreAudio表现及10图、125项资源与临时签名通过，8份独立构建日志严格诊断0；ZIP与10图摘要另行重算一致，两个ZIP完整性与操作说明齐备。Windows Release组件通过，原生仍待实机。实际包矿点耗尽/20:00世界时间和星图矿量画面已查看；构建、路径、摘要及夹具边界见26。源码专项160/170是独立完整T2业务/SQL回归，实际包59检查只覆盖其明确发布场景，不能将两层检查互相替代。


## v0.8.2航行HUD布局

`/usr/local/bin/python3.14 jiaoben/tests/hud_layout_v9_run.py` 使用真实Main、独立SQLite和Viewport GUI事件检查四组布局（1440×900、1280×720，各100%/200%）；`--native` 使用独占Metal/CoreAudio窗口与实际焦点、鼠标位置，`--wide` 追加1920×1080。普通保存请求由已支付的真实采矿周期进入等待，通过实际GUI点击取消，验证只清等待请求、矿量及已支付周期保持。菜单点击验证实际页面、输入消费和键盘防护，失败时记录鼠标/焦点/指针状态而不直接清理状态规避断言。

几何检查涵盖通知与两侧/顶栏/底座避让、相同通知去重及不同反馈保留、舰况与设备同一HBox同排、九舰真实已装/空SLOT可滚动访问、正常总览拉长与紧凑详情/矿量/每个动作/末行可访问、文字实际高度及完整tooltip。九舰通过明确创建/选择、矿船依法标准配装、其他舰保留空槽；矿点解锁和位置为显式定位夹具，不声称自然买齐九舰、自然通关或个人存档试玩。日志为`logs/hud-layout-v9-{headless,native}{,-engine}.log`，追加宽屏的日志带`-wide`；原生截图在`tmp/hud-layout-v9/native/`。最终headless246项，原生含宽屏324项/20图通过，严格错误/警告/泄漏0。相关UI104、生命周期27、源码内置表现66项通过，字体111文件/84表/858字符无缺字或编码缺陷。最终构建身份及证据边界见26及35。

内置发布诊断现要求**66项检查、11张截图**，在原59项上增加顶部菜单、同排仪表/设备、总览高度、按钮文字及真实采矿中的等待保存/无重复通知/取消保持业务；新增`release-save-wait.png`。实际Mac Release须独立运行，源码headless结果不替代包验证。


最终实际交付`0.8.2-f9063ee1-20261003-212516`来自干净已推送源`f9063ee1`。Mac实际包6项数据库、66项Metal/CoreAudio表现/11图、125项资源与临时签名通过，8份独立构建日志严格诊断0；ZIP与11图摘要重算一致、CRC及使用说明齐备。Windows Release组件导出通过，原生仍待实机。包路径、SHA和定位/业务夹具边界见26；本轮未修改正式数值、存档DDL或资产。


## v0.8.3舰船姿态回正

`/usr/local/bin/python3.14 jiaoben/tests/attitude_v10_run.py`运行真实Main/物理/独立SQLite；`--native`需独占Mac窗口、真实焦点与OS指针，使用Metal/CoreAudio。最终headless138项、原生146项/5图通过，完整输出及独立引擎日志严格诊断0，路径为`logs/attitude-v10-{headless,native}{,-engine}.log`及`tmp/attitude-v10/native/`。覆盖俯仰A/D、观察航向WS、总转速预算、Q/E按住与释放、四组精确/近垂直姿态、极点右轴连续、明确回正后相机/舰体右轴一致、实际导航保持及SQLite保存/关闭/重开两类姿态。初始位置、旧倾角和合法持久端点为明确夹具，未修改个人存档。

当前操控headless280、原生294/2图复验通过。旧“释放WS后完整Basis冻结”契约改为前向不漂移、实际输入清零、残余滚转在同转速预算内收敛；non-FRONT A/D观察轴明确为世界上轴。导航渲染567、雷达/标记69、物理战斗18、生命周期27及源码内置70项通过；最终日志`logs/v083-{navigation-render,navigation,combat,lifecycle,presentation-source}-final{,-engine}.log`。导航tooltip检查维护为操控首行与完整紧凑雷达说明，未减少标记/虚线/插值覆盖。字体111文件/84表/858字符，无缺字或编码缺陷。

发布门槛现为**70项表现检查、12张截图**，新增真实Flight回正及其总转速预算、显式滚转、真实镜头回正、精确垂直姿态，并新增`release-attitude-level.png`。实际Mac包必须独立运行6项数据库与70项表现，不以源测试代替；最终包身份与结果见26。Windows原生运行仍待实机。规则及镜头穿越极点的±上轴连续边界见[36](../doc/36-舰船姿态回正与相机基准.md)。

最终实际交付`0.8.3-903ebd87-20261003-225013`来自干净已推送源`903ebd87`，实际Mac6项数据库、70项Metal/CoreAudio表现及12图、125项资源与临时签名通过；8份独立构建日志严格诊断0，两ZIP及12图SHA已重算一致、CRC与说明/许可齐备。源码138/146的完整输入与持久化专项和实际包70固定场景分开记录；回正/航行/站外停止画面已查看。Windows导出组件通过，原生待实机。证据及包路径见26。

## 业务列表与图片检查

从工作区根目录运行 `/usr/local/bin/python3.14 jiaoben/tests/business_list_v11_run.py`，默认使用headless/CoreAudio；追加 `--native` 使用独占Metal/CoreAudio窗口、真实焦点与OS指针。检查真实Main的报价及禁用原因、正常舰体/物品购买、舰队切换、仓储转移、出售、配装/卸装、保护资产限制、各业务列表布局/滚动与SQLite保存关闭重开。资金、解锁与目标位置为独立测试库中的显式准备，不把夹具当作自然通关或个人档案试玩。图片检查和业务动作检查互相不能替代。

完整输出及独立引擎日志为 `logs/business-list-v11-{headless,native}{,-engine}.log`，原生截图位于 `tmp/business-list-v11/native/`。runner要求实际成功端点、退出0以及脚本错误/错误/警告/资源泄漏严格为0；具体检查数和发布状态以本轮实际日志及 [交付记录](../doc/26-开发阶段与交付记录.md) 为准。

业务图片的正式资源与来源清单在 `../code/assets/business_v11/`，静态SVG构建和模型截图辅助脚本在 `art/`。从根目录依次执行：

```sh
/usr/local/bin/python3.14 jiaoben/art/build_business_v11.py
# 在整合者安排的独占窗口中运行；不可加 --headless，不与编辑器导入或其他原生检查并行。
sh jiaoben/run_godot.sh --audio-driver CoreAudio --path code --script ../jiaoben/art/render_business_v11.gd --log-file /Users/a0000/workspace/xingjizhanjian/jiaoben/logs/business-v11-render-engine.log > jiaoben/logs/business-v11-render.log 2>&1
/usr/local/bin/python3.14 jiaoben/art/build_business_v11.py --finalize
```

正式PNG产生后再执行工程导入，使Godot导入256×256透明舰体图片；测试或正式运行前确认导入已完成。渲染直接使用九类现有正式工业GLB及现有PBR材质，拒绝空图和贴边裁切；不会读取或改写玩家进度。114个原创SVG与9个实际GLB截图形成123项图片资源，174条ID映射包含配方复用，manifest不存价格、数量或另一套平衡数值。静态复核报告为 `logs/business-v11-assets-static-final.json`，PNG原生结果仍须配合实际业务界面和最终发布包验收。

## 任务导航、主线与战斗打捞检查

`/usr/local/bin/python3.14 jiaoben/tests/encounter_mission_v12_run.py`检查真实Main、任务地点/主线研究入口、敌群聚合与展开、局部跃迁、打捞载荷、任意站鉴定、唯一预定奖励和SQLite故障回滚。追加`--native`在整合者安排的独占Metal/CoreAudio窗口运行，包含真实指针与四组分辨率/缩放。输出和引擎日志分别位于`logs/encounter-mission-v12-{headless,native}{,-engine}.log`，独立库/截图在`tmp/encounter-mission-v12/`。

`--legacy <绝对路径>`只能指向本工作区tmp下已关闭的历史测试库，不得传入个人存档。旧档专项核验格式5→6、受审冻结内容升级、每源快照独立备份、旧手动槽恢复及事务失败保持原端点。当前源码headless480项、原生496项/15图通过；定位、资金、解锁和早期教学事件是明确夹具，不等于自然通关或长期平衡。

`build_client.py`另用实际Mac bundle加载其导出PCK，绝不传`--path code`；通过显式`--xj-verify-encounters`入口加载绝对外部专项Node，使用新的UUID tmp目录。Release模板不支持编辑器的`--script`参数，源码runner则生成tmp SceneTree启动器。此层不请求legacy输入，与源码旧档测试分开记录，严格核对最终JSON、PASS标记、双日志诊断和每张PNG摘要。实际构建身份、检查数及Windows验证边界见26。
