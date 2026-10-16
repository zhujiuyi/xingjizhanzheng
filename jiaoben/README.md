# 测试与辅助文件

## 航行加载响应

`py jiaoben/tests/startup_navigation_run.py [--executable <v0.37.0 EXE>]` 使用真实标题按钮、共享审计锁、fresh UUID 库与严格双日志，验证新建/继续/保存返回标题的响应以及加载后持续运行。可传 `--profile-copy <jiaoben/tmp 内已关闭的副本>`，先继续原世界再新建；加 `--profile-new-first` 单独验证未先升级的旧档直接新建。不得传个人原件。旧 v0.33.0 反例另加 `--legacy-v61`，只在 tmp 暂存适配脚本。失败/安全停止入口为 `py jiaoben/tests/loading_failure_run.py [--executable <v0.33.1 EXE>]`，固定两条预期错误各一次，其余诊断严格拒绝。原始报告在 logs，截图/副本在 tmp，边界与验收见 [71](../doc/71-航行加载响应与旧档性能修复.md)。

## 全界面UI审查

源码原生检查：`py jiaoben/tests/ui_quality_audit_run.py --label before` 或 `--label after --strict-layout`。工具持有共享运行锁，使用fresh UUID测试库，覆盖28个独立页面/四种尺寸与缩放/声明的子视图、真实控件交互、UI源文件前后摘要与严格双日志；不使用个人存档。实际Windows 0.37.1.0可加`--executable <EXE>`，仅固定v61入口，拒绝向旧EXE传新参数或使用通用`--script`。信用点/解锁/有限库存为明示展示夹具，购船/招募/配装/保存/出港调用真实入口；不能将其作为自然成长或全战斗运行态验收。报告在logs、截图及控件JSON在tmp/ui-quality-audit。`--headless`仅检查结构，不能替代原生图。问题与实际证据见[68](../doc/68-全界面工业风审查与整改.md)。

交互专项：`py jiaoben/tests/ui_interaction_consistency_run.py [--executable <0.37.1.0 EXE>]`。使用同样的锁和fresh UUID，验证未提交/失焦数量、真实资格、旧配装报价、内部SpinBox编辑器焦点、上下文返回和旧页面/旧世界回调。不能把有资金视为有库存；所有禁用判断与业务服务的实际资格比较。

材质、特效与新舰造型：`py jiaoben/tests/render_quality_audit_run.py --label after --baseline <已接受before报告>`，实际包另加`--executable <0.33.0.0 EXE> --source-reference <已接受source-after报告>`。before须在改动前的源码保存；after验证真实资源、几何/锚点、画质切换、FX像素可见性与寿命/暂停/预算、全状态/RNG及严格双日志。模型作者流程为Blender运行`art/build_ships_v4.py`，原生`art/preview_ships_v4.gd`生成逐舰三角度与缩略图，`art/bake_hangar_reflection.gd`仅捕捉静态机库；生成资源后更新两个新表现包manifest及ship_v4 manifest。所有引擎操作串行持锁；图像或manifest存在不能代替实际验收。范围与结果见[69](../doc/69-交互一致性与材质表现优化.md)、[70](../doc/70-舰船造型重建.md)。

## 信息分层与场景化入口

`py jiaoben/tests/ui_information_v63_run.py [--executable <0.37.1.0 EXE>]` 使用固定v63入口、共享锁、fresh UUID测试库和严格双日志，核验当前舰无人机权限/实际装配、站内与飞行命令分离、摘要列表与旧隐藏回调、研究分类及真实投入、成长推荐推进、回收包一次领取、文明分区和合同详情。1280×720/200%货舱领取使用实际640×360逻辑画布。18种目录权限、三艘真实切换/装配舰、资金/进度/容器边界为明示测试夹具，不能替代自然成长或全部战斗验证。源码与实际包分开运行，报告在logs，截图和测试库在tmp/ui-information-v63；整改记录与28页覆盖映射见[72](../doc/72-界面信息分层与场景化入口整改.md)。

## 既有专项入口

Windows仓储与交易使用 `py jiaoben/verify_combat_v18.py --native --only warehouse row-quantity [--executable <0.37.1.0 EXE>]`，沿用固定仓储/行数量入口，启动前只读检查PCK参数存在，严格fresh UUID和双日志。旧Mac专用runner保留为历史工具。仓储来源夹具先真实出港并放入NPC的权威地点，再调用原伤害/封存服务；不直接生成战利品。导航用 `py jiaoben/tests/navigation_commands_v6_run.py --native [--executable <0.37.1.0 EXE>]`，WASAPI/Dummy自动按平台选择，外层600秒；覆盖停止、合法大坐标转向、跃迁/穿门/抵达及持久边界。


遗留界面专项：`py jiaoben/tests/ui_completion_v64_run.py`仅运行本轮七组（相关功能菜单、研究空态、累计指标、折叠、HUD键盘、距离、四尺寸交易）。可加`--executable <已核验且包含固定v64入口的Windows EXE>`；runner校验二进制身份与`--xj-verify-ui-completion-v64`，拒绝向旧包传通用脚本。源码与实际PCK分开运行，共用审计锁、fresh UUID私有库、严格双日志及源码/测试摘要。脚本600秒看门狗、外层660秒有界等待；`--headless`仅作结构/分发检查，不能替代原生窗口。

v64覆盖1440×900、1024×648、1920×1080、1280×720@200%（实际640×360逻辑画布），记录完整关键控件、真实菜单/按来路返回、F6模式下实际导航/停止与战斗开关、模式外原Tab切目标，以及数量2的实际购买/扣款。7字段展示与入籍边界为明示临时夹具，真实交易前恢复；报告裁剪通过原telemetry服务的零时长生命周期边界验证，不作为正常航行证据。最大17槽只把真实目录槽位/模块数据显示于生产EquipmentBar，四尺寸逐磁贴测矩形、标签、完整tooltip与环数值，然后恢复原资源；不创建权威设备、不保存假装配，不声称合法满装。报告在`logs/ui-completion-v64-*`，截图/私有库在`tmp/ui-completion-v64/<UUID>/`。最终实际Windows包14组16842项/304图及正式目录Store6项通过；源码/反例/实际证据分别归档，完整范围见[75](../doc/75-遗留交互与回归整改计划审核.md)。

正常成长续段来源统一使用`prepare_natural_checkpoint.py --report <logs中的已通过报告> --case natural-research|natural-rescue`。输出只读核对后的来源凭据和路径文件。`--only natural-rescue`读取`XJ_NATURAL_RESEARCH_ORIGIN`，运行实际战斗、修复护送、交付与整备款；源库不写入。此组尚待运行，不能因脚本存在就视为通过。

主线/研究正常续段：`--only natural-research`读取`XJ_NATURAL_SCOUT_ORIGIN`指定的`logs/v52-scout-origin-*.json`，只使用已通过正常探索回放的关闭副本，执行原有主线、市场和研究入口。当前运行状态与来源边界见67。

正常探索续段使用`--only natural-scout`与`XJ_NATURAL_EXAM_ORIGIN`指向`logs/v51-exam-origin-*.json`，只允许经摘要和已通过回放记录绑定的`natural-rank-v50`副本。购船、装配、导航、调查、战斗和领取均走Main真实入口，不注入进度或时钟。当前运行状态见67；未完成前不得将部分日志计为通过。

v50补验：`--only march-routes`为三文明24条路线的战略矩阵（明示粗粒度时钟），`--native --only growth-world`验证实际成长入口；正常成长用`--only natural-mid`及`natural-rank`，分别通过`XJ_NATURAL_MID_ORIGIN`和`XJ_NATURAL_RANK_ORIGIN`指定经摘要核对的正常来源。后者的`v50-mid-origin-*.json`明确保留前段登记前提失败，不能作为整组通过凭据。运行仍须持有主工作区共享锁并串行；所有旧输入只读，勿使用个人库。

v0.32联合源码检查：`verify_combat_v18.py --only march`验证114组行军/成长业务，`--native --only march-world`验证真实窗口、舰体和入门速度；`--only march-upgrade`须通过`XJ_MARCH_LEGACY_PROVENANCE`传入`logs/v49-march-legacy-source-*.json`中的已核实际v0.31旧输入。固定入口均为v49，实际EXE须至少0.32且PCK内存在对应参数，不能向旧EXE试探新参数。源码200项/6图通过，边界见61与`logs/v49-source-integration-checkpoint.json`，不等同自然成长或发行验收。

v0.31正式Windows包已交付：最终包15组925项/36图、正式目录另6项与文件/ZIP一致性通过，汇总`logs/v48-final-candidate-checkpoint.json`和`logs/v48-delivery-verification.json`。下文开发检查点的“待验”只描述当时范围，当前状态见[26](../doc/26-开发阶段与交付记录.md)。完整目标继续S34和S29中后期，相关功能合并开发后统一验收。

保留策略：`--only retention`使用固定v48入口和`XJ_RETENTION_V48_INPUTS`指定的测试输入清单，在副本中验证成功保存后的独立清理、清理事务中断、已提交端点不回滚、旧手动/升级/跨世界引用保护及空间复用。原始输入只读核对SHA256；不得传入个人库。68项初次源码证据见`logs/v18-source-headless-174b99f8-7ec2-4017-a2f3-edbb09a860a7.json`，追加跨世界断言已在最终实际包74项通过。

自然成长：`verify_combat_v18.py --only natural-growth`通过固定v45入口，从正常新世界完成五段教学和三类普通合同，再用实际收入购船、配装及招募。headless按固定渲染步长重放，模拟频率和玩法数值不变；没有资金、资产、资格、任务事件、姿态或时钟夹具，结果不代表人工乐趣。`natural-checkpoint`只加载SHA256匹配的已关闭回放库，比较全部108组/RNG在Main表现回调之前的读取边界；原始失败报告和通过的补验必须分开引用。`natural-recovery`从有组合来源凭据的正常世界副本验证真实NPC损失、救援、治疗和付费替代舰；源码24项通过，实际包待验。详见[67](../doc/67-自然成长经济与失败恢复验证.md)。

缓存对照：`prepare_cache_reference_v47.py`从固定已提交源码生成两份带SHA256的测试参考，分别通过`XJ_MARKET_CACHE_V47_REFERENCE`及`XJ_MARKET_CACHE_V47_SPAWN_REFERENCE`传入`--only market-cache`。40项完整108组对照覆盖数学顺序、临界补货、目录替换和NPC生命周期；ID时钟是明示夹具。性能定位的临时源码插桩须核对摘要并在finally恢复，不将它混入发行源码。结果汇总`logs/v47-source-checkpoint.json`。

早期旧档链：`prepare_legacy_chain_index_v44.py --early`校验format9–15的保留摘要与原SQL字段/主键；11–15另有实际旧PCK创建凭据，9/10仅有保留清单和历史输入登记，不扩大其来源结论。`legacy-early`复用固定v44入口；`legacy-boundary`用于从固定历史提交重建实际旧包得到的format6/8，准备和验收结果另行记录。引擎操作一律持有主工作区共享锁并串行。

S32/S33开发检查点：`build_owned_fleet.py`从封存v0.30目录编写新增SQL，`build_catalog.py --output jiaoben/tmp/fleet-candidate.db`执行闭合校验，`store_generate_fleet.py`只生成028/固定v0.23适配器和九组新状态（共108组），保护旧历史SQL。`verify_combat_v18.py --only owned-fleet owned-fleet-travel`使用fresh UUID库检查船员/部署业务和旅行事务；`--native --only owned-fleet-world`检查真实Main/GUI、故障连接活动世界绑定、物理跟随、AU取消/抵达及三种布局。实际包沿用固定`--xj-verify-owned-fleet[-travel|-world]-v40`入口，尚未执行包验收，禁止通用EXE `--script`。

旅行103项、原生75项/5图的接线检查点见`logs/v40-travel-ui-checkpoint.json`，规格和证据边界见[66](../doc/66-自有舰队船员与辅助无人机.md)。资金、舰体、许可、姿态和遭遇隔离为声明夹具；故障须实际命中一次，不能仅凭资金未改变声称SQL回滚。独立工作树执行时额外持有主工作区`E:\星际战舰\jiaoben\tmp\feature-audit.lock`，引擎导入/检查/原生运行保持串行。剩余联合边界、真实旧PCK升级及最终发行仍待完成，不正常启动开发源码处理个人档。

辅助机源码使用`verify_combat_v18.py --native --only auxiliary-world`，固定入口`--xj-verify-auxiliary-world-v41`、fresh `auxiliary-world-v41`目录；禁止默认初始化或通用导出EXE `--script`。最终84项/6图通过，覆盖真实修复/探测/遮挡/弹丸拦截/通信返航/补充及108组和RNG重开，证据`logs/v41-auxiliary-checkpoint.json`。损伤、初始资产、目标/母舰边界姿态、遮挡体、弹丸伤害与TTL时钟为明确夹具；不将其记为自然流程。旧回调须通过弱引用安全返回，机库展示的渲染帧相机使用正确插值并更新资源摘要，不忽略引擎警告。母舰损毁/超时、自有母舰联合和实际包仍待验，规格见66。

向实际EXE执行`owned-fleet*`或`auxiliary-world`前，工具只读检查文件版本并拒绝低于0.31.0的客户端。已验证正式0.30.0.0在启动前被拒绝。旧包升级夹具须选择其已经存在的固定诊断入口，不能把新版参数交给旧EXE尝试。

编队关联批次：`prepare_fleet_upgrade_v42.py --legacy-executable <已核v0.30正式EXE>`只用旧包原有fitting入口产出关闭的format24夹具；不传通用`--script`，不读取用户库。将输出的database及JSON路径分别设为`XJ_FLEET_LEGACY_DATABASE`、`XJ_FLEET_LEGACY_PROVENANCE`，运行`verify_combat_v18.py --only fleet-integration fleet-upgrade`。源码45/23项、原场景86项与辅助机原生85项合计239项/6图通过，汇总`logs/v42-integration-checkpoint.json`。升级严格比较原99组与RNG，只允许四种新增辅助产品的商店行；工程报价桩与贡献/工资边界不当作物理或自然流程。新两个入口也受启动前客户端版本检查保护。下一批范围见66。

实际战斗/母舰边界：`verify_combat_v18.py --native --only owned-combat-world auxiliary-boundaries`，对应两个固定v43入口及fresh目录。自有母舰从原舰支付资源，原有高危NPC数值不变；交战、命中、回收和原舰损失真实模拟。无关遭遇须使用各自数据库再生计时隔离，不只将alive置false。母舰致命伤、在外期限、返航末0.1秒为明示边界。暂停计时通过实际pause页面核验并在恢复后继续，不能把未恢复误报为返航失败。最新四组289项/13图证据`logs/v43-combat-boundaries-checkpoint.json`，含同型舰旅行和管理/AU回归；混合报告仅逐组接受通过项，失败日志保留。

完整回归与旧档链：`py -m unittest discover -s jiaoben/tests`当前363项通过；`build_fleet_assets.py`生成两种静态图标与八个正式模块/配方映射。`prepare_legacy_chain_index_v44.py`校验保留的实际旧PCK测试库和来源摘要，输出`XJ_LEGACY_CHAIN_INDEX`所用索引；`verify_combat_v18.py --only legacy-chain`通过固定v44入口验证七个历史格式16/17/18/19/20/21/23，107项通过。汇总`logs/v44-regression-checkpoint.json`。更早旧档、新档自然成长和最终EXE/PCK仍待验证；禁止使用个人库补充测试样本。

## 临时产物保留与清理

2026-10-15 v0.36清理已完成：用户明确要求重试后，重新核对客户端/ZIP/存档/运行锁及路径，实际删除217目标/4149文件/5.626 GiB，E盘实增5.633 GiB。tmp/logs仅`.gitkeep`，Godot/Python缓存、临时库/截图/日志/候选包与旧0.35已移除，code/dist仅留`0.37.0-819b5e3e-20261015-191038`。正式客户端与必要原始失败/源码/历史/字体证据保留，最终667绑定通过；个人128文件内容/大小/修改时间、源码/配置/资源/桥接库一致。当前记录见该正式目录`cleanup-verification.json`、`verification/cleanup/plan.json`和`deletion.json`；`verification/cleanup-blocked.json`仅是前次未执行的历史。没有再次启动引擎。下文旧原始路径不保证存在，按保留映射查记录，重放须新建独立测试输入。


2026-10-15 v0.35交付后的清理已完成：删除378目标/8672文件/6.902 GiB，E盘可用空间实增6.918 GiB。tmp/logs仅留`.gitkeep`，Godot/Python缓存、一次性脚本和旧v0.34客户端已删除；正式目录仅保留`0.35.0-bcb330c2-20261015-064648`。当前正式263图及必要源码/字体/图标/已知失败记录保留，映射见[记录索引](../code/dist/0.35.0-bcb330c2-20261015-064648/verification/retained-records.json)。源码、正式资源、维护脚本与个人数据128文件校验一致，完整证据见[清理验证](../code/dist/0.35.0-bcb330c2-20261015-064648/cleanup-verification.json)；下列旧临时路径属于历史记录，运行时须重新生成输入。

2026-10-14 v0.34交付后的清理已完成：用户要求重试后，经当前授权通道删除167目标/2816文件/4.319 GiB，实测E盘可用空间增加4.325 GiB。tmp/logs仅留`.gitkeep`，Godot/Python缓存及0.33.0/0.33.1旧包已移除，只保留最新v0.34.0。最终263图、必要源码与历史验收记录留在最新正式包，源码/正式资源/母版/维护脚本/升级桥接库保留，个人数据目录128文件摘要和修改时间一致；不再启动引擎重建缓存。首次删除曾被策略拒绝的历史仍保留在[交付记录](../doc/26-开发阶段与交付记录.md)，当前完成状态见[清理验证](../code/dist/0.34.0-803aa04b-20261014-211910/cleanup-verification.json)。

每个联合开发阶段验收后清理重复候选包、过期UUID运行库/迁移副本、旧截图、下载缓存、一次性修改脚本及Python缓存。`tests/`、`art/`、`probes/`和构建/迁移生成器是维护中的源码，不能因为用于开发就作为垃圾删除。删除前核对Git忽略状态、实际引用和运行锁；只能操作已确认的工作区临时路径。

用户已要求阶段验收后只保留代码、文档及最新一个正式客户端；测试源码与维护中的生成器保留，生成的临时数据库、截图、日志、候选包、旧包与缓存清理。交付摘要与原始验证身份保存在文档和最终构建manifest；历史原始路径不保证存在，后续重放应重新生成所需临时输入。`code/data/catalog_*_v*.db`是运行时旧存档升级桥接库，导航/跃迁数据库也有正式消费者，不能按文件名或版本号清除。

2026-10-14的v0.33交付后清理已完成：删除3470个生成/中间文件，逻辑大小4.926 GiB；tmp/logs仅留`.gitkeep`，Godot/Python缓存已移除，正式包仅留`0.33.0-d64e8897-20261014-174717`。最新正式包内的聚合验收及`cleanup-verification.json`保留，源码/母版/维护脚本/升级数据库和个人存档校验一致；不要将下文历史临时路径视为仍然存在的输入。

2026-10-12清理6432个忽略文件、31826797209字节（约29.6 GiB）；当前tmp约708 MiB。完整盘点、删除清单和保留文件SHA256核对在`logs/cleanup-20261012-{inventory,plan,deletion,verification}.json`，摘要见[交付记录](../doc/26-开发阶段与交付记录.md)。本次未改游戏逻辑，不重复运行游戏验收。

S24/S27/S28联合批次：`verify_combat_v18.py --only scenarios`检查三类挑战、货物/封锁/结果及99组恢复；`--native --only scenarios-world`使用真实Main、焦点/指针、物理武器、护航与移动远修、HUD和JSON3导出，实际包加`--executable`。`prepare_scenarios_upgrade_v39.py --legacy-executable <已验证v0.29 EXE>`仅经旧包固定fitting入口创建关闭的format23测试库；传`XJ_SCENARIOS_LEGACY_DATABASE`运行`--only scenarios-upgrade`，核027/内容分支失败回滚、原87组和旧手动档。全部使用fresh UUID和共用审计锁；不得用通用`--script`启动导出EXE。SQL及旧定义字节保护在`tests/test_scenarios.py`，当前边界见[65](../doc/65-配装挑战航路封锁与行为记录.md)。

同批`--only measurements`直接验证采购、制造领取、矿点采集、组件回收、仓储不重复、任务耗时/弃约、僚舰预算、环境致命伤害/救援；`--native --only blockades-world`实际飞行两条完整路线，使用付费调查或真实交战拆除，检查120吨货物/完整及部分送达。两路线共用900秒看门狗与960秒外层有界等待，不能提高船速、减轻质量、降低敌方耐久或把玩家移动至各节点来代替物理证据。发行包门槛核实际路程/送达数量和必要截图。

远征建设与实耗指标批次：025追加远征/建设/报告，026追加实际材料/维修四组，共format23/87组；历史001–025不重生成。`campaign-extension`运行完整三段路线、新两矿带的六个真实AU位置，以及实际扣料、返料、维修和报告裁剪；`campaign-world`使用独立临时库验证真实UI、战术、导出和失效回调。关联功能合并后统一检查，规则和接受证据见[64](../doc/64-远征建设与主题行动.md)。

状态反馈/情报批次：`store_generate_situational.py`仅生成024/v0.20适配器，两组观测追加至format21；旧001–023、适配器及145表/四视图保持。S20/S21功能合并完成后再统一专项、适用回归与实际包验收；开发中仅做必要编译/故障定位。规则见[63](../doc/63-状态反馈与航行情报.md)。

雇佣支援v0.27.0已验收：`build_hire.py`追加2表及严格`hire_`前缀的NPC/锚点；`store_generate_hire.py`仅生成023/v0.19并保护完整旧守卫。`test_hire.py`验证原143表/四视图、历史SQL原字节、回滚和费用/演员负例；`verify_combat_v18.py --only hire`覆盖合同与真实旧v0.26升级，原生`hire-world hire-travel-world`覆盖物理协同、AU/跨门费用容量与失败恢复、高缩放。实际EXE/PCK29组6320项/179图、正式目录另6项及14文件一致性通过，汇总`logs/v35-delivery-verification.json`，规则/夹具边界见[62](../doc/62-雇佣支援与舰队指令.md)。后续按多个关联目标合并开发后统一适用验收，开发中仅做必要编译与故障定位。

边疆阶段：`build_frontier.py`只追加五表及有明确前缀的NPC/锚点；`store_generate_frontier.py`仅生成022/v0.18，复制旧守卫并只放开有完整新历史的主权关联与有严格友方归属的补给舰/信标远修。`verify_combat_v18.py --only frontier`验证实际阶段支付、双目标、重建、主权循环、报价和68组恢复；资格/到达/长策略时间明确作为夹具。`prepare_roles_upgrade_v32.py --frontier --legacy-executable <已核验v0.25 EXE>`通过旧包固定fitting入口生成历史占领与活动战争、订单/研究/在途货物format18档；`XJ_FRONTIER_LEGACY_DATABASE`启用真实升级与失败回滚。原生`frontier-world`、`frontier-demolition-world`、`frontier-governance-world`验证真实物理护送/受击/远修、两类战斗与重建、支付/运输/防守/精确缩放；失守及回收的边界另有Core与SQL检查。规则和未完成验收见[61](../doc/61-边疆战争与重建争夺.md)。

文明指挥考核：`build_honors.py`、`store_generate_honors.py`仅追加3张定义表、021与v0.17适配器；旧135表/视图和001–020保持。`verify_combat_v18.py --only honors`检查真实四类结算、三文明资格与61组恢复；`prepare_roles_upgrade_v32.py --honors --legacy-executable <已核验v0.24 EXE>`从旧包固定fitting入口生成带付费在途货物及活动战争的真实format17夹具，通过`XJ_HONORS_LEGACY_DATABASE`验证升级与失败回滚。`--native --only honors-world`验证真实登记、来源选择/星图、认证、战争受领、旧回调以及3440×1188/100%和1280×720/200%的精确逻辑尺寸。SQL拒绝见`tests/test_honors.py`，规则见[60](../doc/60-文明贡献与指挥资格.md)。

舰种/承运：`build_roles.py`追加3张定义表，旧132表/四视图不变；`store_generate_roles.py`仅生成020与v0.16适配器，复制完整旧封存守卫并只允许有完整持久记录的远修周期。`verify_combat_v18.py --only roles`检查真实调查、十八舰权限、付费恢复、中断、货损/退款/超时与59组恢复。`prepare_roles_upgrade_v32.py --legacy-executable <实际v0.23 EXE>`经旧包固定fitting测试入口的显式夹具分支，生成真实订单/取消/部分研究/机库format16档；传`XJ_ROLES_LEGACY_DATABASE`验证故障回滚及56组原状态。`--native --only roles-world`检查真实按钮、物理治疗、同225000基础造价上限战斗对照、9km感知、24批满载四门航程/交付及精确640×360逻辑界面。`XJ_ROLES_TRIP_ONLY=1`仅用于临时排障，正式门槛拒绝该子集。SQL负例见`tests/test_roles.py`，规则与边界见[59](../doc/59-舰种能力与有限承运.md)。

配装/火控/HUD：`build_fitting.py`和`store_generate_fitting.py`只追加新SQL与019/v0.15，`build_fitting_assets.py`生成3个原创静态SVG及映射。`verify_combat_v18.py --only fitting`验证真实预算对照、只读比较、部分投入/替代来源、56组恢复；`prepare_fitting_upgrade_v31.py --legacy-executable <实际v0.22 EXE>`生成已关闭的format15付费订单夹具，通过`XJ_FITTING_LEGACY_DATABASE`验证53组旧状态和失败回滚。`--native --only fitting-world`验证实际鼠标/键盘比较、替换和超原射程命中，以及三窗口/缩放HUD和雷达切换，共用审计锁与fresh UUID。真实包使用`--executable`。SQL负例与旧表保护见`tests/test_fitting.py`，旧阶段测试只排除显式受审的新ID，不能放宽历史行或视图一致性。见[57](../doc/57-配装比较与火控专精.md)、[58](../doc/58-太空界面与简洁配装分析.md)。

拆除与突破：`build_operations.py`追加两种目标和物理装置；`store_generate_operations.py`只生成018/v0.14，不改历史迁移。`verify_combat_v18.py --only operations`检查业务、货物、成果、53组恢复，`prepare_operations_upgrade_v30.py --legacy-executable <实际v0.21 EXE>`创建带付费订单和无人机舱的format14旧库，传`XJ_OPERATIONS_LEGACY_DATABASE`检查升级/失败回滚/52组原状态。`--native --only operations-world`检查真实入口、鼠标/Ctrl/Shift、实际伤害及5.2公里突破；资格/资产/初始姿态、近毁装置和隔离/恢复场景均为明确夹具。两入口支持实际`--executable`并共用审计锁/fresh UUID/严格双日志。定义/SQL封存负例见`tests/test_operations.py`，当前证据和边界见[56](../doc/56-拆除与封锁突破.md)。

v0.21.0战术与无人机：`build_tactics.py`追加独立三战术地点/四种能力及真实补充成本，`store_generate_tactics.py`仅生成017与v0.13适配器，旧文件不可重写。`--only tactics`验证真实能力预算、维修/干扰免疫衰减/原位置齐射/命中打断、双方机库数量与损失、三指令、真实付费补充及52组保存恢复。`prepare_tactics_upgrade_v29.py --legacy-executable <实际v0.20 EXE>`创建带三份付费订单和已装无人机舱的format13库，传`XJ_TACTICS_LEGACY_DATABASE`验证017/内容分支失败、48组旧状态/资产/工期/RNG、原手动档和升级后损失持久化。`--only tactics-world --native`使用实际Main、窗口鼠标及键盘输入验证角色动作、火力命中/规避/掩体、物理无人机与双向损失、通信、站点补充和高缩放；所有角色隔离、配装物资、初始/边界姿态须标为夹具，不代表自然成长或战斗乐趣。两入口支持`--executable`且共用审计锁/fresh UUID/严格双日志。见[55](../doc/55-战术敌人与无人机管理.md)。

v0.20.0迁移矿带：`build_mobile_belts.py`追加真实AU地点与三阶段散逸，`store_generate_mobile_belts.py`仅生成016与v0.12适配器；旧001–015和旧适配器不可重写。`--only mobile-belts`执行两事件×三路线、实际付费采集/衰减/原矿与证据保留、48组状态相等重开；`prepare_mobile_belts_upgrade_v28.py --legacy-executable <实际v0.19 EXE>`生成已采出原矿的format12活动矿带，传`XJ_MOBILE_BELTS_LEGACY_DATABASE`验证016/内容分支失败、原47组状态/余量/窗口/RNG保留、剩余窗口宽限、旧手动档及幂等。`--only mobile-belts-world --native`使用真实Main、F与鼠标完成三处矿带、实际AU跃迁/接近/采集/预警/散逸/结算、目标中途迁移安全中止及高缩放。两入口支持`--executable`，共用审计锁、fresh UUID及严格双日志；资格、返回姿态和近阶段时刻为明确夹具。见[54](../doc/54-迁移矿带与分段衰减.md)。

v0.19.0探索：`build_exploration_content.py`生成独立探索SQL，`store_generate_exploration.py`只生成015与v0.11适配器，旧迁移与旧适配器不可重写。`verify_combat_v18.py --only exploration`运行18种变体、付费操作恢复、临时矿量、成果/研究/需求和SQLite约束；`prepare_exploration_upgrade_v27.py --legacy-executable <实际v0.18.0 EXE>`创建含三份付费订单的format11独立夹具，将其路径传`XJ_EXPLORATION_LEGACY_DATABASE`验证015/内容升级失败回滚、旧状态与RNG保留、旧手动档及幂等。`--only exploration-world --native`验证真实F/鼠标、运输舰移动与敌方弹丸、碎片射线遮挡、电磁扫描/护盾与稳定、临时矿体实际采集/消失、恒星热伤害和窄屏。两入口支持`--executable`验证真实PCK，独占共用锁，fresh UUID和严格双日志；资格/物资/姿态/近超时状态均是声明的专项夹具，不代表自然成长。详见[53](../doc/53-多阶段探索与环境风险.md)。

v0.18.0来源情报：`store_generate_resource_intel.py`仅生成014与v0.10适配器，固定两张新定义，旧文件不可重写。`verify_combat_v18.py --only resource-intel`验证真实来源、品位采集与存档；传`XJ_RESOURCE_INTEL_LEGACY_DATABASE`时复制已关闭tmp旧库。可用实际v0.17.0 EXE固定工业诊断配合`XJ_INDUSTRY_FIXTURE_ONLY=1`生成带运行/排队订单的format10夹具，保存后立即退出，不继续执行新版检查。`--only resource-intel-world --native`覆盖真实窗口搜索、星图、过期回调、缩放及实际跨门再抵达来源；两者支持`--executable`验证真实PCK，使用fresh UUID与严格双日志。见[52](../doc/52-物资来源与矿点情报.md)。

v0.17.0单机工业：`build_catalog.py`合并独立`industry_schema/seed.sql`，`store_generate_industry.py`仅生成新013迁移与v0.9固定适配器；已发布001–012和旧适配器不可改写。`verify_combat_v18.py --only industry`运行材料托管、队列/领取/取消、需求、保存和升级故障；传`XJ_INDUSTRY_LEGACY_DATABASE`时只复制已关闭的tmp旧库，真实v0.16.0库可由其实际EXE的`--xj-verify-store`创建。`--only industry-world --native`使用真实窗口输入与Main推进，覆盖过期界面、非法数量与三种尺寸；`--only row-quantity --native`保留仓储/经济矩阵，增加真实制造队列与成品领取。三者均支持`--executable <实际EXE>`而不挂源码路径，使用fresh UUID库、独立输出/引擎日志、严格退出/诊断和图摘要。所有测试数据在tmp/logs，不读取个人存档。单机完整目标和阶段边界见[51](../doc/51-单机完善实施与验收矩阵.md)。

v0.16.0文明扩展：`build_civilization_content.py`从旧正式SQL生成独立文明扩展，`build_catalog.py`校验105表并构建只读目录，`store_generate_civilizations.py`追加012格式9迁移和v0.8冻结适配器，旧SQL不重写。`art/build_civilization_assets.py`生成新舰外观、碰撞包装、星系根与独立清单，`art/bake_civilization_portraits.gd`用真实Godot模型渲染缩略图。

`verify_combat_v18.py --only civilizations`检查真实入籍、捐献、爵位、专属采购/制造/研究、切换保留资产、战役状态与SQLite重开。`--only civilization-world --native`用真实Main/GUI/Renderer验证星图筛选、文明界面、原生捐献、专属模型、友军识别、实际舰队开火与伤害及占领；资格和装配物资为明确测试前提，战斗不跳过真实模拟。`prepare_civilization_upgrade_v24.py --legacy-executable <旧客户端EXE>`创建真实format8旧档夹具，`--only civilization-upgrade --legacy <其progress.db>`验证备份、迁移/内容分支失败回滚、资产与RNG保留、旧手动档及升级幂等。所有游戏检查串行持有同一审计锁，fresh UUID tmp，个人档不参与；必须退出0且完整结果及双日志无错误/警告/泄漏，实际包追加`--executable <EXE>`复验。

v0.15.3空间站图标菜单专项：`verify_combat_v18.py --only service-navigation --native` 执行 `tests/service_navigation_v22.gd`，检查机库/侧栏/下拉/标题同名同序同图标、六种尺寸与缩放、真实GUI点击和Tab、观察舰船、独立出港、飞行停靠权限，以及状态/保存端点/偏好无隐藏修改。另核“服务导航”标题去重、初始工业页焦点、Tab与悬停不产生第二选中、Enter回机库。实际包使用 `--executable <Windows EXE>`，通过固定 `--xj-verify-service-navigation-v22` 入口加载相同Node，保留真实PCK资源。fresh UUID库和图在tmp，严格双日志与摘要在logs；必须退出0、断言完整、11张原生图且无引擎错误/警告/泄漏。`build_service_navigation.py` 生成独立展示资源清单，保留全部旧发布清单。详见[48](../doc/48-空间站图标菜单与名称统一.md)。

v0.14.1任务按钮与显示专项：`verify_combat_v18.py --only mission-display`执行`tests/mission_display_v19.gd`，加`--native`验证真实窗口的五种尺寸/100%与200%缩放、最大化/独占全屏、caption完整宽度、任务所有筛选/分页/滚动访问、长中文/多操作/tooltip、真实接取/放弃/重接和SQLite重开。`--executable <Windows EXE>`使用固定`--xj-verify-mission-display-v19`入口在真实PCK内运行同一Node；临时库与图位于fresh UUID的mission-display-v19子目录。基线`XJ_MISSION_DISPLAY_V19_BASELINE=1`只输出REPRODUCED，不可记录为正常验收PASS。输出窗口observations记录实际native/逻辑尺寸及等比final transform四边，截图尺寸必须对应整个客户区并核左右/上下覆盖。个人存档不参与。

v0.14.0光影/武器/无人机专项：`verify_combat_v18.py`在Windows串行加载四个固定测试Node，源码薄SceneTree启动器和实际PCK使用相同断言。`--native --only combat lighting weapon-ui`验证真实Vulkan/WASAPI画面与业务；`--only upgrade --legacy <已关闭的本项目tmp旧测试库>`验证format6→7、内容分支、回滚、旧档/投入/品质兼容。使用`--executable <实际Windows EXE>`时不传源码工程路径，仅由显式受限`--xj-verify-*-v18`入口读固定外部测试Node。测试库与截图为fresh UUID的tmp子目录，输出/引擎日志和脚本/图片摘要在logs；执行时持有共用feature-audit锁，不与其他引擎检查或导入并行。必须满足退出0、完整结果及双日志诊断0，不能仅看断言PASS或PNG存在。光影专项另核实际舰体/特效像素显隐和姿态亮度差；测试位置、资产/解锁授予不是自然通关或性能基准。

`tests/input_startup.gd`直接调用真实Main的初始化前输入回调，覆盖四类未注册事件、正常Ctrl释放、Ctrl按下及无关键释放；不启动服务或打开个人存档。执行`sh jiaoben/run_godot.sh --headless --path code --script ../jiaoben/tests/input_startup.gd`时，须同时满足`INPUT_STARTUP_RESULT PASS checks=10 failures=0`、退出0及输出/独立引擎日志无错误、警告或泄漏。旧源码会输出PASS但仍产生四条缺失fire动作错误，不能只看断言摘要。

`tests/row_quantity_v17_run.py`验证仓储单行、小按钮与远站只读，市场/工业独立行数量、12次GUI买卖/制造/拆解、五种非法数量拒绝、七种过期上下文、四布局和SQLite重开；加`--native`独占Metal/CoreAudio窗口，fresh UUID库/图在tmp，双日志与结构化结果在logs。实际包通过受限`--xj-verify-row-quantities`入口加载同一外部测试Node，res://保持实际PCK；构建清单记录测试源码、双日志与图的SHA256。详见[44](../doc/44-单行业务列表与行内数量.md)。

`tests/warehouse_transfer_v16_run.py`验证真实双列表与独立行数量、8 GUI搬运、矿舱/设备/密封包、远站排序灰色只读、容量/权限/过期回调、四布局及SQLite重开；加`--native`独占Metal/CoreAudio窗口，fresh UUID数据/图在tmp，严格双日志在logs。实际包通过固定外部Node入口`--xj-verify-warehouse`复验，production资源保持PCK；v0.12.0固定表现门槛104项/16图，含release-warehouse-dual，当前门槛见下。详见[43](../doc/43-双列表仓储与行内搬运.md)。

`tests/combat_automation_v15_run.py`验证真实八组合checkbox、正式双武器周期/支付与资格、近敌锁定/死亡换锁、范围接近和朝敌环绕、手动/X/Z/保存/跃迁边界、四布局真实飞行渲染/tooltip、SQL重开及25步大舰范围边缘。追加`--native`独占Metal/CoreAudio窗口，使用共用锁；UUID临时库/截图在tmp，严格双日志和结构结果在logs，scope/revision/global Z/飞行截图字段必须完整。新实际包通过受限显式`--xj-verify-combat-automation`加载同一固定外部测试Node，res://仍为包内PCK；构建脚本将测试源码/日志/图摘要纳入包清单。详见[42](../doc/42-战斗自动化与索敌环绕.md)。

`tests/turn_response_v14.gd`验证九舰真实转速与输入优先级；`tests/manual_turn_v14_run.py`检查真实Main的九舰/装备/合法载荷216组合及UI隔离；`tests/camera_collision_v14_run.py`检查正式站/门264数值情境、6组真实插值帧采样、九舰FRONT贴面与SQLite重开。两runner用共用独占锁，`--native`独占Metal/CoreAudio窗口；库/图在tmp，严格双日志/结构结果在logs。旧Main复现用`--baseline-only --expect-defect`，旧Rig用`--baseline`，只在确认旧源码并完整恢复新源码时运行；缺陷复现不作验收PASS。结果与证据边界见[41](../doc/41-手动转向与近障碍相机修正.md)。

## 星图重塑

v0.15.1正常跃迁专项为`py jiaoben/verify_combat_v18.py --only warp-scene --native`；actual-PCK加`--executable <EXE>`且不传source project path。正式站/门/矿出发、自然星空与行星、精确舰体轮廓、实际字形不透明内部像素、用户2859×945超宽与3440×1370在100%/200%及三视角受控；测试不加入checker环境。`test_warp_presentation.py`固定旧发布Git字节核旧DB/SQL/manifest不变、新FXv3闭合。基线模式EXPECTED_DEFECT不作为发布PASS，按[47](../doc/47-跃迁离场与真实背景虚化修正.md)记录边界。

v0.15.0空间专项从根目录运行`py jiaoben/verify_combat_v18.py --only mission-display spatial-business spatial-navigation warp-visual space-upgrade`，原生加`--native`；actual-PCK加`--executable <Windows EXE>`且不传源码path。源码/实际包共享固定Node，WASAPI、独占共用锁、fresh UUID tmp库和严格双日志。空间升级fixture由`tests/prepare_space_upgrade_v20.py`固定旧Git catalog身份，通过query_only原生SQLite复制到受审内存adapter，同一路径用于源码和PCK；测试不打开个人档。`py -m unittest discover -s jiaoben/tests -p 'test_*.py'`含空间catalog及SQL完整绑定/不可变约束。规格与最终结果见[46](../doc/46-星系尺度与跃迁体验.md)和[26](../doc/26-开发阶段与交付记录.md)。

同一runner的`--only base-store base-presentation --native`执行6项实际数据库与110项/17图内置表现门槛；源码直接运行固定Main CLI入口，实际EXE无需源码工程。store门槛强制headless/WASAPI且无截图，presentation真实原生窗口。所有进程均检查退出、完整结果及输出/引擎双日志；上一结果的截图文件存在不能代替新包验收。

从根目录执行 `/usr/local/bin/python3.14 jiaoben/tests/star_chart_v13_run.py`，追加`--native`独占Metal/CoreAudio窗口。fresh tmp SQLite验证真实Main的单选情报、方向/门资格/载重变化、输入隔离、关闭重开/换世界/实际旅行绑定、四布局及120/300个纯UI节点；日志和结构化结果在logs，截图和DB在tmp。共用`feature-audit.lock`，不得与其它Godot检查/编辑器导入并行。原生Viewport事件与额外系统输入复查分别记录，最终结果见40。

当前发行包内置表现门槛为110项/17图（保留104项，增加2项仓储单行/小按钮和4项市场/工业独立数量/报价/状态不变检查，并增加release-business-industry图），`build_client.py`必须用实际bundle/PCK独立运行；未通过不得发布。历史小节的旧检查数属于对应版本。

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

操控v0.10.1最终源码：组件699，真实Main headless/原生各2,032；相机headless1,493、原生1,498/4图；8相关回归2,084、Python129、字体899，源码固定表现100均通过。实际干净源`b6399ee6`导出的`0.10.1-b6399ee6-20261004-185156`独立6+100+460/30图、248资源/8包、签名和10份严格日志通过；Windows原生待实机。详细fixture/帧率/恢复范围见41，交付身份见26。

v0.11.0最终战斗自动化source headless574、Metal/CoreAudio605/5真实飞行图，9回归4217、Python129、字体901与原100表现通过；实际干净源`fc87c476`包`0.11.0-fc87c476-20261004-202947`独立6+100+460+605/35图、248资源/8包、签名与12严格日志通过，Windows原生待实机。见42/26。

v0.12.0最终source仓储813headless、827Metal/CoreAudio/6图，6相关1498+旧business389、Python129、字体906、固定104表现均通过；实际干净源`266ab3f0`包`0.12.0-266ab3f0-20261004-225644`独立6+104+462+605+827/42图、248资源/8包、签名、14严格日志通过。初候选和旧依赖warehouse鉴定入口的测试不作新包证据，最终Node支持独立salvage入口。详见43/26，Windows原生待实机。


v0.13.0实际交付`0.13.0-afdc5e1d-20261005-002457`来自干净已推送源`afdc5e1d`：实际Mac独立6+110+462+605+827+5,351项、49图通过，严格16份构建日志诊断0；资源248/8包、签名及ZIP/PNG/源码/日志摘要复核通过。最新独立汇总为`logs/row-v17-delivery-final.json`，完整源回归见44，实际包身份、链接及Windows原生边界见26。无SQL/数值或个人档案变更。

诊断独立变更时，`compare_pck_components_v36.py --before <旧候选EXE> --after <新候选EXE>`独占审计锁，以各自实际EXE运行`tests/pck_manifest_v36.gd`，只通过固定`--xj-verify-situational-v36`隔离入口及显式`XJ_PCK_MANIFEST_ONLY=1`读取包内资源，生成UUID清单；仅允许表现诊断及其编译/重定向文件不同，其他全部虚拟文件和EXE/DLL必须一致。该证明不替代变化组件的实际检查，不允许以源码摘要代替包内字节。

导出客户端不能使用通用`--script`来代替受审诊断入口；本机已观察到参数被忽略并进入默认初始化。包清单必须通过上述固定入口，临时目录/脚本路径检查保持；不启动默认进度库。v0.28最终覆盖及误初始化后的恢复记录见[63](../doc/63-状态反馈与航行情报.md)，最终汇总`logs/v36-delivery-verification.json`。

远征建设合批：`build_campaign_theme.py`仅从v0.28归档追加受审主题命名空间；`store_generate_campaign.py`只生成025/v0.21，保留原015/016账本完整守卫并追加已验证协调来源。`--only campaign`验证联合业务，`--only campaign-upgrade`通过`XJ_CAMPAIGN_LEGACY_DATABASE`仅测实际旧包升级，`--native --only campaign-world`通过`XJ_CAMPAIGN_CORE_DATABASE`导入已关闭test-owned联合库。资金、资格、姿态和命名变体均需声明。`prepare_roles_upgrade_v32.py --campaign --legacy-executable <已核v0.28 EXE>`经旧包固定fitting入口创建旧21/72组数据；不得使用通用`--script`或用户档。当前源码证据及尚未验证范围见[64](../doc/64-远征建设与主题行动.md)，本批实际发行仍待后续统一验收。

无画面正常流程可使用`--replay-fps 20`或`30`减少表现层调用；默认仍为60。只改变渲染/脚本观察频率，项目60Hz物理逐步执行，不改航速、工作耗时、经济或时钟状态。报告记录实际参数；新救援续段另核物理频率。原生画面检查不使用该加速选项。

运输成长续段`--only natural-logistics`使用`XJ_NATURAL_RESCUE_ORIGIN`绑定正常救援关闭档，计划经普通合同收入、船坞制造、旧设备转装和六批实体承运完成物流考核；当前仅已编写，尚未运行。保留实际支出、工期、通行和货损规则。

指挥成长续段`--only natural-command`使用`XJ_NATURAL_LOGISTICS_ORIGIN`绑定已通过物流档，计划经付费配装、真实雇佣后勤、物理拆除/撤离、四项资格认证及普通补给采购达成战争受领条件；脚本刚编写，尚未运行，不作为完成证据。

运输首段曾在完成造船和六批交付后触及2400秒外层墙钟限制，原结果保留为INCOMPLETE。`XJ_NATURAL_LOGISTICS_PARTIAL_ORIGIN`仅接受`v54-logistics-partial-*.json`绑定的关闭测试自动档，校验原日志/数据库摘要及实际造船、交付证据，续验返程和结算；不注入状态，不把旧超时改为整组通过。运输与指挥长流程的外层限时为3600秒，游戏内任务时限不变。

指挥续段支持`XJ_NATURAL_COMMAND_PARTIAL_ORIGIN`读取`v55-command-partial-*.json`绑定的真实自动档，保留已付配装/租约及已接行动，明确不保留未存盘战斗结果。导航诊断输出交战、编队和追击者状态；撤离通过实际僚舰撤退及`forward`/`boost`输入推进，不修改坐标或清除敌人。

首次战争续段`--only natural-war`使用`XJ_NATURAL_COMMAND_ORIGIN`绑定正常认证档，经实际补给、付费护航、NPC行军、侦察/护送/守点/修复及安全返站验证；脚本尚未运行。运行结束后才允许生成`v56-war-origin`，不以代码存在作为完成证据。

文明舰成长脚本`tests/natural_hull_v57.gd`已准备：公共二级科技→专属设计→实际制造→复用旧设备及购买二级武器，尚未注册为运行入口、也未执行，不能计为通过。必须由已通过首战档生成来源后再接入验证器。

首战正常续段现已32项通过，见`logs/v56-normal-war-checkpoint.json`。文明舰`--only natural-hull`已注册，读取`XJ_NATURAL_WAR_ORIGIN`绑定首战关闭档；当前正在运行，不计为通过。上文“尚未注册”仅记录早期准备状态。

正常长期玩法使用`tests/natural_campaign_v58.gd`，由`natural-expedition`/`natural-project`固定入口模式区分。前者绑定已通过文明舰档，后者绑定已通过三段远征档；二者独立关闭数据库和来源。当前远征正在运行、建设尚未运行；有实际结果后再更新状态。正常驻防预警通过既有远程储备指令响应，并记录真实消耗，不改变危机时钟或所有权。

最终原生建设验收：`--native --only natural-project --executable <v0.32实际EXE>`，`XJ_NATURAL_EXPEDITION_ORIGIN`引用经核对的远征关闭档，须清除中断续段变量。窗口1440×900，通过正常采购、六次材料交付和三个工期取得实际阶段效果；记录三张原生工程图及真实出航帧采样。原生方法不使用固定渲染步长，仍要求60Hz生产物理、完整114组/RNG重开及来源档不变。

2026-10-14最终清理已完成：tmp/logs仅留Git占位文件，工程缓存与Python缓存已清除，只保留v0.32正式客户端；个人旧档备份归入游戏存档目录。清理后运行源码检查前，先按[开发环境](../doc/02-开发环境.md)重新导入工程以生成本机缓存；原始旧包夹具、正常成长存档及截图均已移除，需按相应准备/回放步骤重新生成，不能把历史路径视为现存输入。
