# EVE、第二银河参考与易用性改版

状态：v0.6.1航行视角与淡白虚线补丁已交付，实际Mac Release通过原始资源、签名、六项数据及35项表现固定诊断。v0.6条件交互、导航、字体、工业舰船/空间站与六项源码回归保留原阶段证据。Windows导出通过但原生运行未验收，额外人工操作复查尚未完成。参考游戏的画面或机制不作为本项目已实现功能。

## 官方参考与原创边界

| 来源及实际调查 | 可用的参考 | 本项目转化 |
| --- | --- | --- |
| EVE官方 [Evolution, Not Revolution](https://www.eveonline.com/news/view/evolution-not-revolution)，2026-08-26。项目调查通过浏览器查看官方`21_New_Hud`与`15_On-Grid_View`图；未登录EVE实测。 | 前者展示防御环、电容、模块分组和小雷达；后者可见圆形距离环、点状接触、朝向向量与选中圈。文章强调读性与空间利用。这些是开发中的方案，不能称为现行最终HUD。 | 组织三层舰况、电容与热量；局部态势显示距离圈、接触与选中反馈，并给中央空间观察区留白。当前不承诺自由拖拽HUD或参考图中的全部功能。 |
| 第二银河 [官方Steam商店与截图](https://store.steampowered.com/app/1133730/Second_Galaxy/)，截图标识`ss_9011001033d28ffa93ee4f3eccc0d7c52e97be31`。项目调查已在浏览器实际查看。 | 灰钢高塔舰船位于中央，舰侧双弧状态与速度，右下圆形模块及周边留白。这是该截图的视觉观察，不是操作机制测试。 | 强化舰况弧、模块状态和目标方向的可辨性，同时给原创舰船、机库和远景留出空间；不从截图推断自动驾驶、鼠标手感、联机或装备规则。 |
| EVE官方 [Unboxing the new Camera](https://www.eveonline.com/news/view/unboxing-the-new-camera)，2016-02-09。 | 历史资料说明选中对象可通过多个入口调用同一命令，并介绍战术观察。该来源不是2026客户端键位或当前行为实测。 | 键盘与鼠标入口共用本项目资格检查；F的附近可用对象选择规则是本项目设计，不声称复制EVE默认交互。 |

参考用于构图、信息组织和反馈设计。舰船、机库、人物、SVG、shader与音效由本项目原创制作；没有提取、打包或修改EVE/第二银河资源。正式模型、内容数值和资产清单仍按既有数据库与资源契约管理。调研记录见 [交互体验调查草稿](../jiaoben/logs/EVE交互体验调查草稿.md)，仅含官方只读调查，不能替代实际游戏试玩。

## 交互契约

统一入口先预览资格，再执行同一业务命令，预览不扣费、不改变状态；执行时重新检查。可交互对象为站点、门、残骸、信号和资源；敌舰、教学标记与远景天体不成为F候选。

- F：优先已选且可用的对象，否则选择范围内最近的可用对象。没有可用对象时显示对应阻碍原因，不自动飞行。距离按场景对象的实际位置测量；速度、设备范围、门权限/冷却、费用、电容、载重/额度和作业条件读取当前权威状态。
- 鼠标：选定对象的按钮只请求该对象，失败不会偷偷改成另一站点或门。按钮可用状态与F使用同一资格结果，失败展示玩家能处理的原因。
- 门：已满足资格才进入充能；再次F可取消准备，提交阶段明确拒绝取消。充能预览不提前扣跨区成本；完整origin/destination持久化沿用已有跨区规则，不由本轮交互测试重新证明。
- UI：Alt释放光标后可点击目标、雷达与快捷控件；悬停阻止转舰或射击，但不会吞掉F键。暂停、业务菜单和文本输入仍阻断飞行交互。鼠标按钮与F各有入口，统一资格检查，不能以解除鼠标阻塞为由解除暂停。退出操作状态恢复既有捕获规则；本轮没有新增自动接近或自动攻击。

代码入口为 [XJInteractionContext](../code/runtime/interaction_context.gd) 的`choose`与`inspect`，Main调用统一入口。反馈包含对象、操作、可用状态、原因、实际距离/范围、速度限制与冷却；UI只发意图，不自行计算另一套资格或价格。

## 雷达、连线与天体

只读 [导航定义](../code/database/navigation_v3.sql) 提供500米、2公里、6公里三档和十星系各一处远景天体；运行时从独立SQLite导航库读取，不改玩家存档。普通回波取雷达所选范围与舰船探测上限中的较小值。

雷达以舰首向上、本舰平面为投影基准。敌舰三角、门菱形、设施/资源方框与琥珀天体符号区分类型；明显高低差用回波短线提示。Alt释放光标后点击回波只选择对象，− / +切换范围。回波选择不代表自动导航或攻击。

已选目标显示从舰船投影到目标的连线与名称；离开画面或位于镜头后方时，终点移到屏幕边缘并加方向箭头。普通目标显示实际局部距离。远景天体始终使用“航向参考”文字和雷达外围符号，不把其压缩渲染位置报成真实天文距离。

十处天体是视觉背景与方位参照：无碰撞、无登陆、无采集、无F交互，不纳入普通传感器距离语义。当前远景尺寸与位置是表现定义，不能据此宣称无缝天文尺度、行星模拟或在任何距离都可见；实际显示仍受相机裁剪和渲染规则约束。

远景表面已加入imagegen生成的原创地貌贴图，由本项目行星shader结合只读定义表现地貌与云层；此前原生第三轮截图使用该贴图，不以旧程序白斑占位效果作为完成图。新增暗色星云全景按星区旋转天球，保留大面积暗部，使舰船和浅色HUD可辨。两个生成请求均未使用EVE或其他游戏的输入图，没有复制游戏截图或贴图。

`navigation-v3`当前清单登记导航SQLite、行星shader、地貌PNG与星空全景PNG共4项资源，来源与生成边界见 [资源说明](../code/assets/navigation_v3/README.md) 和 [来源记录](../code/assets/navigation_v3/sources.json)。生成请求强调经度包裹，但不据此宣称严格数学无缝；当前含星空的整机原生67项/5图与实际Mac包资源/固定诊断已通过。地貌、星云和天球旋转都是视觉表现，不新增地表玩法、可到达星云或物理天文尺度。

## 工业舰船与空间站

[空间站v3](../code/assets/station_v3/README.md) 使用原创分段装甲环、开放承重桁架、中央反应堆/服务芯、偏轴炼化与货运/居住模块、维护机械及小面积导向灯。高粗糙钢材、凹槽和小窗提供工业尺度。清单的3项运行资源为GLB、shader和几何元数据；可编辑Blender源不作为运行导入。

适配器只替换旧站的视觉模型，保留原StaticBody、碰撞、交互锚点、实体ID和世界位置。外观仍位于原440×230×440米碰撞盒内；凹入泊位只有视觉负空间，原盒没有可穿越船坞开口，停靠仍是原距离/速度资格下的交互。新的几何元数据描述模型，不另建停靠或命中数值。

[工业舰船v3](../code/assets/ship_v3/README.md) 已生成九类既有舰船与静默遗构敌舰共10个GLB及1个PBR shader。装甲间隔、负空间动力接合、偏轴功能舱、热交换器、筋肋、舱口与小窗形成工业外观，并保留四势力差异。这是既有舰类的视觉改版，不新增一类玩家舰船。

新舰体继续使用旧wrapper的碰撞尺寸、武器/工作/推进挂点和镜头锚点，只替换模型及表面材质；纹理不改变顶点或命中。最终headless与Metal/CoreAudio契约各410项已通过，清单11项运行资源、模型合计673,622三角。Godot导入自动LOD已启用，未手工制作LOD层级；独立预览和整机功能回归仍不保证大规模舰队或低配置帧率。

## 字体、材质与档案工作台

共享随包提供的Noto Sans CJK SC FontFile，禁止系统回退，控件与3D职业标签一致；原始OTF及OFL许可保留。第三版Theme以深色玻璃、细刻度线、切角与焦点括角表达工业科幻，避免大面积不透明金属遮住场景。字体来源、9项资源与许可见 [interface-v3说明](../code/assets/interface_v3/README.md)，实际设计与技能落实见 [29](29-操控与界面重塑方案.md)。

暂停与首页档案改用统一卡片，真实槽位、类型、远征名称和UTC时间从操作按钮中分离；空槽明确显示。保存、读取、继续、保存离开与危险放弃分组，保留五个手动槽、救援条件、等待取消、焦点和过期槽拒绝。高缩放可滚动，不编造等级、进度百分比或游玩时长。

## 已验证与待验证

| 证据 | 结果 | 能证明的范围 |
| --- | --- | --- |
| [最新字形报告](../jiaoben/logs/font-v3-final-coverage.json) | 103个源码文件、84张内容表、816字符；缺字/编码替换字0 | 当前输入集合与官方OTF字形覆盖；此前817是较早集合，不承诺后续新增文字自动通过。 |
| [字体headless](../jiaoben/logs/font-v3-headless.log)、[原生字体](../jiaoben/logs/font-v3-native.log) | 29/29、34/34 PASS，原生5图 | Metal / Forward+独立字体、Theme及人员标签；未见错误、警告或泄漏。不是整机HUD或Windows验收。 |
| [交互headless](../jiaoben/logs/interaction-v3.log)、[原生交互](../jiaoben/logs/interaction-v3-native.log) | 51/51、55/55 PASS，严格进程检查通过 | 键盘/指针阻塞分离、真实OS鼠标悬停目标面板后按F停靠与写入队列排空、暂停阻断、充能取消及条件反馈。headless不冒充OS鼠标检查；未走完整目的地提交。 |
| [导航headless当前结果](../jiaoben/logs/navigation-v3-headless-final.log) | 62/62 PASS | 雷达与定义、投影/离屏、竖直天体外圈、四组尺寸/缩放避让、选中说明避免紧凑布局重复、靠站和暂停隐藏；没有原生画面。 |
| [最终原生导航](../jiaoben/logs/navigation-v3-native-final.log)、[独立引擎日志](../jiaoben/logs/navigation-v3-native-final-engine.log) | 67/67 PASS、5图，严格诊断0 | 实际飞行场景/相机、当前星空/地貌、选中/离屏、四组尺寸/缩放、靠站和暂停隐藏。 |
| [空间站headless](../jiaoben/logs/station-v3-test-headless.log)、[空间站原生](../jiaoben/logs/station-v3-test-native.log) | 各114/114 PASS；3项运行资源 | 原资产/核心内容摘要、实际模型导入、材质、碰撞/锚点/世界姿态保持、幂等和错误对象拒绝。整机与实际包固定诊断另列。 |
| [舰船headless](../jiaoben/logs/ships-v3-contract.log)、[舰船原生](../jiaoben/logs/ships-v3-native-contract.log) | 各410/410 PASS；10个GLB＋shader，共11项运行资源 | 全舰模型/材质、尺寸与原挂点/碰撞保持；原始清单已生成，不代替最终导出包校验。 |
| [资源加载失败](../jiaoben/logs/presentation-failures.log) | headless＋显式CoreAudio 28/28 PASS，严格诊断0 | 真实Main/Store准备路径，玩家/NPC模型失败不推进模拟；读档准备失败保留旧世界/epoch/槽，恢复真实工厂后可再加载并保存。故障对象只属于夹具。 |
| [内置发布端点源码原生](../jiaoben/logs/source-v3-presentation2.log) | 33/33 PASS、6图 | 先行源码运行，包含档案工作台和条件交互；与后续实际包执行分开记录。 |
| [实际Mac Release表现](../jiaoben/logs/0.6.0-3196c031-20261003-054157-mac-presentation.log)、[引擎日志](../jiaoben/logs/0.6.0-3196c031-20261003-054157-mac-presentation-engine.log) | 33/33 PASS、6图，完整日志无错误/警告/泄漏 | 实际打包客户端、Metal/CoreAudio、fresh临时库，非个人档案；不等于额外人工操作或Windows实机验收。 |
| 暂停/档案阶段检查 | 原生布局75/42图，业务headless200/native201，生命周期各27 PASS | 卡片改版时的必要范围；后续HUD修改需对应重验，详见29。 |

原生导航首轮截图发现夹具未切换至飞行相机，已纠正测试路径并增加世界/相机断言；同时修正相机平面投影、竖直天体落雷达中心及紧凑高缩放遮挡。首轮47项不作为最终飞行画面依据；最终headless62项和当前含星空的原生67项/5图已通过。

[整机最终原生汇总](../jiaoben/logs/v3-final-native-acceptance.log) 的六脚本全部PASS、diagnostics=0：导航67/5图、布局75/42图、镜头208、客户端36、物理战斗18和生命周期27。完整独立日志无ERROR、WARNING或泄漏。原始运行资源清单共124项；工业舰船清单文件SHA256为 `fa24829b2f7bbe4923e0535a0dbca32afaacbb94a2254256a70bdd373489a8cb`。这些证明源码和当前本机运行，不推导长期经济平衡、自然通关或稳定帧率。

最终构建 `0.6.0-3196c031-20261003-054157` 已复制到code/dist，源提交 `3196c0313110363f203a28eaddc6fb12d9489d76`，构建时 `source_dirty=false`；[构建身份](../code/dist/0.6.0-3196c031-20261003-054157/build-manifest.json)记录124项原始资源、Mac ad-hoc签名、实际包六项数据库和33项表现检查通过。Windows x64 PE/PCK/DLL与导出通过，原生运行仍未验收。这里采用实际包日志作为发布诊断证据，不拿源码33项代替。

实际包生成首页、机库、NPC、飞行、档案和靠站6图。整合者已查看 [NPC近景](../jiaoben/tmp/release-presentation/b7a35a15-15ad-4fca-bad4-a65372ff10b6/release-npc.png)与 [靠站提示](../jiaoben/tmp/release-presentation/b7a35a15-15ad-4fca-bad4-a65372ff10b6/release-approach.png)；额外人工操作复查当时因Mac锁屏未完成，尚无新人工PASS记录。固定诊断的资格与状态刺激属于明确夹具，不代表自然通关、长期平衡或低配置帧率。

最终结果与包身份由 [26](26-开发阶段与交付记录.md) 记录。所有测试使用独立临时库与独立`--log-file`，不覆盖玩家档案或实际AppSupport日志；Windows实机仍待补验。

## v0.6.1补充：自身舰船可见性与选中连线

状态：本轮源码回归、舰首档案恢复专项与实际Mac发布包验收已通过，macOS/Windows客户端已构建交付；Windows原生运行未验收。用户确认新版本乱码已消失，撤回此前旧版本问题；本补丁仅处理航行中找回自身舰船和淡白色虚线连接已选目标。v0.6的模型、字体、导航及实际包检查属于上一阶段证据。

最近自动档案经只读核对保存了未停靠的舰首视角；该视角本来隐藏自身舰体，而原界面没有明确标识当前模式。补丁在航行HUD展示视角及V切换提示，新增“显示舰船”入口直接恢复默认跟随视角、缩放和观察角度。保留三种模式及原有存档契约，镜头恢复不移动舰船或改变速度；V在HUD悬停时可用，在菜单和文本输入时仍受阻断。

舰船至已选目标的连接线改为低透明度白色虚线，去掉整段深色底轨。目标圈、离屏箭头、目标名称和雷达继续使用既有对象分类颜色；远景天体仍只标“航向参考”。这项样式调整来自用户本轮要求，不声称复刻参考游戏的具体连线或操作机制。

[本轮原生源码汇总](../jiaoben/logs/v061-native-acceptance.log)记录导航67项/5图、布局75项/42图、镜头208项和生命周期27项全部PASS、退出0、严格诊断0。整合者查看1440×900 / 100%及1280×720 / 200%导航截图，舰船可见居中、淡白虚线和四个底部按钮可辨。独立 [源码内置诊断](../jiaoben/logs/source-v061-presentation.log)另为35/35 PASS、6图、诊断0，与下方实际Release执行分开记录。详细范围见 [29补丁记录](29-操控与界面重塑方案.md#v061航行视角与连线补丁)。

[字形覆盖](../jiaoben/logs/font-v061-coverage.json)扩展到825字符，缺字和编码缺陷均0，验证新增HUD文本；字体、原79项资产和核心catalog数据库摘要保持不变。没有将此检查描述为本轮重新修复乱码。

[舰首恢复专项headless](../jiaoben/logs/flight-visibility-v4-headless.log)为44/44 PASS，[Metal/CoreAudio原生](../jiaoben/logs/flight-visibility-v4-native.log)为49/49 PASS，包含3项真实OS悬停和2张截图；均退出0，完整stdout及独立引擎日志无错误、警告、泄漏或FAIL。真实sealed SQLite档案经过保存舰首模式→销毁Main重开继续→“显示舰船”→保存跟随模式再次重开的完整路径，保持舰船姿态和速度。还覆盖工业GLB可见居中、V重复事件/菜单/LineEdit/忙状态阻断及四组尺寸/缩放。整合者查看 [舰首档案恢复前](../jiaoben/logs/flight-visibility-v4-saved-front.png)和 [跟随恢复后](../jiaoben/logs/flight-visibility-v4-recovered-follow.png)，差异明确；专项使用独立库，未改个人档案。

最终交付构建 `0.6.1-74ccdab4-20261003-133018` 使用已推送的源提交 `74ccdab49b0bc98b3402fd8b068f050b6f09f9b0`，`source_dirty=false`，原始运行资源124项。[构建身份](../code/dist/0.6.1-74ccdab4-20261003-133018/build-manifest.json)与 [构建日志](../jiaoben/logs/client-v061-build.log)登记Mac/Windows导出结果。实际Mac包Metal/CoreAudio [表现诊断](../jiaoben/logs/0.6.1-74ccdab4-20261003-133018-mac-presentation.log)35/35 PASS、6图，[数据库检查](../jiaoben/logs/0.6.1-74ccdab4-20261003-133018-mac-database.log)6/6 PASS，原始资源与ad-hoc签名通过；该构建8项导出/诊断/引擎日志未见错误、警告或泄漏，不以源码35项代替。

整合者已查看实际包 [飞行](../jiaoben/tmp/release-presentation/444a75a5-5b57-43fc-b5ca-8ac9701337be/release-flight.png)和 [靠站](../jiaoben/tmp/release-presentation/444a75a5-5b57-43fc-b5ca-8ac9701337be/release-approach.png)截图：舰船可见，站点连线为淡白虚线。code/dist对应目录提供Mac `.app`与ZIP、Windows ZIP、构建身份和摘要；完整链接及摘要见 [26](26-开发阶段与交付记录.md)。Windows PE/PCK/SQLite DLL及导出检查通过，原生运行仍待验；固定诊断使用独立临时库，不等于额外人工试玩或自然通关。

## v0.6.2补充：目标轮廓与名称单层显示

状态：源码目标标记专项、三项原生回归及37项内置源码诊断已通过；实际发布包仍待验收。用户反馈静止时选中目标模型和名称也像两层；已确认旧UI与导航HUD在同一目标分别画半径15/18的圆圈，名称另有3像素黑描边。HUD叠层已确认，完整3D模型重复未获得同等证据，不把两者混为一个已修复原因。

旧标记层只保留准星；导航HUD统一管理未选小圈和已选四角方框，避免选中圆圈叠加环形3D目标。名称仅由一个无描边、无阴影的Label显示，使用暗底和整数像素位置；目标ID每渲染帧同步，目标切换与销毁不等待遥测刷新。v0.6.1淡白虚线、离屏方向和对象类型配色继续保留。这是本项目UI实现修正，不声称复刻参考游戏的具体标记，也不改变模型、相机、物理或平衡内容。

[独立几何调查](../jiaoben/logs/ghosting-geometry-audit.log)覆盖fresh Main的10星系、88目标、315个Mesh，未发现同坐标叠加、overlay、next_pass或重复Model；GLB为唯一primitive和OPAQUE材质。独立原生探针TAA未启用、3D缩放为1。调查结果只证明该场景未发现完整模型重复，不替代用户个人档案的画面复现。

[目标标记headless](../jiaoben/logs/target-annotations-v5-headless.log)54/54 PASS，[原生](../jiaoben/logs/target-annotations-v5-native.log)58/58 PASS、4图，均退出0，stdout和独立引擎诊断0；[导航原生](../jiaoben/logs/navigation-v062-native.log)67项/5图、[布局](../jiaoben/logs/ui-v062-layout.log)75项/42图、[生命周期](../jiaoben/logs/lifecycle-v062.log)27项也全部PASS、退出0、严格诊断0。这里直接引用本轮独立日志，不沿用旧版汇总标签。

整合者查看专项 [空间站](../jiaoben/logs/target-annotations-v5-station.png)、[虫洞门](../jiaoben/logs/target-annotations-v5-gate.png)、[NPC](../jiaoben/logs/target-annotations-v5-npc.png)样本，名称单层清晰、方框与虚线正确，未见完整模型副本。NPC是独立临时runtime SQLite原型DTO经正式`world.sync_entities`加载的视觉夹具，不表示自然任务解锁；第四图为 [运动目标](../jiaoben/logs/target-annotations-v5-moving-target.png)。这些结论限于专项场景和已查看样本，不宣称用户个人档案的全部模型重影已解决。

[37项内置源码诊断](../jiaoben/logs/source-v062-presentation.log)、[独立引擎日志](../jiaoben/logs/source-v062-presentation-engine.log)已完成37/37 PASS、6图、退出0、严格诊断0，新增唯一名称、次级标记排除及单一Model检查；该执行是源码运行。实际Mac包37项及Windows导出仍待最终验收，Windows原生运行继续单独待验。结果与范围继续登记 [29](29-操控与界面重塑方案.md) 与 [26](26-开发阶段与交付记录.md)，不使用v0.6.1的35项或本轮源码/专项结果代替实际发布包。
